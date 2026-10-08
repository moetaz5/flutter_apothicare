import 'dart:convert';
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class StepDetail {
  final String instruction;
  final String streetName;
  final String type;
  final String modifier;
  final double distanceMeters;
  final LatLng location;

  StepDetail({
    required this.instruction,
    required this.streetName,
    required this.type,
    required this.modifier,
    required this.distanceMeters,
    required this.location,
  });
}

class RouteInfo {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final List<String> steps;
  final List<StepDetail> stepDetails;
  final String summary;

  RouteInfo({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    this.steps = const [],
    this.stepDetails = const [],
    this.summary = '',
  });
}

class InAppRouteService {
  static Future<RouteInfo?> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    String profile = 'driving', // 'driving' or 'walking'
  }) async {
    try {
      // Query OSRM road network for accurate geometry, distance & steps
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;

          final List<LatLng> polylinePoints = coordinates.map<LatLng>((c) {
            final double lng = (c[0] as num).toDouble();
            final double lat = (c[1] as num).toDouble();
            return LatLng(lat, lng);
          }).toList();

          final double distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
          final double distanceKm = distanceMeters / 1000.0;
          final double driveDurationSec = (route['duration'] as num?)?.toDouble() ?? 0.0;

          // Realistic duration calculation:
          // - Walking: ~4.8 km/h (80 meters / min ≈ 12.5 min per km)
          // - Driving: OSRM driving duration in seconds
          final int calculatedDurationMin = profile == 'walking'
              ? math.max(1, (distanceMeters / 80.0).ceil())
              : math.max(1, (driveDurationSec / 60.0).ceil());

          final List<String> instructionSteps = [];
          final List<StepDetail> detailedSteps = [];

          if (route['legs'] != null && (route['legs'] as List).isNotEmpty) {
            final leg = route['legs'][0];
            if (leg['steps'] != null) {
              for (var step in leg['steps']) {
                final maneuver = step['maneuver'];
                final name = (step['name'] as String?) ?? '';
                final stepDist = (step['distance'] as num?)?.toDouble() ?? 0.0;
                final locationCoords = maneuver != null && maneuver['location'] != null
                    ? maneuver['location'] as List
                    : null;
                final LatLng stepLoc = locationCoords != null && locationCoords.length >= 2
                    ? LatLng((locationCoords[1] as num).toDouble(), (locationCoords[0] as num).toDouble())
                    : destination;

                if (maneuver != null && maneuver['type'] != null) {
                  final type = maneuver['type'] as String;
                  final modifier = (maneuver['modifier'] as String?) ?? '';
                  String text = _formatInstruction(type, modifier, name, profile == 'walking');
                  if (text.isNotEmpty) {
                    instructionSteps.add(text);
                    detailedSteps.add(
                      StepDetail(
                        instruction: text,
                        streetName: name,
                        type: type,
                        modifier: modifier,
                        distanceMeters: stepDist,
                        location: stepLoc,
                      ),
                    );
                  }
                }
              }
            }
          }

          return RouteInfo(
            points: polylinePoints,
            distanceKm: distanceKm,
            durationMinutes: calculatedDurationMin,
            steps: instructionSteps,
            stepDetails: detailedSteps,
            summary: route['legs']?[0]?['summary'] ?? '',
          );
        }
      }
    } catch (_) {
      // Fallback
    }

    // Fallback if network offline or OSRM unavailable
    final double directDistKm = _calcDistance(origin, destination);
    final int fallbackDurationMin = profile == 'walking'
        ? math.max(1, (directDistKm * 1000.0 / 80.0).ceil())
        : math.max(1, (directDistKm * 2.5).ceil());

    return RouteInfo(
      points: [origin, destination],
      distanceKm: directDistKm,
      durationMinutes: fallbackDurationMin,
      steps: [profile == 'walking' ? 'Marchez vers la pharmacie' : 'Dirigez-vous vers la pharmacie'],
      stepDetails: [
        StepDetail(
          instruction: profile == 'walking' ? 'Marchez vers la pharmacie' : 'Dirigez-vous vers la pharmacie',
          streetName: '',
          type: 'depart',
          modifier: '',
          distanceMeters: directDistKm * 1000,
          location: destination,
        ),
      ],
    );
  }

  static String _formatInstruction(String type, String modifier, String street, [bool isWalking = false]) {
    final streetName = street.isNotEmpty ? ' vers $street' : '';
    switch (type) {
      case 'depart':
        return isWalking ? 'Départ à pied$streetName' : 'Départ en voiture$streetName';
      case 'arrive':
        return 'Vous êtes arrivé à la pharmacie !';
      case 'turn':
        if (modifier == 'left' || modifier == 'sharp left' || modifier == 'slight left') {
          return 'Tournez à gauche$streetName';
        } else if (modifier == 'right' || modifier == 'sharp right' || modifier == 'slight right') {
          return 'Tournez à droite$streetName';
        }
        return 'Tournez$streetName';
      case 'continue':
      case 'new name':
        return isWalking ? 'Continuez à pied$streetName' : 'Continuez tout droit$streetName';
      case 'roundabout':
      case 'rotary':
        return isWalking ? 'Traversez le rond-point$streetName' : 'Prenez le rond-point$streetName';
      default:
        return 'Continuez$streetName';
    }
  }

  static double _calcDistance(LatLng p1, LatLng p2) {
    const double p = 0.017453292519943295;
    final double a = 0.5 -
        ((p2.latitude - p1.latitude) * p / 2) * ((p2.latitude - p1.latitude) * p / 2) +
        ((p1.latitude * p) * (p2.latitude * p)) * ((p2.longitude - p1.longitude) * p / 2) * ((p2.longitude - p1.longitude) * p / 2);
    return 12742 * (a > 0 ? a : 0);
  }

  static double calculateBearing(LatLng start, LatLng end) {
    final double startLat = start.latitude * (math.pi / 180.0);
    final double startLng = start.longitude * (math.pi / 180.0);
    final double endLat = end.latitude * (math.pi / 180.0);
    final double endLng = end.longitude * (math.pi / 180.0);

    final double dLng = endLng - startLng;

    final double y = math.sin(dLng) * math.cos(endLat);
    final double x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    double bearing = math.atan2(y, x) * (180.0 / math.pi);
    return (bearing + 360.0) % 360.0;
  }

  static LatLngBounds createBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  final List<Function(Map<String, dynamic> data)> _messageListeners = [];

  bool get isConnected => _isConnected;

  /// Candidate WebSocket URLs to attempt connection
  static const List<String> _wsUrls = [
    'wss://www.apothicare.tn/',
    'ws://www.apothicare.tn:4001/',
    'ws://localhost:4001/',
    'ws://10.0.2.2:4001/',
  ];

  int _currentUrlIndex = 0;

  /// Connect to the Apothicare real-time WebSocket server
  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;
    _reconnectTimer?.cancel();

    final url = _wsUrls[_currentUrlIndex];
    try {
      debugPrint('[WebSocketService] Connecting to $url ...');
      _socket = await WebSocket.connect(url).timeout(const Duration(seconds: 4));
      _isConnected = true;
      _isConnecting = false;
      debugPrint('[WebSocketService] Connected successfully to $url');

      _socket!.listen(
        (event) {
          _handleIncomingMessage(event);
        },
        onDone: () {
          debugPrint('[WebSocketService] Disconnected.');
          _onDisconnected();
        },
        onError: (err) {
          debugPrint('[WebSocketService] Error: $err');
          _onDisconnected();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[WebSocketService] Connection failed to $url: $e');
      _onDisconnected();
    }
  }

  void _handleIncomingMessage(dynamic event) {
    try {
      debugPrint('[WebSocketService] Frame received: $event');
      Map<String, dynamic> data = {};
      if (event is String) {
        final decoded = jsonDecode(event);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      }
      for (final listener in _messageListeners) {
        try {
          listener(data);
        } catch (e) {
          debugPrint('[WebSocketService] Listener error: $e');
        }
      }
    } catch (e) {
      debugPrint('[WebSocketService] Parse error: $e');
    }
  }

  void _onDisconnected() {
    _isConnected = false;
    _isConnecting = false;
    _socket = null;
    
    // Rotate url index if failed
    _currentUrlIndex = (_currentUrlIndex + 1) % _wsUrls.length;

    // Schedule auto-reconnect in 5 seconds
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connect();
    });
  }

  /// Add a listener for real-time WebSocket events
  void addListener(Function(Map<String, dynamic> data) listener) {
    if (!_messageListeners.contains(listener)) {
      _messageListeners.add(listener);
    }
  }

  /// Remove listener
  void removeListener(Function(Map<String, dynamic> data) listener) {
    _messageListeners.remove(listener);
  }

  /// Disconnect WebSocket cleanly
  void disconnect() {
    _reconnectTimer?.cancel();
    _isConnected = false;
    _isConnecting = false;
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
  }
}

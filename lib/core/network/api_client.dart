import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../constants/app_constants.dart';
import '../storage/storage_service.dart';

class CachedResponse {
  final Response response;
  final DateTime timestamp;
  final Duration ttl;

  CachedResponse(this.response, {Duration? ttl})
      : timestamp = DateTime.now(),
        ttl = ttl ?? const Duration(seconds: 45);

  bool get isValid => DateTime.now().difference(timestamp) < ttl;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio dio;
  final Map<String, CachedResponse> _cache = {};

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.backBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 10),
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        responseDecoder: (List<int> responseBytes, RequestOptions options, ResponseBody responseBody) {
          List<int> bytes = responseBytes;
          // Strip UTF-8 BOM if present (0xEF, 0xBB, 0xBF)
          if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
            bytes = bytes.sublist(3);
          }
          try {
            return utf8.decode(bytes);
          } on FormatException {
            try {
              return latin1.decode(bytes);
            } catch (_) {
              return utf8.decode(bytes, allowMalformed: true);
            }
          } catch (_) {
            try {
              return latin1.decode(bytes);
            } catch (_) {
              return utf8.decode(bytes, allowMalformed: true);
            }
          }
        },
      ),
    );

    // Fast HTTP client adapter with connection reuse & SSL bypass for Android emulator
    final adapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 8);
        client.idleTimeout = const Duration(seconds: 15);
        client.maxConnectionsPerHost = 20;
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );
    dio.httpClientAdapter = adapter;

    // Interceptor to add headers automatically for all routes matching React fetch()
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Accept'] = 'application/json';
          if (options.data is! FormData) {
            options.headers['Content-Type'] = 'application/json';
          }

          final isPublicAuth = options.path.contains('user/login') ||
              options.path.contains('user/addInscription') ||
              options.path.contains('user/sendMail');

          if (!isPublicAuth) {
            final token = StorageService.getToken();
            if (token != null && token.isNotEmpty) {
              options.headers['x-access-token'] = token;
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          return handler.next(e);
        },
      ),
    );
  }

  void clearCache([String? keyPrefix]) {
    if (keyPrefix != null) {
      _cache.removeWhere((k, _) => k.startsWith(keyPrefix));
    } else {
      _cache.clear();
    }
  }

  Response _processResponse(Response response) {
    if (response.data is String) {
      String str = (response.data as String).trim();
      while (str.isNotEmpty && (str.startsWith('\uFEFF') || str.codeUnitAt(0) == 65279 || str.codeUnitAt(0) == 0)) {
        str = str.substring(1).trim();
      }
      try {
        response.data = jsonDecode(str);
      } catch (_) {}
    }
    return response;
  }

  // GET Request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool useCache = false,
    bool forceRefresh = false,
    Duration? cacheDuration,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final cacheKey = 'GET:$path:${queryParameters?.toString()}';
    if (forceRefresh) {
      _cache.remove(cacheKey);
    } else if (useCache && _cache.containsKey(cacheKey) && _cache[cacheKey]!.isValid) {
      return _cache[cacheKey]!.response;
    }

    final response = await dio
        .get(path, queryParameters: queryParameters, options: options)
        .timeout(timeout);

    _processResponse(response);

    if (useCache && response.statusCode == 200) {
      _cache[cacheKey] = CachedResponse(response, ttl: cacheDuration);
    }
    return response;
  }

  // POST Request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool useCache = false,
    bool forceRefresh = false,
    Duration? cacheDuration,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final cacheKey = 'POST:$path:${data?.toString()}:${queryParameters?.toString()}';
    if (forceRefresh) {
      _cache.remove(cacheKey);
    } else if (forceRefresh == false && useCache && _cache.containsKey(cacheKey) && _cache[cacheKey]!.isValid) {
      return _cache[cacheKey]!.response;
    }

    final response = await dio
        .post(path, data: data, queryParameters: queryParameters, options: options)
        .timeout(timeout);

    _processResponse(response);

    if (useCache && response.statusCode == 200) {
      _cache[cacheKey] = CachedResponse(response, ttl: cacheDuration);
    }
    return response;
  }

  // PUT Request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    clearCache(path.split('/').first);
    final response = await dio
        .put(path, data: data, queryParameters: queryParameters, options: options)
        .timeout(timeout);
    return _processResponse(response);
  }

  // DELETE Request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    clearCache(path.split('/').first);
    final response = await dio
        .delete(path, data: data, queryParameters: queryParameters, options: options)
        .timeout(timeout);
    return _processResponse(response);
  }
}



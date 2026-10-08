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
  ];

  int _currentUrlIndex = 0;
  int _consecutiveFailures = 0;

  /// Connect to the Apothicare real-time WebSocket server
  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;
    _reconnectTimer?.cancel();

    final url = _wsUrls[_currentUrlIndex];
    try {
      _socket = await WebSocket.connect(url).timeout(const Duration(seconds: 3));
      _isConnected = true;
      _isConnecting = false;
      _consecutiveFailures = 0;
      debugPrint('[WebSocketService] Connected successfully to $url');

      _socket!.listen(
        (event) {
          _handleIncomingMessage(event);
        },
        onDone: () {
          _onDisconnected();
        },
        onError: (_) {
          _onDisconnected();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _onDisconnected();
    }
  }

  void _handleIncomingMessage(dynamic event) {
    try {
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
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _onDisconnected() {
    _isConnected = false;
    _isConnecting = false;
    _socket = null;
    _consecutiveFailures++;

    // Rotate url index if failed
    _currentUrlIndex = (_currentUrlIndex + 1) % _wsUrls.length;

    // Gradual backoff retry (30s to prevent spamming logs or draining battery)
    final retrySeconds = _consecutiveFailures > 2 ? 30 : 10;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: retrySeconds), () {
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

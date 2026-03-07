import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';

/// Service WebSocket pour recevoir les notifications temps reel.
class WsService {
  static final WsService _instance = WsService._internal();
  factory WsService() => _instance;
  WsService._internal();

  WebSocketChannel? _channel;
  final _controller = StreamController<WsEvent>.broadcast();

  Stream<WsEvent> get events => _controller.stream;

  void connect() {
    final wsUrl = ApiConfig.baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://')
        .replaceFirst('/api/v1', '/ws');

    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _channel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _controller.add(WsEvent(
            type: json['type'] as String,
            payload: json['payload'],
          ));
        } catch (_) {}
      },
      onDone: () {
        // Reconnexion automatique apres 3 secondes
        Future.delayed(const Duration(seconds: 3), connect);
      },
      onError: (_) {
        Future.delayed(const Duration(seconds: 3), connect);
      },
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}

class WsEvent {
  final String type;
  final dynamic payload;

  const WsEvent({required this.type, this.payload});
}

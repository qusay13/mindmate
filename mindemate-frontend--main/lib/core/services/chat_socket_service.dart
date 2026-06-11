import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/environment.dart';
import '../storage/secure_storage_service.dart';

final chatSocketServiceProvider = Provider<ChatSocketService>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return ChatSocketService(secureStorage: secureStorage);
});

class ChatSocketService {
  final SecureStorageService _secureStorage;
  WebSocketChannel? _channel;

  ChatSocketService({required SecureStorageService secureStorage}) : _secureStorage = secureStorage;

  Future<Stream<dynamic>> connect(String conversationId) async {
    final token = await _secureStorage.getAccessToken();
    if (token == null) {
      throw Exception('Authentication token missing. Cannot connect to chat.');
    }

    final wsUrl = '${Environment.wsUrl}/chat/$conversationId/?token=$token';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    return _channel!.stream.map((event) => jsonDecode(event));
  }

  void sendMessage({
    required String content,
    String messageType = 'TEXT',
    String? clientMsgId,
  }) {
    if (_channel != null) {
      final payload = {
        'type': 'message',
        'message': content,
        'message_type': messageType,
        'client_msg_id': clientMsgId,
      };
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  void sendTyping(bool isTyping) {
    if (_channel != null) {
      final payload = {
        'type': isTyping ? 'typing' : 'stop_typing',
      };
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  void sendReadReceipt() {
    if (_channel != null) {
      final payload = {
        'type': 'messages_read',
      };
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
  }
}

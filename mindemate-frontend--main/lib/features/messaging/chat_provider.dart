import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/services/chat_socket_service.dart';
import '../../shared/models/app_models.dart';
import '../auth/auth_provider.dart';

// Fetch active conversations list
class ConversationsNotifier extends StateNotifier<AsyncValue<List<ConversationModel>>> {
  final ApiClient _apiClient;

  ConversationsNotifier({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(const AsyncValue.loading()) {
    fetchConversations();
  }

  Future<void> fetchConversations() async {
    try {
      final response = await _apiClient.get('/chat/conversations/?archived=false');
      if (response.statusCode == 200) {
        final list = (response.data as List)
            .map((item) => ConversationModel.fromJson(item))
            .toList();
        state = AsyncValue.data(list);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<bool> toggleArchive(String conversationId) async {
    try {
      final response = await _apiClient.post('/chat/conversations/$conversationId/archive/');
      if (response.statusCode == 200) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> deleteConversation(String conversationId) async {
    try {
      final response = await _apiClient.delete('/chat/conversations/$conversationId/');
      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }
    } catch (_) {}
    return false;
  }
}

final conversationsProvider = StateNotifierProvider<ConversationsNotifier, AsyncValue<List<ConversationModel>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ConversationsNotifier(apiClient: apiClient);
});

// Fetch archived conversations list
class ArchivedConversationsNotifier extends StateNotifier<AsyncValue<List<ConversationModel>>> {
  final ApiClient _apiClient;

  ArchivedConversationsNotifier({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(const AsyncValue.loading()) {
    fetchConversations();
  }

  Future<void> fetchConversations() async {
    try {
      final response = await _apiClient.get('/chat/conversations/?archived=true');
      if (response.statusCode == 200) {
        final list = (response.data as List)
            .map((item) => ConversationModel.fromJson(item))
            .toList();
        state = AsyncValue.data(list);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final archivedConversationsProvider = StateNotifierProvider<ArchivedConversationsNotifier, AsyncValue<List<ConversationModel>>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ArchivedConversationsNotifier(apiClient: apiClient);
});

// Manage active conversation messages and WebSocket stream
class ChatMessagesState {
  final List<ChatMessageModel> messages;
  final bool isLoading;
  final String? cursor;
  final bool isConnected;
  final bool isOtherTyping;
  final bool? isOtherOnline;
  final String? otherLastSeen;

  ChatMessagesState({
    required this.messages,
    required this.isLoading,
    this.cursor,
    required this.isConnected,
    this.isOtherTyping = false,
    this.isOtherOnline,
    this.otherLastSeen,
  });

  factory ChatMessagesState.initial() => ChatMessagesState(
        messages: [],
        isLoading: false,
        isConnected: false,
        isOtherTyping: false,
      );

  ChatMessagesState copyWith({
    List<ChatMessageModel>? messages,
    bool? isLoading,
    String? cursor,
    bool? isConnected,
    bool? isOtherTyping,
    bool? isOtherOnline,
    String? otherLastSeen,
  }) {
    return ChatMessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      cursor: cursor ?? this.cursor,
      isConnected: isConnected ?? this.isConnected,
      isOtherTyping: isOtherTyping ?? this.isOtherTyping,
      isOtherOnline: isOtherOnline ?? this.isOtherOnline,
      otherLastSeen: otherLastSeen ?? this.otherLastSeen,
    );
  }
}

class ChatMessagesNotifier extends StateNotifier<ChatMessagesState> {
  final ApiClient _apiClient;
  final ChatSocketService _socketService;
  final String _conversationId;
  final Ref _ref;

  ChatMessagesNotifier({
    required ApiClient apiClient,
    required ChatSocketService socketService,
    required String conversationId,
    required Ref ref,
  })  : _apiClient = apiClient,
        _socketService = socketService,
        _conversationId = conversationId,
        _ref = ref,
        super(ChatMessagesState.initial()) {
    _init();
  }

  Future<void> _init() async {
    await fetchMessages();
    await _connectWebSocket();
    await markAsRead();
  }

  Future<void> fetchMessages() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiClient.get('/chat/conversations/$_conversationId/messages/');
      if (response.statusCode == 200) {
        final rawResults = response.data['results'] as List<dynamic>? ?? [];
        final messages = rawResults.map((m) => ChatMessageModel.fromJson(m)).toList();
        
        // Reverse so that index 0 is oldest and index N is newest for rendering bottom-up
        final reversedMessages = messages.reversed.toList();
        state = state.copyWith(
          messages: reversedMessages,
          cursor: response.data['next']?.toString(),
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _connectWebSocket() async {
    try {
      final stream = await _socketService.connect(_conversationId);
      state = state.copyWith(isConnected: true);
      
      stream.listen(
        (data) {
          final type = data['type'];
          if (type == 'message') {
            final msg = ChatMessageModel.fromJson(data);
            final exists = state.messages.any((m) => m.id == msg.id || (m.clientMsgId != null && m.clientMsgId == msg.clientMsgId));
            if (!exists) {
              final index = state.messages.indexWhere((m) => m.clientMsgId != null && m.clientMsgId == msg.clientMsgId);
              if (index != -1) {
                final list = List<ChatMessageModel>.from(state.messages);
                list[index] = msg;
                state = state.copyWith(messages: list);
              } else {
                state = state.copyWith(messages: [...state.messages, msg]);
              }
            }
            if (msg.senderType != 'user') {
              markAsRead();
            }
          } else if (type == 'typing') {
            final senderId = data['sender_id']?.toString();
            if (senderId != _ref.read(authProvider).user?.userId) {
              state = state.copyWith(isOtherTyping: data['is_typing'] ?? false);
            }
          } else if (type == 'user_status') {
            final senderId = data['user_id']?.toString();
            if (senderId != _ref.read(authProvider).user?.userId) {
              final isOnline = data['status'] == 'online';
              state = state.copyWith(
                isOtherOnline: isOnline,
                otherLastSeen: isOnline ? null : DateTime.now().toIso8601String(),
              );
            }
          } else if (type == 'read_receipt') {
            final messageId = data['message_id']?.toString();
            state = state.copyWith(
              messages: state.messages.map((m) {
                if (m.id == messageId) {
                  return m.copyWith(isSeen: true);
                }
                return m;
              }).toList(),
            );
          } else if (type == 'messages_read') {
            state = state.copyWith(
              messages: state.messages.map((m) {
                if (m.senderType == 'user') {
                  return m.copyWith(isSeen: true);
                }
                return m;
              }).toList(),
            );
          } else if (type == 'message_ack') {
            final clientMsgId = data['client_msg_id'];
            final messageId = data['message_id'];
            state = state.copyWith(
              messages: state.messages.map((m) {
                if (m.clientMsgId == clientMsgId) {
                  return m.copyWith(id: messageId, status: 'success');
                }
                return m;
              }).toList(),
            );
            _ref.read(conversationsProvider.notifier).fetchConversations();
          }
        },
        onError: (_) {
          state = state.copyWith(isConnected: false);
        },
        onDone: () {
          state = state.copyWith(isConnected: false);
        },
      );
    } catch (e) {
      state = state.copyWith(isConnected: false);
    }
  }

  void sendMessage(String text) {
    final clientMsgId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMsg = ChatMessageModel(
      id: 'temp_$clientMsgId',
      conversation: _conversationId,
      senderId: _ref.read(authProvider).user?.userId ?? '',
      senderType: 'user',
      content: text,
      messageType: 'TEXT',
      isSeen: false,
      createdAt: DateTime.now().toIso8601String(),
      clientMsgId: clientMsgId,
      status: 'sending',
    );
    state = state.copyWith(messages: [...state.messages, tempMsg]);
    _socketService.sendMessage(
      content: text,
      messageType: 'TEXT',
      clientMsgId: clientMsgId,
    );
  }

  void sendTypingStatus(bool isTyping) {
    _socketService.sendTyping(isTyping);
  }

  Future<void> markAsRead() async {
    try {
      await _apiClient.post('/chat/conversations/$_conversationId/mark-read/');
      _socketService.sendReadReceipt();
      _ref.read(conversationsProvider.notifier).fetchConversations();
    } catch (_) {}
  }

  Future<void> uploadChatFile(XFile file, String messageType) async {
    final clientMsgId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMsg = ChatMessageModel(
      id: 'temp_$clientMsgId',
      conversation: _conversationId,
      senderId: _ref.read(authProvider).user?.userId ?? '',
      senderType: 'user',
      content: file.name,
      messageType: messageType,
      isSeen: false,
      createdAt: DateTime.now().toIso8601String(),
      clientMsgId: clientMsgId,
      status: 'sending',
      progress: 0,
    );
    
    state = state.copyWith(messages: [...state.messages, tempMsg]);

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.name,
        ),
      });

      final response = await _apiClient.post(
        '/chat/upload/',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final fileUrl = response.data['file_url'];
        final responseMsgType = response.data['message_type'] ?? messageType;

        _socketService.sendMessage(
          content: fileUrl,
          messageType: responseMsgType,
          clientMsgId: clientMsgId,
        );

        state = state.copyWith(
          messages: state.messages.map((m) {
            if (m.clientMsgId == clientMsgId) {
              return m.copyWith(content: fileUrl, fileUrl: fileUrl, messageType: responseMsgType, status: 'success');
            }
            return m;
          }).toList(),
        );
        _ref.read(conversationsProvider.notifier).fetchConversations();
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      state = state.copyWith(
        messages: state.messages.map((m) {
          if (m.clientMsgId == clientMsgId) {
            return m.copyWith(status: 'failed');
          }
          return m;
        }).toList(),
      );
    }
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }
}

final chatMessagesProvider = StateNotifierProvider.family<
    ChatMessagesNotifier,
    ChatMessagesState,
    String>((ref, conversationId) {
  final apiClient = ref.watch(apiClientProvider);
  final socketService = ref.watch(chatSocketServiceProvider);
  return ChatMessagesNotifier(
    apiClient: apiClient,
    socketService: socketService,
    conversationId: conversationId,
    ref: ref,
  );
});

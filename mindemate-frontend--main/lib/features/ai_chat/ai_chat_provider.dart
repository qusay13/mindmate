import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

class AiChatMessage {
  final int messageId;
  final String sender; // 'user' or 'bot'
  final String content;
  final String sentAt;

  AiChatMessage({
    required this.messageId,
    required this.sender,
    required this.content,
    required this.sentAt,
  });

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      messageId: json['message_id'] ?? 0,
      sender: json['sender'] ?? 'user',
      content: json['content'] ?? '',
      sentAt: json['sent_at'] ?? '',
    );
  }
}

class AiChatState {
  final List<AiChatMessage> messages;
  final bool isLoading;
  final bool isTyping; // true while waiting for AI response
  final String? errorMessage;

  AiChatState({
    required this.messages,
    required this.isLoading,
    this.isTyping = false,
    this.errorMessage,
  });

  factory AiChatState.initial() => AiChatState(messages: [], isLoading: false, isTyping: false);

  AiChatState copyWith({
    List<AiChatMessage>? messages,
    bool? isLoading,
    bool? isTyping,
    String? errorMessage,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isTyping: isTyping ?? this.isTyping,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AiChatNotifier extends StateNotifier<AiChatState> {
  final ApiClient _apiClient;

  AiChatNotifier({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(AiChatState.initial()) {
    loadConversation();
  }

  Future<void> loadConversation() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiClient.get('/chatbot/conversation/');
      if (response.statusCode == 200) {
        final rawMessages = response.data['messages'] as List<dynamic>? ?? [];
        final messages = rawMessages.map((m) => AiChatMessage.fromJson(m)).toList();
        state = state.copyWith(messages: messages, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> sendMessage(String text) async {
    // Add user message optimistically and activate typing indicator
    final optimisticMsg = AiChatMessage(
      messageId: -1,
      sender: 'user',
      content: text,
      sentAt: DateTime.now().toIso8601String(),
    );
    state = state.copyWith(
      messages: [...state.messages, optimisticMsg],
      isLoading: false,
      isTyping: true,
    );

    try {
      final response = await _apiClient.post(
        '/chatbot/message/',
        data: {'message': text},
      );
      if (response.statusCode == 201) {
        final botMsgJson = response.data['bot_message'];
        final userMsgJson = response.data['user_message'];
        
        final botMsg = AiChatMessage.fromJson(botMsgJson);
        final userMsg = AiChatMessage.fromJson(userMsgJson);

        final updatedList = state.messages.where((m) => m.messageId != -1).toList();
        state = state.copyWith(
          messages: [...updatedList, userMsg, botMsg],
          isLoading: false,
          isTyping: false,
        );
        return true;
      }
      state = state.copyWith(isLoading: false, isTyping: false);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, isTyping: false, errorMessage: e.toString());
      return false;
    }
  }
}

final aiChatProvider = StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AiChatNotifier(apiClient: apiClient);
});

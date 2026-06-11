import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../../core/constants/environment.dart';
import '../../core/theme/app_colors.dart';
import '../../features/messaging/chat_provider.dart';
import '../../shared/models/app_models.dart';

class DoctorChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String doctorName;
  final String doctorTitle;

  const DoctorChatScreen({
    super.key,
    required this.conversationId,
    required this.doctorName,
    required this.doctorTitle,
  });

  @override
  ConsumerState<DoctorChatScreen> createState() => _DoctorChatScreenState();
}

class _DoctorChatScreenState extends ConsumerState<DoctorChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatMessagesProvider(widget.conversationId).notifier).markAsRead();
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      ref.read(chatMessagesProvider(widget.conversationId).notifier).sendTypingStatus(true);
      
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          ref.read(chatMessagesProvider(widget.conversationId).notifier).sendTypingStatus(false);
        }
      });
    } else {
      ref.read(chatMessagesProvider(widget.conversationId).notifier).sendTypingStatus(false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(chatMessagesProvider(widget.conversationId).notifier).sendMessage(text);
    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جاري رفع وصالحة الصورة...', textAlign: TextAlign.right),
            backgroundColor: AppColors.primary,
          ),
        );
      }
      await ref.read(chatMessagesProvider(widget.conversationId).notifier).uploadChatFile(image, 'IMAGE');
      _scrollToBottom();
    }
  }

  String _formatTime(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'م' : 'ص';
      return '$hour:$minute $period';
    } catch (_) {
      return '';
    }
  }

  String _formatLastSeen(String isoString) {
    if (isoString.isEmpty) return 'غير متصل';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'م' : 'ص';
      return 'نشط منذ $hour:$minute $period';
    } catch (_) {
      return 'غير متصل';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatMessagesProvider(widget.conversationId));

    // Find initial online/offline state from the active or archived conversation list
    final conversationsState = ref.watch(conversationsProvider);
    final archivedState = ref.watch(archivedConversationsProvider);

    ConversationModel? conversation = conversationsState.when(
      data: (list) => list.firstWhere(
        (c) => c.id == widget.conversationId,
        orElse: () => ConversationModel(id: '', createdAt: '', otherParty: {}, unreadCount: 0),
      ),
      loading: () => null,
      error: (err, stack) => null,
    );

    if (conversation == null || conversation.id.isEmpty) {
      conversation = archivedState.when(
        data: (list) => list.firstWhere(
          (c) => c.id == widget.conversationId,
          orElse: () => ConversationModel(id: '', createdAt: '', otherParty: {}, unreadCount: 0),
        ),
        loading: () => null,
        error: (err, stack) => null,
      );
    }

    final otherParty = conversation?.otherParty;
    final initialIsOnline = otherParty?['is_online'] == true;
    final initialLastSeen = otherParty?['last_seen']?.toString();

    // Determine online status
    final isOnline = chatState.isOtherOnline ?? initialIsOnline;
    final statusText = isOnline
        ? 'متصل الآن'
        : (chatState.otherLastSeen != null
            ? _formatLastSeen(chatState.otherLastSeen!)
            : (initialLastSeen != null && initialLastSeen.isNotEmpty
                ? _formatLastSeen(initialLastSeen)
                : 'غير متصل'));

    // Auto-scroll to bottom on loaded/updated
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF5F7FF),
                Color(0xFFEDF1FD),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                _buildAppBar(isOnline, statusText, conversation),
                
                // Message List
                Expanded(
                  child: chatState.isLoading && chatState.messages.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                          itemCount: chatState.messages.length + (chatState.isOtherTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == chatState.messages.length && chatState.isOtherTyping) {
                              return _buildTypingIndicator();
                            }
                            final msg = chatState.messages[index];
                            final formattedTime = _formatTime(msg.createdAt);

                            final isMine = msg.senderType == 'user';

                            if (msg.messageType == 'IMAGE') {
                              return _buildImageMessage(msg, formattedTime, isMine);
                            } else if (msg.messageType == 'FILE') {
                              return _buildFileCard(msg, formattedTime, isMine);
                            }

                            if (!isMine) {
                              return _buildDoctorBubble(msg.content, formattedTime);
                            } else {
                              return _buildUserBubble(msg, formattedTime);
                            }
                          },
                        ),
                ),
                // Message Input Field
                _buildInputArea(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isOnline, String statusText, ConversationModel? conversation) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.outline),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          // Doctor Avatar
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  color: AppColors.primaryContainer,
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
              ),
              Positioned(
                bottom: 2,
                left: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Doctor Name & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.doctorName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    color: isOnline ? Colors.green : AppColors.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.outline),
            onSelected: (value) async {
              if (value == 'archive') {
                final success = await ref.read(conversationsProvider.notifier).toggleArchive(widget.conversationId);
                if (success) {
                  ref.read(conversationsProvider.notifier).fetchConversations();
                  ref.read(archivedConversationsProvider.notifier).fetchConversations();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          conversation?.isArchived == true
                              ? 'تم إلغاء أرشفة المحادثة'
                              : 'تم أرشفة المحادثة',
                          textAlign: TextAlign.right,
                        ),
                      ),
                    );
                    Navigator.pop(context);
                  }
                }
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: AlertDialog(
                      title: const Text('حذف المحادثة'),
                      content: const Text('هل أنت متأكد من رغبتك في حذف هذه المحادثة؟ سيتم إخفاؤها من قائمتك.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(foregroundColor: AppColors.error),
                          child: const Text('حذف'),
                        ),
                      ],
                    ),
                  ),
                );
                if (confirm == true) {
                  final success = await ref.read(conversationsProvider.notifier).deleteConversation(widget.conversationId);
                  if (success) {
                    ref.read(conversationsProvider.notifier).fetchConversations();
                    ref.read(archivedConversationsProvider.notifier).fetchConversations();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم حذف المحادثة بنجاح', textAlign: TextAlign.right),
                        ),
                      );
                      Navigator.pop(context);
                    }
                  }
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      conversation?.isArchived == true ? 'إلغاء الأرشفة' : 'أرشفة المحادثة',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.archive_outlined, size: 18),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'حذف المحادثة',
                      style: TextStyle(fontSize: 14, color: AppColors.error),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.doctorName} يكتب الآن...',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.outline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorBubble(String text, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildUserBubble(ChatMessageModel msg, String time) {
    final isSending = msg.status == 'sending';
    final isFailed = msg.status == 'failed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.content,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.outline,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (isSending)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.outline),
                        )
                      else if (isFailed)
                        const Icon(Icons.error_outline, size: 14, color: AppColors.error)
                      else
                        Icon(
                          msg.isSeen ? Icons.done_all : Icons.done,
                          size: 14,
                          color: msg.isSeen ? Colors.green : AppColors.outline,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(ChatMessageModel msg, String time, bool isMine) {
    final isSending = msg.status == 'sending';
    final isFailed = msg.status == 'failed';

    final widgetChild = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: Image.network(
              Environment.getFullImageUrl(msg.content),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade300,
                width: 200,
                height: 150,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.grey, size: 40),
                    SizedBox(height: 4),
                    Text('فشل تحميل الصورة', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey.shade200,
                width: 200,
                height: 150,
                alignment: Alignment.center,
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  color: AppColors.primary,
                ),
              );
            },
            ),
          ),
          if (isSending)
            Container(
              color: Colors.black38,
              padding: const EdgeInsets.all(8),
              child: const CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isMine) const SizedBox(width: 48),
          Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
                child: widgetChild,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: const TextStyle(fontSize: 11, color: AppColors.outline),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    if (isSending)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.outline),
                      )
                    else if (isFailed)
                      const Icon(Icons.error_outline, size: 14, color: AppColors.error)
                    else
                      Icon(
                        msg.isSeen ? Icons.done_all : Icons.done,
                        size: 14,
                        color: msg.isSeen ? Colors.green : AppColors.outline,
                      ),
                  ],
                ],
              ),
            ],
          ),
          if (!isMine) const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildFileCard(ChatMessageModel msg, String time, bool isMine) {
    final isSending = msg.status == 'sending';
    final isFailed = msg.status == 'failed';
    final fileName = msg.content.split('/').isNotEmpty ? msg.content.split('/').last : 'ملف مشترك';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isMine) const SizedBox(width: 48),
          Expanded(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6F6FF),
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.description_outlined, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'ملف مشترك',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.file_download_outlined, color: Color(0xFF276452), size: 24),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تحميل المرفق: $fileName', textAlign: TextAlign.right)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: const TextStyle(fontSize: 11, color: AppColors.outline),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      if (isSending)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.outline),
                        )
                      else if (isFailed)
                        const Icon(Icons.error_outline, size: 14, color: AppColors.error)
                      else
                        Icon(
                          msg.isSeen ? Icons.done_all : Icons.done,
                          size: 14,
                          color: msg.isSeen ? Colors.green : AppColors.outline,
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isMine) const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -5),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary,
            radius: 24,
            child: Transform.rotate(
              angle: 3.14159,
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3FA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك هنا...',
                        hintStyle: TextStyle(color: AppColors.outlineVariant, fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: AppColors.outline, size: 22),
                    onPressed: _pickAndUploadImage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

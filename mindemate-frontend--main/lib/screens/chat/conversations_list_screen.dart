import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/environment.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/messaging/chat_provider.dart';
import '../../shared/models/app_models.dart';
import '../profile/user_profile_screen.dart';
import 'doctor_chat_screen.dart';

class ConversationsListScreen extends ConsumerStatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  ConsumerState<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends ConsumerState<ConversationsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(conversationsProvider.notifier).fetchConversations();
      ref.read(archivedConversationsProvider.notifier).fetchConversations();
    });
  }

  String _formatTime(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final difference = DateTime.now().difference(dateTime);
      if (difference.inDays > 7) {
        return '${dateTime.year}-${dateTime.month}-${dateTime.day}';
      } else if (difference.inDays > 0) {
        return 'منذ ${difference.inDays} يوم';
      } else if (difference.inHours > 0) {
        return 'منذ ${difference.inHours} ساعة';
      } else if (difference.inMinutes > 0) {
        return 'منذ ${difference.inMinutes} دقيقة';
      } else {
        return 'الآن';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationsState = ref.watch(conversationsProvider);
    final archivedState = ref.watch(archivedConversationsProvider);

    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface.withValues(alpha: 0.9),
            elevation: 0,
            centerTitle: false,
            automaticallyImplyLeading: false,
            title: const Text(
              'محادثاتي',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                    ).then((_) {
                      ref.read(conversationsProvider.notifier).fetchConversations();
                      ref.read(archivedConversationsProvider.notifier).fetchConversations();
                    });
                  },
                  child: Consumer(
                    builder: (context, ref, _) {
                      final auth = ref.watch(authProvider);
                      return CircleAvatar(
                        backgroundColor: AppColors.primaryContainer,
                        backgroundImage: auth.user?.profileImage != null && auth.user!.profileImage!.isNotEmpty
                            ? NetworkImage(Environment.getFullImageUrl(auth.user!.profileImage))
                            : null,
                        child: auth.user?.profileImage == null || auth.user!.profileImage!.isEmpty
                            ? Text(
                                auth.user?.fullName.isNotEmpty == true
                                    ? auth.user!.fullName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              )
            ],
            bottom: const TabBar(
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.outline,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: [
                Tab(text: 'المحادثات النشطة'),
                Tab(text: 'المحادثات المؤرشفة'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildConversationsList(conversationsState, isActive: true),
              _buildConversationsList(archivedState, isActive: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsList(AsyncValue<List<ConversationModel>> state, {required bool isActive}) {
    return state.when(
      data: (conversations) {
        if (conversations.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isActive ? Icons.chat_bubble_outline_rounded : Icons.archive_outlined,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isActive ? 'لا توجد محادثات نشطة' : 'لا توجد محادثات مؤرشفة',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isActive
                        ? 'ابدأ محادثة مع طبيبك المرتبط من خلال صفحة الملف الشخصي لتلقي المساعدة والمشورة اليومية.'
                        : 'المحادثات التي تقوم بأرشفتها ستظهر هنا.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.outline,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (isActive) {
              await ref.read(conversationsProvider.notifier).fetchConversations();
            } else {
              await ref.read(archivedConversationsProvider.notifier).fetchConversations();
            }
          },
          color: AppColors.primary,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            itemCount: conversations.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final conv = conversations[index];
              final otherParty = conv.otherParty;
              final name = otherParty['name'] ?? 'طبيب';
              final isOnline = otherParty['is_online'] ?? false;
              final role = otherParty['role'] ?? 'doctor';

              // Resolve last message properties
              String lastMsgText = 'لا توجد رسائل بعد';
              String lastMsgTime = '';
              if (conv.lastMessage != null) {
                lastMsgText = conv.lastMessage!['content'] ?? '';
                lastMsgTime = _formatTime(conv.lastMessage!['created_at'] ?? '');
                if (conv.lastMessage!['message_type'] == 'IMAGE') {
                  lastMsgText = '📷 صورة مشترك';
                } else if (conv.lastMessage!['message_type'] == 'FILE') {
                  lastMsgText = '📁 ملف مشترك';
                }
              }

              final avatarLetter = name.isNotEmpty ? name[0].toUpperCase() : 'U';

              return Card(
                elevation: 0,
                color: AppColors.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: conv.unreadCount > 0
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.outlineVariant.withValues(alpha: 0.2),
                    width: conv.unreadCount > 0 ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DoctorChatScreen(
                          conversationId: conv.id,
                          doctorName: name,
                          doctorTitle: role == 'doctor' ? 'أخصائي نفسي' : 'مريض',
                        ),
                      ),
                    ).then((_) {
                      ref.read(conversationsProvider.notifier).fetchConversations();
                      ref.read(archivedConversationsProvider.notifier).fetchConversations();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        // Avatar with Online indicator
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.primaryContainer,
                              child: Text(
                                avatarLetter,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 1,
                              left: 1,
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
                        const SizedBox(width: 16),
                        // Name and message preview
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  if (lastMsgTime.isNotEmpty)
                                    Text(
                                      lastMsgTime,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.outline,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      lastMsgText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: conv.unreadCount > 0
                                            ? AppColors.onSurface
                                            : AppColors.outline,
                                        fontWeight: conv.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (conv.unreadCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${conv.unreadCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (err, stack) => Center(
        child: Text('فشل تحميل المحادثات: $err', style: const TextStyle(color: AppColors.error)),
      ),
    );
  }
}

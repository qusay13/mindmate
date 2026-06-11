// App Data Models mapping backend models to Dart objects

class UserModel {
  final String userId;
  final String email;
  final String fullName;
  final String? dateOfBirth;
  final String? gender;
  final String? phoneNumber;
  final String? nationality;
  final String? profileImage;
  final bool isActive;
  final bool isOnboarded;
  final bool initialSurveyCompleted;
  final String createdAt;

  UserModel({
    required this.userId,
    required this.email,
    required this.fullName,
    this.dateOfBirth,
    this.gender,
    this.phoneNumber,
    this.nationality,
    this.profileImage,
    required this.isActive,
    required this.isOnboarded,
    required this.initialSurveyCompleted,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      dateOfBirth: json['date_of_birth'],
      gender: json['gender'],
      phoneNumber: json['phone_number'],
      nationality: json['nationality'],
      profileImage: json['profile_image'],
      isActive: json['is_active'] ?? false,
      isOnboarded: json['is_onboarded'] ?? false,
      initialSurveyCompleted: json['initial_survey_completed'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'full_name': fullName,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'phone_number': phoneNumber,
      'nationality': nationality,
      'profile_image': profileImage,
      'is_active': isActive,
      'is_onboarded': isOnboarded,
      'initial_survey_completed': initialSurveyCompleted,
      'created_at': createdAt,
    };
  }
}

class DoctorModel {
  final String doctorId;
  final String fullName;
  final String specialization;
  final String? nationality;
  final String? bio;
  final String? profileImage;
  final String? whatsappNumber;
  final bool isWhatsappVisible;
  final String status;
  final String email;
  final String linkStatus; // 'none', 'pending', 'linked'
  final double averageRating;
  final int ratingsCount;
  final bool isActive;

  DoctorModel({
    required this.doctorId,
    required this.fullName,
    required this.specialization,
    this.nationality,
    this.bio,
    this.profileImage,
    this.whatsappNumber,
    required this.isWhatsappVisible,
    required this.status,
    required this.email,
    required this.linkStatus,
    required this.averageRating,
    required this.ratingsCount,
    required this.isActive,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      doctorId: json['doctor_id'] ?? '',
      fullName: json['full_name'] ?? '',
      specialization: json['specialization'] ?? '',
      nationality: json['nationality'],
      bio: json['bio'],
      profileImage: json['profile_image'],
      whatsappNumber: json['whatsapp_number'],
      isWhatsappVisible: json['is_whatsapp_visible'] ?? false,
      status: json['status'] ?? '',
      email: json['email'] ?? '',
      linkStatus: json['link_status'] ?? 'none',
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      ratingsCount: json['ratings_count'] ?? 0,
      isActive: json['is_active'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doctor_id': doctorId,
      'full_name': fullName,
      'specialization': specialization,
      'nationality': nationality,
      'bio': bio,
      'profile_image': profileImage,
      'whatsapp_number': whatsappNumber,
      'is_whatsapp_visible': isWhatsappVisible,
      'status': status,
      'email': email,
      'link_status': linkStatus,
      'average_rating': averageRating,
      'ratings_count': ratingsCount,
      'is_active': isActive,
    };
  }
}

class AuthResponseModel {
  final String token;
  final String expiresAt;
  final String role;
  final UserModel? user;

  AuthResponseModel({
    required this.token,
    required this.expiresAt,
    required this.role,
    this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      token: json['token'] ?? '',
      expiresAt: json['expires_at'] ?? '',
      role: json['role'] ?? '',
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }
}

class MoodEntryModel {
  final String? moodId;
  final int moodLevel;
  final String? moodLabel;
  final String? reasonNote;
  final String? recordedDate;
  final String? createdAt;

  MoodEntryModel({
    this.moodId,
    required this.moodLevel,
    this.moodLabel,
    this.reasonNote,
    this.recordedDate,
    this.createdAt,
  });

  factory MoodEntryModel.fromJson(Map<String, dynamic> json) {
    return MoodEntryModel(
      moodId: json['mood_id']?.toString(),
      moodLevel: json['mood_level'] ?? 3,
      moodLabel: json['mood_label'],
      reasonNote: json['reason_note'],
      recordedDate: json['recorded_date'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mood_level': moodLevel,
      'reason_note': reasonNote ?? '',
    };
  }
}

class JournalEntryModel {
  final String? journalId;
  final String content;
  final String? entryDate;
  final String? createdAt;
  final String? updatedAt;

  JournalEntryModel({
    this.journalId,
    required this.content,
    this.entryDate,
    this.createdAt,
    this.updatedAt,
  });

  factory JournalEntryModel.fromJson(Map<String, dynamic> json) {
    return JournalEntryModel(
      journalId: json['journal_id']?.toString(),
      content: json['content'] ?? '',
      entryDate: json['entry_date'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
    };
  }
}

class QuestionnaireModel {
  final String questionnaireTypeId;
  final String code;
  final String name;
  final String description;
  final int maxScore;
  final dynamic scoringRanges;

  QuestionnaireModel({
    required this.questionnaireTypeId,
    required this.code,
    required this.name,
    required this.description,
    required this.maxScore,
    this.scoringRanges,
  });

  factory QuestionnaireModel.fromJson(Map<String, dynamic> json) {
    return QuestionnaireModel(
      questionnaireTypeId: json['questionnaire_type_id']?.toString() ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      maxScore: json['max_score'] ?? 0,
      scoringRanges: json['scoring_ranges'],
    );
  }
}

class QuestionOption {
  final int score;
  final String text;

  QuestionOption({required this.score, required this.text});

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      score: json['score'] ?? 0,
      text: json['label'] ?? json['text'] ?? '',
    );
  }
}

class QuestionnaireQuestionModel {
  final int questionId;
  final String questionnaireType;
  final String questionText;
  final int questionOrder;
  final List<QuestionOption> options;

  QuestionnaireQuestionModel({
    required this.questionId,
    required this.questionnaireType,
    required this.questionText,
    required this.questionOrder,
    required this.options,
  });

  factory QuestionnaireQuestionModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    return QuestionnaireQuestionModel(
      questionId: json['question_id'] ?? 0,
      questionnaireType: json['questionnaire_type']?.toString() ?? '',
      questionText: json['question_text'] ?? '',
      questionOrder: json['question_order'] ?? 0,
      options: rawOptions.map((opt) => QuestionOption.fromJson(opt as Map<String, dynamic>)).toList(),
    );
  }
}

class QuestionnaireResultModel {
  final String message;
  final int totalScore;
  final String severityLevel;
  final DoctorModel? suggestedDoctor;

  QuestionnaireResultModel({
    required this.message,
    required this.totalScore,
    required this.severityLevel,
    this.suggestedDoctor,
  });

  factory QuestionnaireResultModel.fromJson(Map<String, dynamic> json) {
    return QuestionnaireResultModel(
      message: json['message'] ?? '',
      totalScore: json['total_score'] ?? 0,
      severityLevel: json['severity_level'] ?? '',
      suggestedDoctor: json['suggested_doctor'] != null ? DoctorModel.fromJson(json['suggested_doctor']) : null,
    );
  }
}

class ChatMessageModel {
  final String id;
  final String? conversation;
  final String senderId;
  final String senderType; // 'user' or 'doctor'
  final String content;
  final String messageType; // 'TEXT', 'IMAGE', 'FILE'
  final String? fileUrl;
  final bool isSeen;
  final String createdAt;
  final String? clientMsgId;
  final String? status; // 'sending', 'success', 'failed'
  final int? progress;

  ChatMessageModel({
    required this.id,
    this.conversation,
    required this.senderId,
    required this.senderType,
    required this.content,
    required this.messageType,
    this.fileUrl,
    required this.isSeen,
    required this.createdAt,
    this.clientMsgId,
    this.status = 'success',
    this.progress = 0,
  });

  ChatMessageModel copyWith({
    String? id,
    String? conversation,
    String? senderId,
    String? senderType,
    String? content,
    String? messageType,
    String? fileUrl,
    bool? isSeen,
    String? createdAt,
    String? clientMsgId,
    String? status,
    int? progress,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversation: conversation ?? this.conversation,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      fileUrl: fileUrl ?? this.fileUrl,
      isSeen: isSeen ?? this.isSeen,
      createdAt: createdAt ?? this.createdAt,
      clientMsgId: clientMsgId ?? this.clientMsgId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
    );
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      conversation: json['conversation']?.toString(),
      senderId: json['sender_id']?.toString() ?? '',
      senderType: json['sender_type'] ?? 'user',
      content: json['message'] ?? json['content'] ?? '',
      messageType: json['message_type'] ?? 'TEXT',
      fileUrl: json['file_url'],
      isSeen: json['is_seen'] ?? false,
      createdAt: json['created_at'] ?? '',
      clientMsgId: json['client_msg_id'],
      status: json['status'] ?? 'success',
      progress: json['progress'] ?? 0,
    );
  }
}

class ConversationModel {
  final String id;
  final String createdAt;
  final Map<String, dynamic>? lastMessage;
  final Map<String, dynamic> otherParty;
  final int unreadCount;
  final bool isArchived;

  ConversationModel({
    required this.id,
    required this.createdAt,
    this.lastMessage,
    required this.otherParty,
    required this.unreadCount,
    this.isArchived = false,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] ?? '',
      createdAt: json['created_at'] ?? '',
      lastMessage: json['last_message'],
      otherParty: json['other_party'] ?? {},
      unreadCount: json['unread_count'] ?? 0,
      isArchived: json['is_archived'] ?? false,
    );
  }
}

class DoctorRequestModel {
  final int requestId;
  final String userId;
  final String userName;
  final String userEmail;
  final String requestType;
  final String status;
  final String requestedAt;

  DoctorRequestModel({
    required this.requestId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.requestType,
    required this.status,
    required this.requestedAt,
  });

  factory DoctorRequestModel.fromJson(Map<String, dynamic> json) {
    return DoctorRequestModel(
      requestId: json['request_id'] ?? 0,
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      userEmail: json['user_email'] ?? '',
      requestType: json['request_type'] ?? '',
      status: json['status'] ?? '',
      requestedAt: json['requested_at'] ?? '',
    );
  }
}

class NotificationModel {
  final int notificationId;
  final String notificationUuid;
  final String title;
  final String? body;
  final String notificationType;
  final String? relatedEntityType;
  final int? relatedEntityId;
  final bool isRead;
  final String createdAt;

  NotificationModel({
    required this.notificationId,
    required this.notificationUuid,
    required this.title,
    this.body,
    required this.notificationType,
    this.relatedEntityType,
    this.relatedEntityId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json['notification_id'] ?? 0,
      notificationUuid: json['notification_uuid'] ?? '',
      title: json['title'] ?? '',
      body: json['body'],
      notificationType: json['notification_type'] ?? 'general',
      relatedEntityType: json['related_entity_type'],
      relatedEntityId: json['related_entity_id'],
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class SurveyQuestionModel {
  final int questionId;
  final String questionText;
  final String questionType; // 'multiple_choice', 'scale', 'yes_no', 'text'
  final String? category;
  final List<String> options;
  final int displayOrder;

  SurveyQuestionModel({
    required this.questionId,
    required this.questionText,
    required this.questionType,
    this.category,
    required this.options,
    required this.displayOrder,
  });

  factory SurveyQuestionModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    return SurveyQuestionModel(
      questionId: json['question_id'] ?? 0,
      questionText: json['question_text'] ?? '',
      questionType: json['question_type'] ?? 'text',
      category: json['category'],
      options: rawOptions.map((e) => e.toString()).toList(),
      displayOrder: json['display_order'] ?? 0,
    );
  }
}

class DailyAnalysisModel {
  final double? wellbeingScore;
  final String? riskLevel;
  final String? riskLabelAr;
  final double? anxietyScore;
  final double? depressionScore;
  final double? stressScore;
  final double? moodScore;
  final String? analysisDate;

  DailyAnalysisModel({
    this.wellbeingScore,
    this.riskLevel,
    this.riskLabelAr,
    this.anxietyScore,
    this.depressionScore,
    this.stressScore,
    this.moodScore,
    this.analysisDate,
  });

  factory DailyAnalysisModel.fromJson(Map<String, dynamic> json) {
    return DailyAnalysisModel(
      wellbeingScore: (json['wellbeing_score'] as num?)?.toDouble(),
      riskLevel: json['risk_level']?.toString(),
      riskLabelAr: json['risk_label_ar']?.toString(),
      anxietyScore: (json['anxiety_score'] as num?)?.toDouble(),
      depressionScore: (json['depression_score'] as num?)?.toDouble(),
      stressScore: (json['stress_score'] as num?)?.toDouble(),
      moodScore: (json['mood_score'] as num?)?.toDouble(),
      analysisDate: json['analysis_date']?.toString(),
    );
  }
}

class PeriodAnalysisModel {
  final double averageWellbeing;
  final String? riskLabelAr;
  final String? stabilityAr;
  final String? trend;
  final String? trendAr;
  final String? overallTrendAr;
  final double? anxietyAvg;
  final double? depressionAvg;
  final double? stressAvg;
  final List<String> recommendationsAr;
  final List<String> adaptiveAdjustmentsAr;

  // 30-day exclusive fields
  final String? anxietyTrend;
  final String? anxietyTrendAr;
  final String? depressionTrend;
  final String? depressionTrendAr;
  final String? stressTrend;
  final String? stressTrendAr;
  final double? firstHalfWellbeing;
  final double? secondHalfWellbeing;
  final double? improvementPercentage;
  final String? periodComparison;
  final String? periodComparisonAr;
  final String? severityTrajectoryAr;
  final double? worstDayScore;
  final double? bestDayScore;
  final double? scoreRange;
  final String? weeklyPatternAr;
  final List<String> domainCorrelationAr;
  final List<double> dailyScores;

  PeriodAnalysisModel({
    required this.averageWellbeing,
    this.riskLabelAr,
    this.stabilityAr,
    this.trend,
    this.trendAr,
    this.overallTrendAr,
    this.anxietyAvg,
    this.depressionAvg,
    this.stressAvg,
    required this.recommendationsAr,
    required this.adaptiveAdjustmentsAr,
    this.anxietyTrend,
    this.anxietyTrendAr,
    this.depressionTrend,
    this.depressionTrendAr,
    this.stressTrend,
    this.stressTrendAr,
    this.firstHalfWellbeing,
    this.secondHalfWellbeing,
    this.improvementPercentage,
    this.periodComparison,
    this.periodComparisonAr,
    this.severityTrajectoryAr,
    this.worstDayScore,
    this.bestDayScore,
    this.scoreRange,
    this.weeklyPatternAr,
    required this.domainCorrelationAr,
    required this.dailyScores,
  });

  factory PeriodAnalysisModel.fromJson(Map<String, dynamic> json) {
    final recs = (json['recommendations_ar'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final adps = (json['adaptive_adjustments_ar'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final corrs = (json['domain_correlation_ar'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final scores = (json['daily_scores'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [];

    return PeriodAnalysisModel(
      averageWellbeing: (json['average_wellbeing'] as num?)?.toDouble() ?? 0.0,
      riskLabelAr: json['risk_label_ar']?.toString(),
      stabilityAr: json['stability_ar']?.toString(),
      trend: json['trend']?.toString() ?? json['overall_trend']?.toString(),
      trendAr: json['trend_ar']?.toString() ?? json['overall_trend_ar']?.toString(),
      overallTrendAr: json['overall_trend_ar']?.toString(),
      anxietyAvg: (json['anxiety_avg'] as num?)?.toDouble(),
      depressionAvg: (json['depression_avg'] as num?)?.toDouble(),
      stressAvg: (json['stress_avg'] as num?)?.toDouble(),
      recommendationsAr: recs,
      adaptiveAdjustmentsAr: adps,
      anxietyTrend: json['anxiety_trend']?.toString(),
      anxietyTrendAr: json['anxiety_trend_ar']?.toString(),
      depressionTrend: json['depression_trend']?.toString(),
      depressionTrendAr: json['depression_trend_ar']?.toString(),
      stressTrend: json['stress_trend']?.toString(),
      stressTrendAr: json['stress_trend_ar']?.toString(),
      firstHalfWellbeing: (json['first_half_wellbeing'] as num?)?.toDouble(),
      secondHalfWellbeing: (json['second_half_wellbeing'] as num?)?.toDouble(),
      improvementPercentage: (json['improvement_percentage'] as num?)?.toDouble(),
      periodComparison: json['period_comparison']?.toString(),
      periodComparisonAr: json['period_comparison_ar']?.toString(),
      severityTrajectoryAr: json['severity_trajectory_ar']?.toString(),
      worstDayScore: (json['worst_day_score'] as num?)?.toDouble(),
      bestDayScore: (json['best_day_score'] as num?)?.toDouble(),
      scoreRange: (json['score_range'] as num?)?.toDouble(),
      weeklyPatternAr: json['weekly_pattern_ar']?.toString(),
      domainCorrelationAr: corrs,
      dailyScores: scores,
    );
  }
}

class AnalysisReportModel {
  final List<DailyAnalysisModel> dailyAnalyses;
  final PeriodAnalysisModel? fifteenDayAnalysis;
  final PeriodAnalysisModel? thirtyDayAnalysis;

  AnalysisReportModel({
    required this.dailyAnalyses,
    this.fifteenDayAnalysis,
    this.thirtyDayAnalysis,
  });

  factory AnalysisReportModel.fromJson(Map<String, dynamic> json) {
    final dailies = (json['daily_analyses'] as List<dynamic>?)
            ?.map((e) => DailyAnalysisModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return AnalysisReportModel(
      dailyAnalyses: dailies,
      fifteenDayAnalysis: json['fifteen_day_analysis'] != null
          ? PeriodAnalysisModel.fromJson(json['fifteen_day_analysis'] as Map<String, dynamic>)
          : null,
      thirtyDayAnalysis: json['thirty_day_analysis'] != null
          ? PeriodAnalysisModel.fromJson(json['thirty_day_analysis'] as Map<String, dynamic>)
          : null,
    );
  }
}

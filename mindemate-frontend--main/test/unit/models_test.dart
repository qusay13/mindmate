import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/shared/models/app_models.dart';

void main() {
  group('App Models JSON Deserialization Tests', () {
    test('UserModel.fromJson parses correctly', () {
      final json = {
        'user_id': 'user123',
        'email': 'user@example.com',
        'full_name': 'Ahmad Ali',
        'is_active': true,
        'is_onboarded': true,
        'initial_survey_completed': true,
        'created_at': '2026-06-06T12:00:00Z',
      };
      final model = UserModel.fromJson(json);
      expect(model.userId, 'user123');
      expect(model.email, 'user@example.com');
      expect(model.fullName, 'Ahmad Ali');
      expect(model.isActive, true);
      expect(model.isOnboarded, true);
      expect(model.initialSurveyCompleted, true);
    });

    test('MoodEntryModel.fromJson parses correctly (Int ID to String check)', () {
      final jsonWithInt = {
        'mood_id': 45,
        'mood_level': 4,
        'mood_label': 'Good',
        'reason_note': 'Had a good day',
        'recorded_date': '2026-06-06',
        'created_at': '2026-06-06T12:00:00Z',
      };
      final model = MoodEntryModel.fromJson(jsonWithInt);
      expect(model.moodId, '45');
      expect(model.moodLevel, 4);
      expect(model.moodLabel, 'Good');
      expect(model.reasonNote, 'Had a good day');
    });

    test('JournalEntryModel.fromJson parses correctly (Int ID to String check)', () {
      final jsonWithInt = {
        'journal_id': 102,
        'content': 'Journal entry content',
        'entry_date': '2026-06-06',
      };
      final model = JournalEntryModel.fromJson(jsonWithInt);
      expect(model.journalId, '102');
      expect(model.content, 'Journal entry content');
    });

    test('QuestionOption.fromJson prioritizes label key over text key', () {
      final jsonLabel = {'score': 3, 'label': 'Very Good'};
      final jsonText = {'score': 2, 'text': 'Good'};
      
      final opt1 = QuestionOption.fromJson(jsonLabel);
      final opt2 = QuestionOption.fromJson(jsonText);
      
      expect(opt1.score, 3);
      expect(opt1.text, 'Very Good');
      expect(opt2.score, 2);
      expect(opt2.text, 'Good');
    });

    test('SurveyQuestionModel.fromJson parses correctly', () {
      final json = {
        'question_id': 1,
        'question_text': 'Rate your stress level',
        'question_type': 'scale',
        'options': [],
        'display_order': 2,
      };
      final model = SurveyQuestionModel.fromJson(json);
      expect(model.questionId, 1);
      expect(model.questionText, 'Rate your stress level');
      expect(model.questionType, 'scale');
      expect(model.options.isEmpty, true);
    });

    test('DailyAnalysisModel.fromJson parses correctly', () {
      final json = {
        'wellbeing_score': 82.5,
        'risk_level': 'healthy',
        'risk_label_ar': 'صحي',
        'anxiety_score': 15.0,
        'depression_score': 10.0,
        'stress_score': 20.0,
      };
      final model = DailyAnalysisModel.fromJson(json);
      expect(model.wellbeingScore, 82.5);
      expect(model.riskLevel, 'healthy');
      expect(model.riskLabelAr, 'صحي');
      expect(model.anxietyScore, 15.0);
    });

    test('PeriodAnalysisModel.fromJson parses correctly', () {
      final json = {
        'average_wellbeing': 75.0,
        'risk_label_ar': 'صحي',
        'stability_ar': 'مستقر',
        'trend_ar': 'تحسن',
        'recommendations_ar': ['Tip 1', 'Tip 2'],
        'adaptive_adjustments_ar': [],
        'domain_correlation_ar': [],
        'daily_scores': [70.0, 75.0, 80.0],
      };
      final model = PeriodAnalysisModel.fromJson(json);
      expect(model.averageWellbeing, 75.0);
      expect(model.trendAr, 'تحسن');
      expect(model.recommendationsAr.length, 2);
      expect(model.dailyScores, [70.0, 75.0, 80.0]);
    });

    test('ConversationModel.fromJson parses correctly with is_archived', () {
      final json = {
        'id': 'conv-uuid-123',
        'created_at': '2026-06-06T12:00:00Z',
        'unread_count': 3,
        'is_archived': true,
        'other_party': {'name': 'Dr. Ahmad', 'role': 'doctor'},
      };
      final model = ConversationModel.fromJson(json);
      expect(model.id, 'conv-uuid-123');
      expect(model.createdAt, '2026-06-06T12:00:00Z');
      expect(model.unreadCount, 3);
      expect(model.isArchived, true);
      expect(model.otherParty['name'], 'Dr. Ahmad');
    });
  });
}

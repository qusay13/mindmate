class DailyProgressState {
  static bool isJournalComplete = false;
  static bool isQuestionnaireComplete = false;
  static bool isMoodTrackerComplete = false;

  static int get completedTasksCount {
    int count = 0;
    if (isJournalComplete) count++;
    if (isQuestionnaireComplete) count++;
    if (isMoodTrackerComplete) count++;
    return count;
  }

  static double get progressPercentage => completedTasksCount / 3.0;
}

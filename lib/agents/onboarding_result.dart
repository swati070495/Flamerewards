class OnboardingResult {
  const OnboardingResult({
    required this.occasion,
    required this.preference,
    required this.goal,
  });

  final String occasion;
  final String preference;
  final String goal;

  String toCohortSignal() {
    return 'New member visits during $occasion, '
        'loves ordering $preference, '
        'and their primary goal is to $goal.';
  }
}

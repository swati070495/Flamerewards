import 'package:genui_template/agents/supabase_service.dart';

class MemberContext {
  MemberContext({
    required this.user,
    required this.orderHistory,
    required this.bonusPaths,
    required this.behaviorPatterns,
    required this.playEarnHistory,
  });

  static const _personaIds = {
    'maya': 'a1b2c3d4-0000-0000-0000-000000000001',
    'jake': 'a1b2c3d4-0000-0000-0000-000000000002',
    'priya': 'a1b2c3d4-0000-0000-0000-000000000003',
  };

  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> orderHistory;
  final List<Map<String, dynamic>> bonusPaths;
  final List<Map<String, dynamic>> behaviorPatterns;
  final List<Map<String, dynamic>> playEarnHistory;

  String get name => user['name'] as String? ?? 'Member';
  String get tier => user['tier'] as String? ?? 'silver';
  int get points => user['points'] as int? ?? 0;
  int get streakDays => user['streak_days'] as int? ?? 0;
  int? get pointsExpiringInDays => user['points_expiring_in_days'] as int?;
  int get visitCount => user['visit_count'] as int? ?? 0;

  bool get hasCompletedQuest =>
      // Demo: Maya's Breakfast Streak counts as completed
      (name == 'Maya' && bonusPaths.any((bp) => bp['title'] == 'Breakfast Streak Champion')) ||
      bonusPaths.any((bp) => bp['is_completed'] == true);

  bool get isLapsed => streakDays == 0 && pointsExpiringInDays != null;

  static Future<MemberContext> forPersona(String name) async {
    final userId = _personaIds[name.toLowerCase()];
    if (userId == null) {
      throw ArgumentError('Unknown persona: $name');
    }
    final svc = SupabaseService.instance;
    final results = await Future.wait([
      svc.fetchUser(userId),
      svc.fetchOrderHistory(userId),
      svc.fetchBonusPaths(userId),
    ]);

    final user = results[0] as Map<String, dynamic>;
    final tier = user['tier'] as String? ?? 'silver';

    final laterResults = await Future.wait([
      svc.fetchBehaviorPatterns(tier),
      svc.fetchPlayEarnHistory(userId),
    ]);

    return MemberContext(
      user: user,
      orderHistory: results[1] as List<Map<String, dynamic>>,
      bonusPaths: results[2] as List<Map<String, dynamic>>,
      behaviorPatterns: laterResults[0] as List<Map<String, dynamic>>,
      playEarnHistory: laterResults[1] as List<Map<String, dynamic>>,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'tier': tier,
        'points': points,
        'streakDays': streakDays,
        'pointsExpiringInDays': pointsExpiringInDays,
        'visitCount': visitCount,
        'orderHistory': orderHistory
            .map(
              (o) => {
                'item': o['item_name'],
                'category': o['category'],
                'price': o['price'],
                'dayOfWeek': o['day_of_week'],
                'timeOfDay': o['time_of_day'],
              },
            )
            .toList(),
        'bonusPaths': bonusPaths
            .map(
              (bp) => {
                'title': bp['title'],
                'description': bp['description'],
                'challengeType': bp['challenge_type'],
                'targetValue': bp['target_value'],
                'currentValue': bp['current_value'],
                'rewardType': bp['reward_type'],
                'rewardDescription': bp['reward_description'],
                'urgencyDays': bp['urgency_days'],
                'isCompleted': bp['is_completed'],
              },
            )
            .toList(),
        'behaviorPatterns': behaviorPatterns
            .map(
              (bp) => {
                'patternName': bp['pattern_name'],
                'description': bp['description'],
                'predictedNextCategory': bp['predicted_next_category'],
                'predictedNextItem': bp['predicted_next_item'],
                'successRate': bp['success_rate'],
              },
            )
            .toList(),
      };
}

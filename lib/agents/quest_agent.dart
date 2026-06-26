import 'dart:convert';

import 'package:genui_template/agents/agent_llm.dart';
import 'package:genui_template/agents/member_context.dart';

class QuestAgent {
  static Future<List<Map<String, dynamic>>> compose({
    required MemberContext member,
    required String tone,
  }) async {
    final orderSummary = _buildOrderSummary(member.orderHistory);

    final patterns = member.behaviorPatterns
        .take(3)
        .map((p) =>
            "${p['pattern_name']}: ${p['description']} "
            "(${p['success_rate']}% success rate)")
        .join('\n');

    final userMessage = '''
MEMBER PROFILE:
Name: ${member.name}
Tier: ${member.tier}
Points: ${member.points}
Streak: ${member.streakDays} days
Tone: $tone

BUYING BEHAVIOR (last 30 days):
$orderSummary

COHORT PATTERNS FOR THIS TIER:
$patterns

YOUR JOB:
Generate 3-4 DIVERSE quest activities. Each quest must be a DIFFERENT activityType. Do NOT repeat the same activityType.

ACTIVITY TYPES (you MUST use at least 3 different ones):

1. "streak" — Visit X days in a row. Show current streak.
   Example: "7-Day Breakfast Streak" — "Visit every morning for a week"
   Must include streakCurrent and streakTarget.

2. "try_new" — Try items from a category they've never ordered.
   Example: "Lunch Explorer" — "You always order breakfast. Try 2 lunch items!"
   Must reference their actual buying pattern.

3. "spend" — Spend a total dollar amount across visits.
   Example: "Big Spender Weekend" — "Spend \$25 this weekend for 3x points"
   Must include spendTarget and spendCurrent.

4. "flash" — Time-limited challenge expiring within hours.
   Example: "Flash: McCafe Happy Hour" — "Order any McCafe drink in the next 4 hours"
   Must include expiresIn (hours).

5. "combo" — Order a specific combination of items in one visit.
   Example: "Breakfast Combo Master" — "Order McMuffin + Coffee + Hash Brown in one order"
   Must include comboItems (list of item names).

6. "refer" — Social/referral challenge.
   Example: "Bring a Friend" — "Refer 1 friend who makes a purchase"
   Must include referralReward.

7. "daypart" — Visit at a specific time they don't usually visit.
   Example: "Night Owl Challenge" — "You're a morning person. Try a dinner visit!"
   Must reference their usual time and challenge the opposite.

8. "category" — Order from a specific menu category X times.
   Example: "McCafe Convert" — "Order 3 drinks this week"
   Must include targetCategory and targetCount.

RULES:
- Pick activities based on their ACTUAL buying behavior
- If they only buy breakfast → give them a lunch/dinner daypart or try_new quest
- If they have a streak → give them a streak quest to protect/extend it
- If they're Gold → include at least one quest with rewardType: spin_wheel
- If they're lapsed → include a flash quest with urgency
- EVERY quest must explain WHY based on their data ("You've ordered 6 breakfasts...")
- Make rewards specific: "Free McFlurry" not just "bonus points"

RESPOND WITH VALID JSON ONLY:
{"quests": [
  {
    "activityType": "streak",
    "title": "Morning Streak",
    "subtitle": "You've hit 4 mornings this week — keep it going!",
    "rewardText": "Free McCafe Coffee",
    "rewardType": "free_item",
    "progressValue": 0.8,
    "progressLabel": "4 of 5 days",
    "urgencyText": null,
    "streakCurrent": 4,
    "streakTarget": 5
  },
  {
    "activityType": "try_new",
    "title": "Lunch Explorer",
    "subtitle": "You always order breakfast. Try 2 lunch items this week!",
    "rewardText": "2x Points on lunch",
    "rewardType": "2x_points",
    "progressValue": 0.0,
    "progressLabel": "0 of 2 items",
    "urgencyText": null,
    "targetCategory": "lunch"
  },
  {
    "activityType": "flash",
    "title": "Flash: Happy Hour",
    "subtitle": "McCafe drinks 50% off for the next 3 hours",
    "rewardText": "50% off McCafe",
    "rewardType": "free_item",
    "progressValue": 0.0,
    "progressLabel": "Order now",
    "urgencyText": "3 hours left",
    "expiresIn": 3
  },
  {
    "activityType": "combo",
    "title": "Breakfast Combo Master",
    "subtitle": "Order McMuffin + Coffee + Hash Brown in one visit",
    "rewardText": "Unlock Spin Wheel",
    "rewardType": "spin_wheel",
    "progressValue": 0.0,
    "progressLabel": "0 of 1 combos",
    "urgencyText": null,
    "comboItems": ["Egg McMuffin", "McCafe Coffee", "Hash Brown"]
  }
]}
''';

    try {
      final response = await AgentLlm.call(
        systemPrompt:
            'You are a McDonald\'s loyalty quest generator. Generate DIVERSE activity types. Respond only with valid JSON, no markdown.',
        userMessage: userMessage,
      );

      var cleaned = response.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '');
        cleaned = cleaned.replaceFirst(RegExp(r'\n?```$'), '');
      }
      cleaned = cleaned.trim();
      if (cleaned.contains('{')) {
        cleaned = cleaned.substring(cleaned.indexOf('{'));
        cleaned = cleaned.substring(0, cleaned.lastIndexOf('}') + 1);
      }

      final data = jsonDecode(cleaned) as Map<String, dynamic>;
      final quests = data['quests'] as List;

      return quests.map<Map<String, dynamic>>((q) {
        final quest = q as Map<String, dynamic>;
        return {
          'type': 'QuestCard',
          'data': <String, dynamic>{
            'activityType': quest['activityType'] ?? 'streak',
            'title': quest['title'] ?? 'Quest',
            'subtitle': quest['subtitle'] ?? '',
            'progressValue': (quest['progressValue'] as num?)?.toDouble() ?? 0.0,
            'progressLabel': quest['progressLabel'] ?? '',
            'rewardText': quest['rewardText'] ?? '',
            'rewardType': quest['rewardType'] ?? 'bonus_points',
            if (quest['urgencyText'] != null) 'urgencyText': quest['urgencyText'],
            if (quest['streakCurrent'] != null) 'streakCurrent': quest['streakCurrent'],
            if (quest['streakTarget'] != null) 'streakTarget': quest['streakTarget'],
            if (quest['spendTarget'] != null) 'spendTarget': quest['spendTarget'],
            if (quest['spendCurrent'] != null) 'spendCurrent': quest['spendCurrent'],
            if (quest['expiresIn'] != null) 'expiresIn': quest['expiresIn'],
            if (quest['comboItems'] != null) 'comboItems': quest['comboItems'],
            if (quest['targetCategory'] != null) 'targetCategory': quest['targetCategory'],
            if (quest['targetCount'] != null) 'targetCount': quest['targetCount'],
            if (quest['referralReward'] != null) 'referralReward': quest['referralReward'],
          },
        };
      }).toList();
    } catch (e) {
      return _fallbackQuests(member);
    }
  }

  static String _buildOrderSummary(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) return 'No purchase history yet (new user)';

    final categories = <String, int>{};
    final timeOfDay = <String, int>{};
    final dayOfWeek = <String, int>{};
    final items = <String>[];

    for (final order in orders) {
      final cat = order['category'] as String? ?? 'unknown';
      final time = order['time_of_day'] as String? ?? 'any';
      final day = order['day_of_week'] as String? ?? 'any';
      final item = order['item_name'] as String? ?? '';

      categories[cat] = (categories[cat] ?? 0) + 1;
      timeOfDay[time] = (timeOfDay[time] ?? 0) + 1;
      dayOfWeek[day] = (dayOfWeek[day] ?? 0) + 1;
      if (item.isNotEmpty) items.add(item);
    }

    final topCategory = categories.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final topTime = timeOfDay.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final topDay = dayOfWeek.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final missingCategories = ['breakfast', 'lunch', 'beverage', 'snack']
        .where((c) => !categories.containsKey(c))
        .toList();

    return '''- Most ordered category: $topCategory (${categories[topCategory]} times)
- All categories: ${categories.entries.map((e) => '${e.key}(${e.value})').join(', ')}
- Preferred time: $topTime (${timeOfDay[topTime]} times)
- Most active day: $topDay
- Never ordered from: ${missingCategories.isEmpty ? 'none' : missingCategories.join(', ')}
- Recent items: ${items.take(5).join(', ')}
- Total orders: ${orders.length}''';
  }

  static List<Map<String, dynamic>> _fallbackQuests(MemberContext member) {
    final tier = member.tier;

    if (tier == 'gold') {
      return [
        {
          'type': 'QuestCard',
          'data': <String, dynamic>{
            'activityType': 'streak',
            'title': 'Breakfast Streak',
            'subtitle': 'Visit 5 mornings this week',
            'progressValue': 0.6,
            'progressLabel': '3 of 5 visits',
            'rewardText': 'Unlock Spin Wheel',
            'rewardType': 'spin_wheel',
            'urgencyText': '2 days left',
            'streakCurrent': 3,
            'streakTarget': 5,
          },
        },
        {
          'type': 'QuestCard',
          'data': <String, dynamic>{
            'activityType': 'try_new',
            'title': 'Lunch Explorer',
            'subtitle': 'Try 2 lunch items you\'ve never ordered',
            'progressValue': 0.0,
            'progressLabel': '0 of 2 items',
            'rewardText': '2x Points',
            'rewardType': '2x_points',
            'targetCategory': 'lunch',
          },
        },
        {
          'type': 'QuestCard',
          'data': <String, dynamic>{
            'activityType': 'flash',
            'title': 'Flash: Happy Hour',
            'subtitle': 'McCafe drinks bonus points right now',
            'progressValue': 0.0,
            'progressLabel': 'Order now',
            'rewardText': '3x Points',
            'rewardType': 'bonus_points',
            'urgencyText': '2 hours left',
            'expiresIn': 2,
          },
        },
      ];
    }

    if (tier == 'platinum') {
      return [
        {
          'type': 'QuestCard',
          'data': <String, dynamic>{
            'activityType': 'combo',
            'title': 'VIP Combo Challenge',
            'subtitle': 'Order Big Mac + McFlurry + Fries in one visit',
            'progressValue': 0.0,
            'progressLabel': '0 of 1 combos',
            'rewardText': 'Spin Free',
            'rewardType': 'spin_wheel',
            'comboItems': ['Big Mac', 'McFlurry', 'Large Fries'],
          },
        },
        {
          'type': 'QuestCard',
          'data': <String, dynamic>{
            'activityType': 'refer',
            'title': 'Platinum Referral',
            'subtitle': 'Invite a friend — you both get 500 pts',
            'progressValue': 0.0,
            'progressLabel': '0 of 1 referrals',
            'rewardText': '+500 each',
            'rewardType': 'bonus_points',
            'referralReward': '500 pts each',
          },
        },
        {
          'type': 'QuestCard',
          'data': <String, dynamic>{
            'activityType': 'spend',
            'title': 'Weekend Feast',
            'subtitle': 'Spend \$30 this weekend for mega bonus',
            'progressValue': 0.4,
            'progressLabel': '\$12 of \$30',
            'rewardText': '+1000 pts',
            'rewardType': 'bonus_points',
            'spendCurrent': 12,
            'spendTarget': 30,
          },
        },
      ];
    }

    // Silver / default
    return [
      {
        'type': 'QuestCard',
        'data': <String, dynamic>{
          'activityType': 'daypart',
          'title': 'Morning Starter',
          'subtitle': 'Try a breakfast visit before 11am',
          'progressValue': 0.0,
          'progressLabel': '0 of 1 visits',
          'rewardText': 'Free Hash Brown',
          'rewardType': 'free_item',
        },
      },
      {
        'type': 'QuestCard',
        'data': <String, dynamic>{
          'activityType': 'category',
          'title': 'McCafe Convert',
          'subtitle': 'Order 2 McCafe drinks this week',
          'progressValue': 0.0,
          'progressLabel': '0 of 2 drinks',
          'rewardText': '+200 pts',
          'rewardType': 'bonus_points',
          'targetCategory': 'beverage',
          'targetCount': 2,
        },
      },
    ];
  }
}

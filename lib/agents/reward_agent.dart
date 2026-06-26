import 'dart:convert';

import 'package:genui_template/agents/agent_llm.dart';
import 'package:genui_template/agents/member_context.dart';

class RewardAgent {
  static const _systemPrompt = '''
You are the FlameRewards Reward Agent for McDonald's loyalty.
Compose a lightweight reward redemption panel.

Rules:
- Always show GoldCoinsBalance first with the member's current points balance
- If recentEarned info available, show it (e.g. "+200 from last quest")
- Show max 3 RewardCarouselItems sorted by affordability (cheapest first that they can afford)
- McDonald's rewards with accurate point costs:
  - Small Fries: 150 pts, emoji 🍟
  - Hash Brown: 200 pts, emoji 🥔
  - McFlurry: 300 pts, emoji 🍦
  - Big Mac: 400 pts, emoji 🍔
  - McCafe Coffee: 250 pts, emoji ☕
  - McNuggets 6pc: 350 pts, emoji 🐔
  - Quarter Pounder: 500 pts, emoji 🍔
- isAffordable = true only if member points >= pointsCost
- Show CheckoutApplyPanel only if points >= 300
  - Pick the best affordable reward as appliedRewardName
  - orderTotal: use a realistic McDonald's order (e.g. 10.99)
  - discountAmount: approximate value of the reward
  - finalTotal: orderTotal - discountAmount
- For lapsed members: add recentEarned like "⚠️ 890 pts expiring in 3 days"
- Bronze: show cheapest rewards only (150-250 pts range)
- Gold/Platinum: show premium rewards first (400-500 pts)

Output ONLY valid JSON — an array of widget objects. No markdown, no explanation.
Example:
[
  {
    "type": "GoldCoinsBalance",
    "data": {
      "balance": 2340,
      "recentEarned": "+200 from Breakfast Streak"
    }
  },
  {
    "type": "RewardCarouselItem",
    "data": {
      "itemName": "Big Mac",
      "emoji": "🍔",
      "pointsCost": 400,
      "isAffordable": true
    }
  },
  {
    "type": "CheckoutApplyPanel",
    "data": {
      "orderTotal": 10.99,
      "discountAmount": 4.99,
      "finalTotal": 6.00,
      "appliedRewardName": "Free Big Mac"
    }
  }
]
''';

  static Future<String> compose({
    required MemberContext member,
  }) async {
    final userMessage = jsonEncode({
      'tier': member.tier,
      'points': member.points,
      'isLapsed': member.isLapsed,
      'pointsExpiringInDays': member.pointsExpiringInDays,
      'streakDays': member.streakDays,
    });

    final response = await AgentLlm.call(
      systemPrompt: _systemPrompt,
      userMessage: userMessage,
    );

    return _extractJson(response);
  }

  static String _extractJson(String response) {
    var s = response.trim();
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```\w*\n?'), '');
      s = s.replaceFirst(RegExp(r'\n?```$'), '');
    }
    if (s.contains('[')) {
      s = s.substring(s.indexOf('['));
      s = s.substring(0, s.lastIndexOf(']') + 1);
    }
    return s;
  }
}

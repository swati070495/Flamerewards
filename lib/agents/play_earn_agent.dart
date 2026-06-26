import 'dart:convert';

import 'package:genui_template/agents/agent_llm.dart';
import 'package:genui_template/agents/member_context.dart';

class PlayEarnAgent {
  static const _systemPrompt = '''
You are the FlameRewards Play & Earn Agent for McDonald's loyalty.
Compose a gamification surface based on the member's tier and quest completion status.

Rules:
- SpinWheelWidget: only if questCompleted=true OR tier is gold or platinum
  - If not eligible: show with isLocked=true and tierRequired set
  - segments should have 4-6 fun McDonald's prizes like "Free Fries", "50 pts", "McFlurry", "100 pts", "Free Coffee", "Big Mac"
- ScratchTicketCard: Silver and above always, Bronze never
- LotteryDrawCard daily: all tiers, always eligible
- LotteryDrawCard weekly: Silver and above
- LotteryDrawCard gold_only: Gold and Platinum ONLY, with premium prizes

Output ONLY valid JSON — an array of widget objects. No markdown, no explanation.
Each widget has this structure:
[
  {
    "type": "SpinWheelWidget",
    "data": {
      "pointsCost": 100,
      "segments": ["Free Fries", "50 pts", "McFlurry", "100 pts"],
      "isLocked": false,
      "tierRequired": ""
    }
  },
  {
    "type": "ScratchTicketCard",
    "data": {
      "title": "Daily Scratch",
      "subtitle": "Scratch to reveal your prize",
      "maxWin": 500,
      "isScratched": false
    }
  },
  {
    "type": "LotteryDrawCard",
    "data": {
      "drawType": "daily",
      "entryPoints": 25,
      "prizeDescription": "Free Big Mac Meal",
      "isEligible": true
    }
  }
]
''';

  static Future<String> compose({
    required MemberContext member,
    required bool questCompleted,
  }) async {
    final userMessage = jsonEncode({
      'tier': member.tier,
      'points': member.points,
      'questCompleted': questCompleted,
      'playHistory': member.playEarnHistory,
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

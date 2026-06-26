import 'dart:convert';

import 'package:genui_template/agents/agent_llm.dart';
import 'package:genui_template/agents/member_context.dart';

class QuestAgent {
  static const _systemPrompt = '''
You are the FlameRewards Quest Agent for McDonald's loyalty.
Given a member's active bonus paths and their buying behavior patterns, compose a personalized bonus path experience using A2UI widget specs.

The goal is to move this user one step up the loyalty ladder:
- If they are a coffee regular, predict they will respond to a breakfast food challenge
- If they are a weekend visitor, predict they will respond to a weekday morning challenge
- If they are a breakfast loyalist, challenge them toward lunch expansion for platinum
- Use the behaviorPatterns data to inform your challenge ordering and messaging

Rules:
- Sort by urgency first (urgencyDays < 3 goes top with urgencyText set)
- Max 3 quest cards
- Bronze tone: encouraging, simple, low friction
- Silver/winback tone: motivating, show what they are close to, highlight expiry
- Gold tone: champion, streak protection, prestige
- Urgency tone: time pressure, loss aversion

Output ONLY valid JSON — an array of QuestCard widget objects. No markdown, no explanation.
Each QuestCard has this exact structure:
[
  {
    "type": "QuestCard",
    "data": {
      "title": "string",
      "subtitle": "string",
      "progressValue": 0.6,
      "progressLabel": "3/5 visits",
      "rewardText": "Unlock Spin Wheel",
      "urgencyText": "2 days left",
      "rewardType": "spin_wheel"
    }
  }
]

rewardType must be one of: spin_wheel, free_item, bonus_points, subscription, 2x_points
progressValue must be between 0.0 and 1.0 (currentValue / targetValue)
urgencyText should only be set if urgencyDays exists and is < 7
''';

  static Future<String> compose({
    required MemberContext member,
    required String tone,
  }) async {
    final userMessage = jsonEncode({
      'tone': tone,
      'member': member.toJson(),
    });

    final response = await AgentLlm.call(
      systemPrompt: _systemPrompt,
      userMessage: userMessage,
    );

    return _extractJson(response);
  }

  static String _extractJson(String response) {
    var s = response.trim();
    // Strip markdown code fences
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```\w*\n?'), '');
      s = s.replaceFirst(RegExp(r'\n?```$'), '');
    }
    // Find the array
    if (s.contains('[')) {
      s = s.substring(s.indexOf('['));
      s = s.substring(0, s.lastIndexOf(']') + 1);
    }
    return s;
  }
}

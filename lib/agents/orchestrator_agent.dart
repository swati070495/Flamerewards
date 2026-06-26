import 'dart:convert';

import 'package:genui_template/agents/agent_llm.dart';
import 'package:genui_template/agents/member_context.dart';

class AgentPlan {
  AgentPlan({
    required this.agents,
    required this.layout,
    required this.tone,
    required this.reasoning,
  });

  final List<String> agents;
  final String layout;
  final String tone;
  final String reasoning;
}

class OrchestratorAgent {
  static const _systemPrompt = '''
You are the FlameRewards Orchestrator for McDonald's loyalty.
Given a McDonald's loyalty member's profile and buying behavior, decide which agents to invoke and in what order.

Tiers: silver, gold, platinum.

Rules:
- Silver member: invoke ["quest", "reward"]
- Gold member with completed quest: invoke ["quest", "play_earn", "reward"]
- Gold member no completed quest: invoke ["quest", "reward"]
- Platinum member: invoke ["quest", "play_earn", "reward"]

Layout options:
- quest_first: default for active members
- reward_first: for lapsed members or those with expiring points
- game_first: for members who just completed a quest

Tone options:
- friendly: default welcoming tone
- celebration: for members who completed quests
- winback: for lapsed members with no streak

Respond ONLY with valid JSON, no markdown, no explanation:
{"agents": ["quest", "play_earn", "reward"], "layout": "quest_first", "tone": "friendly", "reasoning": "one sentence why"}
''';

  static Future<AgentPlan> plan(MemberContext member) async {
    final response = await AgentLlm.call(
      systemPrompt: _systemPrompt,
      userMessage: jsonEncode(member.toJson()),
    );

    try {
      // Extract JSON from response (handle markdown code blocks)
      var jsonStr = response.trim();
      if (jsonStr.contains('{')) {
        jsonStr = jsonStr.substring(jsonStr.indexOf('{'));
        jsonStr = jsonStr.substring(0, jsonStr.lastIndexOf('}') + 1);
      }
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AgentPlan(
        agents: List<String>.from(json['agents'] as List),
        layout: json['layout'] as String? ?? 'quest_first',
        tone: json['tone'] as String? ?? 'friendly',
        reasoning: json['reasoning'] as String? ?? '',
      );
    } catch (_) {
      // Fallback plan based on tier
      return fallbackPlan(member);
    }
  }

  static AgentPlan fallbackPlan(MemberContext member) {
    if (member.isLapsed) {
      return AgentPlan(
        agents: ['reward', 'quest'],
        layout: 'reward_first',
        tone: 'winback',
        reasoning: 'Lapsed member — lead with rewards',
      );
    }
    if (member.hasCompletedQuest) {
      return AgentPlan(
        agents: ['quest', 'play_earn', 'reward'],
        layout: 'quest_first',
        tone: 'celebration',
        reasoning: 'Completed quest — unlock gamification',
      );
    }
    return AgentPlan(
      agents: ['quest', 'reward'],
      layout: 'quest_first',
      tone: 'friendly',
      reasoning: 'Active member — quests and rewards',
    );
  }
}

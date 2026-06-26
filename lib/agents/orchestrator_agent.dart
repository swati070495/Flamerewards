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

Rules:
- Bronze member with no completed quests: invoke ["quest"] only
- Silver lapsed member (streakDays=0, pointsExpiringInDays is set): invoke ["reward", "quest"] — reward urgency first
- Gold member with completed quest: invoke ["quest", "play_earn", "reward"]
- Gold member no completed quest: invoke ["quest", "reward"]
- Platinum member: invoke ["quest", "play_earn", "reward"]

Layout options:
- quest_first: default for active members
- reward_first: for lapsed members or those with expiring points
- game_first: for members who just completed a quest

Tone options:
- urgency: when points or streak expiring in < 3 days
- onboarding: for bronze/new members
- celebration: for members who completed quests
- winback: for lapsed members with no streak

Respond ONLY with valid JSON, no markdown, no explanation:
{"agents": ["quest", "play_earn", "reward"], "layout": "quest_first", "tone": "urgency", "reasoning": "one sentence why"}
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
        tone: json['tone'] as String? ?? 'onboarding',
        reasoning: json['reasoning'] as String? ?? '',
      );
    } catch (_) {
      // Fallback plan based on tier
      return _fallbackPlan(member);
    }
  }

  static AgentPlan _fallbackPlan(MemberContext member) {
    if (member.tier == 'bronze') {
      return AgentPlan(
        agents: ['quest'],
        layout: 'quest_first',
        tone: 'onboarding',
        reasoning: 'New bronze member — onboarding quests only',
      );
    }
    if (member.isLapsed) {
      return AgentPlan(
        agents: ['reward', 'quest'],
        layout: 'reward_first',
        tone: 'winback',
        reasoning: 'Lapsed member — lead with reward urgency',
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
      tone: 'urgency',
      reasoning: 'Active member — quests and rewards',
    );
  }
}

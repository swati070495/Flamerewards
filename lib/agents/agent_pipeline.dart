import 'dart:convert';

import 'package:genui_template/agents/member_context.dart';
import 'package:genui_template/agents/orchestrator_agent.dart';
import 'package:genui_template/agents/play_earn_agent.dart';
import 'package:genui_template/agents/quest_agent.dart';
import 'package:genui_template/agents/reward_agent.dart';

class AgentPipeline {
  /// Compose the full loyalty screen for a member.
  ///
  /// Returns a user message string that, when sent to the GenUI conversation,
  /// will produce the combined widget tree. The message includes the raw A2UI
  /// JSON from all agents so the LLM can render it directly.
  static Future<String> composeForMember(MemberContext member) async {
    // Step 1: Orchestrator decides which agents and in what order
    final plan = await OrchestratorAgent.plan(member);

    // Step 2: Always start with TierStatusBar
    final tierWidget = _tierStatusBarJson(member);

    // Step 3: Invoke agents sequentially per plan
    final agentOutputs = <String>[];
    for (final agent in plan.agents) {
      switch (agent) {
        case 'quest':
          final result = await QuestAgent.compose(
            member: member,
            tone: plan.tone,
          );
          agentOutputs.add(result);
        case 'play_earn':
          final result = await PlayEarnAgent.compose(
            member: member,
            questCompleted: member.hasCompletedQuest,
          );
          agentOutputs.add(result);
        case 'reward':
          final result = await RewardAgent.compose(member: member);
          agentOutputs.add(result);
      }
    }

    // Step 4: Combine all widget specs
    final allWidgets = <dynamic>[tierWidget];
    for (final output in agentOutputs) {
      try {
        final parsed = jsonDecode(output);
        if (parsed is List) {
          allWidgets.addAll(parsed);
        }
      } catch (_) {
        // Skip malformed agent output
      }
    }

    // Step 5: Build the prompt that tells GenUI to render these exact widgets
    final widgetsJson = jsonEncode(allWidgets);
    return '''
Render the following loyalty screen for ${member.name} (${member.tier} tier, ${member.points} pts).

Orchestrator reasoning: ${plan.reasoning}
Layout: ${plan.layout}, Tone: ${plan.tone}

Render these widgets in this exact order as a vertical layout. Do not add, remove, or reorder widgets. Render each one using its type from the catalog with the provided data:

$widgetsJson
''';
  }

  static Map<String, dynamic> _tierStatusBarJson(MemberContext member) {
    final pointsToNext = switch (member.tier) {
      'bronze' => 500 - member.points,
      'silver' => 1500 - member.points,
      'gold' => 3000 - member.points,
      _ => 0,
    };
    return {
      'type': 'TierStatusBar',
      'data': {
        'currentTier': member.tier,
        'pointsToNext': pointsToNext > 0 ? pointsToNext : 0,
      },
    };
  }
}

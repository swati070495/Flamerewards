import 'package:genui_template/agents/cold_start_agent.dart';
import 'package:genui_template/agents/member_context.dart';
import 'package:genui_template/agents/onboarding_result.dart';
import 'package:genui_template/agents/orchestrator_agent.dart';
import 'package:genui_template/agents/play_earn_agent.dart';
import 'package:genui_template/agents/quest_agent.dart';
import 'package:genui_template/agents/reward_agent.dart';

class AgentPipeline {
  static Future<List<Map<String, dynamic>>> composeWidgets(
    MemberContext member, {
    OnboardingResult? onboardingResult,
  }) async {
    // Cold start path for new users with onboarding data
    final isNewUser = member.orderHistory.length < 5;
    if (isNewUser && onboardingResult != null) {
      return ColdStartAgent.compose(
        member: member,
        onboarding: onboardingResult,
      );
    }

    final plan = OrchestratorAgent.fallbackPlan(member);

    final allWidgets = <Map<String, dynamic>>[_tierStatusBarJson(member)];

    // Run agents in parallel
    final futures = <String, Future<List<Map<String, dynamic>>>>{};
    for (final agent in plan.agents) {
      switch (agent) {
        case 'quest':
          futures['quest'] = QuestAgent.compose(member: member, tone: plan.tone);
        case 'play_earn':
          futures['play_earn'] = PlayEarnAgent.compose(member: member, questCompleted: member.hasCompletedQuest);
        case 'reward':
          futures['reward'] = RewardAgent.compose(member: member);
      }
    }

    for (final agent in plan.agents) {
      final result = await futures[agent]!;
      allWidgets.addAll(result);
    }

    return allWidgets;
  }

  static Map<String, dynamic> _tierStatusBarJson(MemberContext member) {
    final pointsToNext = switch (member.tier) {
      'silver' => 1500 - member.points,
      'gold' => 3000 - member.points,
      _ => 0,
    };
    return {
      'type': 'TierStatusBar',
      'data': <String, dynamic>{
        'currentTier': member.tier,
        'pointsToNext': pointsToNext > 0 ? pointsToNext : 0,
      },
    };
  }
}

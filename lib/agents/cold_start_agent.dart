import 'dart:convert';

import 'package:genui_template/agents/agent_llm.dart';
import 'package:genui_template/agents/member_context.dart';
import 'package:genui_template/agents/onboarding_result.dart';
import 'package:genui_template/agents/supabase_service.dart';

class ColdStartAgent {
  static const _systemPrompt = '''
You are the FlameRewards Cold Start Agent. A new McDonald's member answered 3 onboarding questions with no purchase history.

Use SIGNAL 1 (their answers) and SIGNAL 2 (cohort patterns from similar users) to compose their first Quest Track.

Rules:
- Exactly 2 quest cards only
- Quest 1: Easy win, completable on first visit
- Quest 2: Stretch goal from cohort prediction
- Tone: welcoming, low pressure
- Reference why: "users like you who did X..."
- Reward: free item or bonus points only
- progressValue must be 0.0 (new user, no progress yet)

Output ONLY valid JSON — an array of QuestCard widget objects. No markdown, no explanation.
Each QuestCard has this exact structure:
[
  {
    "type": "QuestCard",
    "data": {
      "title": "string",
      "subtitle": "string",
      "progressValue": 0.0,
      "progressLabel": "0/N visits",
      "rewardText": "Free item or bonus points",
      "rewardType": "free_item"
    }
  }
]

rewardType must be one of: free_item, bonus_points
''';

  static Future<List<Map<String, dynamic>>> compose({
    required MemberContext member,
    required OnboardingResult onboarding,
  }) async {
    // Fetch matching behavior patterns from Supabase
    final patterns = await SupabaseService.instance.fetchBehaviorPatterns(
      member.tier,
    );

    // Filter for cold_start patterns
    final coldStartPatterns = patterns
        .where((p) => (p['pattern_name'] as String? ?? '').startsWith('cold_start_'))
        .toList();

    final userMessage = jsonEncode({
      'signal_1_onboarding': onboarding.toCohortSignal(),
      'signal_2_cohort_patterns': coldStartPatterns
          .map((p) => {
                'pattern': p['pattern_name'],
                'description': p['description'],
                'predicted_item': p['predicted_next_item'],
                'success_rate': p['success_rate'],
              })
          .toList(),
      'member': {
        'name': member.name,
        'tier': member.tier,
        'points': member.points,
      },
    });

    final response = await AgentLlm.call(
      systemPrompt: _systemPrompt,
      userMessage: userMessage,
    );

    // Build TierStatusBar
    final pointsToNext = switch (member.tier) {
      'silver' => 1500 - member.points,
      'gold' => 3000 - member.points,
      _ => 0,
    };
    final widgets = <Map<String, dynamic>>[
      {
        'type': 'TierStatusBar',
        'data': <String, dynamic>{
          'currentTier': member.tier,
          'pointsToNext': pointsToNext > 0 ? pointsToNext : 0,
        },
      },
    ];

    // Parse quest cards from LLM response
    try {
      var s = response.trim();
      if (s.startsWith('```')) {
        s = s.replaceFirst(RegExp(r'^```\w*\n?'), '');
        s = s.replaceFirst(RegExp(r'\n?```$'), '');
      }
      if (s.contains('[')) {
        s = s.substring(s.indexOf('['));
        s = s.substring(0, s.lastIndexOf(']') + 1);
      }
      final parsed = jsonDecode(s) as List;
      for (final item in parsed) {
        if (item is Map) {
          widgets.add(Map<String, dynamic>.from(item));
        }
      }
    } catch (_) {
      // Fallback quests if LLM fails
      widgets.addAll(_fallbackQuests(onboarding));
    }

    return widgets;
  }

  static List<Map<String, dynamic>> _fallbackQuests(OnboardingResult onboarding) {
    final item = switch (onboarding.preference) {
      'burgers' => 'Big Mac',
      'drinks' => 'McCafe Coffee',
      'breakfast' => 'Egg McMuffin',
      _ => 'Small Fries',
    };

    return [
      {
        'type': 'QuestCard',
        'data': <String, dynamic>{
          'title': 'Welcome First Visit',
          'subtitle': 'Users like you love starting with a $item. Make your first order!',
          'progressValue': 0.0,
          'progressLabel': '0/1 visits',
          'rewardText': 'Free $item',
          'rewardType': 'free_item',
        },
      },
      {
        'type': 'QuestCard',
        'data': <String, dynamic>{
          'title': 'Build Your Streak',
          'subtitle': 'Visit 3 times this week to unlock bonus points',
          'progressValue': 0.0,
          'progressLabel': '0/3 visits',
          'rewardText': '200 Bonus Points',
          'rewardType': 'bonus_points',
        },
      },
    ];
  }
}

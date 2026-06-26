import 'package:genui_template/agents/member_context.dart';

class PlayEarnAgent {
  static Future<List<Map<String, dynamic>>> compose({
    required MemberContext member,
    required bool questCompleted,
  }) async {
    final tier = member.tier;
    final widgets = <Map<String, dynamic>>[];

    final spinEligible = questCompleted || tier == 'gold' || tier == 'platinum';
    widgets.add({
      'type': 'SpinWheelWidget',
      'data': <String, dynamic>{
        'pointsCost': 100,
        'segments': ['Free Fries', '50 pts', 'McFlurry', '100 pts', 'Free Coffee', 'Big Mac'],
        'isLocked': !spinEligible,
        'tierRequired': spinEligible ? '' : 'gold',
      },
    });

    widgets.add({
      'type': 'ScratchTicketCard',
      'data': <String, dynamic>{
        'title': 'Daily Scratch',
        'subtitle': 'Scratch to reveal your prize!',
        'maxWin': tier == 'platinum' ? 1000 : tier == 'gold' ? 500 : 250,
        'isScratched': false,
      },
    });

    widgets.add({
      'type': 'LotteryDrawCard',
      'data': <String, dynamic>{
        'drawType': 'daily',
        'entryPoints': 25,
        'prizeDescription': 'Free Big Mac Meal',
        'isEligible': true,
      },
    });

    widgets.add({
      'type': 'LotteryDrawCard',
      'data': <String, dynamic>{
        'drawType': 'weekly',
        'entryPoints': 50,
        'prizeDescription': 'Free McDelivery for a Month',
        'isEligible': true,
      },
    });

    if (tier == 'gold' || tier == 'platinum') {
      widgets.add({
        'type': 'LotteryDrawCard',
        'data': <String, dynamic>{
          'drawType': 'gold_only',
          'entryPoints': 100,
          'prizeDescription': 'VIP Golden Arch Experience',
          'isEligible': true,
        },
      });
    }

    return widgets;
  }
}

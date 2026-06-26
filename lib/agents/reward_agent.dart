import 'package:genui_template/agents/member_context.dart';

class RewardAgent {
  static const _rewards = [
    {'name': 'Small Fries', 'emoji': '\u{1F35F}', 'cost': 150, 'value': 2.49},
    {'name': 'Hash Brown', 'emoji': '\u{1F954}', 'cost': 200, 'value': 2.29},
    {'name': 'McCafe Coffee', 'emoji': '\u{2615}', 'cost': 250, 'value': 3.49},
    {'name': 'McFlurry', 'emoji': '\u{1F366}', 'cost': 300, 'value': 4.29},
    {'name': 'McNuggets 6pc', 'emoji': '\u{1F414}', 'cost': 350, 'value': 5.49},
    {'name': 'Big Mac', 'emoji': '\u{1F354}', 'cost': 400, 'value': 5.99},
    {'name': 'Quarter Pounder', 'emoji': '\u{1F354}', 'cost': 500, 'value': 6.99},
  ];

  static Future<List<Map<String, dynamic>>> compose({
    required MemberContext member,
  }) async {
    final pts = member.points;
    final tier = member.tier;
    final isLapsed = member.isLapsed;

    final widgets = <Map<String, dynamic>>[];

    // GoldCoinsBalance
    String? recentEarned;
    if (isLapsed && member.pointsExpiringInDays != null) {
      recentEarned = '$pts pts expiring in ${member.pointsExpiringInDays} days';
    } else if (member.streakDays > 0) {
      recentEarned = '+${member.streakDays * 50} from ${member.streakDays}-day streak';
    }
    final coinsData = <String, dynamic>{'balance': pts};
    if (recentEarned != null) coinsData['recentEarned'] = recentEarned;
    widgets.add({'type': 'GoldCoinsBalance', 'data': coinsData});

    // Pick rewards based on tier
    List<Map<String, Object>> available;
    if (tier == 'gold' || tier == 'platinum') {
      available = _rewards.reversed.where((r) => (r['cost'] as int) <= pts + 200).take(3).toList();
      if (available.isEmpty) available = _rewards.take(3).toList();
    } else {
      available = _rewards.where((r) => (r['cost'] as int) <= 300).take(3).toList();
    }

    for (final r in available) {
      widgets.add({
        'type': 'RewardCarouselItem',
        'data': <String, dynamic>{
          'itemName': r['name'],
          'emoji': r['emoji'],
          'pointsCost': r['cost'],
          'isAffordable': pts >= (r['cost'] as int),
        },
      });
    }

    // CheckoutApplyPanel if enough points
    if (pts >= 300) {
      final bestReward = available.lastWhere(
        (r) => pts >= (r['cost'] as int),
        orElse: () => available.first,
      );
      const orderTotal = 10.99;
      final discount = (bestReward['value'] as double);
      widgets.add({
        'type': 'CheckoutApplyPanel',
        'data': <String, dynamic>{
          'orderTotal': orderTotal,
          'discountAmount': discount,
          'finalTotal': double.parse((orderTotal - discount).toStringAsFixed(2)),
          'appliedRewardName': 'Free ${bestReward['name']}',
        },
      });
    }

    return widgets;
  }
}

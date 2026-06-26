import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Builds the catalog of widgets the model is allowed to generate.
Catalog buildCatalog() => BasicCatalogItems.asCatalog().copyWith(
  newItems: [
    _questCard,
    _tierStatusBar,
    _spinWheelWidget,
    _scratchTicketCard,
    _lotteryDrawCard,
    _goldCoinsBalance,
    _rewardCarouselItem,
    _checkoutApplyPanel,
  ],
);

// ─── Helpers ───────────────────────────────────────────────────────────────

const _flame = Color(0xFFFF4E1A);

String _str(Map<String, Object?>? d, String key, [String fallback = '']) {
  if (d == null) return fallback;
  final v = d[key];
  return v is String ? v : fallback;
}

double _dbl(Map<String, Object?>? d, String key, [double fallback = 0]) {
  if (d == null) return fallback;
  final v = d[key];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

bool _bln(Map<String, Object?>? d, String key, [bool fallback = false]) {
  if (d == null) return fallback;
  final v = d[key];
  return v is bool ? v : fallback;
}

int _int(Map<String, Object?>? d, String key, [int fallback = 0]) {
  if (d == null) return fallback;
  final v = d[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

Color _tierColor(String tier) => switch (tier.toLowerCase()) {
  'silver' => const Color(0xFFC0C0C0),
  'gold' => const Color(0xFFFFD700),
  'platinum' => const Color(0xFFE5E4E2),
  _ => _flame,
};

// ─── 1. QuestCard ──────────────────────────────────────────────────────────

final _questCard = CatalogItem(
  name: 'QuestCard',
  dataSchema: S.object(
    description:
        'A loyalty quest with progress bar, reward pill, and optional urgency.',
    properties: {
      'title': S.string(description: 'Quest title'),
      'subtitle': S.string(description: 'Quest description'),
      'progressValue': S.number(description: 'Progress from 0.0 to 1.0'),
      'progressLabel': S.string(description: 'e.g. "3/5 visits"'),
      'rewardText': S.string(description: 'Reward description'),
      'urgencyText': S.string(
        description: 'Optional urgency like "2 days left"',
      ),
      'rewardType': S.string(
        description: 'Type of reward',
        enumValues: ['spin_wheel', 'free_item', 'bonus_points', 'subscription', '2x_points'],
      ),
    },
    required: ['title', 'progressValue', 'progressLabel', 'rewardText'],
  ),
  widgetBuilder: (itemContext) {
    final d = itemContext.data as Map<String, Object?>?;
    final urgency = _str(d, 'urgencyText');
    final progress = _dbl(d, 'progressValue').clamp(0.0, 1.0);
    final rewardType = _str(d, 'rewardType', 'bonus_points');
    final rewardIcon = switch (rewardType) {
      'spin_wheel' => Icons.casino,
      'free_item' => Icons.card_giftcard,
      'subscription' => Icons.star,
      _ => Icons.monetization_on,
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: urgency.isNotEmpty
            ? Border.all(color: _flame, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (urgency.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _flame.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, size: 14, color: _flame),
                  const SizedBox(width: 4),
                  Text(
                    urgency,
                    style: const TextStyle(
                      color: _flame,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            _str(d, 'title'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          if (_str(d, 'subtitle').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _str(d, 'subtitle'),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                progress >= 1.0 ? Colors.green : _flame,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _str(d, 'progressLabel'),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(rewardIcon, size: 16, color: _flame),
                  const SizedBox(width: 4),
                  Text(
                    _str(d, 'rewardText'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _flame,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  },
);

// ─── 2. TierStatusBar ──────────────────────────────────────────────────────

final _tierStatusBar = CatalogItem(
  name: 'TierStatusBar',
  dataSchema: S.object(
    description: 'Displays current loyalty tier and points to next tier.',
    properties: {
      'currentTier': S.string(
        description: 'Member tier',
        enumValues: ['silver', 'gold', 'platinum'],
      ),
      'pointsToNext': S.integer(
        description: 'Points needed for next tier',
      ),
      'tierColor': S.string(description: 'Hex color for tier accent'),
    },
    required: ['currentTier', 'pointsToNext'],
  ),
  widgetBuilder: (itemContext) {
    final d = itemContext.data as Map<String, Object?>?;
    final tier = _str(d, 'currentTier', 'silver');
    final color = _tierColor(tier);
    final pts = _int(d, 'pointsToNext');
    final tierEmoji = switch (tier.toLowerCase()) {
      'silver' => '\u{1F948}',
      'gold' => '\u{1F947}',
      'platinum' => '\u{1F48E}',
      _ => '\u{1F525}',
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(tierEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${tier[0].toUpperCase()}${tier.substring(1)} Member',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: color.computeLuminance() > 0.7
                        ? Colors.grey[800]
                        : color,
                  ),
                ),
                if (tier.toLowerCase() != 'platinum')
                  Text(
                    '$pts pts to next tier',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                if (tier.toLowerCase() == 'platinum')
                  Text(
                    'Max tier reached!',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: color),
        ],
      ),
    );
  },
);

// ─── 3. SpinWheelWidget ────────────────────────────────────────────────────

final _spinWheelWidget = CatalogItem(
  name: 'SpinWheelWidget',
  dataSchema: S.object(
    description: 'A spin-the-wheel game costing points. Tier-gated.',
    properties: {
      'pointsCost': S.integer(description: 'Points to spin'),
      'segments': S.list(
        description: 'Wheel reward labels',
        items: S.string(description: 'A reward label'),
      ),
      'isLocked': S.boolean(description: 'Whether the wheel is locked'),
      'tierRequired': S.string(description: 'Min tier to unlock'),
    },
    required: ['pointsCost', 'segments'],
  ),
  widgetBuilder: (itemContext) {
    final d = itemContext.data as Map<String, Object?>?;
    final cost = _int(d, 'pointsCost', 100);
    final locked = _bln(d, 'isLocked');
    final tierReq = _str(d, 'tierRequired');
    final segments = (d?['segments'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        ['Prize 1', 'Prize 2', 'Prize 3'];

    final segColors = [
      _flame,
      const Color(0xFFFFB347),
      const Color(0xFF87CEEB),
      const Color(0xFF98FB98),
      const Color(0xFFDDA0DD),
      const Color(0xFFFFD700),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.casino, color: _flame, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Spin & Win',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _flame.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$cost pts',
                  style: const TextStyle(
                    color: _flame,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ...List.generate(segments.length, (i) {
                  final angle = (i / segments.length) * 2 * math.pi;
                  return Positioned(
                    left: 60 + 45 * math.cos(angle),
                    top: 45 + 40 * math.sin(angle),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: segColors[i % segColors.length]
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: segColors[i % segColors.length],
                        ),
                      ),
                      child: Text(
                        segments[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: segColors[i % segColors.length],
                        ),
                      ),
                    ),
                  );
                }),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [_flame, _flame.withValues(alpha: 0.7)],
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          if (locked) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    tierReq.isNotEmpty
                        ? 'Unlock at ${tierReq[0].toUpperCase()}${tierReq.substring(1)} tier'
                        : 'Complete a quest to unlock',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  },
);

// ─── 4. ScratchTicketCard ──────────────────────────────────────────────────

final _scratchTicketCard = CatalogItem(
  name: 'ScratchTicketCard',
  dataSchema: S.object(
    description: 'A scratch-off ticket game card.',
    properties: {
      'title': S.string(description: 'Ticket title'),
      'subtitle': S.string(description: 'Ticket description'),
      'maxWin': S.integer(description: 'Maximum points win'),
      'isScratched': S.boolean(description: 'Already scratched?'),
    },
    required: ['title', 'maxWin'],
  ),
  widgetBuilder: (itemContext) {
    final d = itemContext.data as Map<String, Object?>?;
    final scratched = _bln(d, 'isScratched');
    final maxWin = _int(d, 'maxWin', 500);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: scratched
                    ? [Colors.grey[300]!, Colors.grey[200]!]
                    : [_flame, const Color(0xFFFFB347)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              scratched ? Icons.check_circle : Icons.style,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _str(d, 'title', 'Scratch & Win'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (_str(d, 'subtitle').isNotEmpty)
                  Text(
                    _str(d, 'subtitle'),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                Text(
                  scratched
                      ? 'Already scratched'
                      : 'Win up to $maxWin pts!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scratched ? Colors.grey : _flame,
                  ),
                ),
              ],
            ),
          ),
          if (!scratched)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _flame,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'SCRATCH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  },
);

// ─── 5. LotteryDrawCard ────────────────────────────────────────────────────

final _lotteryDrawCard = CatalogItem(
  name: 'LotteryDrawCard',
  dataSchema: S.object(
    description: 'A lottery draw entry card (daily, weekly, or gold-only).',
    properties: {
      'drawType': S.string(
        description: 'Type of draw',
        enumValues: ['daily', 'weekly', 'gold_only'],
      ),
      'entryPoints': S.integer(description: 'Points cost to enter'),
      'prizeDescription': S.string(description: 'Prize description'),
      'isEligible': S.boolean(description: 'Is member eligible?'),
    },
    required: ['drawType', 'prizeDescription'],
  ),
  widgetBuilder: (itemContext) {
    final d = itemContext.data as Map<String, Object?>?;
    final drawType = _str(d, 'drawType', 'daily');
    final eligible = _bln(d, 'isEligible', true);
    final entryPts = _int(d, 'entryPoints', 50);
    final prize = _str(d, 'prizeDescription', 'Mystery prize');

    final drawLabel = switch (drawType) {
      'gold_only' => '\u{1F451} Gold-Only Draw',
      'weekly' => '\u{1F3AF} Weekly Draw',
      _ => '\u{1F3B2} Daily Draw',
    };
    final drawColor = switch (drawType) {
      'gold_only' => const Color(0xFFFFD700),
      'weekly' => const Color(0xFF6C63FF),
      _ => _flame,
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: drawColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  drawLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (eligible)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: drawColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$entryPts pts',
                    style: TextStyle(
                      color: drawColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Prize: $prize',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          if (!eligible) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '\u{1F512} Tier upgrade required',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  },
);

// ─── 6. GoldCoinsBalance ───────────────────────────────────────────────────

final _goldCoinsBalance = CatalogItem(
  name: 'GoldCoinsBalance',
  dataSchema: S.object(
    description: "Shows the member's gold coin / points balance.",
    properties: {
      'balance': S.integer(description: 'Current points balance'),
      'recentEarned': S.string(
        description: 'Optional label like "+200 from last quest"',
      ),
    },
    required: ['balance'],
  ),
  widgetBuilder: (itemContext) {
    final d = itemContext.data as Map<String, Object?>?;
    final balance = _int(d, 'balance');
    final recent = _str(d, 'recentEarned');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFF8F0)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Text('\u{1FA99}', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$balance',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE65100),
                  ),
                ),
                Text(
                  'Gold Coins',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (recent.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                recent,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ),
        ],
      ),
    );
  },
);

// ─── 7. RewardCarouselItem ─────────────────────────────────────────────────

final _rewardCarouselItem = CatalogItem(
  name: 'RewardCarouselItem',
  dataSchema: S.object(
    description: 'A redeemable reward item in the carousel.',
    properties: {
      'itemName': S.string(description: 'Name of the reward item'),
      'emoji': S.string(description: 'Emoji representing the item'),
      'pointsCost': S.integer(description: 'Points required to redeem'),
      'isAffordable': S.boolean(
        description: 'Can the member afford this?',
      ),
    },
    required: ['itemName', 'emoji', 'pointsCost'],
  ),
  widgetBuilder: (itemContext) {
    final d = itemContext.data as Map<String, Object?>?;
    final name = _str(d, 'itemName', 'Reward');
    final emoji = _str(d, 'emoji', '\u{1F381}');
    final cost = _int(d, 'pointsCost', 100);
    final affordable = _bln(d, 'isAffordable', true);

    return Container(
      width: 110,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: affordable
              ? _flame.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: affordable
                  ? _flame.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$cost pts',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: affordable ? _flame : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  },
);

// ─── 8. CheckoutApplyPanel ─────────────────────────────────────────────────

final _checkoutApplyPanel = CatalogItem(
  name: 'CheckoutApplyPanel',
  dataSchema: S.object(
    description:
        'Checkout panel showing order total, discount, and final price.',
    properties: {
      'orderTotal': S.number(description: 'Original order total in dollars'),
      'discountAmount': S.number(description: 'Discount amount in dollars'),
      'finalTotal': S.number(description: 'Final total after discount'),
      'appliedRewardName': S.string(
        description: 'Name of the applied reward',
      ),
    },
    required: ['orderTotal', 'discountAmount', 'finalTotal'],
  ),
  widgetBuilder: (itemContext) {
    final d = itemContext.data as Map<String, Object?>?;
    final total = _dbl(d, 'orderTotal', 12.99);
    final discount = _dbl(d, 'discountAmount');
    final finalTotal = _dbl(d, 'finalTotal', 12.99);
    final rewardName = _str(d, 'appliedRewardName');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long, color: _flame, size: 20),
              SizedBox(width: 8),
              Text(
                'Apply at Checkout',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          if (rewardName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '\u{2705} $rewardName applied',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _priceRow('Order Total', '\$${total.toStringAsFixed(2)}', false),
          if (discount > 0)
            _priceRow(
              'Discount',
              '-\$${discount.toStringAsFixed(2)}',
              false,
              color: Colors.green,
            ),
          const Divider(height: 16),
          _priceRow(
            'Final Total',
            '\$${finalTotal.toStringAsFixed(2)}',
            true,
          ),
        ],
      ),
    );
  },
);

Widget _priceRow(String label, String value, bool bold, {Color? color}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: color ?? Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 18 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: color ?? (bold ? _flame : Colors.grey[800]),
          ),
        ),
      ],
    ),
  );
}

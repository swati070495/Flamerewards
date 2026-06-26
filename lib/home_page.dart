import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui_template/agents/agent_pipeline.dart';
import 'package:genui_template/agents/member_context.dart';
import 'package:genui_template/agents/onboarding_result.dart';
import 'package:genui_template/agents/supabase_service.dart';
import 'package:genui_template/widgets/onboarding_quiz.dart';
import 'package:genui_template/widgets/spin_wheel_screen.dart';

const _flame = Color(0xFFFF4E1A);
const _darkBg = Color(0xFF0D0D0D);
const _darkCard = Color(0xFF1A1A1A);
const _darkBorder = Color(0xFF2A2A2A);
const _gold = Color(0xFFFFD700);

// ─── Persona Definitions ───────────────────────────────────────────────────

class _Persona {
  const _Persona({
    required this.name,
    required this.tier,
    required this.initial,
    required this.color,
  });

  final String name;
  final String tier;
  final String initial;
  final Color color;

  String get tierLabel => tier.toUpperCase();
  Color get tierColor => switch (tier) {
        'gold' => _gold,
        'platinum' => const Color(0xFFE5E4E2),
        'silver' => Colors.grey,
        _ => _flame,
      };
}

const _personas = [
  _Persona(name: 'Jake', tier: 'silver', initial: 'J', color: _flame),
  _Persona(name: 'Maya', tier: 'gold', initial: 'M', color: Color(0xFF9C27B0)),
  _Persona(name: 'Priya', tier: 'platinum', initial: 'P', color: Color(0xFF42A5F5)),
];

// ─── Home Page ─────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedPersona = 0;
  int _bottomNavIndex = 0;
  bool _loading = false;
  MemberContext? _memberContext;
  List<Map<String, dynamic>>? _widgets;
  String? _error;
  bool _showQuiz = false;
  bool _coldStartBanner = false;

  @override
  void initState() {
    super.initState();
    _initSupabase();
  }

  Future<void> _initSupabase() async {
    try {
      await SupabaseService.instance.initialize();
      await _switchPersona(0);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Supabase init failed: $e');
      }
    }
  }

  Future<void> _switchPersona(int index) async {
    setState(() {
      _selectedPersona = index;
      _bottomNavIndex = 0;
      _loading = true;
      _error = null;
      _widgets = null;
      _showQuiz = false;
      _coldStartBanner = false;
    });

    try {
      final member = await MemberContext.forPersona(
        _personas[index].name,
      );

      if (!mounted) return;
      setState(() => _memberContext = member);

      if (_personas[index].name == 'Jake' && member.orderHistory.length < 5) {
        setState(() {
          _loading = false;
          _showQuiz = true;
        });
        return;
      }

      final widgetSpecs = await AgentPipeline.composeWidgets(member);

      if (!mounted) return;
      setState(() {
        _widgets = widgetSpecs;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('***** PIPELINE ERROR: $e');
      debugPrint('***** STACK: $st');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load: $e';
        });
      }
    }
  }

  Future<void> _onQuizComplete(OnboardingResult result) async {
    setState(() {
      _showQuiz = false;
      _loading = true;
    });

    try {
      final widgetSpecs = await AgentPipeline.composeWidgets(
        _memberContext!,
        onboardingResult: result,
      );

      if (!mounted) return;
      setState(() {
        _widgets = widgetSpecs;
        _loading = false;
        _coldStartBanner = true;
        _lastQuizResult = result;
      });
    } catch (e, st) {
      debugPrint('***** COLD START ERROR: $e');
      debugPrint('***** STACK: $st');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load: $e';
        });
      }
    }
  }

  void _openSpinWheel() {
    final name = _memberContext?.name ?? 'Member';
    // Maya always lands on McFlurry (index 2)
    final landOn = name == 'Maya' ? 2 : 0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpinWheelScreen(
          memberName: name,
          landOnIndex: landOn,
        ),
      ),
    );
  }

  OnboardingResult? _lastQuizResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 860),
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: const Color(0xFF333333), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(38),
            child: Column(
              children: [
                // ── Status Bar ──
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
                  color: const Color(0xFF111111),
                  child: Row(
                    children: [
                      const Text(
                        '9:41',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _switchPersona(_selectedPersona),
                        child: Row(
                          children: [
                            Icon(Icons.refresh, color: Colors.grey[500], size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Replay',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Persona Switcher ──
                _buildPersonaSwitcher(),

                // ── Main Content ──
                Expanded(
                  child: switch (_bottomNavIndex) {
                    0 => _buildHome(),
                    1 => SpinWheelScreen(
                           memberName: _memberContext?.name ?? 'Member',
                           landOnIndex: _memberContext?.name == 'Maya' ? 2 : 0,
                         ),
                    2 => _buildOrderTab(),
                    3 => _buildAccountTab(),
                    _ => _buildHome(),
                  },
                ),

                // ── Bottom Nav ──
                _buildBottomNav(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonaSwitcher() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'PREVIEW PERSONA',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              const Text(
                'TAP JAKE \u{2192}',
                style: TextStyle(
                  color: _flame,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(_personas.length, (i) {
              final p = _personas[i];
              final selected = i == _selectedPersona;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 4,
                    right: i == _personas.length - 1 ? 0 : 4,
                  ),
                  child: GestureDetector(
                    onTap: _loading ? null : () => _switchPersona(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? _flame : _darkBorder,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: p.color,
                            child: Text(
                              p.initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            p.tierLabel,
                            style: TextStyle(
                              color: p.tierColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _flame, size: 40),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _switchPersona(_selectedPersona),
                child: const Text('Retry', style: TextStyle(color: _flame)),
              ),
            ],
          ),
        ),
      );
    }

    if (_showQuiz) {
      return OnboardingQuiz(onComplete: _onQuizComplete);
    }

    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _flame),
            SizedBox(height: 12),
            Text(
              'Loading rewards...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_memberContext == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Card ──
          _buildHeaderCard(),
          const SizedBox(height: 20),

          // ── Personalized Path Banner ──
          if (_coldStartBanner && _lastQuizResult != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _darkCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _flame.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('\u{2728}', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text(
                        'YOUR PERSONALIZED PATH',
                        style: TextStyle(
                          color: _flame,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pathChip(_occasionEmoji(_lastQuizResult!.occasion), _lastQuizResult!.occasion),
                      _pathChip(_preferenceEmoji(_lastQuizResult!.preference), _lastQuizResult!.preference),
                      _pathChip(_goalEmoji(_lastQuizResult!.goal), _lastQuizResult!.goal),
                    ],
                  ),
                ],
              ),
            ),

          // ── Quests Section ──
          _buildQuestsSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _pathChip(String emoji, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label[0].toUpperCase() + label.substring(1),
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _occasionEmoji(String o) => switch (o) {
        'morning' => '\u{1F305}',
        'lunch' => '\u{2600}\u{FE0F}',
        'dinner' => '\u{1F319}',
        _ => '\u{1F3B2}',
      };

  String _preferenceEmoji(String p) => switch (p) {
        'burgers' => '\u{1F354}',
        'drinks' => '\u{2615}',
        'breakfast' => '\u{1F373}',
        _ => '\u{1F35F}',
      };

  String _goalEmoji(String g) => switch (g) {
        'save money' => '\u{1F4B0}',
        'earn fast' => '\u{1F3AF}',
        'try new things' => '\u{1F195}',
        _ => '\u{1F3C6}',
      };

  Widget _buildHeaderCard() {
    final m = _memberContext!;
    final persona = _personas[_selectedPersona];
    final pointsToNext = switch (m.tier) {
      'silver' => 1500 - m.points,
      'gold' => 3000 - m.points,
      _ => 0,
    };
    final maxPoints = switch (m.tier) {
      'silver' => 1500,
      'gold' => 3000,
      _ => 1,
    };
    final progress = m.tier == 'platinum'
        ? 1.0
        : ((maxPoints - pointsToNext) / maxPoints).clamp(0.0, 1.0);
    final nextTier = switch (m.tier) {
      'silver' => 'Gold',
      'gold' => 'Platinum',
      _ => '',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                m.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: persona.tierColor),
                ),
                child: Text(
                  persona.tierLabel,
                  style: TextStyle(
                    color: persona.tierColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${m.points}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  'points',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: _darkBorder,
              valueColor: const AlwaysStoppedAnimation(_flame),
            ),
          ),
          if (nextTier.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${pointsToNext > 0 ? pointsToNext : 0} pts to $nextTier',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Max tier reached!',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestsSection() {
    final persona = _personas[_selectedPersona];

    // Build quest list from LLM-generated pipeline data
    final pipelineQuests = _widgets
            ?.where((w) => w['type'] == 'QuestCard')
            .map((w) => w['data'] as Map<String, dynamic>)
            .toList() ??
        [];

    final questList = <_QuestData>[];

    // Maya: always prepend completed spin wheel quest for demo
    if (persona.name == 'Maya') {
      questList.add(const _QuestData(
        emoji: '\u{26A1}',
        title: 'Double Points Weekend',
        subtitle: 'Earn 2x on any order this weekend',
        badge: '+500',
        badgeColor: _flame,
        progress: 1.0,
        progressLabel: '2/2',
        rewardType: 'spin_wheel',
        isCompleted: true,
      ));
    }

    // Add LLM-generated quests from pipeline
    for (final q in pipelineQuests) {
      final prog = _dbl(q, 'progressValue').clamp(0.0, 1.0);
      final rewardType = q['rewardType'] as String? ?? 'bonus_points';
      final rewardText = q['rewardText'] as String? ?? '';
      final activityType = q['activityType'] as String? ?? 'streak';

      final badge = rewardText.isNotEmpty
          ? (rewardText.length > 14 ? rewardText.substring(0, 14) : rewardText)
          : rewardType == 'spin_wheel'
              ? 'Spin'
              : '+pts';

      questList.add(_QuestData(
        emoji: _activityEmoji(activityType),
        title: q['title'] as String? ?? 'Quest',
        subtitle: q['subtitle'] as String? ?? '',
        badge: badge,
        badgeColor: activityType == 'flash'
            ? const Color(0xFFFF6B35)
            : rewardType == 'spin_wheel'
                ? _gold
                : _flame,
        progress: activityType == 'flash' ? null : prog,
        progressLabel: q['progressLabel'] as String?,
        rewardType: rewardType,
        isCompleted: prog >= 1.0,
        activityType: activityType,
        extraData: q,
      ));
    }

    // Maya: add VIP perk card
    if (persona.name == 'Maya') {
      questList.add(const _QuestData(
        emoji: '\u{1F69A}',
        title: 'VIP Free Delivery',
        subtitle: 'Gold perk \u{00B7} always on',
        badge: 'Active',
        badgeColor: _flame,
        progress: null,
        progressLabel: null,
        rewardType: 'perk',
        isCompleted: false,
        isPerk: true,
      ));
    }

    return Column(
      children: [
        Row(
          children: [
            const Text(
              'Your quests',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              'See all',
              style: TextStyle(
                color: _flame,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...questList.map((q) => _DarkQuestCard(
              quest: q,
              onTap: () => _onQuestTapped(q),
            )),
      ],
    );
  }

  static String _activityEmoji(String activityType) => switch (activityType) {
        'streak' => '\u{1F525}',
        'try_new' => '\u{1F50D}',
        'spend' => '\u{1F4B0}',
        'flash' => '\u{26A1}',
        'combo' => '\u{1F37D}\u{FE0F}',
        'refer' => '\u{1F91D}',
        'daypart' => '\u{1F305}',
        'category' => '\u{2615}',
        _ => '\u{1F3AF}',
      };

  void _onQuestTapped(_QuestData quest) {
    if (quest.isPerk) {
      showModalBottomSheet(
        context: context,
        backgroundColor: _darkCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Gold Member Perk \u{1F3C6}',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'Free delivery is always active for you',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _flame,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (quest.isCompleted && quest.rewardType == 'spin_wheel') {
      _openSpinWheel();
      return;
    }

    // Incomplete quest bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: _darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Almost there! \u{1F525}',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              quest.progress != null
                  ? 'You are ${((1 - quest.progress!) * 100).toInt()}% away from completing this quest'
                  : 'Complete ${quest.title} to unlock your reward',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              quest.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            if (quest.progress != null) ...[
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: quest.progress!,
                  minHeight: 10,
                  backgroundColor: _darkBorder,
                  valueColor: const AlwaysStoppedAnimation(_flame),
                ),
              ),
              const SizedBox(height: 6),
              if (quest.progressLabel != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    quest.progressLabel!,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _flame,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Rewards Tab ──
  Widget _buildRewardsTab() {
    if (_memberContext == null) return const SizedBox.shrink();
    final m = _memberContext!;
    final pts = m.points;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Points balance
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Text('\u{1FA99}', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                Text(
                  '$pts',
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
                ),
                Text('points available', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Redeem Rewards',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ..._rewardsList.map((r) => _RewardRedeemCard(
                reward: r,
                canAfford: pts >= r.cost,
                onRedeem: pts >= r.cost ? () => _redeemReward(r) : null,
              )),
          const SizedBox(height: 16),
          // Play & Earn section
          GestureDetector(
            onTap: _openSpinWheel,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _darkCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _flame.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Text('\u{1F3B0}', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Spin & Win', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        Text('Try your luck for free rewards', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: _flame, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _redeemReward(_RewardItem r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text(r.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Redeem ${r.name}?', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('This will cost ${r.cost} points', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${r.emoji} ${r.name} redeemed!'),
                      backgroundColor: _flame,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _flame,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Redeem for ${r.cost} pts', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[500])),
            ),
          ],
        ),
      ),
    );
  }

  // ── Order Tab ──
  Widget _buildOrderTab() {
    if (_memberContext == null) return const SizedBox.shrink();
    final pts = _memberContext!.points;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Points breakdown card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('\u{1FA99}', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      '$pts',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('points available', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'YOUR POINTS CAN GET YOU',
                  style: TextStyle(color: Colors.grey[500], fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1),
                ),
                const SizedBox(height: 10),
                ..._menuItems.map((item) {
                  final canAfford = pts >= item.pointsCost;
                  final barProgress = (pts / item.pointsCost).clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(item.emoji, style: const TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Text(
                            item.name,
                            style: TextStyle(
                              color: canAfford ? Colors.white : Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: barProgress,
                              minHeight: 6,
                              backgroundColor: _darkBorder,
                              valueColor: AlwaysStoppedAnimation(
                                canAfford ? Colors.green : _flame,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 50,
                          child: Text(
                            canAfford ? 'FREE' : '${item.pointsCost} pts',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: canAfford ? Colors.green : Colors.grey[500],
                              fontSize: 10,
                              fontWeight: canAfford ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Menu',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ..._menuItems.map((item) {
            final canAdd = pts >= item.pointsCost;
            return _MenuItemCard(
              item: item,
              canAdd: canAdd,
              onAdd: () => _addToCart(item),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _addToCart(_MenuItem item) {
    final pts = _memberContext!.points;
    if (pts < item.pointsCost) {
      showModalBottomSheet(
        context: context,
        backgroundColor: _darkCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text('\u{1F512}', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              const Text('Not enough points', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'You need ${item.pointsCost - pts} more points to add ${item.name} for free',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Or pay \$${item.price.toStringAsFixed(2)} with cash',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: _darkBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${item.emoji} ${item.name} added (\$${item.price.toStringAsFixed(2)})'), backgroundColor: _flame),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _flame,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Pay \$${item.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: _darkCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text(item.emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('Add ${item.name}?', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('FREE with ${item.pointsCost} pts', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'or \$${item.price.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13, decoration: TextDecoration.lineThrough),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${item.emoji} ${item.name} added FREE! (-${item.pointsCost} pts)'), backgroundColor: Colors.green),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Use ${item.pointsCost} pts \u{2014} FREE', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${item.emoji} ${item.name} added (\$${item.price.toStringAsFixed(2)})'), backgroundColor: _flame),
                  );
                },
                child: Text('Pay \$${item.price.toStringAsFixed(2)} instead', style: TextStyle(color: Colors.grey[500])),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ── Account Tab ──
  Widget _buildAccountTab() {
    if (_memberContext == null) return const SizedBox.shrink();
    final m = _memberContext!;
    final persona = _personas[_selectedPersona];

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: persona.color,
            child: Text(persona.initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 28)),
          ),
          const SizedBox(height: 12),
          Text(m.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: persona.tierColor),
            ),
            child: Text(persona.tierLabel, style: TextStyle(color: persona.tierColor, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
          Text('${m.points} points', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          if (m.streakDays > 0) ...[
            const SizedBox(height: 4),
            Text('\u{1F525} ${m.streakDays} day streak', style: const TextStyle(color: _flame, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _darkCard,
        border: Border(top: BorderSide(color: _darkBorder)),
      ),
      child: Row(
        children: [
          _navItem(0, '\u{1F3E0}', 'Home'),
          _navItem(1, '\u{1F381}', 'Rewards'),
          _navItem(2, '\u{1F374}', 'Order'),
          _navItem(3, '\u{1F464}', 'Account'),
        ],
      ),
    );
  }

  Widget _navItem(int index, String emoji, String label) {
    final active = _bottomNavIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _bottomNavIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: TextStyle(fontSize: 20, color: active ? null : Colors.grey[700])),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: active ? _flame : Colors.grey[600],
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double _dbl(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}

// ─── Quest Data Model ────────────────────────────────────────────────────

class _QuestData {
  const _QuestData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.progress,
    required this.progressLabel,
    required this.rewardType,
    required this.isCompleted,
    this.isPerk = false,
    this.activityType = 'streak',
    this.extraData,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final double? progress;
  final String? progressLabel;
  final String rewardType;
  final bool isCompleted;
  final bool isPerk;
  final String activityType;
  final Map<String, dynamic>? extraData;
}

// ─── Dark Quest Card ─────────────────────────────────────────────────────

class _DarkQuestCard extends StatefulWidget {
  const _DarkQuestCard({required this.quest, required this.onTap});

  final _QuestData quest;
  final VoidCallback onTap;

  @override
  State<_DarkQuestCard> createState() => _DarkQuestCardState();
}

class _DarkQuestCardState extends State<_DarkQuestCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.quest;
    final isFlash = q.activityType == 'flash';
    final isCombo = q.activityType == 'combo';
    final isStreak = q.activityType == 'streak';

    final borderColor = isFlash
        ? const Color(0xFFFF6B35).withValues(alpha: 0.6)
        : q.isCompleted
            ? _flame.withValues(alpha: 0.5)
            : _darkBorder;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: isFlash || q.isCompleted ? 1.5 : 1),
            boxShadow: isFlash
                ? [BoxShadow(color: const Color(0xFFFF6B35).withValues(alpha: 0.1), blurRadius: 12)]
                : q.isCompleted
                    ? [BoxShadow(color: _flame.withValues(alpha: 0.08), blurRadius: 12)]
                    : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Activity type label for special types
              if (isFlash || isCombo) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isFlash
                        ? const Color(0xFFFF6B35).withValues(alpha: 0.15)
                        : _flame.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isFlash ? '\u{26A1}' : '\u{1F37D}\u{FE0F}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFlash ? 'FLASH CHALLENGE' : 'COMBO CHALLENGE',
                        style: TextStyle(
                          color: isFlash ? const Color(0xFFFF6B35) : _flame,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (isFlash && q.extraData?['expiresIn'] != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${q.extraData!['expiresIn']}h left',
                          style: const TextStyle(
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.w600,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              Row(
                children: [
                  // Emoji icon with activity-specific background
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: isFlash
                          ? const Color(0xFFFF6B35).withValues(alpha: 0.1)
                          : isStreak
                              ? _flame.withValues(alpha: 0.1)
                              : _darkBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(q.emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          q.subtitle,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: q.badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      q.badge,
                      style: TextStyle(color: q.badgeColor, fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ),
                  if (q.isCompleted) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 22, height: 22,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ],
                ],
              ),

              // Combo items list
              if (isCombo && q.extraData?['comboItems'] != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (q.extraData!['comboItems'] as List).map<Widget>((item) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _darkBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _darkBorder),
                      ),
                      child: Text(
                        item.toString(),
                        style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Streak visualization
              if (isStreak && q.extraData?['streakCurrent'] != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: List.generate(
                    (q.extraData!['streakTarget'] as num?)?.toInt() ?? 5,
                    (i) {
                      final current = (q.extraData!['streakCurrent'] as num?)?.toInt() ?? 0;
                      final filled = i < current;
                      return Expanded(
                        child: Container(
                          height: 6,
                          margin: EdgeInsets.only(right: i < ((q.extraData!['streakTarget'] as num?)?.toInt() ?? 5) - 1 ? 3 : 0),
                          decoration: BoxDecoration(
                            color: filled ? _flame : _darkBorder,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                if (q.progressLabel != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(q.progressLabel!, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ),
              ],

              // Standard progress bar (non-streak, non-flash)
              if (!isStreak && !isFlash && q.progress != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: q.progress!,
                          minHeight: 5,
                          backgroundColor: _darkBorder,
                          valueColor: AlwaysStoppedAnimation(q.isCompleted ? Colors.green : _flame),
                        ),
                      ),
                    ),
                    if (q.progressLabel != null) ...[
                      const SizedBox(width: 8),
                      Text(q.progressLabel!, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ],
                  ],
                ),
              ],

              // Flash urgency bar
              if (isFlash) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.timer, size: 14, color: const Color(0xFFFF6B35)),
                    const SizedBox(width: 6),
                    Text(
                      q.extraData?['urgencyText'] as String? ?? 'Limited time',
                      style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const Spacer(),
                    if (q.progressLabel != null)
                      Text(q.progressLabel!, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ],

              // Tap to spin hint
              if (q.isCompleted && q.rewardType == 'spin_wheel') ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Tap to spin \u{2192}',
                    style: TextStyle(color: _flame, fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Menu & Reward Data ──────────────────────────────────────────────────

class _MenuItem {
  const _MenuItem({
    required this.name,
    required this.emoji,
    required this.price,
    required this.pointsCost,
    required this.category,
  });

  final String name;
  final String emoji;
  final double price;
  final int pointsCost;
  final String category;
}

const _menuItems = [
  _MenuItem(name: 'Big Mac', emoji: '\u{1F354}', price: 5.99, pointsCost: 400, category: 'Burgers'),
  _MenuItem(name: 'Quarter Pounder', emoji: '\u{1F354}', price: 6.49, pointsCost: 500, category: 'Burgers'),
  _MenuItem(name: 'McNuggets 6pc', emoji: '\u{1F414}', price: 5.49, pointsCost: 350, category: 'Chicken'),
  _MenuItem(name: 'McCafe Latte', emoji: '\u{2615}', price: 3.49, pointsCost: 250, category: 'Drinks'),
  _MenuItem(name: 'McFlurry', emoji: '\u{1F366}', price: 4.29, pointsCost: 300, category: 'Desserts'),
  _MenuItem(name: 'Small Fries', emoji: '\u{1F35F}', price: 2.49, pointsCost: 150, category: 'Sides'),
  _MenuItem(name: 'Hash Brown', emoji: '\u{1F954}', price: 2.29, pointsCost: 200, category: 'Breakfast'),
  _MenuItem(name: 'Egg McMuffin', emoji: '\u{1F373}', price: 4.49, pointsCost: 300, category: 'Breakfast'),
];

class _RewardItem {
  const _RewardItem({
    required this.name,
    required this.emoji,
    required this.cost,
    required this.description,
  });

  final String name;
  final String emoji;
  final int cost;
  final String description;
}

const _rewardsList = [
  _RewardItem(name: 'Small Fries', emoji: '\u{1F35F}', cost: 150, description: 'Crispy golden fries'),
  _RewardItem(name: 'Hash Brown', emoji: '\u{1F954}', cost: 200, description: 'Crispy breakfast classic'),
  _RewardItem(name: 'McCafe Coffee', emoji: '\u{2615}', cost: 250, description: 'Any size hot coffee'),
  _RewardItem(name: 'McFlurry', emoji: '\u{1F366}', cost: 300, description: 'Any flavor McFlurry'),
  _RewardItem(name: 'Big Mac', emoji: '\u{1F354}', cost: 400, description: 'The iconic burger'),
  _RewardItem(name: 'Quarter Pounder', emoji: '\u{1F354}', cost: 500, description: 'Premium quarter pound beef'),
];

// ─── Menu Item Card ──────────────────────────────────────────────────────

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.item,
    required this.canAdd,
    required this.onAdd,
  });

  final _MenuItem item;
  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _darkBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _darkBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '\$${item.price.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.category,
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: canAdd
                    ? Colors.green.withValues(alpha: 0.15)
                    : _flame.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    canAdd ? 'FREE' : '${item.pointsCost}',
                    style: TextStyle(
                      color: canAdd ? Colors.green : _flame,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (!canAdd) ...[
                    const SizedBox(width: 2),
                    Text('pts', style: TextStyle(color: _flame.withValues(alpha: 0.7), fontSize: 10)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reward Redeem Card ──────────────────────────────────────────────────

class _RewardRedeemCard extends StatelessWidget {
  const _RewardRedeemCard({
    required this.reward,
    required this.canAfford,
    this.onRedeem,
  });

  final _RewardItem reward;
  final bool canAfford;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRedeem,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: canAfford ? _flame.withValues(alpha: 0.3) : _darkBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _darkBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(reward.emoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reward.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(reward.description, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: canAfford
                    ? _flame.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${reward.cost} pts',
                style: TextStyle(
                  color: canAfford ? _flame : Colors.grey[600],
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

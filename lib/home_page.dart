import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/conversation.dart';
import 'package:genui_template/model/featherless_model_client.dart';

const _flame = Color(0xFFFF4E1A);
const _bg = Color(0xFFFFF8F5);

// ─── Persona Definitions ───────────────────────────────────────────────────

class _Persona {
  const _Persona({
    required this.name,
    required this.label,
    required this.tier,
    required this.icon,
    required this.context,
  });

  final String name;
  final String label;
  final String tier;
  final IconData icon;
  final Map<String, Object> context;
}

final _personas = [
  _Persona(
    name: 'Maya',
    label: 'Gold \u{2022} 2340 pts',
    tier: 'gold',
    icon: Icons.local_fire_department,
    context: {
      'tier': 'gold',
      'points': 2340,
      'streak': 3,
      'expiringIn': 2,
      'activeQuests': [
        {
          'name': 'Breakfast Streak',
          'progress': 3,
          'target': 5,
          'reward': 'Spin Wheel unlock',
          'urgencyDays': 2,
        },
        {
          'name': 'Big Spender',
          'progress': 40,
          'target': 50,
          'reward': '500 bonus points',
          'urgencyDays': null,
        },
        {
          'name': 'Try Something New',
          'progress': 0,
          'target': 1,
          'reward': 'Free coffee',
          'urgencyDays': null,
        },
      ],
      'orderHistory': [
        'Classic Burger Combo',
        'Breakfast Wrap + Coffee',
        'Spicy Chicken Sandwich',
      ],
    },
  ),
  _Persona(
    name: 'Jake',
    label: 'Bronze \u{2022} 150 pts',
    tier: 'bronze',
    icon: Icons.emoji_people,
    context: {
      'tier': 'bronze',
      'points': 150,
      'streak': 0,
      'expiringIn': null,
      'activeQuests': [
        {
          'name': 'Welcome Quest',
          'progress': 0,
          'target': 1,
          'reward': '100 bonus points',
          'urgencyDays': null,
        },
        {
          'name': 'Try a Combo',
          'progress': 0,
          'target': 1,
          'reward': 'Free fries',
          'urgencyDays': null,
        },
      ],
      'orderHistory': <String>[],
    },
  ),
  _Persona(
    name: 'Priya',
    label: 'Silver \u{2022} 890 pts',
    tier: 'silver',
    icon: Icons.update,
    context: {
      'tier': 'silver',
      'points': 890,
      'streak': 0,
      'expiringIn': 3,
      'activeQuests': [
        {
          'name': 'Win-back Bonus',
          'progress': 0,
          'target': 1,
          'reward': '2x points on next visit',
          'urgencyDays': 3,
        },
      ],
      'orderHistory': [
        'Veggie Wrap',
        'Iced Latte',
      ],
    },
  ),
];

// ─── Home Page ─────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late GenUiSession _session;
  StreamSubscription<ConversationEvent>? _eventsSub;
  int _selectedPersona = 0;

  @override
  void initState() {
    super.initState();
    _initSession();
    // Auto-send Maya's context on launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendPersona(0);
    });
  }

  void _initSession() {
    _session = GenUiSession(modelClientBuilder: FeatherlessModelClient.new);
    _eventsSub = _session.events.listen((event) {
      if (event is ConversationError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request failed: ${event.error}')),
        );
      }
    });
  }

  void _sendPersona(int index) {
    setState(() => _selectedPersona = index);
    final persona = _personas[index];
    final message =
        'Compose the loyalty screen for this member:\n${jsonEncode(persona.context)}';
    _session.sendMessage(message);
  }

  void _switchPersona(int index) {
    // Dispose old session and create a fresh one for clean recomposition.
    unawaited(_eventsSub?.cancel());
    _session.dispose();
    _initSession();
    _sendPersona(index);
  }

  @override
  void dispose() {
    unawaited(_eventsSub?.cancel());
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _flame,
        foregroundColor: Colors.white,
        title: const Text(
          'FlameRewards \u{1F525}',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Persona Switcher ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: List.generate(_personas.length, (i) {
                final p = _personas[i];
                final selected = i == _selectedPersona;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => _switchPersona(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? _flame.withValues(alpha: 0.1)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? _flame
                                : Colors.grey.withValues(alpha: 0.2),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              p.icon,
                              color: selected ? _flame : Colors.grey,
                              size: 22,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: selected ? _flame : Colors.grey[800],
                              ),
                            ),
                            Text(
                              p.label,
                              style: TextStyle(
                                fontSize: 10,
                                color: selected ? _flame : Colors.grey[500],
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
          ),

          // ── GenUI Surface in Phone Frame ──
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: ValueListenableBuilder<ConversationState>(
                    valueListenable: _session.conversationState,
                    builder: (context, state, _) {
                      final isProcessing = state.isWaiting;
                      final latestSurfaceId = state.surfaces.isNotEmpty
                          ? state.surfaces.last
                          : null;

                      return Column(
                        children: [
                          if (isProcessing)
                            const LinearProgressIndicator(
                              minHeight: 3,
                              color: _flame,
                              backgroundColor: Color(0xFFFFE0D6),
                            ),
                          Expanded(
                            child: latestSurfaceId == null || isProcessing
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.local_fire_department,
                                          size: 48,
                                          color: _flame.withValues(alpha: 0.3),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          isProcessing
                                              ? 'Composing experience...'
                                              : 'Select a persona',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Surface(
                                      surfaceContext: _session.contextFor(
                                        latestSurfaceId,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/agents/agent_pipeline.dart';
import 'package:genui_template/agents/member_context.dart';
import 'package:genui_template/agents/supabase_service.dart';
import 'package:genui_template/conversation.dart';
import 'package:genui_template/model/featherless_model_client.dart';

const _flame = Color(0xFFFF4E1A);
const _bg = Color(0xFFFFF8F5);

// ─── Persona Definitions ───────────────────────────────────────────────────

class _Persona {
  const _Persona({
    required this.name,
    required this.tier,
    required this.icon,
  });

  final String name;
  final String tier;
  final IconData icon;

  String get label => switch (tier) {
        'gold' => 'Gold',
        'silver' => 'Silver',
        'bronze' => 'Bronze',
        _ => tier,
      };
}

const _personas = [
  _Persona(name: 'Maya', tier: 'gold', icon: Icons.local_fire_department),
  _Persona(name: 'Jake', tier: 'bronze', icon: Icons.emoji_people),
  _Persona(name: 'Priya', tier: 'silver', icon: Icons.update),
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
  bool _loading = false;
  MemberContext? _memberContext;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initSession();
    _initSupabase();
  }

  void _initSession() {
    _session = GenUiSession(modelClientBuilder: FeatherlessModelClient.new);
    _eventsSub = _session.events.listen((event) {
      if (event is ConversationError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('LLM error: ${event.error}')),
        );
      }
    });
  }

  Future<void> _initSupabase() async {
    try {
      await SupabaseService.instance.initialize();
      // Auto-load Maya on startup
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
      _loading = true;
      _error = null;
    });

    try {
      // Fetch member data from Supabase
      final member = await MemberContext.forPersona(
        _personas[index].name,
      );

      if (!mounted) return;
      setState(() => _memberContext = member);

      // Dispose old session and create fresh one
      unawaited(_eventsSub?.cancel());
      _session.dispose();
      _initSession();

      // Run agent pipeline
      final message = await AgentPipeline.composeForMember(member);

      if (!mounted) return;
      _session.sendMessage(message);
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load: $e';
        });
      }
    }
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
          'McRewards \u{1F35F}',
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
                      onTap: _loading ? null : () => _switchPersona(i),
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

          // ── Phone Frame with GenUI Surface ──
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 390),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(32),
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
                  borderRadius: BorderRadius.circular(30),
                  child: Column(
                    children: [
                      // Phone header with member info
                      if (_memberContext != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          color: _flame,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hey ${_memberContext!.name}!',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '${_memberContext!.tier[0].toUpperCase()}${_memberContext!.tier.substring(1)} Member',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_memberContext!.points} pts',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Loading / Error / Surface
                      Expanded(
                        child: _buildContent(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
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
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _switchPersona(_selectedPersona),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ValueListenableBuilder<ConversationState>(
      valueListenable: _session.conversationState,
      builder: (context, state, _) {
        final isProcessing = state.isWaiting || _loading;
        final latestSurfaceId =
            state.surfaces.isNotEmpty ? state.surfaces.last : null;

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
                          if (_loading)
                            const CircularProgressIndicator(color: _flame)
                          else
                            Icon(
                              Icons.local_fire_department,
                              size: 48,
                              color: _flame.withValues(alpha: 0.3),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            _loading
                                ? 'Loading from Supabase...'
                                : isProcessing
                                    ? 'Agents composing...'
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Surface(
                        surfaceContext: _session.contextFor(latestSurfaceId),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:genui_template/agents/onboarding_result.dart';

const _flame = Color(0xFFFF4E1A);
const _darkCard = Color(0xFF1A1A1A);
const _darkBorder = Color(0xFF2A2A2A);

class OnboardingQuiz extends StatefulWidget {
  const OnboardingQuiz({super.key, required this.onComplete});

  final void Function(OnboardingResult result) onComplete;

  @override
  State<OnboardingQuiz> createState() => _OnboardingQuizState();
}

class _OnboardingQuizState extends State<OnboardingQuiz> {
  int _step = 0;
  String? _occasion;
  String? _preference;
  String? _goal;
  bool _building = false;

  static const _questions = [
    {
      'title': 'When do you usually visit?',
      'options': [
        {'label': '\u{1F305} Morning', 'value': 'morning'},
        {'label': '\u{2600}\u{FE0F} Lunch', 'value': 'lunch'},
        {'label': '\u{1F319} Dinner', 'value': 'dinner'},
        {'label': '\u{1F3B2} Whenever', 'value': 'whenever'},
      ],
    },
    {
      'title': 'What do you love ordering?',
      'options': [
        {'label': '\u{1F354} Burgers', 'value': 'burgers'},
        {'label': '\u{2615} Drinks', 'value': 'drinks'},
        {'label': '\u{1F373} Breakfast', 'value': 'breakfast'},
        {'label': '\u{1F35F} Snacks', 'value': 'snacks'},
      ],
    },
    {
      'title': "What's your goal?",
      'options': [
        {'label': '\u{1F4B0} Save money', 'value': 'save money'},
        {'label': '\u{1F3AF} Earn fast', 'value': 'earn fast'},
        {'label': '\u{1F195} Try new', 'value': 'try new things'},
        {'label': '\u{1F3C6} Top tier', 'value': 'reach top tier'},
      ],
    },
  ];

  void _select(String value) {
    setState(() {
      switch (_step) {
        case 0:
          _occasion = value;
        case 1:
          _preference = value;
        case 2:
          _goal = value;
      }

      if (_step < 2) {
        _step++;
      } else {
        _building = true;
        Future.delayed(const Duration(milliseconds: 1500), () {
          widget.onComplete(OnboardingResult(
            occasion: _occasion!,
            preference: _preference!,
            goal: _goal!,
          ));
        });
      }
    });
  }

  String? _selectedForStep() => switch (_step) {
        0 => _occasion,
        1 => _preference,
        2 => _goal,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    if (_building) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: _flame,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Building your McRewards path...',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final question = _questions[_step];
    final options = question['options'] as List<Map<String, String>>;
    final selected = _selectedForStep();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final active = i <= _step;
              return Container(
                width: active ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active ? _flame : _darkBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            'Step ${_step + 1} of 3',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(height: 28),

          // Question
          Text(
            question['title'] as String,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Options
          ...options.map((opt) {
            final isSelected = selected == opt['value'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _select(opt['value']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _flame.withValues(alpha: 0.15)
                        : _darkCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? _flame : _darkBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    opt['label']!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? _flame : Colors.grey[300],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

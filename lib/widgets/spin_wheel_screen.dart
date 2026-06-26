import 'dart:math' as math;
import 'package:flutter/material.dart';

const _flame = Color(0xFFFF4E1A);
const _darkBg = Color(0xFF0D0D0D);
const _darkCard = Color(0xFF1A1A1A);
const _darkBorder = Color(0xFF2A2A2A);
const _gold = Color(0xFFFFD700);

class SpinWheelScreen extends StatefulWidget {
  const SpinWheelScreen({
    super.key,
    this.memberName = 'Member',
    this.landOnIndex = 2, // default McFlurry for Maya
  });

  final String memberName;
  final int landOnIndex;

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _spinning = false;
  bool _showResult = false;

  static const _segments = [
    '200 pts',
    'Free Fries',
    'McFlurry',
    '2x Points',
    '50 pts',
    'Big Mac',
  ];

  static const _segmentEmojis = [
    '\u{1FA99}',
    '\u{1F35F}',
    '\u{1F366}',
    '\u{2728}',
    '\u{1FA99}',
    '\u{1F354}',
  ];

  static const _segmentColors = [
    _flame,
    Color(0xFFFFB347),
    _flame,
    Color(0xFFFFB347),
    _flame,
    Color(0xFFFFB347),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    // Calculate target angle to land on the desired segment
    // Each segment is 60 degrees. Pointer is at top (0 degrees).
    // Segment 0 starts at -30 deg to 30 deg from top.
    // To land on segment N, we need to rotate so segment N is at top.
    final segAngle = (widget.landOnIndex / 6) * 2 * math.pi;
    final targetAngle = 4 * 2 * math.pi + segAngle; // 4 full spins + landing
    _animation = Tween<double>(begin: 0, end: targetAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showResult = true);
        _showResultSheet();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() {
    if (_spinning) return;
    setState(() {
      _spinning = true;
      _showResult = false;
    });
    _controller.forward(from: 0);
  }

  void _showResultSheet() {
    final wonItem = _segments[widget.landOnIndex];
    final wonEmoji = _segmentEmojis[widget.landOnIndex];

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: _darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            Text(wonEmoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'You won a Free $wonItem!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Redeem at any McDonald's today",
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showRedemption(wonItem, wonEmoji);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _flame,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Redeem Now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _spinning = false);
              },
              child: Text('Save for later', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRedemption(String item, String emoji) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: _darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              '$item Redeemed! \u{1F389}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Show this to the cashier',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 20),
            // QR code placeholder
            Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3A3A3A)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_2, size: 80, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text('QR CODE', style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Valid for 24 hours',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // back to home
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _flame,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Play & Earn',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pointer
            const Icon(Icons.arrow_drop_down, color: _flame, size: 40),

            // Wheel
            SizedBox(
              width: 280,
              height: 280,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (_, child) => Transform.rotate(
                  angle: -_animation.value,
                  child: child,
                ),
                child: CustomPaint(
                  size: const Size(280, 280),
                  painter: _WheelPainter(
                    segments: _segments,
                    colors: _segmentColors,
                  ),
                  child: const Center(
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Text('\u{1F525}', style: TextStyle(fontSize: 28)),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Spin button
            SizedBox(
              width: 220,
              child: ElevatedButton(
                onPressed: _spinning ? null : _spin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _spinning ? Colors.grey[800] : _flame,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[800],
                  disabledForegroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _spinning ? 'Spinning...' : 'Spin (costs 50 pts)',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.segments, required this.colors});

  final List<String> segments;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segAngle = 2 * math.pi / segments.length;

    for (var i = 0; i < segments.length; i++) {
      final startAngle = i * segAngle - math.pi / 2 - segAngle / 2;
      final paint = Paint()..color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segAngle,
        true,
        paint,
      );

      // Border between segments
      final borderPaint = Paint()
        ..color = const Color(0xFF0D0D0D)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segAngle,
        true,
        borderPaint,
      );

      // Text
      final textAngle = startAngle + segAngle / 2;
      final textRadius = radius * 0.65;
      final textX = center.dx + textRadius * math.cos(textAngle);
      final textY = center.dy + textRadius * math.sin(textAngle);

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + math.pi / 2);
      final textPainter = TextPainter(
        text: TextSpan(
          text: segments[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    // Outer ring
    final ringPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

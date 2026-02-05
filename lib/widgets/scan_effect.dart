import 'package:flutter/material.dart';

class ScanEffect extends StatefulWidget {
  final Widget child;
  final Color scanColor;
  final Duration duration;

  const ScanEffect({
    super.key,
    required this.child,
    this.scanColor = const Color(0xFF00FF00),
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<ScanEffect> createState() => _ScanEffectState();
}

class _ScanEffectState extends State<ScanEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Stack(
            children: [
              // Tối ưu quan trọng: Ngăn việc vẽ lại nội dung bên dưới (Camera/Ảnh)
              RepaintBoundary(child: widget.child),

              AnimatedBuilder(
                animation: _animation,
                // Truyền màu vào widget tĩnh để không phải tạo lại toàn bộ UI
                child: _BeamWidget(color: widget.scanColor),
                builder: (context, staticChild) {
                  const double glowHeight = 200.0;
                  final double yOffset = (_animation.value * constraints.maxHeight) - glowHeight;

                  return Transform.translate(
                    offset: Offset(0, yOffset),
                    child: staticChild,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// Tách riêng thành một StatelessWidget để tận dụng tính năng 'child' của AnimatedBuilder
class _BeamWidget extends StatelessWidget {
  final Color color;
  const _BeamWidget({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withOpacity(0), color.withOpacity(0.3)],
            ),
          ),
        ),
        Container(
          height: 2.5,
          decoration: BoxDecoration(
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.8),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
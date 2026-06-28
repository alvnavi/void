import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:animate_do/animate_do.dart';

class AudioFAB extends StatefulWidget {
  final bool isRecording;
  final double soundLevel;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  const AudioFAB({
    Key? key,
    required this.isRecording,
    required this.soundLevel,
    required this.onHoldStart,
    required this.onHoldEnd,
  }) : super(key: key);

  @override
  State<AudioFAB> createState() => _AudioFABState();
}

class _AudioFABState extends State<AudioFAB> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  double _angle = 0.0;
  DateTime _lastTick = DateTime.now();

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Tick every second (just to keep it running)
    )..addListener(_updateRotation);

    _rotationController.repeat();
    _lastTick = DateTime.now();
  }

  void _updateRotation() {
    final now = DateTime.now();
    final dt = now.difference(_lastTick).inMicroseconds / 1000000.0;
    _lastTick = now;

    // Speeds in radians per second
    const double slowSpeed = math.pi / 4; // 8s for a full rotation
    const double fastSpeed = math.pi * 1.5;   // ~1.3s for a full rotation (Fast)

    double currentSpeed = widget.isRecording ? fastSpeed : slowSpeed;

    setState(() {
      _angle += dt * currentSpeed;
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double scale = 1.0 + (widget.isRecording ? (widget.soundLevel.abs() * 0.05).clamp(0.0, 0.4) : 0.0);

    return Listener(
      onPointerDown: (_) => widget.onHoldStart(),
      onPointerUp: (_) => widget.onHoldEnd(),
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.isRecording)
                Pulse(
                  infinite: true,
                  duration: const Duration(milliseconds: 1500),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              // Main Circular Button
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isRecording ? Colors.redAccent : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: widget.isRecording 
                        ? Colors.redAccent.withValues(alpha: 0.5) 
                        : Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: (math.pi / 4) + _angle, // Base 45 deg + dynamic angle
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: widget.isRecording ? Colors.white : Colors.black,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class PixelPanel extends StatelessWidget {
  const PixelPanel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.backgroundColor = const Color(0xEE233A36),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: const Color(0xFFDBD66A), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA101D24),
            offset: Offset(5, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class PixelButton extends StatelessWidget {
  const PixelButton({
    required this.label,
    required this.onPressed,
    this.width = 190,
    this.height = 52,
    this.primary = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final double width;
  final double height;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFFFC2),
          backgroundColor: primary
              ? const Color(0xFF4B2A78)
              : const Color(0xFF314736),
          disabledForegroundColor: const Color(0xFF87907A),
          disabledBackgroundColor: const Color(0xFF2C3635),
          side: const BorderSide(color: Color(0xFFDBD66A), width: 3),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: EdgeInsets.zero,
          textStyle: const TextStyle(
            fontFamily: 'friendlyscribbles',
            fontSize: 22,
            letterSpacing: 1.5,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

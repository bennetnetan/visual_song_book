import 'dart:async';
import 'package:flutter/material.dart';

/// Wraps the projection live-preview canvas with an ambient glow border and a
/// self-dismissing notification banner when an end-of-song, end-of-set, or
/// end-of-chapter boundary slide is reached.
class ProjectionPreviewGlow extends StatefulWidget {
  final bool isEndSlide;
  final String? notificationText;
  final double borderWidth;
  final Widget child;

  const ProjectionPreviewGlow({
    super.key,
    required this.isEndSlide,
    required this.notificationText,
    this.borderWidth = 3.0,
    required this.child,
  });

  @override
  State<ProjectionPreviewGlow> createState() => _ProjectionPreviewGlowState();
}

class _ProjectionPreviewGlowState extends State<ProjectionPreviewGlow> {
  Timer? _dismissTimer;
  String? _displayedText;
  bool _bannerVisible = false;

  @override
  void initState() {
    super.initState();
    _checkNotification();
  }

  @override
  void didUpdateWidget(covariant ProjectionPreviewGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEndSlide != oldWidget.isEndSlide ||
        widget.notificationText != oldWidget.notificationText) {
      _checkNotification();
    }
  }

  void _checkNotification() {
    _dismissTimer?.cancel();
    if (widget.isEndSlide && widget.notificationText != null) {
      setState(() {
        _displayedText = widget.notificationText;
        _bannerVisible = true;
      });
      _dismissTimer = Timer(const Duration(milliseconds: 3500), () {
        if (mounted) {
          setState(() {
            _bannerVisible = false;
          });
        }
      });
    } else {
      setState(() {
        _bannerVisible = false;
        _displayedText = null;
      });
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const glowColor = Color(0xFFFFB74D); // Warm amber gold

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isEndSlide
              ? glowColor
              : theme.colorScheme.outline.withValues(alpha: 0.3),
          width: widget.isEndSlide ? (widget.borderWidth + 1.0) : widget.borderWidth,
        ),
        boxShadow: widget.isEndSlide
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.55),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          widget.child,
          if (_displayedText != null)
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: AnimatedOpacity(
                opacity: _bannerVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: glowColor.withValues(alpha: 0.75),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          size: 14,
                          color: glowColor,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _displayedText!,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: glowColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
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
}

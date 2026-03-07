import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/colors.dart';

/// ══════════════════════════════════════════════════════════════════
///  IncomingCallBanner — Bannière appel entrant (thème sombre)
///  S'affiche en overlay par-dessus n'importe quel écran
/// ══════════════════════════════════════════════════════════════════
class IncomingCallBanner extends StatefulWidget {
  final String callerName, callerPhoto, callerInitials, callerId;
  final VoidCallback onAccept, onDecline;

  const IncomingCallBanner({
    super.key,
    required this.callerName,
    required this.callerPhoto,
    required this.callerInitials,
    required this.callerId,
    required this.onAccept,
    required this.onDecline,
  });

  static void show({
    required BuildContext context,
    required String callerName,
    required String callerPhoto,
    required String callerInitials,
    required String callerId,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12, right: 12,
        child: Material(
          color: Colors.transparent,
          child: IncomingCallBanner(
            callerName:     callerName,
            callerPhoto:    callerPhoto,
            callerInitials: callerInitials,
            callerId:       callerId,
            onAccept:  () { entry.remove(); onAccept(); },
            onDecline: () { entry.remove(); onDecline(); },
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Timer(const Duration(seconds: 30), () {
      try { entry.remove(); } catch (_) {}
    });
  }

  @override
  State<IncomingCallBanner> createState() => _IncomingCallBannerState();
}

class _IncomingCallBannerState extends State<IncomingCallBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double>  _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
    _slide = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(
      position: _slide,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF151A28),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.success.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: C.success.withOpacity(0.15),
              blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 4)),
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: C.success, width: 2),
              boxShadow: [BoxShadow(
                color: C.success.withOpacity(0.4), blurRadius: 12)]),
            child: ClipOval(
              child: widget.callerPhoto.isNotEmpty
                ? Image.network(widget.callerPhoto, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback())
                : _fallback()),
          ),
          const SizedBox(width: 12),
          // Infos
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.callerName,
                style: const TextStyle(
                  color: C.text, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Row(children: [
                _PulsingDot(),
                const SizedBox(width: 6),
                const Text('Appel vocal — Client',
                  style: TextStyle(color: C.muted, fontSize: 12)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          // Refuser
          GestureDetector(
            onTap: widget.onDecline,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.error.withOpacity(0.15),
                border: Border.all(color: C.error.withOpacity(0.5))),
              child: const Icon(Icons.call_end_rounded, color: C.error, size: 22))),
          const SizedBox(width: 8),
          // Accepter
          GestureDetector(
            onTap: widget.onAccept,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.success,
                boxShadow: [BoxShadow(
                  color: C.success.withOpacity(0.5), blurRadius: 12)]),
              child: const Icon(Icons.call_rounded, color: Colors.white, size: 22))),
        ]),
      ),
    ),
  );

  Widget _fallback() => Container(
    color: C.blue.withOpacity(0.2),
    child: Center(
      child: Text(widget.callerInitials,
        style: const TextStyle(
          color: C.text, fontSize: 18, fontWeight: FontWeight.w800))));
}

class _PulsingDot extends StatefulWidget {
  @override State<_PulsingDot> createState() => _PulsingDotState();
}
class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c,
    child: Container(
      width: 8, height: 8,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: C.success)));
}

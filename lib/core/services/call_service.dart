import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// ══════════════════════════════════════════════════════════════════
///  CallService — Appels voix in-app pour l'app Chauffeur
///  Thème sombre adapté au design de l'application chauffeur
/// ══════════════════════════════════════════════════════════════════

enum CallState { idle, calling, ringing, connected, ended }
enum CallType  { voice, video }

class CallService {
  static CallState _state = CallState.idle;
  static CallState get state => _state;

  static final _stateCtrl = StreamController<CallState>.broadcast();
  static Stream<CallState> get onStateChange => _stateCtrl.stream;

  static Future<void> startCall({
    required BuildContext context,
    required String calleeName,
    required String calleeId,
    required String calleePhoto,
    required String calleeInitials,
    CallType type = CallType.voice,
  }) async {
    _setState(CallState.calling);
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => CallScreen(
          calleeName:     calleeName,
          calleeId:       calleeId,
          calleePhoto:    calleePhoto,
          calleeInitials: calleeInitials,
          callType:       type,
          isIncoming:     false,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    _setState(CallState.idle);
  }

  static Future<void> showIncomingCall({
    required BuildContext context,
    required String callerName,
    required String callerId,
    required String callerPhoto,
    required String callerInitials,
  }) async {
    _setState(CallState.ringing);
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => CallScreen(
        calleeName:     callerName,
        calleeId:       callerId,
        calleePhoto:    callerPhoto,
        calleeInitials: callerInitials,
        callType:       CallType.voice,
        isIncoming:     true,
      ),
    );
    _setState(CallState.idle);
  }

  static void _setState(CallState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  static void dispose() => _stateCtrl.close();
}

/// ══════════════════════════════════════════════════════════════════
///  CallScreen — Écran d'appel (thème sombre chauffeur)
/// ══════════════════════════════════════════════════════════════════
class CallScreen extends StatefulWidget {
  final String calleeName, calleeId, calleePhoto, calleeInitials;
  final CallType callType;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.calleeName,
    required this.calleeId,
    required this.calleePhoto,
    required this.calleeInitials,
    required this.callType,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  bool _connected  = false;
  bool _muted      = false;
  bool _speakerOn  = false;
  int  _seconds    = 0;
  Timer? _timer;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    if (!widget.isIncoming) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _onConnect();
      });
    }
  }

  void _onConnect() {
    setState(() => _connected = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    _pulseCtrl.stop();
  }

  void _hangUp() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  String get _timeLabel {
    if (!_connected) return widget.isIncoming ? 'Appel entrant...' : 'Connexion...';
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds  % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [Color(0xFF0A0E1A), Color(0xFF0F1829), Color(0xFF0A0E1A)],
        ),
      ),
      child: SafeArea(
        child: Column(children: [
          const Spacer(flex: 1),

          // ── Type d'appel ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: C.blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.blue.withOpacity(0.3))),
            child: Text(
              widget.callType == CallType.video ? '📹 Appel vidéo' : '📞 Appel vocal TopTopGo',
              style: TextStyle(color: C.blue, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 32),

          // ── Avatar pulsant ─────────────────────────────────────────
          ScaleTransition(
            scale: _connected ? const AlwaysStoppedAnimation(1.0) : _pulseAnim,
            child: Stack(alignment: Alignment.center, children: [
              if (!_connected) ...[
                Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: C.blue.withOpacity(0.05))),
                Container(
                  width: 115, height: 115,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: C.blue.withOpacity(0.09))),
              ],
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _connected ? C.success : C.blue,
                    width: 3),
                  boxShadow: [BoxShadow(
                    color: (_connected ? C.success : C.blue).withOpacity(0.45),
                    blurRadius: 28, spreadRadius: 4)]),
                child: ClipOval(
                  child: widget.calleePhoto.isNotEmpty
                    ? Image.network(widget.calleePhoto, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallback())
                    : _fallback()),
              ),
            ]),
          ),

          const SizedBox(height: 28),

          // ── Nom ────────────────────────────────────────────────────
          Text(widget.calleeName,
            style: const TextStyle(
              color: C.text, fontSize: 26,
              fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          const Text('Client', style: TextStyle(color: C.muted, fontSize: 13)),
          const SizedBox(height: 12),

          // ── Durée / statut ─────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _timeLabel,
              key: ValueKey(_timeLabel),
              style: TextStyle(
                color: _connected ? C.success : C.blue,
                fontSize: 16,
                fontWeight: _connected ? FontWeight.w700 : FontWeight.normal)),
          ),

          const Spacer(flex: 2),

          // ── Contrôles (connecté seulement) ─────────────────────────
          if (_connected) ...[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _CtrlBtn(
                icon:   _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label:  _muted ? 'Muet' : 'Micro',
                active: _muted,
                onTap:  () => setState(() => _muted = !_muted),
              ),
              const SizedBox(width: 36),
              _CtrlBtn(
                icon:   _speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                label:  'HP',
                active: _speakerOn,
                onTap:  () => setState(() => _speakerOn = !_speakerOn),
              ),
            ]),
            const SizedBox(height: 44),
          ],

          // ── Boutons principaux ──────────────────────────────────────
          if (widget.isIncoming && !_connected)
            _IncomingActions(onAccept: _onConnect, onDecline: _hangUp)
          else
            _HangUpBtn(onTap: _hangUp),

          const SizedBox(height: 52),
        ]),
      ),
    ),
  );

  Widget _fallback() => Container(
    color: C.blue.withOpacity(0.2),
    child: Center(
      child: Text(widget.calleeInitials,
        style: const TextStyle(
          color: C.text, fontSize: 32, fontWeight: FontWeight.w800))));
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(
        width: 62, height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? C.blue : Colors.white.withOpacity(0.12)),
        child: Icon(icon, color: active ? Colors.white : C.text, size: 26)),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: C.muted, fontSize: 11)),
    ]),
  );
}

class _HangUpBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _HangUpBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => Column(children: [
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: C.error,
          boxShadow: [BoxShadow(color: C.error.withOpacity(0.5), blurRadius: 20, spreadRadius: 4)]),
        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32))),
    const SizedBox(height: 10),
    const Text('Raccrocher', style: TextStyle(color: C.muted, fontSize: 12)),
  ]);
}

class _IncomingActions extends StatelessWidget {
  final VoidCallback onAccept, onDecline;
  const _IncomingActions({required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      Column(children: [
        GestureDetector(
          onTap: onDecline,
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: C.error,
              boxShadow: [BoxShadow(color: C.error.withOpacity(0.5), blurRadius: 20, spreadRadius: 4)]),
            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32))),
        const SizedBox(height: 10),
        const Text('Refuser', style: TextStyle(color: C.muted, fontSize: 12)),
      ]),
      Column(children: [
        GestureDetector(
          onTap: onAccept,
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: C.success,
              boxShadow: [BoxShadow(color: C.success.withOpacity(0.5), blurRadius: 20, spreadRadius: 4)]),
            child: const Icon(Icons.call_rounded, color: Colors.white, size: 32))),
        const SizedBox(height: 10),
        const Text('Répondre', style: TextStyle(color: C.muted, fontSize: 12)),
      ]),
    ],
  );
}

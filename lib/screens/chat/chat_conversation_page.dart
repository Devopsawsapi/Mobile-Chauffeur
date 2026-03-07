import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../core/services/moderation_service.dart';
import '../../core/services/call_service.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/incoming_call_banner.dart';

/// ══════════════════════════════════════════════════════════════════
///  ChatConversationPage — App Chauffeur
///  • Appels voix in-app style WhatsApp
///  • Modération des messages en temps réel
///  • Indicateur "en train d'écrire"
///  • Notifications Pusher (appels + messages)
/// ══════════════════════════════════════════════════════════════════
class ChatConversationPage extends StatefulWidget {
  final String name, initials, tripId;
  final String clientPhoto, clientPhone, clientId;

  const ChatConversationPage({
    super.key,
    required this.name,
    required this.initials,
    required this.tripId,
    this.clientPhoto = '',
    this.clientPhone = '',
    this.clientId    = '',
  });

  @override
  State<ChatConversationPage> createState() => _ConvState();
}

class _ConvState extends State<ChatConversationPage> {
  final _ctrl = TextEditingController();
  final _sc   = ScrollController();
  List<dynamic> _msgs = [];
  bool _loading    = false;
  bool _sending    = false;
  bool _isTyping   = false;
  String _modPrev  = '';

  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  PusherChannel? _channel;
  String get _ch => 'trip.${widget.tripId}';

  @override
  void initState() {
    super.initState();
    _load();
    _initPusher();
    _ctrl.addListener(_onText);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onText);
    _ctrl.dispose();
    _sc.dispose();
    _pusher.unsubscribe(channelName: _ch);
    _pusher.disconnect();
    super.dispose();
  }

  // ── Modération en temps réel ────────────────────────────────────
  void _onText() {
    final r = ModerationService.check(_ctrl.text.trim());
    final p = r.isBlocked ? r.message ?? '' : '';
    if (p != _modPrev) setState(() => _modPrev = p);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('${Api.messages}/${widget.tripId}');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        final raw = res['messages'] ?? res['data'] ?? [];
        _msgs = (raw as List).map((m) {
          if (m['sender'] is Map) {
            final s = (m['sender_type'] ?? '').toString();
            m = Map<String, dynamic>.from(m);
            m['sender'] = s.contains('Driver') ? 'driver' : 'client';
          }
          return m;
        }).toList();
      }
    });
    _scroll();
  }

  Future<void> _initPusher() async {
    try {
      await _pusher.init(
        apiKey: 'b936f5c8f1666939a7fa', cluster: 'eu',
        onError: (m, c, e) => debugPrint('Pusher: $m'),
        onConnectionStateChange: (cur, _) => debugPrint('Pusher: $cur'),
      );
      await _pusher.connect();
      _channel = await _pusher.subscribe(
        channelName: _ch,
        onEvent: (event) {
          if (event.data == null) return;
          final data = json.decode(event.data);

          // ── Appel entrant du client ──
          if (event.eventName == 'call.incoming' && mounted) {
            IncomingCallBanner.show(
              context: context,
              callerName:     data['caller_name'] ?? widget.name,
              callerPhoto:    data['caller_photo'] ?? widget.clientPhoto,
              callerInitials: widget.initials,
              callerId:       data['caller_id']?.toString() ?? widget.clientId,
              onAccept: () => CallService.startCall(
                context: context,
                calleeName:     data['caller_name'] ?? widget.name,
                calleeId:       data['caller_id']?.toString() ?? widget.clientId,
                calleePhoto:    data['caller_photo'] ?? widget.clientPhoto,
                calleeInitials: widget.initials,
              ),
              onDecline: () {},
            );
            return;
          }

          // ── Client en train d'écrire ──
          if (event.eventName == 'client-typing' && mounted) {
            setState(() => _isTyping = true);
            Future.delayed(const Duration(seconds: 3),
              () { if (mounted) setState(() => _isTyping = false); });
            return;
          }

          if (event.eventName != 'message.sent') return;
          final sType  = (data['sender_type'] ?? '').toString();
          final sender = sType.contains('Driver') ? 'driver' : 'client';
          final content = data['content']?.toString() ?? '';
          final exists = _msgs.any((m) =>
            m['content'] == content && m['sender'] == sender && m['_pending'] == true);
          setState(() {
            if (exists) {
              final idx = _msgs.lastIndexWhere((m) =>
                m['content'] == content && m['sender'] == sender && m['_pending'] == true);
              if (idx != -1) _msgs[idx] = {
                'content': content, 'sender': sender, 'created_at': data['created_at']};
            } else {
              _msgs.add({'content': content, 'sender': sender, 'created_at': data['created_at']});
            }
          });
          _scroll();
        },
      );
    } catch (e) { debugPrint('Pusher init: $e'); }
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _sending) return;

    final r = ModerationService.check(t);
    if (r.isBlocked) {
      _ctrl.clear();
      setState(() => _modPrev = '');
      _showModAlert(r);
      return;
    }

    _ctrl.clear();
    setState(() {
      _modPrev = '';
      _msgs.add({'content': t, 'sender': 'driver',
        'created_at': DateTime.now().toIso8601String(), '_pending': true});
      _sending = true;
    });
    _scroll();

    final res = await ApiService.post('${Api.messages}/${widget.tripId}', {'content': t});
    setState(() => _sending = false);
    if (res['success'] != true && mounted) snack(context, 'Message non envoyé', error: true);
  }

  void _scroll() => Future.delayed(const Duration(milliseconds: 100), () {
    if (_sc.hasClients) _sc.animateTo(
      _sc.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut);
  });

  // ── Alerte modération (thème sombre) ────────────────────────────
  void _showModAlert(ModerationResult r) {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: C.error.withOpacity(0.4)),
          boxShadow: [BoxShadow(
            color: C.error.withOpacity(0.1),
            blurRadius: 24, offset: const Offset(0, 8))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: C.error.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: C.error.withOpacity(0.4))),
            child: Center(child: Text(r.icon, style: const TextStyle(fontSize: 28)))),
          const SizedBox(height: 16),
          const Text('Message bloqué',
            style: TextStyle(color: C.text, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(r.message ?? '',
            style: const TextStyle(color: C.muted, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: C.surface, borderRadius: BorderRadius.circular(10)),
            child: const Text(
              '🛡️ Tous les échanges sont surveillés pour votre sécurité.',
              style: TextStyle(color: C.muted, fontSize: 11, height: 1.5),
              textAlign: TextAlign.center)),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: C.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Compris',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
        ]),
      ),
    ));
  }

  // ── Initier un appel vers le client ─────────────────────────────
  Future<void> _startCall() => CallService.startCall(
    context: context,
    calleeName:     widget.name,
    calleeId:       widget.clientId,
    calleePhoto:    widget.clientPhoto,
    calleeInitials: widget.initials,
  );

  Widget _fallback() => Container(
    color: C.orange.withOpacity(0.15),
    child: Center(child: Text(widget.initials,
      style: const TextStyle(
        color: C.orange, fontSize: 18, fontWeight: FontWeight.w800))));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: _buildAppBar(),
    body: Column(children: [
      _SecurityBanner(),
      Expanded(child: _buildMessages()),
      if (_isTyping) _buildTypingIndicator(),
      if (_modPrev.isNotEmpty) _buildModPreview(),
      _buildInputBar(),
    ]),
  );

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: C.card,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_rounded, color: C.text, size: 20),
      onPressed: () => Navigator.pop(context)),
    titleSpacing: 0,
    title: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: C.orange.withOpacity(0.5), width: 2)),
        child: ClipOval(
          child: widget.clientPhoto.isNotEmpty
            ? Image.network(widget.clientPhoto, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback())
            : _fallback()),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.name,
          style: const TextStyle(color: C.text, fontSize: 15, fontWeight: FontWeight.w700)),
        Text('Client · Trajet #${widget.tripId}',
          style: const TextStyle(color: C.muted, fontSize: 11)),
      ]),
    ]),
    actions: [
      GestureDetector(
        onTap: _startCall,
        child: Container(
          margin: const EdgeInsets.only(right: 16),
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: C.success.withOpacity(0.12),
            border: Border.all(color: C.success.withOpacity(0.4))),
          child: const Icon(Icons.call_rounded, color: C.success, size: 20))),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: C.border)),
  );

  Widget _buildMessages() {
    if (_loading) return const Center(child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation(C.blue)));

    if (_msgs.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: C.surface),
          child: const Icon(Icons.chat_bubble_outline_rounded, color: C.muted, size: 32)),
        const SizedBox(height: 14),
        const Text('Démarrez la conversation',
          style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('Messages sécurisés TopTopGo',
          style: TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _startCall,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: C.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: C.success.withOpacity(0.3))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.call_rounded, color: C.success, size: 18),
              SizedBox(width: 8),
              Text('Appeler le client',
                style: TextStyle(color: C.success, fontWeight: FontWeight.w700)),
            ]))),
      ],
    ));

    return ListView.builder(
      controller: _sc,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _msgs.length,
      itemBuilder: (_, i) {
        final m       = _msgs[i];
        final mine    = m['sender'] == 'driver';
        final t       = m['created_at']?.toString() ?? '';
        final pending = m['_pending'] == true;

        if (m['refused'] == true || m['blocked'] == true) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: C.error.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.error.withOpacity(0.3))),
            child: const Row(children: [
              Icon(Icons.block_rounded, color: C.error, size: 14),
              SizedBox(width: 8),
              Text('Message bloqué par la modération',
                style: TextStyle(color: C.error, fontSize: 12, fontStyle: FontStyle.italic)),
            ]));
        }

        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mine ? C.orange : C.surface,
              borderRadius: BorderRadius.only(
                topLeft:     const Radius.circular(18),
                topRight:    const Radius.circular(18),
                bottomLeft:  Radius.circular(mine ? 18 : 4),
                bottomRight: Radius.circular(mine ? 4 : 18)),
              boxShadow: [BoxShadow(
                color: mine ? C.orange.withOpacity(0.2) : Colors.black.withOpacity(0.15),
                blurRadius: 6, offset: const Offset(0, 2))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(m['content'] ?? '',
                style: TextStyle(
                  color: mine ? Colors.white : C.text,
                  fontSize: 14, height: 1.4)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(t.length > 16 ? t.substring(11, 16) : t,
                  style: TextStyle(
                    color: mine ? Colors.white60 : C.muted, fontSize: 10)),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(pending ? Icons.access_time_rounded : Icons.done_all_rounded,
                    size: 12,
                    color: pending ? Colors.white38 : Colors.white70),
                ],
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildTypingIndicator() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          _Dot(delay: 0), const SizedBox(width: 4),
          _Dot(delay: 200), const SizedBox(width: 4),
          _Dot(delay: 400),
        ]),
      ),
      const SizedBox(width: 8),
      Text('${widget.name} écrit...',
        style: const TextStyle(color: C.muted, fontSize: 11)),
    ]),
  );

  Widget _buildModPreview() => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: C.error.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: C.error.withOpacity(0.3))),
    child: Row(children: [
      const Icon(Icons.block_rounded, color: C.error, size: 14),
      const SizedBox(width: 8),
      Expanded(child: Text(_modPrev,
        style: const TextStyle(color: C.error, fontSize: 11, height: 1.4))),
    ]),
  );

  Widget _buildInputBar() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
    decoration: BoxDecoration(
      color: C.card,
      border: Border(top: BorderSide(color: C.border))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _modPrev.isNotEmpty ? C.error.withOpacity(0.5) : C.border)),
          child: TextField(
            controller: _ctrl,
            style: const TextStyle(color: C.text, fontSize: 14),
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: const InputDecoration(
              hintText: 'Message...',
              hintStyle: TextStyle(color: C.muted),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: InputBorder.none),
          ),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _send,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _modPrev.isNotEmpty ? C.muted : C.blue,
            boxShadow: _modPrev.isEmpty ? [
              BoxShadow(
                color: C.blue.withOpacity(0.4),
                blurRadius: 10, offset: const Offset(0, 4)),
            ] : null),
          child: _sending
            ? const Padding(padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.send_rounded, color: Colors.white, size: 20))),
    ]),
  );
}

// ── Bannière sécurité (thème sombre) ────────────────────────────────
class _SecurityBanner extends StatefulWidget {
  @override State<_SecurityBanner> createState() => _SecurityBannerState();
}
class _SecurityBannerState extends State<_SecurityBanner> {
  bool _visible = true;
  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: C.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.blue.withOpacity(0.3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.verified_user_rounded, color: C.blue, size: 16),
        const SizedBox(width: 8),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🛡️ Échanges sécurisés',
            style: TextStyle(color: C.blue, fontSize: 11, fontWeight: FontWeight.w800)),
          SizedBox(height: 3),
          Text(
            'Numéros, e-mails et liens bloqués automatiquement. '
            'Utilisez le bouton 📞 pour appeler le client.',
            style: TextStyle(color: C.muted, fontSize: 10, height: 1.5)),
        ])),
        GestureDetector(
          onTap: () => setState(() => _visible = false),
          child: const Padding(padding: EdgeInsets.all(4),
            child: Icon(Icons.close_rounded, color: C.muted, size: 14))),
      ]),
    );
  }
}

// ── Dots animés (typing indicator) ──────────────────────────────────
class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override State<_Dot> createState() => _DotState();
}
class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse: true);
    });
    _a = Tween<double>(begin: 0.3, end: 1.0).animate(_c);
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: Container(width: 6, height: 6,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: C.muted)));
}

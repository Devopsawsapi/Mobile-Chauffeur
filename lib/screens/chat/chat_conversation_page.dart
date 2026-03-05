import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/app_widgets.dart';

class ChatConversationPage extends StatefulWidget {
  final String name, initials, tripId;
  final String clientPhoto;   // FIX: photo du client
  final String clientPhone;   // FIX: téléphone pour appel direct
  final String clientId;

  const ChatConversationPage({
    super.key,
    required this.name,
    required this.initials,
    required this.tripId,
    this.clientPhoto = '',
    this.clientPhone = '',
    this.clientId    = '',
  });
  @override State<ChatConversationPage> createState() => _ConvState();
}

class _ConvState extends State<ChatConversationPage> {
  final _ctrl = TextEditingController();
  final _sc   = ScrollController();
  List<dynamic> _msgs = [];
  bool _loading = false, _sending = false;

  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  PusherChannel? _channel;
  String get _channelName => 'trip.${widget.tripId}';

  @override
  void initState() { super.initState(); _load(); _initPusher(); }

  @override
  void dispose() {
    _ctrl.dispose(); _sc.dispose();
    _pusher.unsubscribe(channelName: _channelName);
    _pusher.disconnect();
    super.dispose();
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
            final sType = (m['sender_type'] ?? '').toString();
            m = Map<String, dynamic>.from(m);
            m['sender'] = sType.contains('Driver') ? 'driver' : 'client';
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
        onError: (m, c, e) => debugPrint('Pusher erreur: $m'),
        onConnectionStateChange: (cur, prev) => debugPrint('Pusher: $cur'),
      );
      await _pusher.connect();
      _channel = await _pusher.subscribe(
        channelName: _channelName,
        onEvent: (event) {
          if (event.eventName != 'message.sent' || event.data == null) return;
          final data   = json.decode(event.data);
          if (!mounted) return;
          final sType  = (data['sender_type'] ?? '').toString();
          final sender = sType.contains('Driver') ? 'driver' : 'client';
          final content = data['content']?.toString() ?? '';
          final exists  = _msgs.any((m) =>
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
    } catch (e) { debugPrint('Pusher init erreur: $e'); }
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    _ctrl.clear();
    setState(() {
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
    if (_sc.hasClients) _sc.animateTo(_sc.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  });

  // FIX: appel direct (numéro réel)
  Future<void> _callDirect() async {
    if (widget.clientPhone.isEmpty) {
      snack(context, 'Numéro de téléphone non disponible', error: true); return;
    }
    final uri = Uri.parse('tel:${widget.clientPhone}');
    if (await canLaunchUrl(uri)) {
      launchUrl(uri);
    } else {
      snack(context, 'Impossible d\'appeler', error: true);
    }
  }

  // FIX: appel in-app (via API TopTopGo — VoIP future)
  void _callInApp() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: C.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        // Avatar animé
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: C.orange, width: 3),
            boxShadow: [BoxShadow(color: C.orange.withOpacity(0.3), blurRadius: 20)]),
          child: ClipOval(
            child: widget.clientPhoto.isNotEmpty
              ? Image.network(widget.clientPhoto, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _avatarFallback())
              : _avatarFallback())),
        const SizedBox(height: 14),
        Text(widget.name,
          style: const TextStyle(color: C.text, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Appel en cours...', style: TextStyle(color: C.muted, fontSize: 13)),
        const SizedBox(height: 20),
        // Bouton raccrocher
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 60, height: 60,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28))),
        const SizedBox(height: 10),
        const Text('Appel in-app TopTopGo', style: TextStyle(color: C.muted, fontSize: 11)),
      ]),
    ));
  }

  Widget _avatarFallback() => Container(
    color: C.orange.withOpacity(0.2),
    child: Center(child: Text(widget.initials,
      style: const TextStyle(color: C.orange, fontSize: 20, fontWeight: FontWeight.w800))));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(
      backgroundColor: C.card, elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: C.text),
        onPressed: () => Navigator.pop(context)),
      title: Row(children: [
        // FIX: photo du client dans l'AppBar
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: C.orange, width: 1.5)),
          child: ClipOval(
            child: widget.clientPhoto.isNotEmpty
              ? Image.network(widget.clientPhoto, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _avatarFallback())
              : _avatarFallback())),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.name,
            style: const TextStyle(color: C.text, fontSize: 14, fontWeight: FontWeight.w700)),
          const Text('Client', style: TextStyle(color: C.muted, fontSize: 11)),
        ]),
      ]),
      // FIX: boutons appel DIRECT + IN-APP
      actions: [
        // Appel in-app TopTopGo
        GestureDetector(
          onTap: _callInApp,
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: C.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.orange.withOpacity(0.4))),
            child: const Row(children: [
              Icon(Icons.call_rounded, color: C.orange, size: 14),
              SizedBox(width: 4),
              Text('App', style: TextStyle(color: C.orange, fontSize: 11, fontWeight: FontWeight.w700)),
            ]))),
        // Appel direct (numéro réel)
        if (widget.clientPhone.isNotEmpty)
          GestureDetector(
            onTap: _callDirect,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.4))),
              child: const Row(children: [
                Icon(Icons.phone_rounded, color: Colors.green, size: 14),
                SizedBox(width: 4),
                Text('Direct', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w700)),
              ]))),
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border)),
    ),
    body: Column(children: [
      Expanded(
        child: _loading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(C.orange)))
          : _msgs.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.chat_bubble_outline_rounded, color: C.muted.withOpacity(0.4), size: 52),
                const SizedBox(height: 12),
                const Text('Démarrez la conversation', style: TextStyle(color: C.muted)),
                if (widget.clientPhone.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _callDirect,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.withOpacity(0.3))),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.phone_rounded, color: Colors.green, size: 16),
                        SizedBox(width: 6),
                        Text('Appeler le client',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
                      ]))),
                ],
              ]))
            : ListView.builder(
                controller: _sc,
                padding: const EdgeInsets.all(16),
                itemCount: _msgs.length,
                itemBuilder: (_, i) {
                  final m         = _msgs[i];
                  final mine      = m['sender'] == 'driver';
                  final t         = m['created_at']?.toString() ?? '';
                  final isPending = m['_pending'] == true;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: mine ? C.orange : C.surface,
                        borderRadius: BorderRadius.only(
                          topLeft:     const Radius.circular(16),
                          topRight:    const Radius.circular(16),
                          bottomLeft:  Radius.circular(mine ? 16 : 4),
                          bottomRight: Radius.circular(mine ? 4 : 16))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(m['content'] ?? '',
                          style: const TextStyle(color: C.text, fontSize: 14, height: 1.4)),
                        const SizedBox(height: 4),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(t.length > 16 ? t.substring(11, 16) : t,
                            style: TextStyle(
                              color: mine ? Colors.white60 : C.muted, fontSize: 10)),
                          if (mine) ...[
                            const SizedBox(width: 4),
                            Icon(
                              isPending ? Icons.access_time_rounded : Icons.done_all_rounded,
                              size: 12,
                              color: isPending ? Colors.white38 : Colors.white70),
                          ],
                        ]),
                      ]),
                    ),
                  );
                }),
      ),
      inputBar(_ctrl, _send, sending: _sending),
    ]),
  );
}

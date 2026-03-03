import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/app_widgets.dart';

class ChatConversationPage extends StatefulWidget {
  final String name, initials, tripId;
  const ChatConversationPage({super.key,
    required this.name, required this.initials, required this.tripId});
  @override State<ChatConversationPage> createState() => _ConvState();
}

class _ConvState extends State<ChatConversationPage> {
  final _ctrl = TextEditingController();
  final _sc   = ScrollController();
  List<dynamic> _msgs = []; bool _loading = true, _sending = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _ctrl.dispose(); _sc.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('${Api.messages}/${widget.tripId}');
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

  Future<void> _send() async {
    final t = _ctrl.text.trim(); if (t.isEmpty) return;
    _ctrl.clear();
    setState(() {
      _msgs.add({'content': t, 'sender': 'driver', 'created_at': DateTime.now().toIso8601String()});
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(backgroundColor: C.card, elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: C.text),
        onPressed: () => Navigator.pop(context)),
      title: Row(children: [
        Container(width: 36, height: 36,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [C.orange, Color(0xFFE8921A)]),
            shape: BoxShape.circle),
          child: Center(child: Text(widget.initials,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)))),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.name, style: const TextStyle(color: C.text, fontSize: 14, fontWeight: FontWeight.w700)),
          const Text('En ligne', style: TextStyle(color: C.online, fontSize: 11)),
        ]),
      ]),
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border))),
    body: Column(children: [
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(C.orange)))
        : ListView.builder(
            controller: _sc,
            padding: const EdgeInsets.all(16),
            itemCount: _msgs.length,
            itemBuilder: (_, i) {
              final m = _msgs[i];
              final mine = m['sender'] == 'driver';
              final t = m['created_at']?.toString() ?? '';
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: mine ? C.orange : C.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(mine ? 16 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 16))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(m['content'] ?? '',
                      style: const TextStyle(color: C.text, fontSize: 14, height: 1.4)),
                    const SizedBox(height: 4),
                    Text(t.length > 16 ? t.substring(11, 16) : t,
                      style: TextStyle(color: mine ? Colors.white60 : C.muted, fontSize: 10)),
                  ])));
            })),
      inputBar(_ctrl, _send, sending: _sending),
    ]));
}

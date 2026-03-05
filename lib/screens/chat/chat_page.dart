import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../widgets/tt_logo.dart';
import 'chat_conversation_page.dart';
import 'support_chat_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<dynamic> _convos = [];
  bool _loading = true;

  @override void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); _load(); }
  @override void dispose()   { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get(Api.messages);
    setState(() {
      _loading = false;
      if (res['success'] == true) _convos = res['data'] ?? res['conversations'] ?? [];
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(
      backgroundColor: C.card, elevation: 0,
      title: Row(children: [
        const TTIconLogo(size: 34, glow: false), const SizedBox(width: 10),
        const TTTextLogo(fontSize: 18), const SizedBox(width: 8),
        const Text('· Messagerie', style: TextStyle(color: C.muted, fontSize: 13))]),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded, color: C.muted, size: 20), onPressed: _load),
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border))),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14)),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              gradient: const LinearGradient(colors: [C.orange, Color(0xFFE8921A)]),
              borderRadius: BorderRadius.circular(12)),
            dividerColor: Colors.transparent, padding: const EdgeInsets.all(4),
            labelColor: Colors.white, unselectedLabelColor: C.muted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: const [Tab(text: '💬 Clients'), Tab(text: '🛠 Support')]))),
      Expanded(child: TabBarView(controller: _tab, children: [
        // ── Onglet Clients ────────────────────────────────────────────────────
        _loading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(C.orange)))
          : RefreshIndicator(
              onRefresh: _load, color: C.orange,
              child: _convos.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 60),
                    Center(child: Column(children: [
                      Icon(Icons.chat_bubble_outline_rounded, color: C.muted, size: 52),
                      SizedBox(height: 12),
                      Text('Aucune conversation',
                        style: TextStyle(color: C.muted, fontSize: 14)),
                      SizedBox(height: 6),
                      Text('Les clients peuvent vous écrire\naprès réservation confirmée',
                        style: TextStyle(color: C.muted, fontSize: 12),
                        textAlign: TextAlign.center),
                    ])),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _convos.length,
                    itemBuilder: (_, i) {
                      final c       = _convos[i];
                      final name    = c['client_name']  ?? c['user_name'] ?? c['name'] ?? 'Client';
                      final last    = c['last_message']  ?? '';
                      final time    = c['updated_at']?.toString() ?? '';
                      final unread  = c['unread_count'] ?? 0;
                      final tripId  = (c['trip_id'] ?? c['id'] ?? '').toString();
                      // FIX: récupérer photo + téléphone client
                      final photo   = c['client_photo']?.toString() ?? c['user_photo']?.toString() ?? '';
                      final phone   = c['client_phone']?.toString() ?? c['user_phone']?.toString() ?? '';
                      final clientId = c['client_id'] ?? c['user_id'];
                      // Status de la réservation
                      final bookingStatus = c['booking_status']?.toString() ?? c['status']?.toString() ?? '';
                      final isConfirmed = ['confirmed','paid','accepted','in_progress']
                          .contains(bookingStatus.toLowerCase());
                      final ini = name.split(' ')
                          .map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChatConversationPage(
                            name:      name,
                            initials:  ini.isNotEmpty ? ini : 'CL',
                            tripId:    tripId,
                            clientPhoto: photo,
                            clientPhone: phone,
                            clientId:  clientId?.toString() ?? '',
                          ))),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: C.card, borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: unread > 0 ? C.orange.withOpacity(0.4) : C.border)),
                          child: Row(children: [
                            // FIX: photo client avec fallback initiales
                            _clientAvatar(photo, ini, 24),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(name,
                                  style: const TextStyle(color: C.text, fontWeight: FontWeight.w700))),
                                // FIX: badge statut réservation
                                if (isConfirmed)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6)),
                                    child: const Text('Confirmé',
                                      style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w700)))
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: C.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6)),
                                    child: const Text('En attente',
                                      style: TextStyle(color: C.orange, fontSize: 9, fontWeight: FontWeight.w700))),
                              ]),
                              const SizedBox(height: 4),
                              Text(last.isNotEmpty ? last : 'Aucun message',
                                style: const TextStyle(color: C.muted, fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                            ])),
                            const SizedBox(width: 8),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(time.length > 16 ? time.substring(11, 16) : time,
                                style: const TextStyle(color: C.muted, fontSize: 11)),
                              const SizedBox(height: 6),
                              if (unread > 0)
                                Container(
                                  width: 20, height: 20,
                                  decoration: const BoxDecoration(color: C.orange, shape: BoxShape.circle),
                                  child: Center(child: Text('$unread',
                                    style: const TextStyle(color: Colors.white, fontSize: 10,
                                      fontWeight: FontWeight.w700)))),
                              const SizedBox(height: 4),
                              // FIX: bouton appel direct depuis la liste
                              if (phone.isNotEmpty)
                                GestureDetector(
                                  onTap: () async {
                                    final uri = Uri.parse('tel:$phone');
                                    if (await canLaunchUrl(uri)) launchUrl(uri);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.12),
                                      shape: BoxShape.circle),
                                    child: const Icon(Icons.phone_rounded, color: Colors.green, size: 14))),
                            ]),
                          ])));
                    })),
        // ── Onglet Support ────────────────────────────────────────────────────
        const SupportChatPage(embedded: true),
      ])),
    ]));

  Widget _clientAvatar(String photo, String ini, double radius) {
    if (photo.isNotEmpty) {
      return Container(
        width: radius * 2, height: radius * 2,
        decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: C.orange, width: 1.5)),
        child: ClipOval(child: Image.network(photo, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _iniAvatar(ini, radius))));
    }
    return _iniAvatar(ini, radius);
  }

  Widget _iniAvatar(String ini, double radius) => Container(
    width: radius * 2, height: radius * 2,
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [C.orange, Color(0xFFE8921A)]),
      shape: BoxShape.circle),
    child: Center(child: Text(ini.isNotEmpty ? ini : 'CL',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))));
}

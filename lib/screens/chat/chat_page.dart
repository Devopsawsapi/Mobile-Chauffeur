import 'package:flutter/material.dart';
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
  List<dynamic> _convos = []; bool _loading = true;

  @override void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); _load(); }
  @override void dispose() { _tab.dispose(); super.dispose(); }

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
    appBar: AppBar(backgroundColor: C.card, elevation: 0,
      title: Row(children: [
        const TTIconLogo(size: 34, glow: false), const SizedBox(width: 10),
        const TTTextLogo(fontSize: 18), const SizedBox(width: 8),
        const Text('· Messagerie', style: TextStyle(color: C.muted, fontSize: 13))]),
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border))),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14)),
          child: TabBar(controller: _tab,
            indicator: BoxDecoration(
              gradient: const LinearGradient(colors: [C.orange, Color(0xFFE8921A)]),
              borderRadius: BorderRadius.circular(12)),
            dividerColor: Colors.transparent, padding: const EdgeInsets.all(4),
            labelColor: Colors.white, unselectedLabelColor: C.muted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: const [Tab(text: '💬 Clients'), Tab(text: '🛠 Support')]))),
      Expanded(child: TabBarView(controller: _tab, children: [
        // Onglet Clients
        _loading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(C.orange)))
          : RefreshIndicator(onRefresh: _load, color: C.orange,
              child: _convos.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 80),
                    Center(child: Text('Aucune conversation', style: TextStyle(color: C.muted))),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _convos.length,
                    itemBuilder: (_, i) {
                      final c      = _convos[i];
                      final name   = c['client_name'] ?? c['name'] ?? 'Client';
                      final last   = c['last_message'] ?? '';
                      final time   = c['updated_at']?.toString() ?? '';
                      final unread = c['unread_count'] ?? 0;
                      final tripId = (c['trip_id'] ?? c['id'] ?? '').toString();
                      final ini    = name.split(' ')
                        .map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChatConversationPage(
                            name: name,
                            initials: ini.isNotEmpty ? ini : 'CL',
                            tripId: tripId))),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: C.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: C.border)),
                          child: Row(children: [
                            Container(width: 48, height: 48,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: [C.orange, Color(0xFFE8921A)]),
                                shape: BoxShape.circle),
                              child: Center(child: Text(ini.isNotEmpty ? ini : 'CL',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(name, style: const TextStyle(color: C.text, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(last, style: const TextStyle(color: C.muted, fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(time.length > 16 ? time.substring(11, 16) : time,
                                style: const TextStyle(color: C.muted, fontSize: 11)),
                              const SizedBox(height: 6),
                              if (unread > 0)
                                Container(width: 20, height: 20,
                                  decoration: const BoxDecoration(color: C.orange, shape: BoxShape.circle),
                                  child: Center(child: Text('$unread',
                                    style: const TextStyle(color: Colors.white, fontSize: 10,
                                      fontWeight: FontWeight.w700)))),
                            ]),
                          ])));
                    })),
        // Onglet Support
        const SupportChatPage(embedded: true),
      ])),
    ]));
}

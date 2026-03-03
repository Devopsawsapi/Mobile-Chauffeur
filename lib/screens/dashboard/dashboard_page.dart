import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../core/models/driver_model.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/tt_logo.dart';
import '../../widgets/app_widgets.dart';
import '../profile/wallet_page.dart';
import '../chat/support_chat_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override State<DashboardPage> createState() => _DashState();
}

class _DashState extends State<DashboardPage> {
  bool _loadData = false, _loadStatus = false;

  Color    get _sc => currentDriver.status=='online' ? C.online : currentDriver.status=='pause' ? C.pause : C.offline;
  String   get _sl => currentDriver.status=='online' ? 'En ligne' : currentDriver.status=='pause' ? 'En pause' : 'Hors ligne';
  IconData get _si => currentDriver.status=='online'
    ? Icons.wifi_tethering_rounded
    : currentDriver.status=='pause' ? Icons.pause_circle_outline_rounded : Icons.wifi_tethering_off_rounded;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loadData = true);
    final res = await ApiService.get(Api.me);
    if (res['success'] == true && mounted) setState(() => currentDriver = DriverModel.fromJson(res));
    setState(() => _loadData = false);
  }

  Future<void> _changeStatus(String s) async {
    setState(() => _loadStatus = true);
    final res = await ApiService.put(Api.status, {'status': s});
    if (res['success'] == true) setState(() => currentDriver.status = s);
    else if (mounted) snack(context, res['message'] ?? 'Erreur', error: true);
    setState(() => _loadStatus = false);
  }

  void _sos(BuildContext ctx) => showDialog(context: ctx, builder: (_) => AlertDialog(
    backgroundColor: C.card,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Row(children: [
      Icon(Icons.warning_amber_rounded, color: C.error, size: 28), SizedBox(width: 10),
      Text('SOS — Urgence', style: TextStyle(color: C.error, fontWeight: FontWeight.w800)),
    ]),
    content: const Text("Envoyer une alerte d'urgence à TopTopGo et aux secours ?",
      style: TextStyle(color: C.text, height: 1.5)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx),
        child: const Text('Annuler', style: TextStyle(color: C.muted))),
      GestureDetector(
        onTap: () async {
          Navigator.pop(ctx);
          final res = await ApiService.post(Api.sos,
            {'latitude': 0.0, 'longitude': 0.0, 'message': 'Alerte SOS depuis app chauffeur'});
          if (mounted) snack(ctx,
            res['success']==true ? '🚨 SOS envoyé ! Secours alertés.' : res['message'] ?? 'Erreur',
            error: res['success'] != true);
        },
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: C.error, borderRadius: BorderRadius.circular(10)),
          child: const Text('ENVOYER SOS',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))),
    ],
  ));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(backgroundColor: C.card, elevation: 0,
      title: Row(children: [
        const TTIconLogo(size: 34, glow: false), const SizedBox(width: 10),
        const TTTextLogo(fontSize: 18)]),
      actions: [
        GestureDetector(onTap: () => _sos(context),
          child: Container(margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: C.error,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: C.error.withOpacity(0.5), blurRadius: 12)]),
            child: const Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16), SizedBox(width: 4),
              Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ]))),
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border))),
    body: _loadData
      ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(C.orange)))
      : RefreshIndicator(onRefresh: _load, color: C.orange,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Bonjour, ${currentDriver.firstName.isNotEmpty ? currentDriver.firstName : "Conducteur"} 👋',
                    style: const TextStyle(color: C.text, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(width: 8, height: 8,
                      decoration: BoxDecoration(color: _sc, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(_sl, style: TextStyle(color: _sc, fontSize: 13, fontWeight: FontWeight.w600)),
                    if (_loadStatus) ...[const SizedBox(width: 8),
                      SizedBox(width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(_sc)))],
                  ]),
                ])),
                PopupMenuButton<String>(color: C.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: _changeStatus,
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'online',  child: Text('🟢  En ligne',  style: TextStyle(color: C.online,  fontWeight: FontWeight.w600))),
                    PopupMenuItem(value: 'pause',   child: Text('🟡  En pause',   style: TextStyle(color: C.pause,   fontWeight: FontWeight.w600))),
                    PopupMenuItem(value: 'offline', child: Text('🔴  Hors ligne', style: TextStyle(color: C.offline, fontWeight: FontWeight.w600))),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: _sc.withOpacity(0.1),
                      border: Border.all(color: _sc.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Icon(_si, color: _sc, size: 17), const SizedBox(width: 6),
                      Text(_sl, style: TextStyle(color: _sc, fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(width: 4), Icon(Icons.expand_more, color: _sc, size: 15),
                    ]))),
              ]),
              const SizedBox(height: 20),
              _walletCard(context),
              const SizedBox(height: 20),
              const Text("Aujourd'hui",
                style: TextStyle(color: C.text, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              GridView.count(crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.6,
                children: [
                  _stat('Revenus', '${currentDriver.todayRevenue.toStringAsFixed(0)} FCFA', Icons.trending_up_rounded, C.success),
                  _stat('Courses', '${currentDriver.todayTrips}', Icons.directions_car_rounded, C.blue),
                  _stat('Clients', '${currentDriver.todayClients}', Icons.people_outline_rounded, C.orange),
                  _stat('Commission', '${currentDriver.commission.toStringAsFixed(0)} FCFA', Icons.percent_rounded, C.offline),
                ]),
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [C.orange.withOpacity(0.12), C.blue.withOpacity(0.05)]),
                  border: Border.all(color: C.orange.withOpacity(0.25)),
                  borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: C.orange, size: 28),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Net du jour', style: TextStyle(color: C.muted, fontSize: 12)),
                    Text('${currentDriver.net.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(color: C.orange, fontSize: 22, fontWeight: FontWeight.w900)),
                  ]),
                ])),
              const SizedBox(height: 22),
              const Text('Accès rapide',
                style: TextStyle(color: C.text, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _qBtn(Icons.add_road_rounded, 'Nouveau trajet', C.blue, () {})),
                const SizedBox(width: 12),
                Expanded(child: _qBtn(Icons.account_balance_wallet_rounded, 'Mon wallet', C.orange,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage())))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _qBtn(Icons.headset_mic_outlined, 'Support', C.success,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportChatPage())))),
                const SizedBox(width: 12),
                Expanded(child: _qBtn(Icons.history_rounded, 'Historique', C.muted, () {})),
              ]),
              const SizedBox(height: 20),
            ]),
          )),
  );

  Widget _walletCard(BuildContext ctx) => GestureDetector(
    onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const WalletPage())),
    child: Container(padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0D1F35), Color(0xFF08131F)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.orange.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: C.orange.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const TTIconLogo(size: 38, glow: false), const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TTTextLogo(fontSize: 14),
            Text('Wallet Conducteur', style: TextStyle(color: C.muted, fontSize: 11)),
          ]),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [C.orange, Color(0xFFE8921A)]),
              borderRadius: BorderRadius.circular(10)),
            child: const Text('Retirer',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
        ]),
        const SizedBox(height: 18),
        const Text('Solde disponible', style: TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(height: 5),
        Text('${currentDriver.walletBalance.toStringAsFixed(0)} FCFA',
          style: const TextStyle(color: C.text, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const Text('Appuyer pour gérer le wallet', style: TextStyle(color: C.muted, fontSize: 10)),
      ])));

  Widget _stat(String l, String v, IconData icon, Color c) =>
    Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.card,
        border: Border.all(color: c.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: c, size: 22), const Spacer(),
        Text(v, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.w800)),
        Text(l, style: const TextStyle(color: C.muted, fontSize: 11),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ]));

  Widget _qBtn(IconData icon, String l, Color c, VoidCallback t) =>
    GestureDetector(onTap: t,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
        decoration: BoxDecoration(color: c.withOpacity(0.08),
          border: Border.all(color: c.withOpacity(0.25)),
          borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, color: c, size: 22), const SizedBox(width: 10),
          Text(l, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 13)),
        ])));
}

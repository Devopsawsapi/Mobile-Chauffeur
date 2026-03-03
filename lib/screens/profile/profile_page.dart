import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/models/driver_model.dart';
import '../../core/services/api_service.dart';
import '../../widgets/tt_logo.dart';
import '../auth/auth_screen.dart';
import 'change_password_page.dart';
import 'wallet_page.dart';
import '../chat/support_chat_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override State<ProfilePage> createState() => _ProfileState();
}

class _ProfileState extends State<ProfilePage> {
  bool _loading = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get(Api.profile);
    if (res['success'] == true && mounted) setState(() => currentDriver = DriverModel.fromJson(res));
    setState(() => _loading = false);
  }

  void _logout(BuildContext ctx) => showDialog(context: ctx, builder: (_) => AlertDialog(
    backgroundColor: C.card,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Row(children: [
      TTIconLogo(size: 36, glow: false), SizedBox(width: 10),
      Text('Déconnexion', style: TextStyle(color: C.text, fontWeight: FontWeight.w700))]),
    content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?',
      style: TextStyle(color: C.muted, height: 1.5)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx),
        child: const Text('Annuler', style: TextStyle(color: C.muted))),
      GestureDetector(
        onTap: () async {
          Navigator.pop(ctx);
          await ApiService.post(Api.logout, {});
          await ApiService.clearToken();
          if (mounted) Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
        },
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: C.error, borderRadius: BorderRadius.circular(10)),
          child: const Text('Déconnecter',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
    ]));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(backgroundColor: C.card, elevation: 0,
      title: Row(children: [
        const TTIconLogo(size: 34, glow: false), const SizedBox(width: 10),
        const TTTextLogo(fontSize: 18), const SizedBox(width: 8),
        const Text('· Mon Profil', style: TextStyle(color: C.muted, fontSize: 13))]),
      actions: [
        IconButton(icon: const Icon(Icons.logout_rounded, color: C.error),
          onPressed: () => _logout(context))],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border))),
    body: _loading
      ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(C.orange)))
      : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
          Center(child: Stack(children: [
            Container(width: 90, height: 90,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [C.orange, Color(0xFFE8921A)]),
                shape: BoxShape.circle,
                border: Border.all(color: C.blue, width: 3),
                boxShadow: [BoxShadow(color: C.orange.withOpacity(0.4), blurRadius: 24)]),
              child: Center(child: Text(currentDriver.initials,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)))),
            Positioned(bottom: 0, right: 0,
              child: Container(width: 28, height: 28,
                decoration: const BoxDecoration(color: C.blue, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15))),
          ])),
          const SizedBox(height: 14),
          Text(currentDriver.fullName.isNotEmpty ? currentDriver.fullName : 'Mon profil',
            style: const TextStyle(color: C.text, fontSize: 20, fontWeight: FontWeight.w800)),
          Text('${currentDriver.vehicleType ?? "Conducteur"} · ${currentDriver.city ?? ""}',
            style: const TextStyle(color: C.muted, fontSize: 13)),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: C.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.success.withOpacity(0.3))),
            child: const Text('✓ Compte vérifié',
              style: TextStyle(color: C.success, fontSize: 12, fontWeight: FontWeight.w600))),
          const SizedBox(height: 22),
          Row(children: [
            _pStat('${currentDriver.todayTrips}', 'Courses'), const SizedBox(width: 8),
            _pStat('4.9 ★', 'Note'),                          const SizedBox(width: 8),
            _pStat('–', 'Ancienneté'),
          ]),
          const SizedBox(height: 22),
          _mnu(Icons.person_outline_rounded, 'Informations personnelles', onTap: () {}),
          _mnu(Icons.directions_car_outlined, 'Mon véhicule', onTap: () {}),
          _mnu(Icons.lock_outline_rounded, 'Changer le mot de passe',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()))),
          _mnu(Icons.account_balance_wallet_rounded, 'Mon Wallet', color: C.orange,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const WalletPage()))),
          _mnu(Icons.headset_mic_outlined, 'Support technique',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SupportChatPage()))),
          _mnu(Icons.star_outline_rounded,  'Mes avis',                onTap: () {}),
          _mnu(Icons.history_rounded,        'Historique des courses',  onTap: () {}),
          const SizedBox(height: 16),
          GestureDetector(onTap: () => _logout(context),
            child: Container(width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: C.error.withOpacity(0.07),
                border: Border.all(color: C.error.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(14)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.logout_rounded, color: C.error, size: 20), SizedBox(width: 10),
                Text('Se déconnecter',
                  style: TextStyle(color: C.error, fontWeight: FontWeight.w700, fontSize: 15)),
              ]))),
          const SizedBox(height: 30),
        ])));

  Widget _pStat(String v, String l) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: C.card,
      borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
    child: Column(children: [
      Text(v, style: const TextStyle(color: C.orange, fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(l, style: const TextStyle(color: C.muted, fontSize: 11)),
    ])));

  Widget _mnu(IconData icon, String label, {required VoidCallback onTap, Color? color}) =>
    GestureDetector(onTap: onTap,
      child: Container(margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: C.card,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
        child: Row(children: [
          Icon(icon, color: color ?? C.muted, size: 22), const SizedBox(width: 14),
          Expanded(child: Text(label,
            style: const TextStyle(color: C.text, fontSize: 14, fontWeight: FontWeight.w500))),
          const Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
        ])));
}

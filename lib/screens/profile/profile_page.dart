import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/models/driver_model.dart';
import '../../core/services/api_service.dart';
import '../../widgets/tt_logo.dart';
import '../auth/auth_screen.dart';
import 'change_password_page.dart';
import 'personal_info_page.dart';
import 'vehicle_page.dart';
import 'wallet_page.dart';
import '../chat/support_chat_page.dart';
import '../trips/trip_history_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override State<ProfilePage> createState() => _ProfileState();
}

class _ProfileState extends State<ProfilePage> {
  bool _loading     = false;
  bool _uploading   = false;
  // FIX: données de notes
  double _rating    = 0;
  int    _ratingCount = 0;
  List<dynamic> _reviews = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get(Api.profile);
    if (res['success'] == true && mounted) {
      final d = res['data'] ?? res['driver'] ?? res;
      setState(() {
        currentDriver = DriverModel.fromJson(res);
        // FIX: récupérer les notes
        _rating      = double.tryParse((d['average_rating'] ?? d['rating'] ?? '0').toString()) ?? 0;
        _ratingCount = int.tryParse((d['rating_count'] ?? d['reviews_count'] ?? '0').toString()) ?? 0;
        _reviews     = d['reviews'] ?? d['ratings'] ?? [];
      });
    }
    setState(() => _loading = false);
  }

  // FIX: upload photo — endpoint corrigé
  Future<void> _uploadPhoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Changer la photo de profil',
          style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.camera_alt_rounded, color: C.orange),
          title: const Text('Prendre une photo', style: TextStyle(color: C.text)),
          onTap: () { Navigator.pop(context); _pickAndUpload(ImageSource.camera); }),
        ListTile(
          leading: const Icon(Icons.photo_library_rounded, color: C.orange),
          title: const Text('Choisir depuis la galerie', style: TextStyle(color: C.text)),
          onTap: () { Navigator.pop(context); _pickAndUpload(ImageSource.gallery); }),
        const SizedBox(height: 10),
      ])),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final picker = ImagePicker();
    final xFile  = await picker.pickImage(source: source, imageQuality: 80);
    if (xFile == null) return;

    setState(() => _uploading = true);
    try {
      final token = await ApiService.getToken();
      // FIX: utiliser multipart POST sur le bon endpoint
      final uri     = Uri.parse('${Api.profile}/photo');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept']        = 'application/json';
      request.files.add(await http.MultipartFile.fromPath('photo', xFile.path));

      final streamed  = await request.send();
      final response  = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack('✅ Photo mise à jour !');
        await _load(); // recharger le profil
      } else {
        // FIX: essayer l'endpoint alternatif si 404
        if (response.statusCode == 404) {
          await _tryAltUpload(xFile.path, token ?? '');
        } else {
          _showSnack('Erreur upload : ${response.statusCode}', error: true);
        }
      }
    } catch (e) {
      _showSnack('Erreur : $e', error: true);
    }
    setState(() => _uploading = false);
  }

  // FIX: endpoint alternatif pour compatibilité
  Future<void> _tryAltUpload(String path, String token) async {
    try {
      final alts = [
        '${Api.base}/driver/profile/upload-photo',
        '${Api.base}/driver/upload-photo',
        '${Api.base}/driver/profile/avatar',
      ];
      for (final alt in alts) {
        final req = http.MultipartRequest('POST', Uri.parse(alt));
        req.headers['Authorization'] = 'Bearer $token';
        req.headers['Accept']        = 'application/json';
        req.files.add(await http.MultipartFile.fromPath('photo', path));
        final resp = await http.Response.fromStream(await req.send());
        if (resp.statusCode == 200 || resp.statusCode == 201) {
          _showSnack('✅ Photo mise à jour !');
          await _load();
          return;
        }
      }
      _showSnack('Upload photo non disponible pour l\'instant', error: true);
    } catch (_) {
      _showSnack('Erreur lors de l\'upload', error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? C.error : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: C.error, borderRadius: BorderRadius.circular(10)),
          child: const Text('Déconnecter',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
    ]));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(
      backgroundColor: C.card, elevation: 0,
      title: Row(children: [
        const TTIconLogo(size: 34, glow: false), const SizedBox(width: 10),
        const TTTextLogo(fontSize: 18), const SizedBox(width: 8),
        const Text('· Mon Profil', style: TextStyle(color: C.muted, fontSize: 13))]),
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded, color: C.muted, size: 20), onPressed: _load),
        IconButton(icon: const Icon(Icons.logout_rounded, color: C.error),
          onPressed: () => _logout(context)),
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border))),
    body: _loading
      ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(C.orange)))
      : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [

          // ── Avatar cliquable ────────────────────────────────────────────────
          Center(child: GestureDetector(
            onTap: _uploadPhoto,
            child: Stack(children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [C.orange, Color(0xFFE8921A)]),
                  shape: BoxShape.circle,
                  border: Border.all(color: C.blue, width: 3),
                  boxShadow: [BoxShadow(color: C.orange.withOpacity(0.4), blurRadius: 24)]),
                child: ClipOval(
                  child: _uploading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : (currentDriver.profilePhoto != null && currentDriver.profilePhoto!.isNotEmpty
                        ? Image.network(currentDriver.profilePhoto!, fit: BoxFit.cover,
                            width: 90, height: 90,
                            errorBuilder: (_, __, ___) => _initials())
                        : _initials()))),
              Positioned(bottom: 0, right: 0,
                child: Container(width: 28, height: 28,
                  decoration: const BoxDecoration(color: C.blue, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15))),
            ]))),
          const SizedBox(height: 14),

          // Nom + badge vérifié
          Text(currentDriver.fullName.isNotEmpty ? currentDriver.fullName : 'Mon profil',
            style: const TextStyle(color: C.text, fontSize: 20, fontWeight: FontWeight.w800)),
          Text('${currentDriver.vehicleType ?? "Conducteur"}${currentDriver.city != null ? " · ${currentDriver.city}" : ""}',
            style: const TextStyle(color: C.muted, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: C.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.success.withOpacity(0.3))),
            child: const Text('✓ Compte vérifié',
              style: TextStyle(color: C.success, fontSize: 12, fontWeight: FontWeight.w600))),
          const SizedBox(height: 22),

          // ── Stats : courses + NOTE RÉELLE + ancienneté ──────────────────────
          Row(children: [
            _pStat('${currentDriver.todayTrips}', 'Courses'),
            const SizedBox(width: 8),
            // FIX: vraie note depuis l'API
            _pStatRating(_rating, _ratingCount),
            const SizedBox(width: 8),
            _pStat('–', 'Ancienneté'),
          ]),
          const SizedBox(height: 16),

          // FIX: Derniers avis clients (si disponibles)
          if (_reviews.isNotEmpty) ...[
            _buildReviewsSection(),
            const SizedBox(height: 16),
          ],

          // ── Véhicule complet ────────────────────────────────────────────────
          if (currentDriver.vehicleBrand != null && currentDriver.vehicleBrand!.isNotEmpty)
            _buildVehicleCard(),

          // ── Menu ────────────────────────────────────────────────────────────
          _mnu(Icons.person_outline_rounded, 'Informations personnelles',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PersonalInfoPage())).then((_) => _load())),

          _mnu(Icons.directions_car_outlined, 'Mon véhicule',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const VehiclePage())).then((_) => _load())),

          _mnu(Icons.lock_outline_rounded, 'Changer le mot de passe',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()))),

          _mnu(Icons.account_balance_wallet_rounded, 'Mon Wallet', color: C.orange,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const WalletPage()))),

          // FIX: section avis cliquable
          _mnu(Icons.star_rounded, 'Mes avis & notes${_ratingCount > 0 ? " ($_ratingCount)" : ""}',
            color: const Color(0xFFFFC107),
            onTap: () => _showAllReviews()),

          _mnu(Icons.history_rounded, 'Historique des courses',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TripHistoryPage()))),

          _mnu(Icons.headset_mic_outlined, 'Support technique',
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SupportChatPage()))),

          const SizedBox(height: 16),

          GestureDetector(
            onTap: () => _logout(context),
            child: Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: C.error.withOpacity(0.07),
                border: Border.all(color: C.error.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(14)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.logout_rounded, color: C.error, size: 20), SizedBox(width: 10),
                Text('Se déconnecter',
                  style: TextStyle(color: C.error, fontWeight: FontWeight.w700, fontSize: 15)),
              ]))),
          const SizedBox(height: 30),
        ])));

  // ── Widget initiales ────────────────────────────────────────────────────────
  Widget _initials() => Center(child: Text(currentDriver.initials,
    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)));

  // ── Stat basique ────────────────────────────────────────────────────────────
  Widget _pStat(String v, String l) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: C.border)),
    child: Column(children: [
      Text(v, style: const TextStyle(color: C.orange, fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(l, style: const TextStyle(color: C.muted, fontSize: 11)),
    ])));

  // FIX: stat note avec étoiles
  Widget _pStatRating(double rating, int count) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: C.border)),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(rating > 0 ? rating.toStringAsFixed(1) : '–',
          style: const TextStyle(color: Color(0xFFFFC107), fontSize: 17, fontWeight: FontWeight.w800)),
        if (rating > 0) const Text(' ★', style: TextStyle(color: Color(0xFFFFC107), fontSize: 14)),
      ]),
      const SizedBox(height: 3),
      Text(count > 0 ? 'Note ($count)' : 'Note',
        style: const TextStyle(color: C.muted, fontSize: 11)),
    ])));

  // FIX: card véhicule COMPLÈTE (marque + modèle + couleur + plaque)
  Widget _buildVehicleCard() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: C.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.directions_car_rounded, color: C.orange, size: 18),
        SizedBox(width: 8),
        Text('Mon véhicule', style: TextStyle(color: C.muted, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Marque + Modèle
          Text(
            '${currentDriver.vehicleBrand ?? ""}${currentDriver.vehicleModel != null ? " ${currentDriver.vehicleModel}" : ""}',
            style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          // Couleur
          if (currentDriver.vehicleColor != null && currentDriver.vehicleColor!.isNotEmpty)
            Row(children: [
              const Icon(Icons.palette_outlined, color: C.muted, size: 13),
              const SizedBox(width: 5),
              Text('Couleur : ${currentDriver.vehicleColor}',
                style: const TextStyle(color: C.muted, fontSize: 12)),
            ]),
          // Type
          if (currentDriver.vehicleType != null) ...[
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.category_outlined, color: C.muted, size: 13),
              const SizedBox(width: 5),
              Text(currentDriver.vehicleType!,
                style: const TextStyle(color: C.muted, fontSize: 12)),
            ]),
          ],
        ])),
        // Plaque
        if (currentDriver.vehiclePlate != null && currentDriver.vehiclePlate!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: C.surface, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: C.border, width: 1.5)),
            child: Text(currentDriver.vehiclePlate!,
              style: const TextStyle(color: C.text, fontWeight: FontWeight.w800,
                fontSize: 13, letterSpacing: 1.2))),
      ]),
    ]));

  // FIX: section 3 derniers avis
  Widget _buildReviewsSection() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: C.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 16),
        const SizedBox(width: 6),
        Text('Derniers avis (${_reviews.length})',
          style: const TextStyle(color: C.muted, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 10),
      ..._reviews.take(3).map((r) {
        final clientName = r['client_name'] ?? r['user_name'] ?? r['name'] ?? 'Client';
        final stars      = int.tryParse((r['rating'] ?? r['stars'] ?? '5').toString()) ?? 5;
        final comment    = r['comment'] ?? r['review'] ?? '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(clientName, style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Row(children: List.generate(5, (i) => Icon(
                i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                color: const Color(0xFFFFC107), size: 13))),
            ]),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(comment, style: const TextStyle(color: C.muted, fontSize: 12)),
            ],
            if (r != _reviews.take(3).last)
              const Divider(color: C.border, height: 14),
          ]));
      }),
    ]));

  void _showAllReviews() {
    if (_reviews.isEmpty) {
      _showSnack('Aucun avis pour le moment');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: C.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.7, maxChildSize: 0.95,
        builder: (_, ctrl) => Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.star_rounded, color: Color(0xFFFFC107)),
              const SizedBox(width: 8),
              Text('Tous mes avis (${_reviews.length})',
                style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 16)),
            ])),
          Expanded(child: ListView.builder(
            controller: ctrl, padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _reviews.length,
            itemBuilder: (_, i) {
              final r = _reviews[i];
              final stars = int.tryParse((r['rating'] ?? '5').toString()) ?? 5;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(r['client_name'] ?? r['name'] ?? 'Client',
                      style: const TextStyle(color: C.text, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Row(children: List.generate(5, (j) => Icon(
                      j < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFFFC107), size: 14))),
                  ]),
                  if ((r['comment'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(r['comment'], style: const TextStyle(color: C.muted, fontSize: 13)),
                  ],
                ]));
            })),
        ])));
  }

 
  Widget _mnu(IconData icon, String label, {required VoidCallback onTap, Color? color}) =>
    GestureDetector(onTap: onTap,
      child: Container(margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.border)),
        child: Row(children: [
          Icon(icon, color: color ?? C.muted, size: 22), const SizedBox(width: 14),
          Expanded(child: Text(label,
            style: const TextStyle(color: C.text, fontSize: 14, fontWeight: FontWeight.w500))),
          const Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
        ])));
}

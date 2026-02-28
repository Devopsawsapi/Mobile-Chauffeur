// ============================================================
//  TopTopGo — APP CHAUFFEUR
//  lib/main.dart
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const TopTopGoDriverApp());
}

// ─── Constantes ───────────────────────────────────────────────
const kBaseUrl  = 'http://localhost:8000/api';
const kPrimary  = Color(0xFFFF6B00);
const kBg       = Color(0xFF0F0F1A);
const kCard     = Color(0xFF1E1E30);
const kCardL    = Color(0xFF252538);
const kWhite    = Colors.white;
const kGray     = Color(0xFF6B7280);
const kGrayD    = Color(0xFF374151);
const kSuccess  = Color(0xFF00C48C);
const kDanger   = Color(0xFFFF4D4D);
const kWarning  = Color(0xFFFFB800);
const kDark     = Color(0xFF0D0D1A);

// ─── API Helper ───────────────────────────────────────────────
Future<String?> _getToken() async {
  final p = await SharedPreferences.getInstance();
  return p.getString('driverToken');
}

Future<Map<String, dynamic>> _apiGet(String ep) async {
  final token = await _getToken();
  final res = await http.get(Uri.parse('$kBaseUrl$ep'), headers: {
    'Content-Type': 'application/json', 'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  });
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode >= 400) throw body;
  return body;
}

Future<Map<String, dynamic>> _apiPost(String ep, [Map<String, dynamic>? data]) async {
  final token = await _getToken();
  final res = await http.post(Uri.parse('$kBaseUrl$ep'),
    headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', if (token != null) 'Authorization': 'Bearer $token' },
    body: data != null ? jsonEncode(data) : null,
  );
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode >= 400) throw body;
  return body;
}

Future<Map<String, dynamic>> _apiUpload(String ep, Map<String, String> fields) async {
  final token = await _getToken();
  final req = http.MultipartRequest('POST', Uri.parse('$kBaseUrl$ep'));
  if (token != null) req.headers['Authorization'] = 'Bearer $token';
  req.fields.addAll(fields);
  final streamed = await req.send();
  final res = await http.Response.fromStream(streamed);
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode >= 400) throw body;
  return body;
}

// ─── APP ──────────────────────────────────────────────────────
class TopTopGoDriverApp extends StatelessWidget {
  const TopTopGoDriverApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TopTopGo Chauffeur',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: kPrimary, brightness: Brightness.dark),
      scaffoldBackgroundColor: kBg,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary, foregroundColor: kWhite,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    ),
    home: const SplashScreen(),
  );
}

// ═══════════════════════════════════════════════════════════════
//  SPLASH
// ═══════════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), _check);
  }

  Future<void> _check() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => p.getString('driverToken') != null ? const MainScreen() : const LoginScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 110, height: 110,
        decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(55)),
        child: const Center(child: Text('🚖', style: TextStyle(fontSize: 52)))),
      const SizedBox(height: 20),
      const Text('TopTopGo', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: kWhite)),
      const SizedBox(height: 6),
      const Text('Espace Chauffeur', style: TextStyle(fontSize: 16, color: kGray)),
      const SizedBox(height: 60),
      const CircularProgressIndicator(color: kPrimary),
    ])),
  );
}

// ═══════════════════════════════════════════════════════════════
//  LOGIN
// ═══════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _pass  = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (_phone.text.isEmpty || _pass.text.isEmpty) { _snack('Remplis tous les champs'); return; }
    setState(() => _loading = true);
    try {
      final res = await _apiPost('/driver/auth/login', {'phone': _phone.text, 'password': _pass.text});
      final p = await SharedPreferences.getInstance();
      await p.setString('driverToken',   res['token']  ?? res['data']?['token']  ?? '');
      await p.setString('driverProfile', jsonEncode(res['driver'] ?? res['user'] ?? res['data']?['driver'] ?? {}));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
    } catch (_) { _snack('Identifiants incorrects'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _field(String label, TextEditingController c, {bool obscure = false, TextInputType? type}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kGray, letterSpacing: 0.5)),
      const SizedBox(height: 6),
      TextField(controller: c, obscureText: obscure, keyboardType: type,
        style: const TextStyle(color: kWhite),
        decoration: InputDecoration(
          filled: true, fillColor: kCardL,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrayD)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrayD, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 2)),
        ),
      ),
      const SizedBox(height: 14),
    ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
      const SizedBox(height: 40),
      Container(width: 80, height: 80, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(40)),
        child: const Center(child: Text('🚖', style: TextStyle(fontSize: 40)))),
      const SizedBox(height: 16),
      const Text('Espace Chauffeur', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kWhite)),
      const SizedBox(height: 6),
      const Text('Connectez-vous pour commencer', style: TextStyle(color: kGray, fontSize: 14)),
      const SizedBox(height: 36),
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(24)), child: Column(children: [
        _field('📞  Téléphone', _phone, type: TextInputType.phone),
        _field('🔒  Mot de passe', _pass, obscure: true),
        const SizedBox(height: 4),
        _loading ? const CircularProgressIndicator(color: kPrimary)
                 : ElevatedButton(onPressed: _submit, child: const Text('Se connecter')),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
          child: RichText(text: const TextSpan(
            text: 'Nouveau chauffeur ?  ',
            style: TextStyle(color: kGray, fontSize: 14),
            children: [TextSpan(text: "S'inscrire", style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700))],
          )),
        ),
      ])),
    ]))),
  );
}

// ═══════════════════════════════════════════════════════════════
//  REGISTER (2 étapes)
// ═══════════════════════════════════════════════════════════════
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}
class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 1;
  bool _loading = false;
  final _firstName  = TextEditingController();
  final _lastName   = TextEditingController();
  final _birthDate  = TextEditingController();
  final _phone      = TextEditingController();
  final _pass       = TextEditingController();
  final _passConf   = TextEditingController();
  final _vBrand     = TextEditingController();
  final _vModel     = TextEditingController();
  final _vPlate     = TextEditingController();
  final _vType      = TextEditingController();
  final _vColor     = TextEditingController();
  final _vCountry   = TextEditingController();
  final _vCity      = TextEditingController();

  Future<void> _submit() async {
    if (_pass.text != _passConf.text) { _snack('Les mots de passe ne correspondent pas'); return; }
    setState(() => _loading = true);
    try {
      await _apiUpload('/driver/auth/register', {
        'first_name': _firstName.text, 'last_name': _lastName.text,
        'birth_date': _birthDate.text, 'phone': _phone.text,
        'password': _pass.text, 'password_confirmation': _passConf.text,
        'vehicle_brand': _vBrand.text, 'vehicle_model': _vModel.text,
        'vehicle_plate': _vPlate.text, 'vehicle_type': _vType.text,
        'vehicle_color': _vColor.text, 'vehicle_country': _vCountry.text,
        'vehicle_city': _vCity.text,
      });
      if (!mounted) return;
      showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
        title: const Text('✅ Inscription envoyée'),
        content: const Text('Votre dossier est en cours de vérification. Vous serez contacté sous 24h.'),
        actions: [ElevatedButton(onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); }, child: const Text('OK'))],
      ));
    } catch (e) { _snack('Erreur lors de l\'inscription'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _f(String label, TextEditingController c, {String? hint, bool obscure = false, TextInputType? type}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kGray, letterSpacing: 0.5)),
      const SizedBox(height: 5),
      TextField(controller: c, obscureText: obscure, keyboardType: type,
        style: const TextStyle(color: kWhite),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: kGray),
          filled: true, fillColor: kCardL,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrayD)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrayD, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      const SizedBox(height: 12),
    ]);

  Widget _stepBar() => Row(children: [
    _stepDot(1), Expanded(child: Container(height: 3, color: _step >= 2 ? kPrimary : kGrayD)), _stepDot(2),
  ]);

  Widget _stepDot(int n) => Container(width: 28, height: 28,
    decoration: BoxDecoration(color: _step >= n ? kPrimary : kGrayD, borderRadius: BorderRadius.circular(14)),
    child: Center(child: Text('$n', style: TextStyle(color: _step >= n ? kWhite : kGray, fontWeight: FontWeight.w700))));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
      const SizedBox(height: 20),
      const Text('Devenir Chauffeur', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kWhite)),
      const SizedBox(height: 6),
      Text('Étape $_step sur 2', style: const TextStyle(color: kGray, fontSize: 14)),
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(24)), child: Column(children: [
        _stepBar(),
        const SizedBox(height: 24),
        if (_step == 1) ...[
          const Align(alignment: Alignment.centerLeft, child: Text('Informations personnelles', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kWhite))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _f('Prénom *', _firstName, hint: 'Jean')),
            const SizedBox(width: 10),
            Expanded(child: _f('Nom *', _lastName, hint: 'Doe')),
          ]),
          _f('📞  Téléphone *', _phone, hint: '+242 00 000 00 00', type: TextInputType.phone),
          _f('📅  Date naissance', _birthDate, hint: '1990-01-15'),
          _f('🔒  Mot de passe *', _pass, hint: '••••••••', obscure: true),
          _f('🔒  Confirmer *', _passConf, hint: '••••••••', obscure: true),
          ElevatedButton(
            onPressed: () {
              if (_firstName.text.isEmpty || _phone.text.isEmpty || _pass.text.isEmpty) { _snack('Remplis les champs obligatoires'); return; }
              setState(() => _step = 2);
            },
            child: const Text('Suivant →'),
          ),
        ] else ...[
          const Align(alignment: Alignment.centerLeft, child: Text('Informations véhicule', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kWhite))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _f('Marque *', _vBrand, hint: 'Toyota')),
            const SizedBox(width: 10),
            Expanded(child: _f('Modèle *', _vModel, hint: 'Corolla')),
          ]),
          _f('Immatriculation *', _vPlate, hint: 'AA-123-BB'),
          Row(children: [
            Expanded(child: _f('Type', _vType, hint: 'Berline')),
            const SizedBox(width: 10),
            Expanded(child: _f('Couleur', _vColor, hint: 'Blanc')),
          ]),
          Row(children: [
            Expanded(child: _f('Pays', _vCountry, hint: 'Congo')),
            const SizedBox(width: 10),
            Expanded(child: _f('Ville', _vCity, hint: 'Brazzaville')),
          ]),
          Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: kCardL, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: kWarning, width: 3))),
            child: const Text('📄 Documents à uploader après inscription : CNI (recto/verso), Permis, Carte grise, Assurance.',
              style: TextStyle(color: kGray, fontSize: 13, height: 1.5))),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => setState(() => _step = 1),
              style: OutlinedButton.styleFrom(foregroundColor: kGray, side: const BorderSide(color: kGrayD),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), minimumSize: const Size(0, 50)),
              child: const Text('← Retour'),
            )),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: _loading
              ? const Center(child: CircularProgressIndicator(color: kPrimary))
              : ElevatedButton(onPressed: _submit, child: const Text('S\'inscrire ✓'))),
          ]),
        ],
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: RichText(text: const TextSpan(
            text: 'Déjà chauffeur ?  ',
            style: TextStyle(color: kGray, fontSize: 14),
            children: [TextSpan(text: 'Se connecter', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700))],
          )),
        ),
      ])),
    ]))),
  );
}

// ═══════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ═══════════════════════════════════════════════════════════════
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override State<MainScreen> createState() => _MainScreenState();
}
class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  Map<String, dynamic>? _activeCourse;

  Future<void> _sendSOS() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: kCard,
      title: const Text('🆘 SOS', style: TextStyle(color: kWhite)),
      content: const Text("Confirmer l'envoi d'une alerte d'urgence ?", style: TextStyle(color: kGray)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler', style: TextStyle(color: kGray))),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: kDanger), child: const Text('SOS')),
      ],
    ));
    if (ok != true) return;
    try { await _apiPost('/sos', {'lat': 0, 'lng': 0}); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _activeCourse != null
        ? ActiveCourseScreen(course: _activeCourse!, onComplete: () => setState(() => _activeCourse = null))
        : DashboardScreen(onCourseAccepted: (c) => setState(() { _activeCourse = c; _tab = 0; })),
      const HistoryScreen(),
      const WalletScreen(),
      const DriverProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kCard,
        elevation: 0,
        title: RichText(text: const TextSpan(children: [
          TextSpan(text: '🚖 ', style: TextStyle(fontSize: 22)),
          TextSpan(text: 'TopTop', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kPrimary)),
          TextSpan(text: 'Go',    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kWhite)),
        ])),
        actions: [
          Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: kCardL, borderRadius: BorderRadius.circular(10)),
            child: const Text('CHAUFFEUR', style: TextStyle(color: kGray, fontSize: 11, fontWeight: FontWeight.w700))),
          GestureDetector(
            onTap: _sendSOS,
            child: Container(margin: const EdgeInsets.only(right: 16), width: 36, height: 36,
              decoration: BoxDecoration(color: kDanger, borderRadius: BorderRadius.circular(18)),
              child: const Center(child: Text('🆘', style: TextStyle(fontSize: 16)))),
          ),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: kGrayD)),
      ),
      body: screens[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: kCard,
        indicatorColor: kPrimary.withOpacity(0.15),
        labelTextStyle: MaterialStateProperty.resolveWith((s) =>
          TextStyle(fontSize: 11, fontWeight: s.contains(MaterialState.selected) ? FontWeight.w700 : FontWeight.w400,
            color: s.contains(MaterialState.selected) ? kPrimary : kGray)),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined, color: kGray), selectedIcon: Icon(Icons.home, color: kPrimary), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined, color: kGray), selectedIcon: Icon(Icons.list_alt, color: kPrimary), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined, color: kGray), selectedIcon: Icon(Icons.account_balance_wallet, color: kPrimary), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.person_outline, color: kGray), selectedIcon: Icon(Icons.person, color: kPrimary), label: 'Profil'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  DASHBOARD
// ═══════════════════════════════════════════════════════════════
class DashboardScreen extends StatefulWidget {
  final void Function(Map<String, dynamic>) onCourseAccepted;
  const DashboardScreen({super.key, required this.onCourseAccepted});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen> {
  bool _online = false;
  Map<String, dynamic>? _wallet;
  List<dynamic> _courses = [];
  Timer? _pollTimer;
  final Set<int> _busyCourses = {};

  @override void dispose() { _pollTimer?.cancel(); super.dispose(); }

  Future<void> _loadWallet() async {
    try { final r = await _apiGet('/driver/wallet'); if (mounted) setState(() => _wallet = r['data'] ?? r); } catch (_) {}
  }
  Future<void> _loadCourses() async {
    try { final r = await _apiGet('/driver/courses/available'); if (mounted) setState(() => _courses = r['data'] ?? []); } catch (_) {}
  }

  Future<void> _toggleOnline(bool val) async {
    setState(() => _online = val);
    try { await _apiPost('/driver/status', {'driver_status': val ? 'online' : 'offline'}); } catch (_) {}
    if (val) {
      _loadCourses();
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) => _loadCourses());
    } else {
      _pollTimer?.cancel();
      setState(() => _courses = []);
    }
  }

  Future<void> _accept(Map<String, dynamic> course) async {
    setState(() => _busyCourses.add(course['id']));
    try {
      await _apiPost('/driver/courses/${course['id']}/accept');
      widget.onCourseAccepted(course);
    } catch (e) {
      _snack('Impossible d\'accepter cette course');
    } finally {
      if (mounted) setState(() => _busyCourses.remove(course['id']));
    }
  }

  Future<void> _reject(int id) async {
    try { await _apiPost('/driver/courses/$id/reject'); _loadCourses(); } catch (_) {}
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void initState() { super.initState(); _loadWallet(); }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Statut en ligne ──
      _card(child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('STATUT', style: TextStyle(color: kGray, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: _online ? kSuccess : kGray, borderRadius: BorderRadius.circular(5))),
            const SizedBox(width: 8),
            Text(_online ? 'En ligne' : 'Hors ligne',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _online ? kSuccess : kGray)),
          ]),
        ]),
        Switch(value: _online, onChanged: _toggleOnline, activeColor: kSuccess, trackColor: MaterialStateProperty.all(kGrayD)),
      ])),
      const SizedBox(height: 16),

      // ── Solde ──
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [kPrimary, Color(0xFFFF9A3C)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('💰 Solde disponible', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            Text('${_wallet?['balance'] ?? '---'}', style: const TextStyle(color: kWhite, fontSize: 32, fontWeight: FontWeight.w900)),
            Text(_wallet?['currency'] ?? 'XAF', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
            child: const Text('Retirer', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700))),
        ]),
      ),
      const SizedBox(height: 24),

      // ── Courses disponibles ──
      if (_online) ...[
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('🚖 Courses disponibles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kWhite)),
          GestureDetector(onTap: _loadCourses, child: const Text('↺ Actualiser', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 14),
        if (_courses.isEmpty) _card(child: const Column(children: [
          SizedBox(height: 8),
          Text('⏳', style: TextStyle(fontSize: 36)),
          SizedBox(height: 8),
          Text('En attente de courses…', style: TextStyle(color: kGray, fontSize: 15)),
          SizedBox(height: 4),
          Text('Actualisation automatique toutes les 12s', style: TextStyle(color: kGrayD, fontSize: 12)),
          SizedBox(height: 8),
        ]))
        else ...(_courses.map((c) => _courseCard(c as Map<String, dynamic>))),
      ] else _card(child: const Column(children: [
        SizedBox(height: 8),
        Text('💤', style: TextStyle(fontSize: 40)),
        SizedBox(height: 12),
        Text('Vous êtes hors ligne', style: TextStyle(color: kWhite, fontSize: 17, fontWeight: FontWeight.w700)),
        SizedBox(height: 6),
        Text('Activez le mode en ligne pour recevoir des courses', style: TextStyle(color: kGray, fontSize: 13), textAlign: TextAlign.center),
        SizedBox(height: 8),
      ])),
    ]),
  );

  Widget _card({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20)),
    child: child,
  );

  Widget _courseCard(Map<String, dynamic> c) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Course #${c['id']}', style: const TextStyle(color: kGray, fontSize: 12)),
        Text('${c['montant_total'] ?? '-'} ${c['currency'] ?? 'XAF'}',
          style: const TextStyle(color: kPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 12),
      _addrRow(kSuccess, c['pickup_address'] ?? ''),
      const SizedBox(height: 6),
      _addrRow(kPrimary, c['dropoff_address'] ?? ''),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => _reject(c['id']),
          style: OutlinedButton.styleFrom(foregroundColor: kDanger, side: const BorderSide(color: kDanger),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), minimumSize: const Size(0, 42)),
          child: const Text('✕ Refuser'),
        )),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: ElevatedButton(
          onPressed: _busyCourses.contains(c['id']) ? null : () => _accept(c),
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _busyCourses.contains(c['id'])
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2))
            : const Text('✓ Accepter'),
        )),
      ]),
    ]),
  );

  Widget _addrRow(Color color, String text) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
    const SizedBox(width: 10),
    Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: kWhite), overflow: TextOverflow.ellipsis)),
  ]);
}

// ═══════════════════════════════════════════════════════════════
//  ACTIVE COURSE CHAUFFEUR
// ═══════════════════════════════════════════════════════════════
class ActiveCourseScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  final VoidCallback onComplete;
  const ActiveCourseScreen({super.key, required this.course, required this.onComplete});
  @override State<ActiveCourseScreen> createState() => _ActiveCourseScreenState();
}
class _ActiveCourseScreenState extends State<ActiveCourseScreen> {
  late Map<String, dynamic> _course;
  bool _chatOpen = false;
  List<dynamic> _msgs = [];
  final _msgCtrl = TextEditingController();
  bool _busy = false;

  @override void initState() { super.initState(); _course = widget.course; _loadMsgs(); }
  @override void dispose()   { _msgCtrl.dispose(); super.dispose(); }

  Future<void> _loadMsgs() async {
    try { final r = await _apiGet('/trips/${_course['id']}/messages'); if (mounted) setState(() => _msgs = r['data'] ?? r); } catch (_) {}
  }
  Future<void> _sendMsg() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    try { await _apiPost('/trips/${_course['id']}/messages', {'message': _msgCtrl.text}); _msgCtrl.clear(); _loadMsgs(); } catch (_) {}
  }

  Future<void> _doAction(String endpoint, String successMsg) async {
    setState(() => _busy = true);
    try {
      await _apiPost(endpoint);
      final r = await _apiGet('/driver/courses/${_course['id']}');
      final c = r['data'] ?? r;
      if (mounted) setState(() { _course = c; _busy = false; });
      _snack(successMsg);
      if (c['status'] == 'completed') widget.onComplete();
    } catch (e) { _snack('Erreur'); setState(() => _busy = false); }
  }

  Future<void> _sendSOS() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: kCard,
      title: const Text('🆘 SOS', style: TextStyle(color: kWhite)),
      content: const Text("Envoyer une alerte d'urgence ?", style: TextStyle(color: kGray)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler', style: TextStyle(color: kGray))),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: kDanger), child: const Text('SOS')),
      ],
    ));
    if (ok != true) return;
    try { await _apiPost('/sos', {'trip_id': _course['id'], 'lat': 0, 'lng': 0, 'message': 'SOS chauffeur'}); _snack('✅ SOS envoyé'); }
    catch (_) { _snack('Erreur SOS'); }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String? get _actionLabel {
    if (_course['status'] == 'accepted') return '▶  Démarrer la course';
    if (_course['status'] == 'started')  return '✓  Terminer la course';
    return null;
  }
  String? get _actionEndpoint {
    if (_course['status'] == 'accepted') return '/driver/courses/${_course['id']}/start';
    if (_course['status'] == 'started')  return '/driver/courses/${_course['id']}/complete';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final u = (_course['user'] as Map<String, dynamic>?) ?? {};
    return Stack(children: [
      Column(children: [
        Container(height: 200, color: const Color(0xFF1A1A2E),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🗺️', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 6),
            const Text('Navigation en cours', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700)),
          ]))),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
          // Infos client
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20)), child: Column(children: [
            Row(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: kCardL, borderRadius: BorderRadius.circular(26)), child: const Center(child: Text('👤', style: TextStyle(fontSize: 28)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${u['first_name'] ?? 'Client'} ${u['last_name'] ?? ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kWhite)),
                Text(u['phone'] ?? '', style: const TextStyle(color: kGray, fontSize: 13)),
              ])),
              Container(width: 42, height: 42, decoration: BoxDecoration(color: kSuccess.withOpacity(0.2), borderRadius: BorderRadius.circular(21)),
                child: const Center(child: Text('📞', style: TextStyle(fontSize: 20)))),
            ]),
            const SizedBox(height: 14),
            // Adresses
            _addrRow(kSuccess, _course['pickup_address'] ?? ''),
            const SizedBox(height: 6),
            _addrRow(kPrimary, _course['dropoff_address'] ?? ''),
            const SizedBox(height: 14),
            // Actions
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () { setState(() => _chatOpen = true); _loadMsgs(); },
                child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: kPrimary.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                  child: const Column(children: [Text('💬', style: TextStyle(fontSize: 24)), SizedBox(height: 4), Text('Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary))])),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: _sendSOS,
                child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: kDanger.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                  child: const Column(children: [Text('🆘', style: TextStyle(fontSize: 24)), SizedBox(height: 4), Text('SOS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kDanger))])),
              )),
            ]),
            if (_actionLabel != null) ...[
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _busy ? null : () => _doAction(_actionEndpoint!, '✅ Action effectuée'),
                child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2)) : Text(_actionLabel!),
              ),
            ],
          ])),
        ]))),
      ]),
      if (_chatOpen) _buildChat(),
    ]);
  }

  Widget _addrRow(Color color, String text) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
    const SizedBox(width: 10),
    Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: kWhite), overflow: TextOverflow.ellipsis)),
  ]);

  Widget _buildChat() => Positioned.fill(child: Container(
    color: kCard,
    child: SafeArea(child: Column(children: [
      Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGrayD))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('💬 Chat avec le client', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kWhite)),
          GestureDetector(onTap: () => setState(() => _chatOpen = false), child: const Icon(Icons.close, color: kGray)),
        ])),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(16), itemCount: _msgs.length,
        itemBuilder: (_, i) {
          final m = _msgs[i] as Map<String, dynamic>;
          final isMe = m['sender_type'] == 'driver';
          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              decoration: BoxDecoration(
                color: isMe ? kPrimary : kCardL,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4), bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Text(m['message'] ?? '', style: const TextStyle(color: kWhite, fontSize: 14)),
            ),
          );
        },
      )),
      Container(padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), decoration: const BoxDecoration(border: Border(top: BorderSide(color: kGrayD))),
        child: Row(children: [
          Expanded(child: TextField(controller: _msgCtrl, style: const TextStyle(color: kWhite),
            decoration: InputDecoration(hintText: 'Écrire…', hintStyle: const TextStyle(color: kGray),
              filled: true, fillColor: kCardL, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
            onSubmitted: (_) => _sendMsg())),
          const SizedBox(width: 10),
          GestureDetector(onTap: _sendMsg,
            child: Container(width: 44, height: 44, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.send, color: kWhite, size: 20))),
        ])),
    ])),
  ));
}

// ═══════════════════════════════════════════════════════════════
//  HISTORY
// ═══════════════════════════════════════════════════════════════
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override State<HistoryScreen> createState() => _HistoryScreenState();
}
class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _courses = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try { final r = await _apiGet('/driver/courses'); setState(() { _courses = r['data'] ?? []; _loading = false; }); }
    catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: kPrimary));
    return RefreshIndicator(onRefresh: _load, color: kPrimary, child: _courses.isEmpty
      ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🚖', style: TextStyle(fontSize: 48)), SizedBox(height: 12), Text('Aucune course', style: TextStyle(color: kGray, fontSize: 15))]))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _courses.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) return Padding(padding: const EdgeInsets.only(bottom: 16), child: Text('Mes courses', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kWhite)));
            final c = _courses[i - 1] as Map<String, dynamic>;
            return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16)), child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(c['created_at'] != null ? '${DateTime.parse(c['created_at']).day}/${DateTime.parse(c['created_at']).month}' : '', style: const TextStyle(color: kGray, fontSize: 13)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: kPrimary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text((c['status'] ?? '').toUpperCase(), style: const TextStyle(color: kPrimary, fontSize: 10, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 10),
              Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: kSuccess, borderRadius: BorderRadius.circular(4))), const SizedBox(width: 10), Expanded(child: Text(c['pickup_address'] ?? '', style: const TextStyle(fontSize: 13, color: kWhite), overflow: TextOverflow.ellipsis))]),
              const SizedBox(height: 6),
              Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(4))), const SizedBox(width: 10), Expanded(child: Text(c['dropoff_address'] ?? '', style: const TextStyle(fontSize: 13, color: kWhite), overflow: TextOverflow.ellipsis))]),
              const Divider(color: kGrayD, height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('📏 ${c['distance_km'] ?? '-'} km', style: const TextStyle(color: kGray, fontSize: 13)),
                Text('${c['montant_total'] ?? '-'} ${c['currency'] ?? 'XAF'}', style: const TextStyle(color: kPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
              ]),
            ]));
          }));
  }
}

// ═══════════════════════════════════════════════════════════════
//  WALLET & RETRAITS
// ═══════════════════════════════════════════════════════════════
const _kOperators = [
  {'id': 'mtn',    'label': 'MTN Mobile Money', 'color': 0xFFFFCB00},
  {'id': 'orange', 'label': 'Orange Money',      'color': 0xFFFF6600},
  {'id': 'airtel', 'label': 'Airtel Money',      'color': 0xFFE40000},
  {'id': 'peex',   'label': 'Peex',              'color': 0xFF00A86B},
  {'id': 'moov',   'label': 'Moov Money',        'color': 0xFF0057A8},
];

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override State<WalletScreen> createState() => _WalletScreenState();
}
class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _wallet;
  List<dynamic> _txns = [];
  List<dynamic> _withdrawals = [];
  bool _loading = true;
  bool _showModal = false;
  String? _selOp;
  final _amount = TextEditingController();
  final _phone  = TextEditingController();
  bool _wBusy = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        _apiGet('/driver/wallet').catchError((_) => <String, dynamic>{}),
        _apiGet('/driver/wallet/transactions').catchError((_) => <String, dynamic>{}),
        _apiGet('/driver/withdrawals').catchError((_) => <String, dynamic>{}),
      ]);
      if (mounted) setState(() {
        _wallet = res[0]['data'] ?? res[0];
        _txns   = res[1]['data'] ?? [];
        _withdrawals = res[2]['data'] ?? [];
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _requestWithdrawal() async {
    if (_selOp == null || _amount.text.isEmpty || _phone.text.isEmpty) { _snack('Remplis tous les champs'); return; }
    final amt = double.tryParse(_amount.text);
    if (amt == null || amt <= 0) { _snack('Montant invalide'); return; }
    final balance = (_wallet?['balance'] as num?)?.toDouble() ?? 0;
    if (amt > balance) { _snack('Solde insuffisant (${balance.toStringAsFixed(0)} ${_wallet?['currency'] ?? 'XAF'})'); return; }
    setState(() => _wBusy = true);
    try {
      await _apiPost('/driver/withdrawals', {'amount': amt, 'method': _selOp, 'phone_number': _phone.text});
      _snack('✅ Demande de retrait envoyée avec succès !');
      setState(() { _showModal = false; _wBusy = false; _selOp = null; });
      _amount.clear(); _phone.clear();
      _load();
    } catch (e) { _snack('Erreur lors du retrait'); setState(() => _wBusy = false); }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: kPrimary));
    return Stack(children: [
      RefreshIndicator(onRefresh: _load, color: kPrimary, child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mon Portefeuille', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kWhite)),
          const SizedBox(height: 20),
          // Solde card
          Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [kPrimary, Color(0xFFFF9A3C)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Solde disponible', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text('${_wallet?['balance'] ?? '---'}', style: const TextStyle(color: kWhite, fontSize: 40, fontWeight: FontWeight.w900)),
              Text(_wallet?['currency'] ?? 'XAF', style: const TextStyle(color: Colors.white60, fontSize: 16)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setState(() => _showModal = true),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                  child: const Text('💳 Retirer mes gains', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700))),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          // Transactions
          if (_txns.isNotEmpty) ...[
            const Text('Transactions récentes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kWhite)),
            const SizedBox(height: 12),
            Container(decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16)), child: Column(
              children: List.generate(_txns.take(8).length, (i) {
                final t = _txns[i] as Map<String, dynamic>;
                final isCredit = t['type'] == 'credit';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(border: i < _txns.take(8).length - 1 ? const Border(bottom: BorderSide(color: kGrayD)) : null),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t['description'] ?? t['type'] ?? '', style: const TextStyle(color: kWhite, fontSize: 14, fontWeight: FontWeight.w600)),
                      if (t['created_at'] != null) Text(
                        '${DateTime.parse(t['created_at']).day}/${DateTime.parse(t['created_at']).month}/${DateTime.parse(t['created_at']).year}',
                        style: const TextStyle(color: kGray, fontSize: 12)),
                    ])),
                    Text('${isCredit ? '+' : '-'}${t['amount']} ${_wallet?['currency'] ?? ''}',
                      style: TextStyle(color: isCredit ? kSuccess : kDanger, fontSize: 15, fontWeight: FontWeight.w800)),
                  ]),
                );
              }),
            )),
            const SizedBox(height: 24),
          ],
          // Retraits
          if (_withdrawals.isNotEmpty) ...[
            const Text('Historique des retraits', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kWhite)),
            const SizedBox(height: 12),
            Container(decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16)), child: Column(
              children: List.generate(_withdrawals.length, (i) {
                final w = _withdrawals[i] as Map<String, dynamic>;
                final op = _kOperators.firstWhere((o) => o['id'] == w['method'], orElse: () => {'label': w['method'], 'color': 0xFF8892A4});
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: i < _withdrawals.length - 1 ? const Border(bottom: BorderSide(color: kGrayD)) : null),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${op['label']} • ${w['phone_number'] ?? ''}', style: const TextStyle(color: kWhite, fontSize: 14, fontWeight: FontWeight.w600)),
                      if (w['created_at'] != null) Text(
                        '${DateTime.parse(w['created_at']).day}/${DateTime.parse(w['created_at']).month}/${DateTime.parse(w['created_at']).year}',
                        style: const TextStyle(color: kGray, fontSize: 12)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('-${w['amount']} ${_wallet?['currency'] ?? ''}', style: const TextStyle(color: kDanger, fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: (w['status'] == 'completed' ? kSuccess : kWarning).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text(w['status'] == 'completed' ? 'Envoyé' : 'En attente',
                          style: TextStyle(color: w['status'] == 'completed' ? kSuccess : kWarning, fontSize: 10, fontWeight: FontWeight.w700))),
                    ]),
                  ]),
                );
              }),
            )),
          ],
        ]),
      )),
      // Modal retrait
      if (_showModal) Positioned.fill(child: Container(
        color: Colors.black54,
        child: Align(alignment: Alignment.bottomCenter, child: Container(
          decoration: const BoxDecoration(color: kCard, borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28))),
          child: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('💳 Retirer mes gains', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kWhite)),
              GestureDetector(onTap: () => setState(() => _showModal = false), child: const Icon(Icons.close, color: kGray)),
            ]),
            const SizedBox(height: 6),
            Text('Solde : ${_wallet?['balance'] ?? '-'} ${_wallet?['currency'] ?? 'XAF'}', style: const TextStyle(color: kGray, fontSize: 13)),
            const SizedBox(height: 20),
            const Text('1. Opérateur', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: _kOperators.map((op) {
              final sel = _selOp == op['id'];
              final color = Color(op['color'] as int);
              return GestureDetector(
                onTap: () => setState(() => _selOp = op['id'] as String),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: sel ? color.withOpacity(0.2) : kCardL, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? color : kGrayD, width: sel ? 2 : 1)),
                  child: Text(op['label'] as String, style: TextStyle(color: sel ? color : kGray, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, fontSize: 13))),
              );
            }).toList()),
            const SizedBox(height: 20),
            const Text('2. Numéro Mobile Money', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(controller: _phone, keyboardType: TextInputType.phone, style: const TextStyle(color: kWhite),
              decoration: InputDecoration(hintText: '+242 00 000 00 00', hintStyle: const TextStyle(color: kGray),
                filled: true, fillColor: kCardL, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrayD)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrayD, width: 1.5)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 2)),
              )),
            const SizedBox(height: 16),
            const Text('3. Montant', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(controller: _amount, keyboardType: TextInputType.number, style: const TextStyle(color: kWhite, fontSize: 24, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              decoration: InputDecoration(hintText: 'Ex: 5000', hintStyle: const TextStyle(color: kGray),
                filled: true, fillColor: kCardL, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrayD)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrayD, width: 1.5)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 2)),
              )),
            const SizedBox(height: 16),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: kCardL, borderRadius: BorderRadius.circular(12)),
              child: const Text('ℹ️ Les retraits sont traités dans un délai de 5 à 30 minutes selon l\'opérateur.', style: TextStyle(color: kGray, fontSize: 13, height: 1.5))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _wBusy ? null : _requestWithdrawal,
              child: _wBusy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2)) : const Text('Confirmer le retrait'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => setState(() => _showModal = false),
              style: OutlinedButton.styleFrom(foregroundColor: kGray, side: const BorderSide(color: kGrayD),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), minimumSize: const Size(double.infinity, 50)),
              child: const Text('Annuler'),
            ),
          ]))),
        )),
      )),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  PROFILE CHAUFFEUR
// ═══════════════════════════════════════════════════════════════
class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});
  @override State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}
class _DriverProfileScreenState extends State<DriverProfileScreen> {
  Map<String, dynamic>? _driver;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final d = p.getString('driverProfile');
      if (d != null && mounted) setState(() => _driver = jsonDecode(d));
    });
  }

  Future<void> _logout() async {
    setState(() => _loading = true);
    try { await _apiPost('/driver/auth/logout'); } catch (_) {}
    final p = await SharedPreferences.getInstance();
    await p.remove('driverToken');
    await p.remove('driverProfile');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Mon profil', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kWhite)),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20)), child: Column(children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: kCardL, borderRadius: BorderRadius.circular(40), border: Border.all(color: kPrimary, width: 3)),
          child: const Center(child: Text('👨‍✈️', style: TextStyle(fontSize: 40)))),
        const SizedBox(height: 12),
        if (_driver != null) ...[
          Text('${_driver!['first_name'] ?? ''} ${_driver!['last_name'] ?? ''}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kWhite)),
          const SizedBox(height: 4),
          Text(_driver!['phone'] ?? '', style: const TextStyle(color: kGray)),
          if (_driver!['vehicle_brand'] != null) ...[const SizedBox(height: 4), Text('🚗 ${_driver!['vehicle_brand']} ${_driver!['vehicle_model']} • ${_driver!['vehicle_plate']}', style: const TextStyle(color: kGray, fontSize: 13))],
        ],
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Column(children: const [Icon(Icons.star, color: kWarning, size: 20), SizedBox(height: 2), Text('4.8', style: TextStyle(color: kGray, fontSize: 12))]),
          const SizedBox(width: 24),
          Container(width: 1, height: 30, color: kGrayD),
          const SizedBox(width: 24),
          Column(children: const [Text('0', style: TextStyle(color: kWhite, fontSize: 18, fontWeight: FontWeight.w700)), SizedBox(height: 2), Text('Courses', style: TextStyle(color: kGray, fontSize: 12))]),
        ]),
      ])),
      const SizedBox(height: 20),
      Container(decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20)), child: Column(
        children: [
          for (final item in [['📄', 'Documents & vérification'], ['🚗', 'Mon véhicule'], ['💬', 'Support'], ['🔔', 'Notifications'], ['🔒', 'Sécurité']])
            ListTile(leading: Text(item[0], style: const TextStyle(fontSize: 22)), title: Text(item[1], style: const TextStyle(color: kWhite, fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.chevron_right, color: kGray), onTap: () {},
              shape: Border(bottom: BorderSide(color: kGrayD.withOpacity(0.5)))),
        ],
      )),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: _loading ? null : _logout,
        style: ElevatedButton.styleFrom(backgroundColor: kDanger),
        child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2)) : const Text('Se déconnecter'),
      ),
    ]),
  );
}
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../core/models/driver_model.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/app_widgets.dart';
import '../dashboard/main_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final _idCtrl   = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true, _loading = false;

  Future<void> _login() async {
    final id = _idCtrl.text.trim();
    final pw = _passCtrl.text;
    if (id.isEmpty || pw.isEmpty) {
      snack(context, 'Remplissez tous les champs', error: true); return;
    }
    setState(() => _loading = true);
    final body = id.contains('@') ? {'email': id, 'password': pw} : {'phone': id, 'password': pw};
    final res = await ApiService.post(Api.login, body);
    setState(() => _loading = false);
    if (!mounted) return;

    if (res['success'] == true) {
      final token = res['token'] ?? res['access_token'];
      if (token != null) {
        await ApiService.saveToken(token.toString());
        currentDriver = DriverModel.fromJson(res);
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const MainDashboard()));
      } else {
        snack(context, 'Token manquant dans la réponse', error: true);
      }
    } else {
      final errs = res['errors'];
      String msg = res['message'] ?? 'Identifiants incorrects';
      if (errs is Map) msg = (errs.values.first as List).first.toString();
      snack(context, msg, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 28),
      const Text('Bon retour !',
        style: TextStyle(color: C.text, fontSize: 28, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('Connectez-vous à votre espace conducteur',
        style: TextStyle(color: C.muted, fontSize: 14)),
      const SizedBox(height: 32),
      TF(hint: '+242 06 XXX XX XX ou email', label: '📱  Téléphone / Email',
        ctrl: _idCtrl, type: TextInputType.emailAddress),
      const SizedBox(height: 14),
      TF(hint: 'Votre mot de passe', label: '🔒  Mot de passe',
        ctrl: _passCtrl, obscure: _obscure,
        suffix: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: C.muted, size: 20),
          onPressed: () => setState(() => _obscure = !_obscure))),
      const SizedBox(height: 10),
      Align(alignment: Alignment.centerRight,
        child: TextButton(onPressed: () {},
          child: const Text('Mot de passe oublié ?',
            style: TextStyle(color: C.orange, fontSize: 13)))),
      const SizedBox(height: 14),
      OBtn(text: 'Se connecter', onTap: _login, loading: _loading),
      const SizedBox(height: 20),
    ]),
  );
}

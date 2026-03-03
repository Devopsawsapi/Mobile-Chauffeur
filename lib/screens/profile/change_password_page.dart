import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/tt_logo.dart';
import '../../widgets/app_widgets.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
  @override State<ChangePasswordPage> createState() => _ChgPwState();
}

class _ChgPwState extends State<ChangePasswordPage> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _cnfCtrl = TextEditingController();
  bool _obscure = true, _loading = false;

  Future<void> _update() async {
    if (_newCtrl.text != _cnfCtrl.text) { snack(context, 'Mots de passe différents', error: true); return; }
    if (_newCtrl.text.length < 6)        { snack(context, 'Minimum 6 caractères', error: true);  return; }
    setState(() => _loading = true);
    final res = await ApiService.put(Api.password, {
      'current_password':      _oldCtrl.text,
      'password':              _newCtrl.text,
      'password_confirmation': _cnfCtrl.text,
    });
    setState(() => _loading = false);
    if (!mounted) return;
    if (res['success'] == true) {
      snack(context, '✅ Mot de passe modifié !');
      Navigator.pop(context);
    } else {
      snack(context, res['message'] ?? 'Erreur', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(backgroundColor: C.card, elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: C.text),
        onPressed: () => Navigator.pop(context)),
      title: const TTTextLogo(fontSize: 18),
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border))),
    body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      const SizedBox(height: 20),
      const TTIconLogo(size: 64, glow: true),
      const SizedBox(height: 20),
      const TTTextLogo(fontSize: 26),
      const SizedBox(height: 6),
      const Text('Modifier votre mot de passe', style: TextStyle(color: C.muted, fontSize: 14)),
      const SizedBox(height: 36),
      TF(hint: 'Ancien mot de passe', ctrl: _oldCtrl, obscure: _obscure,
        prefix: const Icon(Icons.lock_outline, color: C.muted, size: 20)),
      const SizedBox(height: 14),
      TF(hint: 'Nouveau mot de passe', ctrl: _newCtrl, obscure: _obscure,
        prefix: const Icon(Icons.lock_reset, color: C.muted, size: 20)),
      const SizedBox(height: 14),
      TF(hint: 'Confirmer le nouveau', ctrl: _cnfCtrl, obscure: _obscure,
        prefix: const Icon(Icons.lock_clock_outlined, color: C.muted, size: 20),
        suffix: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: C.muted, size: 20),
          onPressed: () => setState(() => _obscure = !_obscure))),
      const SizedBox(height: 32),
      OBtn(text: 'METTRE À JOUR', icon: Icons.check_circle_rounded,
        loading: _loading, onTap: _update),
    ])));
}

import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../core/models/driver_model.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/app_widgets.dart';
import '../dashboard/main_dashboard.dart';

// Longueurs de numéros locaux par pays (sans indicatif)
const Map<String, int> _phoneLengths = {
  'CG': 9,  // Congo Brazzaville +242
  'CD': 9,  // RDC +243
  'GA': 8,  // Gabon +241
  'CM': 9,  // Cameroun +237
  'CI': 10, // Côte d'Ivoire +225
  'SN': 9,  // Sénégal +221
  'TG': 8,  // Togo +228
  'BJ': 8,  // Bénin +229
  'ML': 8,  // Mali +223
  'BF': 8,  // Burkina Faso +226
  'GN': 9,  // Guinée +224
  'MG': 9,  // Madagascar +261
  'FR': 9,  // France +33
  'BE': 9,  // Belgique +32
  'US': 10, // USA +1
  'CA': 10, // Canada +1
};

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final _phoneCtrl    = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _resetCtrl    = TextEditingController();
  bool _obscure           = true;
  bool _loading           = false;
  bool _usePhone          = true;
  String _fullPhone       = '';
  String _selectedCountry = 'CG'; // pays sélectionné

  int get _maxPhoneLength => _phoneLengths[_selectedCountry] ?? 10;

  // ── Connexion ──────────────────────────────────────────────────────
  Future<void> _login() async {
    final pw = _passCtrl.text;
    if (pw.isEmpty) {
      snack(context, 'Remplissez tous les champs', error: true); return;
    }

    Map<String, dynamic> body;
    if (_usePhone) {
      if (_fullPhone.isEmpty) {
        snack(context, 'Entrez votre numéro de téléphone', error: true); return;
      }
      // Validation longueur selon pays
      if (_phoneCtrl.text.length != _maxPhoneLength) {
        snack(context,
          'Numéro invalide : $_maxPhoneLength chiffres attendus pour ce pays',
          error: true);
        return;
      }
      body = {'phone': _fullPhone, 'password': pw};
    } else {
      final email = _emailCtrl.text.trim();
      if (email.isEmpty) {
        snack(context, 'Entrez votre email', error: true); return;
      }
      body = {'email': email, 'password': pw};
    }

    setState(() => _loading = true);
    final res = await ApiService.post(Api.login, body);
    setState(() => _loading = false);
    if (!mounted) return;

    if (res['success'] == true) {
      if (res['message'] != null &&
          res['message'].toString().contains('suspendu')) {
        snack(context, res['message'], error: true); return;
      }
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

  // ── Réinitialisation mot de passe ──────────────────────────────────
  void _showResetDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: C.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Mot de passe oublié ?',
        style: TextStyle(color: C.text, fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text(
          'Entrez votre numéro de téléphone ou email pour recevoir un lien de réinitialisation.',
          style: TextStyle(color: C.muted, fontSize: 13, height: 1.5)),
        const SizedBox(height: 16),
        TF(hint: 'Téléphone ou email', label: '📱 Identifiant',
          ctrl: _resetCtrl, type: TextInputType.emailAddress),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: C.muted))),
        GestureDetector(
          onTap: () async {
            final id = _resetCtrl.text.trim();
            if (id.isEmpty) return;
            Navigator.pop(context);
            final res = await ApiService.post(Api.forgotPassword, {
              id.contains('@') ? 'email' : 'phone': id,
            });
            if (mounted) snack(context,
              res['success'] == true
                ? '✅ Instructions envoyées par SMS/email.'
                : res['message'] ?? 'Erreur',
              error: res['success'] != true);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: C.orange,
              borderRadius: BorderRadius.circular(10)),
            child: const Text('Envoyer',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        ),
      ],
    ));
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
      const SizedBox(height: 24),

      // ── Toggle Téléphone / Email ──────────────────────────────────
      Container(
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border)),
        child: Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _usePhone = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _usePhone ? C.orange : Colors.transparent,
                borderRadius: BorderRadius.circular(11)),
              child: Center(child: Text('📱 Téléphone',
                style: TextStyle(
                  color: _usePhone ? Colors.white : C.muted,
                  fontWeight: FontWeight.w700, fontSize: 13)))))),
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _usePhone = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: !_usePhone ? C.orange : Colors.transparent,
                borderRadius: BorderRadius.circular(11)),
              child: Center(child: Text('✉️ Email',
                style: TextStyle(
                  color: !_usePhone ? Colors.white : C.muted,
                  fontWeight: FontWeight.w700, fontSize: 13)))))),
        ]),
      ),
      const SizedBox(height: 16),

      // ── Champ téléphone avec indicatif pays ───────────────────────
      if (_usePhone)
        Container(
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.border)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: IntlPhoneField(
            controller: _phoneCtrl,
            initialCountryCode: 'CG',
            disableLengthCheck: true, // Désactive la limite automatique incorrecte
            dropdownTextStyle: const TextStyle(color: C.text, fontSize: 14),
            style: const TextStyle(color: C.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: '06 XXX XX XX',
              hintStyle: const TextStyle(color: C.muted),
              border: InputBorder.none,
              labelText: 'Numéro de téléphone',
              labelStyle: const TextStyle(color: C.muted, fontSize: 12),
              // Compteur dynamique selon pays
              counterText: '${_phoneCtrl.text.length}/$_maxPhoneLength',
              counterStyle: TextStyle(
                color: _phoneCtrl.text.length == _maxPhoneLength
                  ? C.orange
                  : C.muted,
                fontSize: 11,
              ),
            ),
            onCountryChanged: (country) {
              setState(() {
                _selectedCountry = country.code;
                _phoneCtrl.clear(); // Vide le champ quand le pays change
                _fullPhone = '';
              });
            },
            onChanged: (phone) {
              setState(() => _fullPhone = phone.completeNumber);
            },
          ),
        )
      else
        TF(hint: 'exemple@email.com', label: '✉️  Email',
          ctrl: _emailCtrl, type: TextInputType.emailAddress),

      const SizedBox(height: 14),

      // ── Mot de passe ──────────────────────────────────────────────
      TF(hint: 'Votre mot de passe', label: '🔒  Mot de passe',
        ctrl: _passCtrl, obscure: _obscure,
        suffix: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: C.muted, size: 20),
          onPressed: () => setState(() => _obscure = !_obscure))),

      const SizedBox(height: 10),

      // ── Mot de passe oublié ───────────────────────────────────────
      Align(alignment: Alignment.centerRight,
        child: TextButton(onPressed: _showResetDialog,
          child: const Text('Mot de passe oublié ?',
            style: TextStyle(color: C.orange, fontSize: 13)))),

      const SizedBox(height: 14),
      OBtn(text: 'Se connecter', onTap: _login, loading: _loading),
      const SizedBox(height: 20),
    ]),
  );
}

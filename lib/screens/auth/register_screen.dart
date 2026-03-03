import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_data.dart';
import '../../core/models/country_model.dart';
import '../../core/models/driver_model.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/app_widgets.dart';
import '../dashboard/main_dashboard.dart';
import 'auth_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegState();
}

class _RegState extends State<RegisterScreen> {
  int _step = 0;

  // Étape 1
  final _firstCtrl = TextEditingController();
  final _lastCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _confCtrl  = TextEditingController();
  Country? _resCt; String? _resCity;
  Country? _birthCt;
  bool _obscure = true, _loading = false;
  String? _birthDate;

  // Étape 2
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  String? _vType, _vColor; Country? _vCountry; String? _vCity;
  String? _docType; Country? _idCt, _licCt;
  String _idEm='', _idEx='', _licEm='', _licEx='', _insEm='', _insEx='', _grEm='', _grEx='';

  // Fichiers images
  File? _photoId;
  File? _photoIdRecto, _photoIdVerso;
  File? _photoLicRecto, _photoLicVerso;
  File? _photoIns;
  File? _photoGray;

  // ✅ Convertit DD/MM/YYYY → YYYY-MM-DD pour Laravel
  String _convertDate(String d) {
    if (d.isEmpty) return '';
    final p = d.split('/');
    if (p.length != 3) return d;
    return '${p[2]}-${p[1]}-${p[0]}';
  }

  // ── Validation étape 1
  void _next() {
    final dial     = _resCt?.dial ?? kCountries[0].dial;
    final expected = expectedPhoneDigits(dial);
    final phoneNum = _phoneCtrl.text.trim().replaceAll(' ', '');

    if (_firstCtrl.text.trim().isEmpty || _lastCtrl.text.trim().isEmpty) {
      snack(context, 'Prénom et nom obligatoires', error: true); return;
    }
    if (phoneNum.isEmpty) {
      snack(context, 'Numéro de téléphone obligatoire', error: true); return;
    }
    if (!RegExp(r'^\d+$').hasMatch(phoneNum)) {
      snack(context, 'Le téléphone doit contenir uniquement des chiffres', error: true); return;
    }
    if (phoneNum.length != expected) {
      snack(context, 'Le numéro pour $dial doit contenir exactement $expected chiffres', error: true); return;
    }
    if (_passCtrl.text.isEmpty) {
      snack(context, 'Mot de passe obligatoire', error: true); return;
    }
    if (_passCtrl.text.length < 6) {
      snack(context, 'Mot de passe : minimum 6 caractères', error: true); return;
    }
    if (_passCtrl.text != _confCtrl.text) {
      snack(context, 'Les mots de passe ne correspondent pas', error: true); return;
    }
    if (_birthDate == null || _birthDate!.isEmpty) {
      snack(context, 'Date de naissance obligatoire', error: true); return;
    }
    if (_birthCt == null) {
      snack(context, 'Pays de naissance obligatoire', error: true); return;
    }
    try {
      final parts = _birthDate!.split('/');
      final dob = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      final now = DateTime.now();
      final age = now.year - dob.year -
        ((now.month < dob.month || (now.month == dob.month && now.day < dob.day)) ? 1 : 0);
      if (age < 21) {
        snack(context, 'Vous devez avoir au moins 21 ans', error: true); return;
      }
      if (age > 75) {
        snack(context, 'Vous devez avoir au maximum 75 ans', error: true); return;
      }
    } catch (_) {
      snack(context, 'Date de naissance invalide', error: true); return;
    }
    setState(() => _step = 1);
  }

  void _prev() => setState(() => _step = 0);

  // Sélection date de naissance (21-75 ans)
  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 35, 1, 1),
      firstDate: DateTime(now.year - 75, now.month, now.day),
      lastDate:  DateTime(now.year - 21, now.month, now.day),
      helpText: 'Date de naissance (21-75 ans)',
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: C.orange)),
        child: child!),
    );
    if (picked != null) {
      setState(() => _birthDate =
        '${picked.day.toString().padLeft(2,'0')}/${picked.month.toString().padLeft(2,'0')}/${picked.year}');
    }
  }

  // Validation dates documents
  String? _validateDates(String emis, String expir, String label) {
    if (emis.isEmpty || expir.isEmpty) return null;
    try {
      final parseDate = (String d) {
        final p = d.split('/');
        return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      };
      final em = parseDate(emis);
      final ex = parseDate(expir);
      final now = DateTime.now();
      if (em.isAfter(now))  return "Date d'émission ($label) ne peut pas être dans le futur";
      if (ex.isBefore(now)) return "Document ($label) expiré";
      if (ex.isBefore(em))  return "Expiration ($label) doit être après l'émission";
    } catch (_) {}
    return null;
  }

  Future<void> _register() async {
    for (final check in [
      _validateDates(_idEm,  _idEx,  "Pièce d'identité"),
      _validateDates(_licEm, _licEx, 'Permis'),
      _validateDates(_insEm, _insEx, 'Assurance'),
      _validateDates(_grEm,  _grEx,  'Carte grise'),
    ]) {
      if (check != null) { snack(context, check, error: true); return; }
    }

    setState(() => _loading = true);
    final dial  = _resCt?.dial ?? kCountries[0].dial;
    final phone = '$dial${_phoneCtrl.text.trim()}';

    final res = await ApiService.postMultipart(Api.register, {
      'first_name':  _firstCtrl.text.trim(),
      'last_name':   _lastCtrl.text.trim(),
      'phone':       phone,
      'email':       _emailCtrl.text.trim(),
      'password':    _passCtrl.text,
      'password_confirmation': _confCtrl.text,
      'country':        _resCt?.name ?? '',
      'country_code':   _resCt?.code ?? '',
      'city':           _resCity ?? '',
      'birth_date':     _convertDate(_birthDate ?? ''),   // ✅ YYYY-MM-DD
      'country_birth':  _birthCt?.code ?? '',
      'vehicle_brand':   _brandCtrl.text.trim(),
      'vehicle_model':   _modelCtrl.text.trim(),
      'vehicle_plate':   _plateCtrl.text.trim(),
      'vehicle_type':    _vType ?? '',
      'vehicle_color':   _vColor ?? '',
      'vehicle_country': _vCountry?.name ?? '',
      'vehicle_city':    _vCity ?? '',
      'id_doc_type':       _docType ?? '',
      'id_doc_country':    _idCt?.code ?? '',
      'id_doc_issued_at':  _convertDate(_idEm),           // ✅ YYYY-MM-DD
      'id_doc_expires_at': _convertDate(_idEx),           // ✅ YYYY-MM-DD
      'license_country':    _licCt?.code ?? '',
      'license_issued_at':  _convertDate(_licEm),         // ✅ YYYY-MM-DD
      'license_expires_at': _convertDate(_licEx),         // ✅ YYYY-MM-DD
      'insurance_issued_at':  _convertDate(_insEm),       // ✅ YYYY-MM-DD
      'insurance_expires_at': _convertDate(_insEx),       // ✅ YYYY-MM-DD
      'gray_card_issued_at':  _convertDate(_grEm),        // ✅ YYYY-MM-DD
      'gray_card_expires_at': _convertDate(_grEx),        // ✅ YYYY-MM-DD
    }, files: {
      if (_photoId       != null) 'photo':           _photoId!,
      if (_photoIdRecto  != null) 'id_doc_recto':    _photoIdRecto!,
      if (_photoIdVerso  != null) 'id_doc_verso':    _photoIdVerso!,
      if (_photoLicRecto != null) 'license_recto':   _photoLicRecto!,
      if (_photoLicVerso != null) 'license_verso':   _photoLicVerso!,
      if (_photoIns      != null) 'insurance_photo': _photoIns!,
      if (_photoGray     != null) 'gray_card_photo': _photoGray!,
    });

    setState(() => _loading = false);
    if (!mounted) return;

    if (res['success'] == true) {
      final token = res['token'] ?? res['access_token'];
      if (token != null) {
        await ApiService.saveToken(token.toString());
        currentDriver = DriverModel.fromJson(res);
        snack(context, '✅ Compte créé avec succès !');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const MainDashboard()));
      } else {
        snack(context, '✅ Inscription réussie ! Connectez-vous.');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const AuthScreen()));
      }
    } else {
      final errs = res['errors'];
      String msg = res['message'] ?? "Erreur lors de l'inscription";
      if (errs is Map) msg = (errs.values.first as List).first.toString();
      snack(context, msg, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(margin: const EdgeInsets.fromLTRB(24, 16, 24, 0), child: Row(children: [
      _dot(0, 'Infos'),
      Expanded(child: Container(height: 2, color: _step >= 1 ? C.orange : C.border)),
      _dot(1, 'Véhicule'),
    ])),
    Expanded(child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
          child: child)),
      child: KeyedSubtree(key: ValueKey(_step), child: _step == 0 ? _s1() : _s2()),
    )),
  ]);

  Widget _dot(int i, String l) {
    final on = _step >= i;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: on ? C.orange : C.surface,
          border: Border.all(color: on ? C.orange : C.border, width: 2)),
        child: Center(child: on && _step > i
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : Text('${i+1}', style: TextStyle(
              color: on ? Colors.white : C.muted,
              fontWeight: FontWeight.w700, fontSize: 13)))),
      const SizedBox(height: 4),
      Text(l, style: TextStyle(color: on ? C.orange : C.muted,
        fontSize: 10, fontWeight: FontWeight.w600)),
    ]);
  }

  // ── Étape 1
  Widget _s1() {
    final dial     = _resCt?.dial ?? kCountries[0].dial;
    final expected = expectedPhoneDigits(dial);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        const Text('Devenez Conducteur',
          style: TextStyle(color: C.text, fontSize: 24, fontWeight: FontWeight.w900)),
        const Text('Inscription — Afrique Centrale',
          style: TextStyle(color: C.muted, fontSize: 13)),
        const SLabel('INFORMATIONS PERSONNELLES'),
        Row(children: [
          Expanded(child: TF(hint: 'Alain',  label: 'Prénom *', ctrl: _firstCtrl)),
          const SizedBox(width: 12),
          Expanded(child: TF(hint: 'Mbarga', label: 'Nom *',    ctrl: _lastCtrl)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          GestureDetector(
            onTap: () => showCountryPicker(context,
              (c) => setState(() { _resCt = c; _resCity = null; _phoneCtrl.clear(); })),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(color: C.surface,
                border: Border.all(color: C.border),
                borderRadius: BorderRadius.circular(14)),
              child: Text(
                '${_resCt?.flag ?? kCountries[0].flag} ${_resCt?.dial ?? kCountries[0].dial}',
                style: const TextStyle(color: C.text, fontSize: 14)))),
          const SizedBox(width: 10),
          Expanded(child: TF(
            hint: 'X' * expected,
            label: '📱 Téléphone * ($expected chiffres)',
            ctrl: _phoneCtrl,
            type: TextInputType.phone,
            maxLength: expected,
          )),
        ]),
        const SizedBox(height: 14),
        TF(hint: 'email@exemple.com', label: '✉️  Email',
          ctrl: _emailCtrl, type: TextInputType.emailAddress),
        const SizedBox(height: 14),
        TF(hint: 'Min. 6 caractères', label: '🔒  Mot de passe *',
          ctrl: _passCtrl, obscure: _obscure),
        const SizedBox(height: 14),
        TF(hint: 'Répéter le mot de passe', label: '🔒  Confirmer *',
          ctrl: _confCtrl, obscure: _obscure,
          suffix: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: C.muted, size: 20),
            onPressed: () => setState(() => _obscure = !_obscure))),

        const SLabel('DATE & LIEU DE NAISSANCE'),
        GestureDetector(
          onTap: _pickBirthDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: C.surface,
              border: Border.all(color: _birthDate != null ? C.orange : C.border),
              borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.cake_outlined, color: C.muted, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _birthDate ?? 'Date de naissance * (21-75 ans)',
                style: TextStyle(
                  color: _birthDate != null ? C.text : C.muted, fontSize: 14))),
              const Icon(Icons.calendar_today_outlined, color: C.muted, size: 18),
            ]))),
        const SizedBox(height: 14),
        appDrop<Country>(
          hint: '🌍  Pays de naissance *',
          value: _birthCt,
          items: kCountries,
          builder: (c) => Text('${c.flag}  ${c.name}'),
          onChanged: (v) => setState(() => _birthCt = v),
          prefix: const Icon(Icons.place_outlined, color: C.muted, size: 20)),

        const SLabel('PAYS & VILLE DE RÉSIDENCE'),
        appDrop<Country>(hint: '🌍  Pays de résidence', value: _resCt, items: kCountries,
          builder: (c) => Text('${c.flag}  ${c.name}'),
          onChanged: (v) => setState(() { _resCt = v; _resCity = null; }),
          prefix: const Icon(Icons.public_outlined, color: C.muted, size: 20)),
        if (_resCt != null) ...[
          const SizedBox(height: 14),
          appDrop<String>(hint: 'Ville', value: _resCity, items: _resCt!.cities,
            builder: (c) => Text(c),
            onChanged: (v) => setState(() => _resCity = v),
            prefix: const Icon(Icons.location_city_outlined, color: C.muted, size: 20)),
        ],

        const SLabel("PHOTO D'IDENTITÉ"),
        PhotoBox(
          label: "Photo d'identité\n(appuyer pour ajouter)",
          icon: Icons.face_outlined,
          onImageSelected: (f) => setState(() => _photoId = f),
        ),
        const SizedBox(height: 28),
        OBtn(text: 'Suivant →', onTap: _next),
        const SizedBox(height: 20),
      ]),
    );
  }

  // ── Étape 2
  Widget _s2() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      const Text('Informations véhicule',
        style: TextStyle(color: C.text, fontSize: 22, fontWeight: FontWeight.w900)),
      const SLabel('DÉTAILS DU VÉHICULE'),
      Row(children: [
        Expanded(child: TF(hint: 'Toyota',  label: 'Marque *', ctrl: _brandCtrl)),
        const SizedBox(width: 12),
        Expanded(child: TF(hint: 'Corolla', label: 'Modèle *', ctrl: _modelCtrl)),
      ]),
      const SizedBox(height: 14),
      TF(hint: 'Ex: PNR 234', label: 'Immatriculation *', ctrl: _plateCtrl,
        prefix: const Icon(Icons.confirmation_number_outlined, color: C.muted, size: 20)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: appDrop<String>(hint: 'Type', value: _vType, items: kVehicleTypes,
          builder: (e) => Text(e), onChanged: (v) => setState(() => _vType = v),
          prefix: const Icon(Icons.category_outlined, color: C.muted, size: 20))),
        const SizedBox(width: 12),
        Expanded(child: appDrop<String>(hint: 'Couleur', value: _vColor, items: kCarColors,
          builder: (e) => Row(children: [
            Container(width: 16, height: 16, margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: _clr(e), shape: BoxShape.circle,
                border: Border.all(color: C.border))),
            Text(e),
          ]),
          onChanged: (v) => setState(() => _vColor = v),
          prefix: const Icon(Icons.palette_outlined, color: C.muted, size: 20))),
      ]),
      const SizedBox(height: 14),
      appDrop<Country>(hint: '🌍 Pays', value: _vCountry, items: kCountries,
        builder: (c) => Text('${c.flag}  ${c.name}'),
        onChanged: (v) => setState(() { _vCountry = v; _vCity = null; }),
        prefix: const Icon(Icons.public_outlined, color: C.muted, size: 20)),
      if (_vCountry != null) ...[
        const SizedBox(height: 14),
        appDrop<String>(hint: 'Ville', value: _vCity, items: _vCountry!.cities,
          builder: (c) => Text(c), onChanged: (v) => setState(() => _vCity = v),
          prefix: const Icon(Icons.location_city_outlined, color: C.muted, size: 20)),
      ],
      Container(margin: const EdgeInsets.only(top: 20), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.blue.withOpacity(0.06),
          border: Border.all(color: C.blue.withOpacity(0.25)),
          borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.info_outline, color: C.blue, size: 18), SizedBox(width: 10),
          Expanded(child: Text(
            "Vos documents peuvent aussi être uploadés depuis votre espace Profil.",
            style: TextStyle(color: C.blue, fontSize: 12, height: 1.5))),
        ])),

      // Pièce d'identité
      const SLabel("PIÈCE D'IDENTITÉ"),
      appDrop<String>(hint: "Type de document *", value: _docType, items: kIdDocTypes,
        builder: (e) => Text(e), onChanged: (v) => setState(() => _docType = v),
        prefix: const Icon(Icons.credit_card_outlined, color: C.muted, size: 20)),
      const SizedBox(height: 14),
      appDrop<Country>(hint: 'Pays de délivrance *', value: _idCt, items: kCountries,
        builder: (c) => Text('${c.flag}  ${c.name}'),
        onChanged: (v) => setState(() => _idCt = v),
        prefix: const Icon(Icons.flag_outlined, color: C.muted, size: 20)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: datePicker(context, "Date d'émission", _idEm,
          () => pickDate(context, (d) => setState(() => _idEm = d), lastDate: DateTime.now()))),
        const SizedBox(width: 12),
        Expanded(child: datePicker(context, "Expiration", _idEx,
          () => pickDate(context, (d) => setState(() => _idEx = d), firstDate: DateTime.now()))),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: PhotoBox(
          label: 'Recto\n${_docType ?? "Document"}',
          icon: Icons.credit_card,
          onImageSelected: (f) => setState(() => _photoIdRecto = f),
        )),
        const SizedBox(width: 12),
        Expanded(child: PhotoBox(
          label: 'Verso\n${_docType ?? "Document"}',
          icon: Icons.credit_card_outlined,
          onImageSelected: (f) => setState(() => _photoIdVerso = f),
        )),
      ]),

      // Permis
      const SLabel('PERMIS DE CONDUIRE'),
      appDrop<Country>(hint: 'Pays de délivrance *', value: _licCt, items: kCountries,
        builder: (c) => Text('${c.flag}  ${c.name}'),
        onChanged: (v) => setState(() => _licCt = v),
        prefix: const Icon(Icons.flag_outlined, color: C.muted, size: 20)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: datePicker(context, "Date d'émission", _licEm,
          () => pickDate(context, (d) => setState(() => _licEm = d), lastDate: DateTime.now()))),
        const SizedBox(width: 12),
        Expanded(child: datePicker(context, "Expiration", _licEx,
          () => pickDate(context, (d) => setState(() => _licEx = d), firstDate: DateTime.now()))),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: PhotoBox(
          label: 'Permis Recto',
          icon: Icons.drive_eta_outlined,
          onImageSelected: (f) => setState(() => _photoLicRecto = f),
        )),
        const SizedBox(width: 12),
        Expanded(child: PhotoBox(
          label: 'Permis Verso',
          icon: Icons.drive_eta_outlined,
          onImageSelected: (f) => setState(() => _photoLicVerso = f),
        )),
      ]),

      // Assurance
      const SLabel('ASSURANCE VOITURE'),
      Row(children: [
        Expanded(child: datePicker(context, "Date d'émission", _insEm,
          () => pickDate(context, (d) => setState(() => _insEm = d), lastDate: DateTime.now()))),
        const SizedBox(width: 12),
        Expanded(child: datePicker(context, "Expiration", _insEx,
          () => pickDate(context, (d) => setState(() => _insEx = d), firstDate: DateTime.now()))),
      ]),
      const SizedBox(height: 14),
      PhotoBox(
        label: 'Photo assurance voiture',
        icon: Icons.shield_outlined,
        onImageSelected: (f) => setState(() => _photoIns = f),
      ),

      // Carte grise
      const SLabel('CARTE GRISE'),
      Row(children: [
        Expanded(child: datePicker(context, "Date d'émission", _grEm,
          () => pickDate(context, (d) => setState(() => _grEm = d), lastDate: DateTime.now()))),
        const SizedBox(width: 12),
        Expanded(child: datePicker(context, "Expiration", _grEx,
          () => pickDate(context, (d) => setState(() => _grEx = d), firstDate: DateTime.now()))),
      ]),
      const SizedBox(height: 14),
      PhotoBox(
        label: 'Photo carte grise',
        icon: Icons.article_outlined,
        onImageSelected: (f) => setState(() => _photoGray = f),
      ),

      const SizedBox(height: 28),
      Row(children: [
        Expanded(child: GestureDetector(onTap: _prev,
          child: Container(height: 56,
            decoration: BoxDecoration(color: C.surface,
              borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
            child: const Center(child: Text('← Retour',
              style: TextStyle(color: C.muted, fontWeight: FontWeight.w700, fontSize: 15)))))),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: OBtn(text: "S'inscrire ✓", loading: _loading, onTap: _register)),
      ]),
      const SizedBox(height: 24),
    ]),
  );

  Color _clr(String n) {
    const m = {
      'Blanc': Colors.white, 'Noir': Colors.black, 'Gris': Colors.grey,
      'Rouge': Colors.red,   'Bleu': Colors.blue,  'Vert': Colors.green,
      'Marron': Colors.brown,'Orange': Colors.orange,'Jaune': Colors.yellow,
      'Violet': Colors.purple,'Beige': Color(0xFFF5F5DC),'Argent': Color(0xFFC0C0C0),
    };
    return m[n] ?? C.border;
  }
}
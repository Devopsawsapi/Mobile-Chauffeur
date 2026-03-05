import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/models/driver_model.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/tt_logo.dart';

// ✅ Longueurs correctes par pays
const Map<String, int> _phoneLengths = {
  'CG': 9,  // Congo Brazzaville +242
  'CD': 9,  // RDC +243
  'GA': 8,  // Gabon +241
  'CM': 9,  // Cameroun +237
  'CF': 8,  // Centrafrique +236
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

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});
  @override State<PersonalInfoPage> createState() => _PersonalInfoState();
}

class _PersonalInfoState extends State<PersonalInfoPage> {
  final _firstCtrl   = TextEditingController();
  final _lastCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _birthCtrl   = TextEditingController();
  final _placeCtrl   = TextEditingController();
  final _countryCtrl = TextEditingController();

  String _fullPhone      = '';
  String _initialCode    = 'CG';
  String _selectedCountry = 'CG'; // ✅ Pour le compteur dynamique
  bool   _loading        = false;
  bool   _saving         = false;

  // ✅ Longueur max selon pays sélectionné
  int get _maxLen => _phoneLengths[_selectedCountry] ?? 10;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  void _prefill() {
    _firstCtrl.text   = currentDriver.firstName;
    _lastCtrl.text    = currentDriver.lastName;
    _countryCtrl.text = currentDriver.country ?? '';

    final phone = currentDriver.phone;
    _fullPhone  = phone;

    // Détecter indicatif pays depuis le numéro
    if (phone.startsWith('+242'))      { _initialCode = 'CG'; _selectedCountry = 'CG'; _phoneCtrl.text = phone.replaceFirst('+242', '').trim(); }
    else if (phone.startsWith('+237')) { _initialCode = 'CM'; _selectedCountry = 'CM'; _phoneCtrl.text = phone.replaceFirst('+237', '').trim(); }
    else if (phone.startsWith('+241')) { _initialCode = 'GA'; _selectedCountry = 'GA'; _phoneCtrl.text = phone.replaceFirst('+241', '').trim(); }
    else if (phone.startsWith('+243')) { _initialCode = 'CD'; _selectedCountry = 'CD'; _phoneCtrl.text = phone.replaceFirst('+243', '').trim(); }
    else if (phone.startsWith('+236')) { _initialCode = 'CF'; _selectedCountry = 'CF'; _phoneCtrl.text = phone.replaceFirst('+236', '').trim(); }
    else                               { _initialCode = 'CG'; _selectedCountry = 'CG'; _phoneCtrl.text = phone; }

    _loadExtra();
  }

  Future<void> _loadExtra() async {
    setState(() => _loading = true);
    final res = await ApiService.get(Api.profile);
    if (res['success'] == true && mounted) {
      final d = res['data'] ?? res['driver'] ?? res;
      setState(() {
        _birthCtrl.text   = d['birth_date']    ?? '';
        _placeCtrl.text   = d['birth_place']   ?? '';
        _countryCtrl.text = d['country_birth'] ?? currentDriver.country ?? '';
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_firstCtrl.text.isEmpty || _lastCtrl.text.isEmpty) {
      snack(context, 'Prénom et nom obligatoires', error: true); return;
    }
    if (_fullPhone.isEmpty) {
      snack(context, 'Numéro de téléphone obligatoire', error: true); return;
    }
    // ✅ Validation longueur selon pays
    if (_phoneCtrl.text.trim().length != _maxLen) {
      snack(context,
        'Numéro invalide : $_maxLen chiffres attendus pour ce pays',
        error: true);
      return;
    }
    setState(() => _saving = true);
    final res = await ApiService.put(Api.profile, {
      'first_name'   : _firstCtrl.text.trim(),
      'last_name'    : _lastCtrl.text.trim(),
      'phone'        : _fullPhone,
      'birth_date'   : _birthCtrl.text.trim(),
      'birth_place'  : _placeCtrl.text.trim(),
      'country_birth': _countryCtrl.text.trim(),
    });
    setState(() => _saving = false);
    if (!mounted) return;
    snack(context,
      res['success'] == true ? '✅ Profil mis à jour !' : res['message'] ?? 'Erreur',
      error: res['success'] != true);
    if (res['success'] == true) Navigator.pop(context);
  }

  @override
  void dispose() {
    _firstCtrl.dispose(); _lastCtrl.dispose(); _phoneCtrl.dispose();
    _birthCtrl.dispose(); _placeCtrl.dispose(); _countryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(
      backgroundColor: C.card, elevation: 0,
      title: Row(children: [
        const TTIconLogo(size: 34, glow: false), const SizedBox(width: 10),
        const TTTextLogo(fontSize: 18), const SizedBox(width: 8),
        const Text('· Informations', style: TextStyle(color: C.muted, fontSize: 13)),
      ]),
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border)),
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(C.orange)))
      : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            const SLabel('IDENTITÉ'),
            TF(hint: 'Prénom', ctrl: _firstCtrl,
              prefix: const Icon(Icons.person_outline_rounded, color: C.muted, size: 20)),
            const SizedBox(height: 12),
            TF(hint: 'Nom', ctrl: _lastCtrl,
              prefix: const Icon(Icons.person_outline_rounded, color: C.muted, size: 20)),

            const SLabel('CONTACT'),
            IntlPhoneField(
              controller: _phoneCtrl,
              initialCountryCode: _initialCode,
              disableLengthCheck: true, // ✅ Désactive la limite automatique incorrecte
              style: const TextStyle(color: C.text, fontSize: 14),
              dropdownTextStyle: const TextStyle(color: C.text),
              flagsButtonPadding: const EdgeInsets.only(left: 12),
              decoration: InputDecoration(
                hintText: 'Numéro de téléphone',
                hintStyle: const TextStyle(color: C.muted, fontSize: 14),
                filled: true,
                fillColor: C.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: C.border)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: C.border)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: C.orange, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 16),
                // ✅ Compteur dynamique selon pays
                counterText: '${_phoneCtrl.text.trim().length}/$_maxLen',
                counterStyle: TextStyle(
                  color: _phoneCtrl.text.trim().length == _maxLen
                    ? C.orange : C.muted,
                  fontSize: 11),
              ),
              onCountryChanged: (country) {
                setState(() {
                  _initialCode     = country.code;
                  _selectedCountry = country.code; // ✅ Met à jour le compteur
                  _phoneCtrl.clear();
                  _fullPhone = '';
                });
              },
              onChanged: (phone) {
                setState(() => _fullPhone = phone.completeNumber);
              },
            ),

            const SLabel('NAISSANCE'),
            TF(hint: 'Date de naissance (YYYY-MM-DD)', ctrl: _birthCtrl,
              prefix: const Icon(Icons.cake_outlined, color: C.muted, size: 20)),
            const SizedBox(height: 12),
            TF(hint: 'Lieu de naissance', ctrl: _placeCtrl,
              prefix: const Icon(Icons.location_city_outlined, color: C.muted, size: 20)),
            const SizedBox(height: 12),
            TF(hint: 'Pays de naissance', ctrl: _countryCtrl,
              prefix: const Icon(Icons.flag_outlined, color: C.muted, size: 20)),

            const SizedBox(height: 32),
            OBtn(text: 'ENREGISTRER', icon: Icons.save_rounded,
              loading: _saving, onTap: _save),
            const SizedBox(height: 30),
          ]),
        ),
  );
}

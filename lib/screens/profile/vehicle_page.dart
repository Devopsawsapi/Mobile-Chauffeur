import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_data.dart';
import '../../core/models/driver_model.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/tt_logo.dart';

class VehiclePage extends StatefulWidget {
  const VehiclePage({super.key});
  @override State<VehiclePage> createState() => _VehicleState();
}

class _VehicleState extends State<VehiclePage> {
  final _brandCtrl   = TextEditingController();
  final _modelCtrl   = TextEditingController();
  final _plateCtrl   = TextEditingController();
  final _yearCtrl    = TextEditingController();
  final _colorCtrl   = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _countryCtrl = TextEditingController();
  String? _vType;
  bool _loading = false, _saving = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  // ✅ Pré-remplir depuis currentDriver
  void _prefill() {
    _brandCtrl.text   = currentDriver.vehicleBrand ?? '';
    _modelCtrl.text   = currentDriver.vehicleModel ?? '';
    _colorCtrl.text   = currentDriver.vehicleColor ?? '';
    _cityCtrl.text    = currentDriver.city         ?? '';
    _countryCtrl.text = currentDriver.country      ?? '';
    _vType            = currentDriver.vehicleType;
    _loadExtra();
  }

  Future<void> _loadExtra() async {
    setState(() => _loading = true);
    final res = await ApiService.get(Api.profile);
    if (res['success'] == true && mounted) {
      final d = res['data'] ?? res['driver'] ?? res;
      setState(() {
        _plateCtrl.text   = d['vehicle_plate']   ?? '';
        _yearCtrl.text    = d['vehicle_year']?.toString() ?? '';
        _cityCtrl.text    = d['vehicle_city']    ?? currentDriver.city    ?? '';
        _countryCtrl.text = d['vehicle_country'] ?? currentDriver.country ?? '';
        _vType            = d['vehicle_type']    ?? currentDriver.vehicleType;
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    // FIX: valider que city n'est pas vide avant d'envoyer
    if (_cityCtrl.text.trim().isEmpty) {
      snack(context, 'La ville est obligatoire', error: true);
      return;
    }
    setState(() => _saving = true);
    final res = await ApiService.put(Api.profile, {
      'vehicle_brand'  : _brandCtrl.text.trim(),
      'vehicle_model'  : _modelCtrl.text.trim(),
      'vehicle_plate'  : _plateCtrl.text.trim(),
      'vehicle_year'   : int.tryParse(_yearCtrl.text) ?? 0,
      'vehicle_color'  : _colorCtrl.text.trim(),
      'vehicle_city'   : _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : 'Non spécifié',
      'vehicle_country': _countryCtrl.text.trim().isNotEmpty ? _countryCtrl.text.trim() : 'République du Congo',
      'vehicle_type'   : _vType ?? '',
    });
    setState(() => _saving = false);
    if (!mounted) return;
    snack(context,
      res['success'] == true ? '✅ Véhicule mis à jour !' : res['message'] ?? 'Erreur',
      error: res['success'] != true);
    if (res['success'] == true) Navigator.pop(context);
  }

  @override
  void dispose() {
    _brandCtrl.dispose(); _modelCtrl.dispose(); _plateCtrl.dispose();
    _yearCtrl.dispose(); _colorCtrl.dispose(); _cityCtrl.dispose();
    _countryCtrl.dispose();
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
        const Text('· Mon véhicule', style: TextStyle(color: C.muted, fontSize: 13)),
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

            const SLabel('INFORMATIONS VÉHICULE'),
            TF(hint: 'Marque (ex: Toyota)', ctrl: _brandCtrl,
              prefix: const Icon(Icons.directions_car_outlined, color: C.muted, size: 20)),
            const SizedBox(height: 12),
            TF(hint: 'Modèle (ex: Camry)', ctrl: _modelCtrl,
              prefix: const Icon(Icons.directions_car_rounded, color: C.muted, size: 20)),
            const SizedBox(height: 12),
            TF(hint: 'Plaque d\'immatriculation', ctrl: _plateCtrl,
              prefix: const Icon(Icons.credit_card_outlined, color: C.muted, size: 20)),
            const SizedBox(height: 12),
            TF(hint: 'Année', ctrl: _yearCtrl, type: TextInputType.number,
              prefix: const Icon(Icons.calendar_today_outlined, color: C.muted, size: 20)),
            const SizedBox(height: 12),
            TF(hint: 'Couleur', ctrl: _colorCtrl,
              prefix: const Icon(Icons.palette_outlined, color: C.muted, size: 20)),

            const SLabel('TYPE DE VÉHICULE'),
            appDrop<String>(
              hint: 'Type de véhicule',
              value: _vType,
              items: kVehicleTypes,
              builder: (e) => Text(e),
              onChanged: (v) => setState(() => _vType = v),
              prefix: const Icon(Icons.category_outlined, color: C.muted, size: 20),
            ),

            const SLabel('LOCALISATION'),
            TF(hint: 'Ville', ctrl: _cityCtrl,
              prefix: const Icon(Icons.location_city_outlined, color: C.muted, size: 20)),
            const SizedBox(height: 12),
            TF(hint: 'Pays', ctrl: _countryCtrl,
              prefix: const Icon(Icons.flag_outlined, color: C.muted, size: 20)),

            const SizedBox(height: 32),
            OBtn(text: 'ENREGISTRER', icon: Icons.save_rounded,
              loading: _saving, onTap: _save),
            const SizedBox(height: 30),
          ]),
        ),
  );
}

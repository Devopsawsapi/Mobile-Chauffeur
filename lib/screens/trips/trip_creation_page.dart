import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_data.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/tt_logo.dart';
import '../../widgets/app_widgets.dart';

class TripCreationPage extends StatefulWidget {
  const TripCreationPage({super.key});
  @override State<TripCreationPage> createState() => _TripState();
}

class _TripState extends State<TripCreationPage> {
  final _fromCtrl = TextEditingController();
  final _toCtrl   = TextEditingController();
  final _prCtrl   = TextEditingController();
  final _seCtrl   = TextEditingController(text: '3');
  final _exCtrl   = TextEditingController();
  int _bags = 1; bool _extra = false, _loading = false;
  String? _vType;
  String _depDate = '';
  TimeOfDay? _depTime;             // ✅ heure de départ

  // ✅ Convertit DD/MM/YYYY → YYYY-MM-DD pour Laravel
  String _convertDate(String d) {
    if (d.isEmpty) return '';
    final p = d.split('/');
    if (p.length != 3) return d;
    return '${p[2]}-${p[1]}-${p[0]}';
  }

  // ✅ Formate l'heure en HH:mm
  String _formatTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ✅ Sélection de l'heure
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _depTime ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: C.orange)),
        child: child!),
    );
    if (picked != null) setState(() => _depTime = picked);
  }

  Future<void> _publish() async {
    if (_fromCtrl.text.isEmpty || _toCtrl.text.isEmpty || _prCtrl.text.isEmpty) {
      snack(context, 'Remplissez départ, destination et prix', error: true); return;
    }
    if (_depDate.isEmpty) {
      snack(context, 'Date de départ obligatoire', error: true); return;
    }
    if (_depTime == null) {
      snack(context, 'Heure de départ obligatoire', error: true); return;
    }

    setState(() => _loading = true);

    final res = await ApiService.post(Api.trips, {
      'departure':         _fromCtrl.text.trim(),
      'destination':       _toCtrl.text.trim(),
      'price_per_seat':    double.tryParse(_prCtrl.text) ?? 0,
      'available_seats':   int.tryParse(_seCtrl.text)    ?? 3,
      'departure_date':    _convertDate(_depDate),         // ✅ YYYY-MM-DD
      'departure_time':    _formatTime(_depTime!),         // ✅ HH:mm
      'luggage_included':  _bags,
      'extra_luggage_fee': _extra ? (double.tryParse(_exCtrl.text) ?? 0) : 0,
      'vehicle_type':      _vType ?? '',
    });

    setState(() => _loading = false);
    if (!mounted) return;

    snack(context,
      res['success']==true ? '✅ Trajet publié !' : res['message'] ?? 'Erreur',
      error: res['success'] != true);

    if (res['success']==true) {
      _fromCtrl.clear();
      _toCtrl.clear();
      _prCtrl.clear();
      setState(() {
        _depDate = '';
        _depTime = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(backgroundColor: C.card, elevation: 0,
      title: Row(children: [
        const TTIconLogo(size: 34, glow: false), const SizedBox(width: 10),
        const TTTextLogo(fontSize: 18), const SizedBox(width: 8),
        const Text('· Créer un trajet', style: TextStyle(color: C.muted, fontSize: 13))]),
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border))),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        const SLabel('ITINÉRAIRE'),
        TF(hint: 'Lieu de départ', ctrl: _fromCtrl,
          prefix: const Icon(Icons.my_location_rounded, color: C.blue, size: 20)),
        const SizedBox(height: 8),
        const Center(child: Icon(Icons.swap_vert_rounded, color: C.border, size: 24)),
        const SizedBox(height: 8),
        TF(hint: 'Destination', ctrl: _toCtrl,
          prefix: const Icon(Icons.location_on_rounded, color: C.orange, size: 20)),

        const SLabel('DATE & HEURE DE DÉPART'),

        // ── Date de départ
        datePicker(context, 'Choisir la date *', _depDate,
          () => pickDate(context, (d) => setState(() => _depDate = d))),

        const SizedBox(height: 12),

        // ✅ Heure de départ
        GestureDetector(
          onTap: _pickTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: C.surface,
              border: Border.all(
                color: _depTime != null ? C.orange : C.border),
              borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(Icons.access_time_rounded,
                color: _depTime != null ? C.orange : C.muted, size: 18),
              const SizedBox(width: 12),
              Expanded(child: Text(
                _depTime != null
                  ? 'Départ à ${_formatTime(_depTime!)}'
                  : 'Choisir l\'heure de départ *',
                style: TextStyle(
                  color: _depTime != null ? C.text : C.muted,
                  fontSize: 14))),
              if (_depTime != null)
                const Icon(Icons.check_circle, color: C.orange, size: 18),
            ]),
          ),
        ),

        const SLabel('TARIFICATION'),
        TF(hint: 'Prix par passager (FCFA)', ctrl: _prCtrl, type: TextInputType.number,
          prefix: const Icon(Icons.attach_money_rounded, color: C.muted, size: 20)),
        const SizedBox(height: 14),
        TF(hint: 'Nombre de places', ctrl: _seCtrl, type: TextInputType.number,
          prefix: const Icon(Icons.people_outline_rounded, color: C.muted, size: 20)),

        const SLabel('BAGAGES'),
        Row(children: [
          const Text('Bagages inclus :', style: TextStyle(color: C.muted, fontSize: 14)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: C.muted),
            onPressed: () => setState(() { if (_bags > 0) _bags--; })),
          Text('$_bags', style: const TextStyle(
            color: C.text, fontSize: 18, fontWeight: FontWeight.w700)),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: C.orange),
            onPressed: () => setState(() => _bags++)),
        ]),
        Row(children: [
          Switch(value: _extra, activeColor: C.orange,
            onChanged: (v) => setState(() => _extra = v)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Facturer les bagages excédentaires',
            style: TextStyle(color: C.text, fontSize: 14))),
        ]),
        if (_extra) ...[
          const SizedBox(height: 10),
          TF(hint: 'Prix bagage excédentaire (FCFA)', ctrl: _exCtrl,
            type: TextInputType.number,
            prefix: const Icon(Icons.luggage, color: C.muted, size: 20)),
        ],

        const SLabel('TYPE DE VÉHICULE'),
        appDrop<String>(hint: 'Type', value: _vType, items: kVehicleTypes,
          builder: (e) => Text(e), onChanged: (v) => setState(() => _vType = v),
          prefix: const Icon(Icons.category_outlined, color: C.muted, size: 20)),

        const SizedBox(height: 32),
        OBtn(text: 'PUBLIER LE TRAJET', icon: Icons.publish_rounded,
          loading: _loading, onTap: _publish),
        const SizedBox(height: 30),
      ])));
}
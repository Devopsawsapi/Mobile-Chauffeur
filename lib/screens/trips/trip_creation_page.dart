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

  // ── Contrôleurs ──────────────────────────────────────────────────────────
  final _fromCtrl        = TextEditingController();   // Ville de départ
  final _pickupCtrl      = TextEditingController();   // Lieu précis d'embarquement
  final _toCtrl          = TextEditingController();   // Destination
  final _dropoffCtrl     = TextEditingController();   // Lieu précis de dépose
  final _prCtrl          = TextEditingController();   // Prix par passager
  final _seCtrl          = TextEditingController(text: '3'); // Nb places
  final _lugKgCtrl       = TextEditingController(text: '20'); // Poids max inclus (kg)
  final _extraKgCtrl     = TextEditingController();   // Prix bagage excédentaire (FCFA/kg)
  final _extraSlotsCtrl  = TextEditingController(text: '0'); // Nb bagages suppl. autorisés

  int      _bagsIncluded = 1;      // Nombre de bagages inclus
  bool     _extra        = false;  // Facturer bagages excédentaires ?
  bool     _loading      = false;
  String?  _vType;
  String   _depDate      = '';
  TimeOfDay? _depTime;

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _convertDate(String d) {
    if (d.isEmpty) return '';
    final p = d.split('/');
    return p.length == 3 ? '${p[2]}-${p[1]}-${p[0]}' : d;
  }

  String _formatTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:00';

  double get _totalAmount =>
    (double.tryParse(_prCtrl.text) ?? 0) * (int.tryParse(_seCtrl.text) ?? 0);

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

  // ── Validation & envoi ───────────────────────────────────────────────────
  Future<void> _publish() async {
    if (_fromCtrl.text.isEmpty || _toCtrl.text.isEmpty) {
      snack(context, 'Remplissez le départ et la destination', error: true); return;
    }
    if (_pickupCtrl.text.isEmpty) {
      snack(context, 'Précisez le lieu exact d\'embarquement', error: true); return;
    }
    if (_prCtrl.text.isEmpty) {
      snack(context, 'Renseignez le prix par passager', error: true); return;
    }
    if (_depDate.isEmpty) {
      snack(context, 'Date de départ obligatoire', error: true); return;
    }
    if (_depTime == null) {
      snack(context, 'Heure de départ obligatoire', error: true); return;
    }

    setState(() => _loading = true);

    final price     = double.tryParse(_prCtrl.text) ?? 0;
    final seats     = int.tryParse(_seCtrl.text) ?? 3;
    final lugKg     = int.tryParse(_lugKgCtrl.text) ?? 20;
    final extraFee  = _extra ? (double.tryParse(_extraKgCtrl.text) ?? 0) : 0;
    final extraSlots = _extra ? (int.tryParse(_extraSlotsCtrl.text) ?? 0) : 0;

    final res = await ApiService.post(Api.trips, {
      // ── Itinéraire ──
      'pickup_address':    _fromCtrl.text.trim(),
      'dropoff_address':   _toCtrl.text.trim(),
      'departure':         _fromCtrl.text.trim(),
      'destination':       _toCtrl.text.trim(),
      // ── Lieu précis ──
      'pickup_point':      _pickupCtrl.text.trim(),   // ex: "Marché Total, face pharmacie"
      'dropoff_point':     _dropoffCtrl.text.trim(),
      // ── Tarification ──
      'price_per_seat':    price,
      'amount':            price * seats,             // montant total calculé
      'available_seats':   seats,
      // ── Date & heure ──
      'departure_date':    _convertDate(_depDate),
      'departure_time':    _formatTime(_depTime!),
      // ── Bagages inclus ──
      'luggage_included':  _bagsIncluded,
      'luggage_kg':        _bagsIncluded,
      'luggage_weight_kg': lugKg,                     // poids max par bagage
      // ── Bagages excédentaires ──
      'extra_luggage_fee':   extraFee,
      'extra_luggage_slots': extraSlots,              // nb supplémentaires autorisés
      // ── Véhicule ──
      'vehicle_type':      _vType ?? 'Confort',
    });

    setState(() => _loading = false);
    if (!mounted) return;

    snack(context,
      res['success'] == true ? '✅ Trajet publié avec succès !' : res['message'] ?? 'Erreur',
      error: res['success'] != true);

    if (res['success'] == true) _resetForm();
  }

  void _resetForm() {
    _fromCtrl.clear(); _pickupCtrl.clear();
    _toCtrl.clear();   _dropoffCtrl.clear();
    _prCtrl.clear();   _extraKgCtrl.clear();
    _seCtrl.text = '3'; _lugKgCtrl.text = '20'; _extraSlotsCtrl.text = '0';
    setState(() {
      _depDate = ''; _depTime = null;
      _bagsIncluded = 1; _extra = false; _vType = null;
    });
  }

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(
      backgroundColor: C.card, elevation: 0,
      title: Row(children: [
        const TTIconLogo(size: 34, glow: false), const SizedBox(width: 10),
        const TTTextLogo(fontSize: 18), const SizedBox(width: 8),
        const Text('· Créer un trajet', style: TextStyle(color: C.muted, fontSize: 13)),
      ]),
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border))),

    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ════════════════════════════════════════════════════════
        // 1. ITINÉRAIRE
        // ════════════════════════════════════════════════════════
        const SLabel('ITINÉRAIRE'),

        TF(hint: 'Ville de départ', ctrl: _fromCtrl,
          prefix: const Icon(Icons.my_location_rounded, color: C.blue, size: 20)),
        const SizedBox(height: 8),

        // Lieu précis d'embarquement
        TF(hint: 'Lieu exact d\'embarquement (rue, repère…)', ctrl: _pickupCtrl,
          prefix: const Icon(Icons.place_rounded, color: C.blue, size: 20)),
        _hint('Ex : Marché Total, face pharmacie Centrale'),

        const SizedBox(height: 8),
        const Center(child: Icon(Icons.swap_vert_rounded, color: C.border, size: 24)),
        const SizedBox(height: 8),

        TF(hint: 'Ville de destination', ctrl: _toCtrl,
          prefix: const Icon(Icons.location_on_rounded, color: C.orange, size: 20)),
        const SizedBox(height: 8),

        // Lieu précis de dépose (optionnel)
        TF(hint: 'Lieu de dépose (optionnel)', ctrl: _dropoffCtrl,
          prefix: const Icon(Icons.flag_rounded, color: C.orange, size: 20)),
        _hint('Ex : Gare routière, centre-ville Oyo'),

        // ════════════════════════════════════════════════════════
        // 2. DATE & HEURE
        // ════════════════════════════════════════════════════════
        const SLabel('DATE & HEURE DE DÉPART'),

        datePicker(context, 'Choisir la date *', _depDate,
          () => pickDate(context, (d) => setState(() => _depDate = d),
            firstDate: DateTime.now())),

        const SizedBox(height: 12),

        GestureDetector(
          onTap: _pickTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: C.surface,
              border: Border.all(color: _depTime != null ? C.orange : C.border),
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
                  color: _depTime != null ? C.text : C.muted, fontSize: 14))),
              if (_depTime != null)
                const Icon(Icons.check_circle, color: C.orange, size: 18),
            ]),
          ),
        ),

        // ════════════════════════════════════════════════════════
        // 3. TARIFICATION
        // ════════════════════════════════════════════════════════
        const SLabel('TARIFICATION'),

        TF(hint: 'Prix par passager (FCFA)', ctrl: _prCtrl,
          type: TextInputType.number,
          prefix: const Icon(Icons.attach_money_rounded, color: C.muted, size: 20),
          onChange: (_) => setState(() {})),

        const SizedBox(height: 12),

        TF(hint: 'Nombre de places disponibles', ctrl: _seCtrl,
          type: TextInputType.number,
          prefix: const Icon(Icons.people_outline_rounded, color: C.muted, size: 20),
          onChange: (_) => setState(() {})),

        // ── Récapitulatif montant total ──────────────────────────
        if (_totalAmount > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [C.orange.withOpacity(0.15), C.orange.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.orange.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.calculate_rounded, color: C.orange, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Montant total estimé',
                  style: TextStyle(color: C.muted, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  '${_totalAmount.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    color: C.orange, fontSize: 20, fontWeight: FontWeight.w900)),
                Text(
                  '${_prCtrl.text.isEmpty ? "0" : _prCtrl.text} FCFA × '
                  '${_seCtrl.text.isEmpty ? "0" : _seCtrl.text} places',
                  style: const TextStyle(color: C.muted, fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: C.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '${_seCtrl.text.isEmpty ? "0" : _seCtrl.text} places',
                  style: const TextStyle(
                    color: C.orange, fontSize: 12, fontWeight: FontWeight.w700))),
            ])),
        ],

        // ════════════════════════════════════════════════════════
        // 4. BAGAGES
        // ════════════════════════════════════════════════════════
        const SLabel('BAGAGES'),

        // Nombre de bagages inclus
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: C.surface,
            border: Border.all(color: C.border),
            borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.luggage, color: C.muted, size: 18),
              const SizedBox(width: 10),
              const Expanded(child: Text('Bagages inclus par passager',
                style: TextStyle(color: C.text, fontSize: 13))),
              _counterBtn(Icons.remove_rounded, () {
                if (_bagsIncluded > 0) setState(() => _bagsIncluded--);
              }),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('$_bagsIncluded',
                  style: const TextStyle(
                    color: C.text, fontSize: 18, fontWeight: FontWeight.w800))),
              _counterBtn(Icons.add_rounded, () => setState(() => _bagsIncluded++),
                filled: true),
            ]),
          ])),

        const SizedBox(height: 12),

        // Poids max par bagage (kg)
        TF(
          hint: 'Poids max par bagage inclus (kg)',
          ctrl: _lugKgCtrl,
          type: TextInputType.number,
          prefix: const Icon(Icons.monitor_weight_outlined, color: C.muted, size: 20)),
        _hint('Ex : 20 kg par bagage inclus'),

        const SizedBox(height: 14),

        // Switch : bagages excédentaires
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _extra ? C.orange.withOpacity(0.07) : C.surface,
            border: Border.all(
              color: _extra ? C.orange.withOpacity(0.4) : C.border),
            borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.add_box_outlined, color: C.muted, size: 18),
            const SizedBox(width: 10),
            const Expanded(child: Text('Accepter les bagages excédentaires',
              style: TextStyle(color: C.text, fontSize: 13))),
            Switch(value: _extra, activeColor: C.orange,
              onChanged: (v) => setState(() => _extra = v)),
          ])),

        if (_extra) ...[
          const SizedBox(height: 12),

          // Nombre de places bagages supplémentaires
          TF(
            hint: 'Nb de bagages suppl. autorisés',
            ctrl: _extraSlotsCtrl,
            type: TextInputType.number,
            prefix: const Icon(Icons.inventory_2_outlined, color: C.orange, size: 20)),
          _hint('Ex : 3 bagages supplémentaires au total'),

          const SizedBox(height: 10),

          // Prix par kg excédentaire
          TF(
            hint: 'Prix par kg excédentaire (FCFA/kg)',
            ctrl: _extraKgCtrl,
            type: TextInputType.number,
            prefix: const Icon(Icons.price_change_outlined, color: C.orange, size: 20)),
          _hint('Ex : 500 FCFA par kg au-delà du poids inclus'),

          // Récap bagages
          if ((_extraKgCtrl.text.isNotEmpty && double.tryParse(_extraKgCtrl.text) != null) ||
              (_extraSlotsCtrl.text.isNotEmpty && int.tryParse(_extraSlotsCtrl.text) != null)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.orange.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.orange.withOpacity(0.25))),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: C.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '${_extraSlotsCtrl.text.isNotEmpty ? "${_extraSlotsCtrl.text} bagage(s) suppl. " : ""}'
                  '${_extraKgCtrl.text.isNotEmpty ? "· ${_extraKgCtrl.text} FCFA/kg" : ""}',
                  style: const TextStyle(color: C.orange, fontSize: 12, fontWeight: FontWeight.w600))),
              ])),
          ],
        ],

        // ════════════════════════════════════════════════════════
        // 5. TYPE DE VÉHICULE
        // ════════════════════════════════════════════════════════
        const SLabel('TYPE DE VÉHICULE'),
        appDrop<String>(
          hint: 'Sélectionner le type',
          value: _vType,
          items: kVehicleTypes,
          builder: (e) => Text(e),
          onChanged: (v) => setState(() => _vType = v),
          prefix: const Icon(Icons.directions_car_outlined, color: C.muted, size: 20)),

        // ════════════════════════════════════════════════════════
        // 6. RÉCAPITULATIF FINAL
        // ════════════════════════════════════════════════════════
        if (_fromCtrl.text.isNotEmpty && _toCtrl.text.isNotEmpty &&
            _depDate.isNotEmpty && _depTime != null && _prCtrl.text.isNotEmpty) ...[
          const SLabel('RÉCAPITULATIF'),
          _recapCard(),
        ],

        const SizedBox(height: 24),
        OBtn(
          text: 'PUBLIER LE TRAJET',
          icon: Icons.publish_rounded,
          loading: _loading,
          onTap: _publish),
        const SizedBox(height: 30),
      ])),
  );

  // ── Récapitulatif avant publication ──────────────────────────────────────
  Widget _recapCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: C.card,
      border: Border.all(color: C.border),
      borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Itinéraire
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          const Icon(Icons.my_location_rounded, color: C.blue, size: 14),
          Container(width: 1, height: 20, color: C.border),
          const Icon(Icons.location_on_rounded, color: C.orange, size: 14),
        ]),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_fromCtrl.text,
            style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 13)),
          if (_pickupCtrl.text.isNotEmpty)
            Text(_pickupCtrl.text,
              style: const TextStyle(color: C.muted, fontSize: 11)),
          const SizedBox(height: 8),
          Text(_toCtrl.text,
            style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 13)),
          if (_dropoffCtrl.text.isNotEmpty)
            Text(_dropoffCtrl.text,
              style: const TextStyle(color: C.muted, fontSize: 11)),
        ])),
      ]),

      const SizedBox(height: 12),
      const Divider(height: 1, color: C.border),
      const SizedBox(height: 12),

      // Infos
      Wrap(spacing: 8, runSpacing: 8, children: [
        _tag(Icons.calendar_today_rounded, C.muted,    _depDate),
        _tag(Icons.access_time_rounded,    C.blue,     _depTime != null ? _formatTime(_depTime!) : ''),
        _tag(Icons.attach_money_rounded,   C.orange,   '${_prCtrl.text} FCFA/place'),
        _tag(Icons.people_outline_rounded, C.muted,    '${_seCtrl.text} places'),
        _tag(Icons.luggage,                C.muted,    '$_bagsIncluded bag · ${_lugKgCtrl.text}kg'),
        if (_extra && _extraKgCtrl.text.isNotEmpty)
          _tag(Icons.add_box_outlined,     C.orange,
            '${_extraSlotsCtrl.text} suppl · ${_extraKgCtrl.text}F/kg'),
        if (_vType != null)
          _tag(Icons.directions_car,       C.muted,    _vType!),
      ]),
    ]));

  Widget _tag(IconData icon, Color color, String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]));
  }

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(top: 4, left: 16, bottom: 2),
    child: Text(text, style: const TextStyle(color: C.muted, fontSize: 10)));

  Widget _counterBtn(IconData icon, VoidCallback onTap, {bool filled = false}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? C.orange : Colors.transparent,
          border: Border.all(color: C.orange, width: 1.5)),
        child: Icon(icon, size: 16,
          color: filled ? Colors.white : C.orange)));
}

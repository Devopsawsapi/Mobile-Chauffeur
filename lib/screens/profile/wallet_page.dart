import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_data.dart';
import '../../core/models/country_model.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/tt_logo.dart';
import '../../widgets/app_widgets.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});
  @override State<WalletPage> createState() => _WalletState();
}

class _WalletState extends State<WalletPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _amCtrl  = TextEditingController();
  final _numCtrl = TextEditingController();
  String? _operator, _cardType; Country? _country;
  double _balance = 0; bool _loadWallet = true, _loadWithdraw = false;

  @override void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); _load(); }
  @override void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loadWallet = true);
    final res = await ApiService.get(Api.wallet);
    setState(() {
      _loadWallet = false;
      if (res['success'] == true) {
        final w = res['wallet'] ?? res['data'] ?? res;
        _balance = double.tryParse('${w['balance'] ?? 0}') ?? 0;
      }
    });
  }

  Future<void> _withdraw(String method, Map<String, dynamic> extra) async {
    final amount = double.tryParse(_amCtrl.text);
    if (amount == null || amount <= 0) { snack(context, 'Montant invalide', error: true); return; }
    final min = method == 'mobile_money' ? 5000.0 : 10000.0;
    if (amount < min) { snack(context, 'Minimum ${min.toInt()} FCFA', error: true); return; }

    setState(() => _loadWithdraw = true);
    final res = await ApiService.post(Api.withdrawals, {'method': method, 'amount': amount, ...extra});
    setState(() => _loadWithdraw = false);
    if (!mounted) return;
    if (res['success'] == true) {
      snack(context, '✅ Retrait lancé !');
      _amCtrl.clear(); _numCtrl.clear();
      _load();
    } else {
      snack(context, res['message'] ?? 'Erreur', error: true);
    }
  }

  void _confirm(String method) {
    final extra = method == 'mobile_money'
      ? {'operator': _operator ?? '', 'phone': '${_country?.dial ?? ""}${_numCtrl.text.trim()}', 'country_code': _country?.code ?? ''}
      : {'card_type': _cardType ?? '', 'card_number': _numCtrl.text.trim()};
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: C.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        TTIconLogo(size: 36, glow: false), SizedBox(width: 10),
        Text('Confirmer le retrait', style: TextStyle(color: C.text, fontWeight: FontWeight.w700))]),
      content: Text(
        'Retrait de ${_amCtrl.text} FCFA via ${method=="mobile_money" ? "Mobile Money" : "Carte $_cardType"} ?',
        style: const TextStyle(color: C.muted, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: C.muted))),
        GestureDetector(
          onTap: () { Navigator.pop(context); _withdraw(method, extra); },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [C.orange, Color(0xFFE8921A)]),
              borderRadius: BorderRadius.circular(10)),
            child: const Text('Confirmer',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))),
      ]));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(backgroundColor: C.card, elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: C.text),
        onPressed: () => Navigator.pop(context)),
      title: Row(children: [
        const TTIconLogo(size: 34, glow: false), const SizedBox(width: 10),
        const TTTextLogo(fontSize: 18), const SizedBox(width: 8),
        const Text('· Mon Wallet', style: TextStyle(color: C.muted, fontSize: 13))]),
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: C.orange), onPressed: _load)],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border))),
    body: Column(children: [
      // Carte solde
      Container(margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0E1F32), Color(0xFF091729)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: C.orange.withOpacity(0.35)),
          boxShadow: [BoxShadow(color: C.orange.withOpacity(0.2), blurRadius: 28, offset: const Offset(0, 8))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const TTTextLogo(fontSize: 20), const Spacer(), const TTIconLogo(size: 44, glow: false)]),
          const SizedBox(height: 20),
          const Text('Solde disponible', style: TextStyle(color: C.muted, fontSize: 12)),
          const SizedBox(height: 6),
          _loadWallet
            ? const SizedBox(height: 36,
                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(C.orange)))
            : Text('${_balance.toStringAsFixed(0)} FCFA',
                style: const TextStyle(color: C.text, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const Text('Solde en temps réel', style: TextStyle(color: C.muted, fontSize: 11)),
        ])),

      // Onglets
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14)),
          child: TabBar(controller: _tab,
            indicator: BoxDecoration(
              gradient: const LinearGradient(colors: [C.orange, Color(0xFFE8921A)]),
              borderRadius: BorderRadius.circular(12)),
            dividerColor: Colors.transparent, padding: const EdgeInsets.all(4),
            labelColor: Colors.white, unselectedLabelColor: C.muted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: const [Tab(text: '📱 Mobile Money'), Tab(text: '💳 Carte Bancaire')]))),
      const SizedBox(height: 4),

      Expanded(child: TabBarView(controller: _tab, children: [
        // Mobile Money
        SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(children: [
            const SLabel('RETRAIT MOBILE MONEY'),
            appDrop<Country>(hint: 'Pays *', value: _country, items: kCountries,
              builder: (c) => Text('${c.flag}  ${c.name}'),
              onChanged: (v) => setState(() { _country = v; _operator = null; }),
              prefix: const Icon(Icons.public_outlined, color: C.muted, size: 20)),
            if (_country != null) ...[
              const SizedBox(height: 14),
              appDrop<String>(hint: 'Opérateur Mobile *', value: _operator,
                items: _country!.operators, builder: (e) => Text(e),
                onChanged: (v) => setState(() => _operator = v),
                prefix: const Icon(Icons.sim_card_outlined, color: C.muted, size: 20)),
            ],
            const SizedBox(height: 14),
            Row(children: [
              if (_country != null)
                Container(margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(color: C.surface,
                    borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
                  child: Text('${_country!.flag} ${_country!.dial}',
                    style: const TextStyle(color: C.text, fontSize: 14))),
              Expanded(child: TF(hint: '6XX XX XX XX', label: 'Numéro Mobile *',
                ctrl: _numCtrl, type: TextInputType.phone,
                prefix: const Icon(Icons.phone, color: C.muted, size: 20))),
            ]),
            const SizedBox(height: 14),
            TF(hint: 'Ex: 10000', label: 'Montant à retirer (FCFA) *',
              ctrl: _amCtrl, type: TextInputType.number,
              prefix: const Icon(Icons.attach_money_rounded, color: C.muted, size: 20)),
            const SizedBox(height: 6),
            const Text('Minimum : 5 000 FCFA  ·  Commission : 1%',
              style: TextStyle(color: C.muted, fontSize: 11)),
            const SizedBox(height: 24),
            OBtn(text: 'RETIRER VIA MOBILE MONEY', icon: Icons.send_to_mobile_rounded,
              loading: _loadWithdraw, onTap: () => _confirm('mobile_money')),
            const SizedBox(height: 20),
          ])),

        // Carte Bancaire
        SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(children: [
            const SLabel('RETRAIT CARTE BANCAIRE'),
            Row(children: [
              Expanded(child: _cBtn('Visa',       '💳 Visa')),
              const SizedBox(width: 12),
              Expanded(child: _cBtn('Mastercard', '💳 Mastercard')),
            ]),
            const SizedBox(height: 14),
            TF(hint: '1234 5678 9012 3456', label: 'Numéro de carte *',
              ctrl: _numCtrl, type: TextInputType.number,
              prefix: const Icon(Icons.credit_card, color: C.muted, size: 20)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TF(hint: 'MM/AA', label: 'Expiration', ctrl: TextEditingController())),
              const SizedBox(width: 12),
              Expanded(child: TF(hint: '•••', label: 'CVV', ctrl: TextEditingController(), obscure: true)),
            ]),
            const SizedBox(height: 14),
            TF(hint: 'Ex: 20000', label: 'Montant à retirer (FCFA) *',
              ctrl: _amCtrl, type: TextInputType.number,
              prefix: const Icon(Icons.attach_money_rounded, color: C.muted, size: 20)),
            const SizedBox(height: 6),
            const Text('Minimum : 10 000 FCFA  ·  Commission : 2.5%',
              style: TextStyle(color: C.muted, fontSize: 11)),
            const SizedBox(height: 24),
            OBtn(text: 'RETIRER VIA CARTE', icon: Icons.credit_card_rounded,
              loading: _loadWithdraw, onTap: () => _confirm('card')),
            const SizedBox(height: 20),
          ])),
      ])),
    ]));

  Widget _cBtn(String v, String label) {
    final sel = _cardType == v;
    return GestureDetector(onTap: () => setState(() => _cardType = v),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? C.orange.withOpacity(0.12) : C.surface,
          border: Border.all(color: sel ? C.orange : C.border, width: sel ? 2 : 1),
          borderRadius: BorderRadius.circular(14)),
        child: Center(child: Text(label,
          style: TextStyle(color: sel ? C.orange : C.muted, fontWeight: FontWeight.w600)))));
  }
}

import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/app_data.dart';
import '../models/country_model.dart';

void snack(BuildContext ctx, String msg, {bool error = false}) =>
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? C.error : C.success,
    duration: const Duration(seconds: 3)));

Future<void> pickDate(
  BuildContext ctx,
  void Function(String) cb, {
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final d = await showDatePicker(
    context: ctx,
    initialDate: DateTime.now(),
    firstDate: firstDate ?? DateTime(1950),
    lastDate:  lastDate  ?? DateTime(2045),
    builder: (_, child) => Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: C.orange, onSurface: C.text)),
      child: child!),
  );
  if (d != null) {
    cb('${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}');
  }
}

void showCountryPicker(BuildContext ctx, void Function(Country) onSelect) =>
  showModalBottomSheet(
    context: ctx,
    backgroundColor: C.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.65, maxChildSize: 0.92, minChildSize: 0.4, expand: false,
      builder: (_, scroll) => Column(children: [
        const SizedBox(height: 10),
        Container(width: 36, height: 4,
          decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        const Text('Choisir un pays',
          style: TextStyle(color: C.text, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Expanded(child: ListView.builder(
          controller: scroll, itemCount: kCountries.length,
          itemBuilder: (_, i) {
            final c = kCountries[i];
            return ListTile(
              leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
              title:    Text(c.name, style: const TextStyle(color: C.text, fontSize: 14)),
              subtitle: Text(c.dial, style: const TextStyle(color: C.muted, fontSize: 12)),
              onTap: () { Navigator.pop(ctx); onSelect(c); },
            );
          })),
      ]),
    ));

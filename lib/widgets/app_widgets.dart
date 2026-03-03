import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants/colors.dart';

// ── Bouton principal
class OBtn extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool loading;
  final IconData? icon;
  final List<Color> colors;
  const OBtn({
    super.key, required this.text, required this.onTap,
    this.loading = false, this.icon,
    this.colors = const [Color(0xFFF5A623), Color(0xFFE8921A)],
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      width: double.infinity, height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: loading ? [C.muted, C.muted] : colors),
        borderRadius: BorderRadius.circular(16),
        boxShadow: loading ? [] : [
          BoxShadow(color: colors.first.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6))
        ]),
      child: loading
        ? const Center(child: SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
    ),
  );
}

// ── Champ texte
class TF extends StatelessWidget {
  final String hint;
  final TextEditingController? ctrl;
  final Widget? prefix, suffix;
  final bool obscure;
  final TextInputType? type;
  final String? Function(String?)? validator;
  final void Function(String)? onChange;
  final int maxLines;
  final String? label;
  final int? maxLength;
  final List<dynamic>? inputFormatters;

  const TF({
    super.key, required this.hint, this.ctrl, this.prefix, this.suffix,
    this.obscure = false, this.type, this.validator, this.onChange,
    this.maxLines = 1, this.label, this.maxLength, this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    obscureText: obscure,
    keyboardType: type,
    validator: validator,
    onChanged: onChange,
    maxLines: maxLines,
    maxLength: maxLength,
    style: const TextStyle(color: C.text, fontSize: 15),
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      prefixIcon: prefix, suffixIcon: suffix,
      counterText: '',
    ),
  );
}

// ── Label de section
class SLabel extends StatelessWidget {
  final String text;
  final Color color;
  const SLabel(this.text, {super.key, this.color = C.blue});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(text, style: TextStyle(
      color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
  );
}

// ── Dropdown générique
DropdownButtonFormField<T> appDrop<T>({
  required String hint,
  required T? value,
  required List<T> items,
  required Widget Function(T) builder,
  required void Function(T?) onChanged,
  Widget? prefix,
}) => DropdownButtonFormField<T>(
  value: value, onChanged: onChanged, dropdownColor: C.surface,
  style: const TextStyle(color: C.text, fontSize: 15),
  decoration: InputDecoration(hintText: hint, prefixIcon: prefix),
  items: items.map((e) => DropdownMenuItem(value: e, child: builder(e))).toList(),
);

// ── Sélecteur de date
Widget datePicker(BuildContext ctx, String hint, String val, VoidCallback onTap) =>
  GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: C.surface,
        border: Border.all(color: val.isEmpty ? C.border : C.orange),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.calendar_today_outlined,
          color: val.isEmpty ? C.muted : C.orange, size: 18),
        const SizedBox(width: 12),
        Expanded(child: Text(val.isEmpty ? hint : val,
          style: TextStyle(color: val.isEmpty ? C.muted : C.text, fontSize: 14))),
        if (val.isNotEmpty) const Icon(Icons.check_circle, color: C.orange, size: 18),
      ]),
    ));

// ── Box photo RÉELLE avec image_picker
class PhotoBox extends StatefulWidget {
  final String label;
  final IconData icon;
  final void Function(File?)? onImageSelected;

  const PhotoBox({
    super.key,
    required this.label,
    required this.icon,
    this.onImageSelected,
  });

  @override
  State<PhotoBox> createState() => _PBState();
}

class _PBState extends State<PhotoBox> {
  File? _image;
  final _picker = ImagePicker();

  Future<void> _pick() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: C.border,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: C.orange),
            title: const Text('Prendre une photo',
              style: TextStyle(color: C.text)),
            onTap: () async {
              Navigator.pop(context);
              final f = await _picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 80);
              if (f != null) _setImage(File(f.path));
            }),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: C.orange),
            title: const Text('Choisir depuis la galerie',
              style: TextStyle(color: C.text)),
            onTap: () async {
              Navigator.pop(context);
              final f = await _picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 80);
              if (f != null) _setImage(File(f.path));
            }),
          if (_image != null) ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _setImage(null);
            }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _setImage(File? f) {
    setState(() => _image = f);
    widget.onImageSelected?.call(f);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _pick,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220), height: 110,
      decoration: BoxDecoration(
        color: _image != null ? C.orange.withOpacity(0.08) : C.surface,
        border: Border.all(
          color: _image != null ? C.orange : C.border,
          width: _image != null ? 2 : 1),
        borderRadius: BorderRadius.circular(14)),
      child: _image != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(fit: StackFit.expand, children: [
              Image.file(_image!, fit: BoxFit.cover),
              Container(color: Colors.black.withOpacity(0.25)),
              const Center(child: Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 32)),
            ]))
        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(widget.icon, color: C.muted, size: 28),
            const SizedBox(height: 8),
            Text(widget.label,
              style: const TextStyle(color: C.muted, fontSize: 11,
                fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
            const SizedBox(height: 4),
            const Text('Appuyer pour ajouter',
              style: TextStyle(color: C.orange, fontSize: 10,
                fontWeight: FontWeight.w600)),
          ]),
    ));
}

// ── Barre de saisie message
Widget inputBar(
  TextEditingController ctrl,
  VoidCallback onSend, {
  Color btnColor = C.orange,
  bool sending = false,
}) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: C.card,
    border: Border(top: BorderSide(color: C.border))),
  child: Row(children: [
    Expanded(child: TextField(
      controller: ctrl,
      style: const TextStyle(color: C.text),
      decoration: InputDecoration(
        hintText: 'Votre message...',
        hintStyle: const TextStyle(color: C.muted),
        filled: true, fillColor: C.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none)))),
    const SizedBox(width: 10),
    GestureDetector(
      onTap: sending ? null : onSend,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: sending ? C.muted : btnColor, shape: BoxShape.circle),
        child: sending
          ? const Center(child: SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
          : const Icon(Icons.send_rounded, color: Colors.white, size: 20))),
  ]));
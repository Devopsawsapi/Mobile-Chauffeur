import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String? _token;

  static Future<void> saveToken(String token) async {
    _token = token;
    final p = await SharedPreferences.getInstance();
    await p.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    final p = await SharedPreferences.getInstance();
    _token = p.getString('auth_token');
    return _token;
  }

  static Future<void> clearToken() async {
    _token = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('auth_token');
    await p.remove('driver_cache');
  }

  static Future<Map<String, String>> _headers() async {
    final t = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  static Future<Map<String, dynamic>> get(String url) async {
    try {
      final r = await http.get(Uri.parse(url), headers: await _headers())
          .timeout(const Duration(seconds: 30));
      return _parse(r);
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body) async {
    try {
      final r = await http.post(Uri.parse(url),
          headers: await _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      return _parse(r);
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> put(String url, Map<String, dynamic> body) async {
    try {
      final r = await http.put(Uri.parse(url),
          headers: await _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      return _parse(r);
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  static Future<Map<String, dynamic>> delete(String url) async {
    try {
      final r = await http.delete(Uri.parse(url), headers: await _headers())
          .timeout(const Duration(seconds: 30));
      return _parse(r);
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  // ✅ AJOUTÉ — envoi multipart (texte + fichiers images)
  static Future<Map<String, dynamic>> postMultipart(
    String url,
    Map<String, String> fields, {
    Map<String, File> files = const {},
  }) async {
    try {
      final t = await getToken();
      final request = http.MultipartRequest('POST', Uri.parse(url));

      // Headers
      request.headers.addAll({
        'Accept': 'application/json',
        if (t != null) 'Authorization': 'Bearer $t',
      });

      // Champs texte
      request.fields.addAll(fields);

      // Fichiers images
      for (final entry in files.entries) {
        request.files.add(await http.MultipartFile.fromPath(
          entry.key,
          entry.value.path,
        ));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      return _parse(response);

    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau : $e'};
    }
  }

  static Map<String, dynamic> _parse(http.Response r) {
    try {
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final httpOk   = r.statusCode >= 200 && r.statusCode < 300;
      final statusOk = data['status'] == 'success' || data['status'] == 'ok';
      if (httpOk || statusOk) return {'success': true, ...data};
      return {'success': false, 'message': data['message'] ?? data['error'] ?? 'Erreur ${r.statusCode}', ...data};
    } catch (_) {
      return {'success': false, 'message': 'Réponse invalide du serveur'};
    }
  }
}
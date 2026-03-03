import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class PusherService {

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static PusherChannel? _channel;
  static final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();

  /// INITIALISATION GLOBALE
  static Future<void> init() async {

    // ───────── NOTIFICATIONS ─────────

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(                            // ✅ CORRIGÉ
      initSettings,
      onDidReceiveNotificationResponse: (details) {},
    );


    // ───────── PUSHER ─────────

    await _pusher.init(
      apiKey: 'b936f5c8f1666939a7fa',
      cluster: 'eu',
      onError: (message, code, error) {
        print("Erreur Pusher: $message code: $code erreur: $error");
      },
      onConnectionStateChange: (currentState, previousState) {
        print("Pusher état: $currentState");
      },
    );

    await _pusher.connect();


    // ───────── CHANNEL LARAVEL ─────────

    _channel = await _pusher.subscribe(
      channelName: 'admin-support',
      onEvent: (event) {

        // ───────── EVENEMENT MESSAGE ─────────

        if (event.eventName != 'message.received') return;

        if (event.data == null) return;

        try {

          final data = jsonDecode(event.data);

          final message = data['content'] ?? "Nouveau message";

          _showNotification(message);

        } catch (e) {

          print("Erreur Pusher JSON: $e");

        }
      },
    );
  }



  /// NOTIFICATION LOCALE

  static Future<void> _showNotification(String body) async {

    const androidDetails = AndroidNotificationDetails(
      'support_channel',
      'Support Messages',
      channelDescription: 'Notifications Support TopTopGo',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(                                  // ✅ CORRIGÉ
      0,
      'TopTopGo Support',
      body,
      details,
    );
  }



  /// DECONNEXION

  static Future<void> disconnect() async {

    try {

      await _pusher.unsubscribe(channelName: 'admin-support');

      await _pusher.disconnect();

    } catch (_) {}

  }
}
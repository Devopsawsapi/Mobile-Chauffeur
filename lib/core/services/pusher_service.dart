import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

/// ══════════════════════════════════════════════════════════════════
///  PusherService — App Chauffeur
///  • Notifications : messages client, appels entrants, réservations
///  • Canal chauffeur personnel : driver.{driverId}
///  • Canal support : admin-support
/// ══════════════════════════════════════════════════════════════════
class PusherService {

  static final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();

  static PusherChannel? _supportChannel;
  static PusherChannel? _driverChannel;
  static final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();

  static String? currentDriverId;

  // Callback appel entrant (brancher dans main.dart)
  static void Function({
    required String callerName,
    required String callerPhoto,
    required String callerInitials,
    required String callerId,
  })? onIncomingCall;

  /// INITIALISATION GLOBALE
  static Future<void> init({String? driverId}) async {
    currentDriverId = driverId;

    // ── Notifications locales ──────────────────────────────────────
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _notif.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (d) => debugPrint('Notif tappée: ${d.payload}'),
    );
    final androidPlugin = _notif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    // ── Pusher ─────────────────────────────────────────────────────
    await _pusher.init(
      apiKey: 'b936f5c8f1666939a7fa',
      cluster: 'eu',
      onError: (m, c, e) => debugPrint('Pusher erreur: $m'),
      onConnectionStateChange: (cur, prev) => debugPrint('Pusher: $cur'),
    );
    await _pusher.connect();

    // ── Channel support (admin → chauffeur) ────────────────────────
    _supportChannel = await _pusher.subscribe(
      channelName: 'admin-support',
      onEvent: (event) {
        if (event.eventName != 'message.received' || event.data == null) return;
        try {
          final data = jsonDecode(event.data);
          _show(
            id: 1,
            title: '💬 Support TopTopGo',
            body:  data['content'] ?? 'Nouveau message du support',
            channel: 'support',
          );
        } catch (e) { debugPrint('Pusher support: $e'); }
      },
    );

    // ── Channel chauffeur personnel ────────────────────────────────
    if (driverId != null && driverId.isNotEmpty) {
      await _subscribeDriver(driverId);
    }
  }

  static Future<void> _subscribeDriver(String driverId) async {
    try {
      _driverChannel = await _pusher.subscribe(
        channelName: 'driver.$driverId',
        onEvent: (event) {
          if (event.data == null) return;
          try {
            final data = jsonDecode(event.data);
            switch (event.eventName) {

              // ── Appel entrant (depuis le client) ──
              case 'call.incoming':
                _show(
                  id: 10,
                  title: '📞 Appel entrant',
                  body:  '${data['caller_name'] ?? 'Un client'} vous appelle',
                  channel: 'calls',
                  importance: Importance.max,
                );
                onIncomingCall?.call(
                  callerName:     data['caller_name'] ?? 'Client',
                  callerPhoto:    data['caller_photo'] ?? '',
                  callerInitials: (data['caller_name'] ?? 'C').toString().substring(0, 1).toUpperCase(),
                  callerId:       data['caller_id']?.toString() ?? '',
                );
                break;

              // ── Nouveau message d'un client ──
              case 'message.sent':
              case 'message.received':
                final sType = (data['sender_type'] ?? '').toString();
                if (!sType.contains('Driver')) {
                  _show(
                    id: 2,
                    title: '💬 ${data['client_name'] ?? 'Votre client'}',
                    body:  data['content'] ?? 'Nouveau message',
                    channel: 'messages',
                  );
                }
                break;

              // ── Nouvelle réservation reçue ──
              case 'booking.new':
                _show(
                  id: 3,
                  title: '🆕 Nouvelle réservation',
                  body:  data['message'] ?? 'Un client souhaite réserver votre trajet !',
                  channel: 'bookings',
                  importance: Importance.max,
                );
                break;

              // ── Réservation annulée par le client ──
              case 'booking.cancelled':
                _show(
                  id: 4,
                  title: '❌ Réservation annulée',
                  body:  data['message'] ?? 'Un client a annulé sa réservation.',
                  channel: 'bookings',
                );
                break;

              // ── Paiement reçu ──
              case 'payment.received':
                _show(
                  id: 5,
                  title: '💰 Paiement reçu',
                  body:  data['message'] ?? 'Vous avez reçu un paiement.',
                  channel: 'payments',
                  importance: Importance.max,
                );
                break;

              // ── Notification générique ──
              case 'notification':
                _show(
                  id: 6,
                  title: data['title'] ?? 'TopTopGo',
                  body:  data['body'] ?? data['message'] ?? 'Nouvelle notification',
                  channel: 'general',
                );
                break;
            }
          } catch (e) { debugPrint('Pusher driver JSON: $e'); }
        },
      );
    } catch (e) { debugPrint('Pusher subscribe driver.$driverId: $e'); }
  }

  /// Changer le chauffeur connecté (après login)
  static Future<void> setDriver(String driverId) async {
    if (currentDriverId == driverId) return;
    if (currentDriverId != null) {
      try { await _pusher.unsubscribe(channelName: 'driver.$currentDriverId'); } catch (_) {}
    }
    currentDriverId = driverId;
    await _subscribeDriver(driverId);
  }

  /// Notification locale
  static Future<void> _show({
    required int    id,
    required String title,
    required String body,
    required String channel,
    Importance importance = Importance.high,
  }) async {
    final android = AndroidNotificationDetails(
      'toptopgo_driver_$channel',
      'TopTopGo Chauffeur — ${_label(channel)}',
      channelDescription: 'Notifications chauffeur — $channel',
      importance:      importance,
      priority:        Priority.high,
      playSound:       true,
      enableVibration: true,
      icon:            '@mipmap/ic_launcher',
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true, presentBadge: true, presentSound: true);
    await _notif.show(id, title, body, NotificationDetails(android: android, iOS: ios));
  }

  static String _label(String ch) {
    switch (ch) {
      case 'calls':    return 'Appels';
      case 'messages': return 'Messages';
      case 'bookings': return 'Réservations';
      case 'payments': return 'Paiements';
      case 'support':  return 'Support';
      default:         return 'Notifications';
    }
  }

  /// Notification manuelle
  static Future<void> showLocalNotification({
    required String title,
    required String body,
  }) => _show(id: 99, title: title, body: body, channel: 'general');

  /// Déconnexion
  static Future<void> disconnect() async {
    try {
      await _pusher.unsubscribe(channelName: 'admin-support');
      if (currentDriverId != null) {
        await _pusher.unsubscribe(channelName: 'driver.$currentDriverId');
      }
      await _pusher.disconnect();
      currentDriverId = null;
    } catch (_) {}
  }
}

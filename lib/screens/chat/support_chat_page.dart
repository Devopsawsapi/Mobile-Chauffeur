import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../widgets/tt_logo.dart';
import '../../widgets/app_widgets.dart';

class SupportChatPage extends StatefulWidget {
  final bool embedded;

  const SupportChatPage({super.key, this.embedded = false});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {

  final _ctrl = TextEditingController();
  final _sc = ScrollController();

  List<dynamic> _msgs = [];

  bool _loading = true;
  bool _sending = false;

  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  PusherChannel? _channel;

  @override
  void initState() {
    super.initState();

    _loadInitial();
    _initPusher();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _sc.dispose();
    _pusher.unsubscribe(channelName: 'admin-support');
    _pusher.disconnect();
    super.dispose();
  }

  /// Charger messages API
  Future<void> _loadInitial() async {

    setState(() => _loading = true);

    final res = await ApiService.get(Api.support);

    if (!mounted) return;

    if (res['success'] == true) {

      final raw = res['messages'] ?? res['data'] ?? [];

      final newMsgs = (raw as List).map<Map<String, dynamic>>((m) {

        final map = Map<String, dynamic>.from(m);

        if (map['sender'] is Map || map['sender'] == null) {

          final sType = (map['sender_type'] ?? '').toString();

          map['sender'] =
              sType.contains('Driver')
                  ? 'driver'
                  : 'support';
        }

        return map;

      }).toList();

      setState(() {

        _msgs = newMsgs.isEmpty
            ? [
                {
                  'content': "Bonjour ! Support TopTopGo",
                  'sender': 'support'
                }
              ]
            : newMsgs;

      });

      _scrollBottom();
    }

    setState(() => _loading = false);
  }

  /// Initialisation PUSHER
  Future<void> _initPusher() async {

    try {

      await _pusher.init(
        apiKey: 'b936f5c8f1666939a7fa',
        cluster: 'eu',
        onError: (message, code, error) {
          debugPrint("Erreur Pusher: $message code: $code");
        },
        onConnectionStateChange: (currentState, previousState) {
          debugPrint("Pusher état: $currentState");
        },
      );

      await _pusher.connect();

      _channel = await _pusher.subscribe(
        channelName: 'admin-support',
        onEvent: (event) {

          if (event.eventName != 'message.received') return;
          if (event.data == null) return;

          final data = json.decode(event.data);

          if (!mounted) return;

          setState(() {

            _msgs.add({

              'content': data['content'],

              'sender':
                  data['sender_type']
                          .toString()
                          .contains('Driver')
                      ? 'driver'
                      : 'support',

              'created_at': data['created_at'],

            });

          });

          _scrollBottom();

        },
      );

    } catch (e) {

      debugPrint("Erreur Pusher: $e");

    }

  }

  /// Envoyer message
  Future<void> _send() async {

    final t = _ctrl.text.trim();

    if (t.isEmpty) return;

    _ctrl.clear();

    setState(() {

      _msgs.add({

        'content': t,
        'sender': 'driver',
        'created_at':
            DateTime.now().toIso8601String()

      });

      _sending = true;

    });

    _scrollBottom();

    await ApiService.post(
      Api.support,
      {
        'content': t,
      },
    );

    setState(() => _sending = false);
  }

  void _scrollBottom() {

    Future.delayed(
        const Duration(milliseconds: 100), () {

      if (_sc.hasClients) {

        _sc.animateTo(
          _sc.position.maxScrollExtent,
          duration:
              const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );

      }

    });

  }

  @override
  Widget build(BuildContext context) {

    final body = Column(
      children: [

        Expanded(
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator())
              : ListView.builder(

                  controller: _sc,

                  padding:
                      const EdgeInsets.all(16),

                  itemCount: _msgs.length,

                  itemBuilder: (_, i) {

                    final m = _msgs[i];

                    final mine =
                        m['sender'] == 'driver';

                    return Align(

                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,

                      child: Container(

                        margin:
                            const EdgeInsets.only(
                                bottom: 10),

                        padding:
                            const EdgeInsets.all(
                                12),

                        decoration: BoxDecoration(

                          color: mine
                              ? C.orange
                              : C.surface,

                          borderRadius:
                              BorderRadius.circular(
                                  16),

                        ),

                        child: Text(

                          m['content'] ?? '',

                          style: const TextStyle(
                              color: C.text),

                        ),

                      ),

                    );

                  },

                ),
        ),

        inputBar(
          _ctrl,
          _send,
          btnColor: C.blue,
          sending: _sending,
        ),

      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: C.bg,

      appBar: AppBar(
        title: const Text("Support"),
      ),

      body: body,
    );
  }
}
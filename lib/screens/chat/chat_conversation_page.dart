import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/app_widgets.dart';

class ChatConversationPage extends StatefulWidget {
  final String name, initials, tripId;
  const ChatConversationPage({
    super.key,
    required this.name,
    required this.initials,
    required this.tripId,
  });
  @override
  State<ChatConversationPage> createState() => _ConvState();
}

class _ConvState extends State<ChatConversationPage> {
  final _ctrl = TextEditingController();
  final _sc   = ScrollController();

  List<dynamic> _msgs = [];
  bool _loading       = false;
  bool _sending       = false;

  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  PusherChannel? _channel;

  String get _channelName => 'trip.${widget.tripId}';

  @override
  void initState() {
    super.initState();
    _load();
    _initPusher();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _sc.dispose();
    _pusher.unsubscribe(channelName: _channelName);
    _pusher.disconnect();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('${Api.messages}/${widget.tripId}');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        final raw = res['messages'] ?? res['data'] ?? [];
        _msgs = (raw as List).map((m) {
          if (m['sender'] is Map) {
            final sType = (m['sender_type'] ?? '').toString();
            m = Map<String, dynamic>.from(m);
            m['sender'] = sType.contains('Driver') ? 'driver' : 'client';
          }
          return m;
        }).toList();
      }
    });
    _scroll();
  }

  Future<void> _initPusher() async {
    try {
      await _pusher.init(
        apiKey: 'b936f5c8f1666939a7fa',
        cluster: 'eu',
        onError: (message, code, error) {
          debugPrint('Pusher erreur: $message code: $code');
        },
        onConnectionStateChange: (currentState, previousState) {
          debugPrint('Pusher etat: $currentState');
        },
      );

      await _pusher.connect();

      _channel = await _pusher.subscribe(
        channelName: _channelName,
        onEvent: (event) {
          if (event.eventName != 'message.sent') return;
          if (event.data == null) return;

          final data    = json.decode(event.data);
          if (!mounted) return;

          final sType   = (data['sender_type'] ?? '').toString();
          final sender  = sType.contains('Driver') ? 'driver' : 'client';
          final content = data['content']?.toString() ?? '';

          final alreadyExists = _msgs.any((m) =>
              m['content'] == content &&
              m['sender'] == sender &&
              m['_pending'] == true);

          if (alreadyExists) {
            setState(() {
              final idx = _msgs.lastIndexWhere((m) =>
                  m['content'] == content &&
                  m['sender'] == sender &&
                  m['_pending'] == true);
              if (idx != -1) {
                _msgs[idx] = {
                  'content':    content,
                  'sender':     sender,
                  'created_at': data['created_at'],
                };
              }
            });
          } else {
            setState(() {
              _msgs.add({
                'content':    content,
                'sender':     sender,
                'created_at': data['created_at'],
              });
            });
          }
          _scroll();
        },
      );
    } catch (e) {
      debugPrint('Pusher init erreur: $e');
    }
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    _ctrl.clear();

    setState(() {
      _msgs.add({
        'content':    t,
        'sender':     'driver',
        'created_at': DateTime.now().toIso8601String(),
        '_pending':   true,
      });
      _sending = true;
    });
    _scroll();

    final res = await ApiService.post(
      '${Api.messages}/${widget.tripId}',
      {'content': t},
    );

    setState(() => _sending = false);
    if (res['success'] != true && mounted) {
      snack(context, 'Message non envoye', error: true);
    }
  }

  void _scroll() => Future.delayed(const Duration(milliseconds: 100), () {
    if (_sc.hasClients) {
      _sc.animateTo(
        _sc.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(
      backgroundColor: C.card,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: C.text),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [C.orange, Color(0xFFE8921A)]),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(widget.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              )),
          ),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.name,
            style: const TextStyle(
              color: C.text, fontSize: 14, fontWeight: FontWeight.w700)),
          const Text('En ligne',
            style: TextStyle(color: C.online, fontSize: 11)),
        ]),
      ]),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border),
      ),
    ),
    body: Column(children: [
      Expanded(
        child: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(C.orange)))
          : ListView.builder(
              controller: _sc,
              padding: const EdgeInsets.all(16),
              itemCount: _msgs.length,
              itemBuilder: (_, i) {
                final m         = _msgs[i];
                final mine      = m['sender'] == 'driver';
                final t         = m['created_at']?.toString() ?? '';
                final isPending = m['_pending'] == true;

                return Align(
                  alignment: mine
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: mine ? C.orange : C.surface,
                      borderRadius: BorderRadius.only(
                        topLeft:     const Radius.circular(16),
                        topRight:    const Radius.circular(16),
                        bottomLeft:  Radius.circular(mine ? 16 : 4),
                        bottomRight: Radius.circular(mine ? 4 : 16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(m['content'] ?? '',
                          style: const TextStyle(
                            color: C.text, fontSize: 14, height: 1.4)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.length > 16 ? t.substring(11, 16) : t,
                              style: TextStyle(
                                color: mine ? Colors.white60 : C.muted,
                                fontSize: 10,
                              ),
                            ),
                            if (mine) ...[
                              const SizedBox(width: 4),
                              Icon(
                                isPending
                                  ? Icons.access_time_rounded
                                  : Icons.done_all_rounded,
                                size: 12,
                                color: isPending
                                  ? Colors.white38
                                  : Colors.white70,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
      inputBar(_ctrl, _send, sending: _sending),
    ]),
  );
}
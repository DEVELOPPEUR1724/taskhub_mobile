import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message.dart';
import 'client_service.dart';

// Client WebSocket "protocole Pusher" écrit à la main, vers le serveur
// Reverb auto-hébergé du backend Laravel — reçoit les nouveaux messages de
// chat en temps réel au lieu d'attendre un rechargement manuel de l'écran
// (voir MessageSent côté backend, diffusé sur le canal privé
// "conversations.{id}").
//
// Écrit à la main plutôt qu'avec un package Pusher tiers : les packages
// disponibles supposent tous un cluster Pusher Cloud officiel et ne
// permettent pas de pointer vers un hôte auto-hébergé personnalisé comme
// Reverb. web_socket_channel est un simple client WebSocket generique, sans
// cette limitation, et fonctionne sur toutes les plateformes (y compris Web).
class RealtimeChatService {
  RealtimeChatService._();
  static final RealtimeChatService instance = RealtimeChatService._();

  // Doit correspondre à REVERB_APP_KEY dans le .env du backend.
  static const _appKey = 'dilblnznvszeflilhnj5';
  static const _wsPort = 8080;

  // Même logique que ClientService.baseUrl : 127.0.0.1 pointe vers
  // l'émulateur Android lui-même, pas vers la machine hôte qui fait tourner
  // `php artisan reverb:start`.
  static String get _host {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return '127.0.0.1';
  }

  WebSocketChannel? _channel;
  String? _socketId;
  final Map<String, void Function(Message)> _handlers = {};
  final Set<String> _pendingSubscriptions = {};

  Future<void> init() async {
    if (_channel != null) return;
    try {
      final uri = Uri.parse('ws://$_host:$_wsPort/app/$_appKey?protocol=7&client=flutter&version=1.0');
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      channel.stream.listen(_onFrame, onDone: _reset, onError: (_) => _reset(), cancelOnError: true);
    } catch (_) {
      // Serveur Reverb injoignable (pas lancé, mode dégradé Web...) : le
      // chat reste utilisable en HTTP classique, juste sans temps réel.
      _reset();
    }
  }

  void _reset() {
    _channel = null;
    _socketId = null;
  }

  void _onFrame(dynamic raw) {
    final Map<String, dynamic> frame = jsonDecode(raw as String);
    final event = frame['event'] as String?;
    final channelName = frame['channel'] as String?;

    if (event == 'pusher:connection_established') {
      final Map<String, dynamic> payload = jsonDecode(frame['data'] as String);
      _socketId = payload['socket_id'] as String?;
      // Rejoue les abonnements demandés avant que la connexion soit prête.
      for (final name in _pendingSubscriptions.toList()) {
        _sendSubscribe(name);
      }
      return;
    }

    if (event == 'message.sent' && channelName != null) {
      final handler = _handlers[channelName];
      if (handler == null) return;
      final rawData = frame['data'];
      final Map<String, dynamic> json = rawData is String ? jsonDecode(rawData) : rawData;
      handler(Message.fromJson(json));
    }
  }

  Future<void> subscribeToConversation(int conversationId, void Function(Message) onMessage) async {
    final channelName = 'private-conversations.$conversationId';
    _handlers[channelName] = onMessage;
    if (_socketId == null) {
      _pendingSubscriptions.add(channelName);
      return;
    }
    await _sendSubscribe(channelName);
  }

  Future<void> _sendSubscribe(String channelName) async {
    if (_channel == null || _socketId == null) return;
    try {
      final auth = await _authorize(channelName, _socketId!);
      _channel!.sink.add(jsonEncode({
        'event': 'pusher:subscribe',
        'data': {
          'channel': channelName,
          'auth': auth['auth'],
          if (auth['channel_data'] != null) 'channel_data': auth['channel_data'],
        },
      }));
      _pendingSubscriptions.remove(channelName);
    } catch (_) {
      // Abonnement refusé/impossible : silencieux, l'écran reste utilisable
      // sans mise à jour temps réel.
    }
  }

  // Autorisation des canaux privés — le serveur Reverb ne connaît pas nos
  // tokens Sanctum, donc on signe la demande nous-mêmes via l'endpoint
  // Laravel /broadcasting/auth (Bearer token), comme le reste de l'API.
  Future<Map<String, dynamic>> _authorize(String channelName, String socketId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.post(
      Uri.parse('${ClientService.baseUrl}/broadcasting/auth'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'socket_id': socketId, 'channel_name': channelName}),
    );
    return jsonDecode(response.body);
  }

  void unsubscribeFromConversation(int conversationId) {
    final channelName = 'private-conversations.$conversationId';
    _handlers.remove(channelName);
    _pendingSubscriptions.remove(channelName);
    _channel?.sink.add(jsonEncode({
      'event': 'pusher:unsubscribe',
      'data': {'channel': channelName},
    }));
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:geonote/models/message.dart';

void main() {
  group('Message.fromJson', () {
    test('parse un message complet', () {
      final json = {
        'id': 'abc-123',
        'user_id': 'user-1',
        'username': 'alice',
        'content': 'Hello world',
        'latitude': 48.8566,
        'longitude': 2.3522,
        'visibility': 'public',
        'hashtags': ['paris', 'test'],
        'likes_count': 5,
        'comments_count': 2,
        'distance_meters': 150.5,
        'created_at': '2026-03-07T10:00:00Z',
      };

      final message = Message.fromJson(json);

      expect(message.id, 'abc-123');
      expect(message.username, 'alice');
      expect(message.latitude, 48.8566);
      expect(message.hashtags, ['paris', 'test']);
      expect(message.likesCount, 5);
      expect(message.distanceMeters, 150.5);
    });

    test('gere les champs optionnels absents', () {
      final json = {
        'id': 'abc-123',
        'user_id': 'user-1',
        'username': 'bob',
        'content': 'Minimal',
        'latitude': 0.0,
        'longitude': 0.0,
        'created_at': '2026-03-07T10:00:00Z',
      };

      final message = Message.fromJson(json);

      expect(message.visibility, 'public');
      expect(message.hashtags, isEmpty);
      expect(message.likesCount, 0);
      expect(message.distanceMeters, isNull);
    });
  });

  group('Message.distanceFormatted', () {
    test('affiche en metres si < 1000', () {
      final msg = Message(
        id: '1', userId: '1', username: 'a', content: 'x',
        latitude: 0, longitude: 0,
        createdAt: DateTime.now(), distanceMeters: 450,
      );
      expect(msg.distanceFormatted, '450m');
    });

    test('affiche en km si >= 1000', () {
      final msg = Message(
        id: '1', userId: '1', username: 'a', content: 'x',
        latitude: 0, longitude: 0,
        createdAt: DateTime.now(), distanceMeters: 2500,
      );
      expect(msg.distanceFormatted, '2.5km');
    });

    test('vide si null', () {
      final msg = Message(
        id: '1', userId: '1', username: 'a', content: 'x',
        latitude: 0, longitude: 0,
        createdAt: DateTime.now(),
      );
      expect(msg.distanceFormatted, '');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:geonote/models/user.dart';

void main() {
  group('User.fromJson', () {
    test('parse un user complet', () {
      final json = {
        'id': 'abc-123',
        'username': 'alice_explore',
        'email': 'alice@test.com',
        'avatar_url': null,
        'is_anonymous': false,
        'created_at': '2026-03-01T10:00:00Z',
      };

      final user = User.fromJson(json);

      expect(user.id, 'abc-123');
      expect(user.username, 'alice_explore');
      expect(user.email, 'alice@test.com');
      expect(user.isAnonymous, false);
    });

    test('toJson roundtrip', () {
      final user = User(
        id: 'abc',
        username: 'bob',
        email: 'bob@test.com',
        createdAt: DateTime.utc(2026, 3, 1),
      );

      final json = user.toJson();
      final restored = User.fromJson(json);

      expect(restored.id, user.id);
      expect(restored.username, user.username);
    });
  });
}

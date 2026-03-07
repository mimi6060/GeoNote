import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/message.dart';
import '../widgets/message_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  List<Message> _myMessages = [];
  Map<String, dynamic>? _profile;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getUserMessages(auth.user!.id),
        _api.getMyProfile(),
      ]);
      _myMessages = results[0] as List<Message>;
      _profile = results[1] as Map<String, dynamic>;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteMessage(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Supprimer cette note ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _api.deleteMessage(id);
      _loadAll();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final streak = _profile?['streak'] as Map<String, dynamic>?;
    final badges = (_profile?['badges'] as List<dynamic>?) ?? [];

    return Scaffold(
      body: user == null
          ? const Center(child: Text('Non connecte'))
          : RefreshIndicator(
              color: GeoNoteTheme.primary,
              onRefresh: _loadAll,
              child: CustomScrollView(
                slivers: [
                  // Profile header
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 24,
                        bottom: 24,
                        left: 24,
                        right: 24,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [GeoNoteTheme.primary, GeoNoteTheme.primaryDark],
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.logout, color: Colors.white70),
                                onPressed: () async {
                                  await auth.logout();
                                },
                              ),
                            ],
                          ),
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white24,
                            child: Text(
                              user.username[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '@${user.username}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email ?? '',
                            style: const TextStyle(color: Colors.white60, fontSize: 14),
                          ),
                          const SizedBox(height: 20),
                          // Stats row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _Stat(value: '${_myMessages.length}', label: 'Notes'),
                              const SizedBox(width: 24),
                              _Stat(
                                value: '${_myMessages.fold<int>(0, (sum, m) => sum + m.likesCount)}',
                                label: 'Likes',
                              ),
                              const SizedBox(width: 24),
                              _Stat(
                                value: '${streak?['current_streak'] ?? 0}',
                                label: 'Streak',
                                icon: Icons.local_fire_department,
                              ),
                              const SizedBox(width: 24),
                              _Stat(
                                value: '${streak?['total_zones'] ?? 0}',
                                label: 'Zones',
                                icon: Icons.explore,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Streak bar
                  if (streak != null)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${streak['current_streak'] ?? 0} jour${(streak['current_streak'] ?? 0) != 1 ? 's' : ''} de streak',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Record: ${streak['max_streak'] ?? 0} jours  ·  ${streak['total_unlocks'] ?? 0} unlocks',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Badges
                  if (badges.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.emoji_events, size: 18, color: Colors.amber),
                                const SizedBox(width: 6),
                                Text(
                                  'Badges (${badges.length})',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: badges.map<Widget>((b) {
                                final badge = b as Map<String, dynamic>;
                                final type = badge['badge_type'] as String? ?? '';
                                return _BadgeChip(badgeType: type);
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Text(
                        'Mes notes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                      ),
                    ),
                  ),
                  // Messages list
                  if (_loading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (_myMessages.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.note_add_outlined, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'Aucune note pour le moment',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => MessageCard(
                          message: _myMessages[i],
                          showDelete: true,
                          onDelete: () => _deleteMessage(_myMessages[i].id),
                        ),
                        childCount: _myMessages.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  const _Stat({required this.value, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(height: 2),
        ],
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String badgeType;
  const _BadgeChip({required this.badgeType});

  @override
  Widget build(BuildContext context) {
    final (String label, IconData icon, Color color) = switch (badgeType) {
      'first_post' => ('Premier post', Icons.star, Colors.amber),
      'explorer_5' => ('Explorateur 5', Icons.explore, Colors.green),
      'explorer_10' => ('Explorateur 10', Icons.explore, Colors.teal),
      'explorer_25' => ('Explorateur 25', Icons.explore, Colors.blue),
      'streak_3' => ('Streak 3j', Icons.local_fire_department, Colors.orange),
      'streak_7' => ('Streak 7j', Icons.local_fire_department, Colors.deepOrange),
      'streak_30' => ('Streak 30j', Icons.local_fire_department, Colors.red),
      'mystery_hunter_5' => ('Chasseur 5', Icons.search, Colors.deepPurple),
      'mystery_hunter_25' => ('Chasseur 25', Icons.search, Colors.purple),
      'capsule_creator' => ('Capsule', Icons.schedule, Colors.purple),
      'local_legend' => ('Legende locale', Icons.emoji_events, Colors.amber),
      _ => (badgeType, Icons.military_tech, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

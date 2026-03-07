import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final location = await LocationService.getCurrentLocation();
      final lat = location?.latitude ?? 48.8566;
      final lng = location?.longitude ?? 2.3522;
      _entries = await _api.getLeaderboard(lat, lng, radius: 5000);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: GeoNoteTheme.primary,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('Pas encore de classement',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                            const SizedBox(height: 8),
                            Text('Postez des messages pour apparaitre !',
                                style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: _entries.length,
                    itemBuilder: (context, i) => _LeaderboardTile(
                      rank: i + 1,
                      entry: _entries[i],
                    ),
                  ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> entry;
  const _LeaderboardTile({required this.rank, required this.entry});

  @override
  Widget build(BuildContext context) {
    final username = entry['username'] as String? ?? '?';
    final totalPosts = entry['total_posts'] as int? ?? 0;
    final totalLikes = entry['total_likes'] as int? ?? 0;
    final score = entry['score'] as int? ?? 0;

    final (Color medalColor, IconData? medalIcon) = switch (rank) {
      1 => (const Color(0xFFFFD700), Icons.emoji_events),
      2 => (const Color(0xFFC0C0C0), Icons.emoji_events),
      3 => (const Color(0xFFCD7F32), Icons.emoji_events),
      _ => (Colors.grey, null),
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: rank <= 3 ? medalColor.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rank <= 3 ? medalColor.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 36,
              child: rank <= 3
                  ? Icon(medalIcon, color: medalColor, size: 28)
                  : Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[400],
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: rank <= 3
                  ? medalColor.withOpacity(0.2)
                  : GeoNoteTheme.primary.withOpacity(0.12),
              child: Text(
                username[0].toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: rank <= 3 ? medalColor : GeoNoteTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Name & stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@$username',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: rank <= 3 ? Colors.black87 : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Text('$totalPosts', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      const SizedBox(width: 10),
                      Icon(Icons.favorite_border, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Text('$totalLikes', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            ),
            // Score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: rank <= 3 ? medalColor.withOpacity(0.15) : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$score pts',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: rank <= 3 ? medalColor : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

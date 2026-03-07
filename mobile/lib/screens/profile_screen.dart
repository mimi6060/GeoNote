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
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadMyMessages();
  }

  Future<void> _loadMyMessages() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    setState(() => _loading = true);
    try {
      _myMessages = await _api.getUserMessages(auth.user!.id);
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
      _loadMyMessages();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      body: user == null
          ? const Center(child: Text('Non connecte'))
          : RefreshIndicator(
              color: GeoNoteTheme.primary,
              onRefresh: _loadMyMessages,
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
                          // Stats
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _Stat(
                                value: '${_myMessages.length}',
                                label: 'Notes',
                              ),
                              const SizedBox(width: 32),
                              _Stat(
                                value: '${_myMessages.fold<int>(0, (sum, m) => sum + m.likesCount)}',
                                label: 'Likes',
                              ),
                              const SizedBox(width: 32),
                              _Stat(
                                value: '${_myMessages.fold<int>(0, (sum, m) => sum + m.commentsCount)}',
                                label: 'Commentaires',
                              ),
                            ],
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
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
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}

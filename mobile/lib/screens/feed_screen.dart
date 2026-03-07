import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/messages_provider.dart';
import '../services/location_service.dart';
import '../widgets/message_card.dart';
import '../widgets/message_popup.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _sort = 'distance';
  String? _hashtag;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final location = await LocationService.getCurrentLocation();
    if (!mounted) return;
    context.read<MessagesProvider>().loadNearby(
          location ?? LocationService.defaultLocation,
          radius: 50000,
        );
  }

  void _showMessage(msg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MessagePopup(message: msg, onRefresh: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessagesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GeoNote',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.sort,
              color: _sort == 'distance' ? Colors.black87 : GeoNoteTheme.primary,
            ),
            onSelected: (value) {
              setState(() => _sort = value);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'distance', child: Text('Plus proches')),
              const PopupMenuItem(value: 'recent', child: Text('Plus recents')),
              const PopupMenuItem(value: 'popular', child: Text('Plus populaires')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: GeoNoteTheme.primary,
        onRefresh: _load,
        child: provider.messages.isEmpty && !provider.loading
            ? const _EmptyFeed()
            : ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 80),
                itemCount: provider.messages.length,
                itemBuilder: (context, i) {
                  final sorted = _sortedMessages(provider.messages);
                  if (i >= sorted.length) return const SizedBox.shrink();
                  return MessageCard(
                    message: sorted[i],
                    onTap: () => _showMessage(sorted[i]),
                    onLike: () async {
                      await provider.toggleLike(sorted[i].id);
                      _load();
                    },
                  );
                },
              ),
      ),
    );
  }

  List<dynamic> _sortedMessages(List msgs) {
    final sorted = List.of(msgs);
    switch (_sort) {
      case 'recent':
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'popular':
        sorted.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        break;
      default:
        break;
    }
    return sorted;
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Icon(Icons.explore_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'Aucune note autour de vous',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Soyez le premier a laisser un message !',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

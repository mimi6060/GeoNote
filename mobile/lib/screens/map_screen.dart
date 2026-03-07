import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/messages_provider.dart';
import '../services/location_service.dart';
import '../services/ws_service.dart';
import '../widgets/message_popup.dart';
import '../widgets/create_sheet.dart';
import '../models/message.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final WsService _ws = WsService();
  LatLng _center = LocationService.defaultLocation;
  StreamSubscription? _wsSub;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _connectWebSocket() {
    _ws.connect();
    _wsSub = _ws.events.listen((event) {
      if (event.type == 'new_message' ||
          event.type == 'new_like' ||
          event.type == 'new_comment') {
        _loadMessages();
      }
    });
  }

  Future<void> _initLocation() async {
    final location = await LocationService.getCurrentLocation();
    if (location != null && mounted) {
      setState(() => _center = location);
      _mapController.move(_center, 15);
    }
    _loadMessages();
  }

  void _loadMessages() {
    context.read<MessagesProvider>().loadNearby(_center);
  }

  void _onMapMoved() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _loadMessages);
  }

  void _showMessageSheet(Message message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MessagePopup(message: message, onRefresh: _loadMessages),
    );
  }

  void _showCreateSheet({LatLng? position}) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateSheet(
        position: position ?? _center,
        onCreated: _loadMessages,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesProvider = context.watch<MessagesProvider>();
    final markers = messagesProvider.messages.map((msg) {
      return Marker(
        point: LatLng(msg.latitude, msg.longitude),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _showMessageSheet(msg),
          child: Container(
            decoration: BoxDecoration(
              color: GeoNoteTheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
          ),
        ),
      );
    }).toList();

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13,
              onPositionChanged: (pos, _) {
                _center = pos.center ?? _center;
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) _onMapMoved();
              },
              onLongPress: (tapPos, latlng) {
                _showCreateSheet(position: latlng);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.geonote.app',
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(44, 44),
                  markers: markers,
                  builder: (context, clusterMarkers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: GeoNoteTheme.primaryDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${clusterMarkers.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                // Message count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 16, color: GeoNoteTheme.primary),
                      const SizedBox(width: 6),
                      if (messagesProvider.loading)
                        const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: GeoNoteTheme.primary),
                        )
                      else
                        Text(
                          '${messagesProvider.messages.length} note${messagesProvider.messages.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                // GPS button
                _MapButton(
                  icon: Icons.my_location,
                  onTap: _initLocation,
                ),
              ],
            ),
          ),
          // Hint
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Appui long pour deposer une note',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Note'),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}

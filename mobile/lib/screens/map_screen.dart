import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/messages_provider.dart';
import '../services/location_service.dart';
import '../services/ws_service.dart';
import '../widgets/message_popup.dart';
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MessagePopup(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesProvider = context.watch<MessagesProvider>();
    final markers = messagesProvider.messages.map((msg) {
      return Marker(
        point: LatLng(msg.latitude, msg.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showMessageSheet(msg),
          child: const Icon(
            Icons.location_pin,
            color: GeoNoteTheme.primary,
            size: 40,
          ),
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('GeoNote'),
            if (messagesProvider.loading)
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _initLocation,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13,
              onPositionChanged: (pos, _) {
                _center = pos.center;
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) _onMapMoved();
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
                  size: const Size(40, 40),
                  markers: markers,
                  builder: (context, clusterMarkers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: GeoNoteTheme.primary,
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
          // Badge compteur
          if (messagesProvider.messages.isNotEmpty)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    '${messagesProvider.messages.length} message${messagesProvider.messages.length > 1 ? 's' : ''} autour de vous',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.pushNamed(context, '/create');
          if (created == true) _loadMessages();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

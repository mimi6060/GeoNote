import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/events_provider.dart';
import '../providers/messages_provider.dart';
import '../services/api_service.dart';
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
  final ApiService _api = ApiService();
  LatLng _center = LocationService.defaultLocation;
  LatLng _lastLoadCenter = LocationService.defaultLocation;
  StreamSubscription? _wsSub;
  Timer? _debounce;
  DateTime _lastLoad = DateTime.fromMillisecondsSinceEpoch(0);
  bool _showHeatmap = false;
  List<Map<String, dynamic>> _heatmapPoints = [];

  static const double _minReloadDistanceMeters = 100;
  static const Duration _minReloadInterval = Duration(seconds: 5);

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
        _forceLoadMessages();
      }
    });
  }

  Future<void> _initLocation() async {
    final location = await LocationService.getCurrentLocation();
    if (location != null && mounted) {
      setState(() => _center = location);
      _mapController.move(_center, 15);
    }
    _forceLoadMessages();
  }

  /// Always load, ignoring debounce/distance checks.
  void _forceLoadMessages() {
    _lastLoadCenter = _center;
    _lastLoad = DateTime.now();
    context.read<MessagesProvider>().loadNearby(_center, radius: 1000);
    context.read<EventsProvider>().loadNearby(_center, radius: 5000);
    if (_showHeatmap) _loadHeatmap();
  }

  Future<void> _loadHeatmap() async {
    try {
      final points = await _api.getHeatmap(_center.latitude, _center.longitude, radius: 2000);
      if (mounted) setState(() => _heatmapPoints = points);
    } catch (_) {}
  }

  void _toggleHeatmap() {
    setState(() => _showHeatmap = !_showHeatmap);
    if (_showHeatmap) _loadHeatmap();
  }

  /// Smart reload: only if moved > 100m AND at least 5s since last load.
  void _onMapMoved() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final dist = _distanceMeters(_center, _lastLoadCenter);
      final elapsed = DateTime.now().difference(_lastLoad);

      if (dist >= _minReloadDistanceMeters && elapsed >= _minReloadInterval) {
        _forceLoadMessages();
      }
    });
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  double _rad(double deg) => deg * math.pi / 180;

  void _showMessageSheet(Message message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MessagePopup(message: message, onRefresh: _forceLoadMessages),
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
        onCreated: _forceLoadMessages,
      ),
    );
  }

  void _showEventSheet(GeoEvent event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_fire_department, color: Colors.red, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('EVENT DETECTED',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                      Text(event.subtitle,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _EventStat(icon: Icons.chat_bubble_outline, value: '${event.messageCount}', label: 'messages'),
                const SizedBox(width: 24),
                _EventStat(icon: Icons.people_outline, value: '${event.userCount}', label: 'personnes'),
              ],
            ),
            if (event.topHashtags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: event.topHashtags.map((tag) => Chip(
                  label: Text('#$tag', style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.red.withOpacity(0.08),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesProvider = context.watch<MessagesProvider>();
    final eventsProvider = context.watch<EventsProvider>();

    final markers = messagesProvider.messages.map((msg) {
      final Color markerColor;
      final Widget markerIcon;

      if (msg.isMystery) {
        markerColor = Colors.deepPurple;
        markerIcon = msg.isLocked
            ? const Text('???',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold))
            : const Icon(Icons.help_outline, color: Colors.white, size: 20);
      } else if (msg.isCapsule) {
        markerColor = Colors.purple;
        markerIcon =
            const Icon(Icons.schedule, color: Colors.white, size: 20);
      } else {
        markerColor = GeoNoteTheme.primary;
        markerIcon =
            const Icon(Icons.chat_bubble, color: Colors.white, size: 20);
      }

      return Marker(
        point: LatLng(msg.latitude, msg.longitude),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _showMessageSheet(msg),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: markerColor,
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
                child: Center(child: markerIcon),
              ),
              // Badge overlay for locked mystery messages
              if (msg.isMystery && msg.isLocked)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Center(
                      child: Text('?',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              // Red countdown badge for ephemeral standard messages
              if (!msg.isMystery && !msg.isCapsule && msg.isEphemeral)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      msg.timeRemaining,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();

    final eventMarkers = eventsProvider.events.map((event) {
      return Marker(
        point: LatLng(event.lat, event.lng),
        width: 60,
        height: 60,
        child: GestureDetector(
          onTap: () => _showEventSheet(event),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_fire_department, color: Colors.white, size: 18),
                Text(
                  '${event.messageCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
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
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
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
                maxZoom: 19,
              ),
              // Heatmap layer
              if (_showHeatmap && _heatmapPoints.isNotEmpty)
                CircleLayer(
                  circles: _heatmapPoints.map((p) {
                    final intensity = (p['intensity'] as num?)?.toInt() ?? 1;
                    final opacity = (intensity / 10).clamp(0.15, 0.6);
                    final radius = (30 + intensity * 8).clamp(30, 120).toDouble();
                    return CircleMarker(
                      point: LatLng(
                        (p['lat'] as num).toDouble(),
                        (p['lng'] as num).toDouble(),
                      ),
                      radius: radius,
                      color: Colors.orange.withOpacity(opacity),
                      borderColor: Colors.orange.withOpacity(opacity * 0.5),
                      borderStrokeWidth: 1,
                    );
                  }).toList(),
                ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(44, 44),
                  markers: [...markers, ...eventMarkers],
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
                // Heatmap toggle
                Tooltip(
                  message: 'Carte de chaleur : voir les zones actives',
                  child: _MapButton(
                    icon: Icons.thermostat,
                    onTap: _toggleHeatmap,
                    active: _showHeatmap,
                  ),
                ),
                const SizedBox(width: 8),
                // GPS button
                Tooltip(
                  message: 'Recentrer sur ma position',
                  child: _MapButton(
                    icon: Icons.my_location,
                    onTap: _initLocation,
                  ),
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
  final bool active;
  const _MapButton({required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: active ? GeoNoteTheme.primary : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: active ? Colors.white : Colors.black87),
      ),
    );
  }
}

class _EventStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _EventStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.red),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }
}

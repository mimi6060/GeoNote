import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/messages_provider.dart';
import '../services/api_service.dart';

class CreateSheet extends StatefulWidget {
  final LatLng position;
  final VoidCallback onCreated;

  const CreateSheet({super.key, required this.position, required this.onCreated});

  @override
  State<CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<CreateSheet> {
  final _controller = TextEditingController();
  String _visibility = 'public';
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    setState(() => _submitting = true);

    try {
      await context.read<MessagesProvider>().create(
            content: content,
            latitude: widget.position.latitude,
            longitude: widget.position.longitude,
            visibility: _visibility,
          );
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } on ApiException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la creation')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Row(
              children: [
                const Icon(Icons.edit_location_alt, color: GeoNoteTheme.primary, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Nouvelle note',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${widget.position.latitude.toStringAsFixed(4)}, ${widget.position.longitude.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Input
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              maxLength: 500,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Quoi de neuf ici ? Utilisez des #hashtags...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: GeoNoteTheme.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Visibility
            Row(
              children: [
                _VisibilityChip(
                  label: 'Public',
                  icon: Icons.public,
                  selected: _visibility == 'public',
                  onTap: () => setState(() => _visibility = 'public'),
                ),
                const SizedBox(width: 8),
                _VisibilityChip(
                  label: 'Amis',
                  icon: Icons.group,
                  selected: _visibility == 'friends',
                  onTap: () => setState(() => _visibility = 'friends'),
                ),
                const SizedBox(width: 8),
                _VisibilityChip(
                  label: 'Prive',
                  icon: Icons.lock,
                  selected: _visibility == 'private',
                  onTap: () => setState(() => _visibility = 'private'),
                ),
                const Spacer(),
                // Submit
                FilledButton.icon(
                  onPressed: _submitting || _controller.text.trim().isEmpty
                      ? null
                      : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, size: 18),
                  label: const Text('Publier'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _VisibilityChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? GeoNoteTheme.primary.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? GeoNoteTheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? GeoNoteTheme.primary : Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? GeoNoteTheme.primary : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

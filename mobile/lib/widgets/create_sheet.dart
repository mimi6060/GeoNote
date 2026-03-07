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
  String _messageType = 'standard';
  DateTime? _scheduledAt;
  bool _submitting = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null && mounted) {
        setState(() {
          _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
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
            messageType: _messageType,
            scheduledAt: _scheduledAt?.toUtc().toIso8601String(),
          );
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                width: 36, height: 4,
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
                Icon(
                  _messageType == 'mystery' ? Icons.help_outline
                    : _messageType == 'capsule' ? Icons.schedule
                    : Icons.edit_location_alt,
                  color: GeoNoteTheme.primary, size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  _messageType == 'mystery' ? 'Message mystere'
                    : _messageType == 'capsule' ? 'Capsule temporelle'
                    : 'Nouvelle note',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${widget.position.latitude.toStringAsFixed(4)}, ${widget.position.longitude.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Message type selector
            Row(
              children: [
                _TypeChip(
                  label: 'Standard',
                  icon: Icons.chat_bubble_outline,
                  subtitle: '24h',
                  selected: _messageType == 'standard',
                  onTap: () => setState(() => _messageType = 'standard'),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: 'Mystere',
                  icon: Icons.help_outline,
                  subtitle: 'Sur place',
                  selected: _messageType == 'mystery',
                  onTap: () => setState(() => _messageType = 'mystery'),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: 'Capsule',
                  icon: Icons.schedule,
                  subtitle: 'Futur',
                  selected: _messageType == 'capsule',
                  onTap: () => setState(() {
                    _messageType = 'capsule';
                    if (_scheduledAt == null) _pickDate();
                  }),
                ),
              ],
            ),
            // Info bubble explaining the selected type
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: ValueKey(_messageType),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _messageType == 'mystery'
                      ? Colors.deepPurple.withOpacity(0.06)
                      : _messageType == 'capsule'
                          ? Colors.purple.withOpacity(0.06)
                          : GeoNoteTheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: _messageType == 'mystery'
                          ? Colors.deepPurple
                          : _messageType == 'capsule'
                              ? Colors.purple
                              : GeoNoteTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _messageType == 'mystery'
                            ? 'Les autres doivent se deplacer sur place pour lire votre message. Ideal pour des secrets ou des chasses au tresor !'
                            : _messageType == 'capsule'
                                ? 'Votre message restera cache et apparaitra a la date choisie. Parfait pour des surprises ou des souvenirs !'
                                : 'Visible par tous pendant 24h puis disparait. Partagez ce qui se passe ici et maintenant !',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Capsule date display
            if (_messageType == 'capsule') ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, size: 16, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text(
                        _scheduledAt != null
                            ? 'Ouverture: ${_scheduledAt!.day}/${_scheduledAt!.month}/${_scheduledAt!.year} ${_scheduledAt!.hour}:${_scheduledAt!.minute.toString().padLeft(2, '0')}'
                            : 'Choisir une date...',
                        style: const TextStyle(fontSize: 13, color: Colors.purple),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Input
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              maxLength: 500,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: _messageType == 'mystery'
                    ? 'Ecrivez un secret a decouvrir sur place...'
                    : _messageType == 'capsule'
                    ? 'Un message pour le futur...'
                    : 'Quoi de neuf ici ? #hashtags...',
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
            // Visibility chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _VisibilityChip(
                  label: 'Public', icon: Icons.public,
                  selected: _visibility == 'public',
                  onTap: () => setState(() => _visibility = 'public'),
                ),
                _VisibilityChip(
                  label: 'Amis', icon: Icons.group,
                  selected: _visibility == 'friends',
                  onTap: () => setState(() => _visibility = 'friends'),
                ),
                _VisibilityChip(
                  label: 'Prive', icon: Icons.lock,
                  selected: _visibility == 'private',
                  onTap: () => setState(() => _visibility = 'private'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Submit
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting || !_hasText ||
                    (_messageType == 'capsule' && _scheduledAt == null) ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        _messageType == 'mystery' ? Icons.lock
                          : _messageType == 'capsule' ? Icons.schedule_send
                          : Icons.send,
                        size: 18,
                      ),
                label: Text(
                  _messageType == 'mystery' ? 'Cacher le message'
                    : _messageType == 'capsule' ? 'Programmer'
                    : 'Publier',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _messageType == 'mystery' ? Colors.deepPurple
                    : _messageType == 'capsule' ? Colors.purple
                    : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label, required this.icon, required this.subtitle,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? GeoNoteTheme.primary.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? GeoNoteTheme.primary : Colors.grey[200]!,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: selected ? GeoNoteTheme.primary : Colors.grey[500]),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(
                fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? GeoNoteTheme.primary : Colors.grey[700],
              )),
              Text(subtitle, style: TextStyle(fontSize: 9, color: Colors.grey[400])),
            ],
          ),
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
    required this.label, required this.icon,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? GeoNoteTheme.primary.withOpacity(0.12) : Colors.grey[100],
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
            Text(label, style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? GeoNoteTheme.primary : Colors.grey[600],
            )),
          ],
        ),
      ),
    );
  }
}

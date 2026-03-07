import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/messages_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class CreateMessageScreen extends StatefulWidget {
  const CreateMessageScreen({super.key});

  @override
  State<CreateMessageScreen> createState() => _CreateMessageScreenState();
}

class _CreateMessageScreenState extends State<CreateMessageScreen> {
  final _contentController = TextEditingController();
  String _visibility = 'public';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final location = await LocationService.getCurrentLocation();
      final lat = location?.latitude ?? LocationService.defaultLocation.latitude;
      final lng = location?.longitude ?? LocationService.defaultLocation.longitude;

      await context.read<MessagesProvider>().create(
            content: content,
            latitude: lat,
            longitude: lng,
            visibility: _visibility,
          );

      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle note')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _contentController,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Votre message... (utilisez #hashtags)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'public', label: Text('Public')),
                ButtonSegment(value: 'friends', label: Text('Amis')),
                ButtonSegment(value: 'private', label: Text('Prive')),
              ],
              selected: {_visibility},
              onSelectionChanged: (v) => setState(() => _visibility = v.first),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Publier'),
            ),
          ],
        ),
      ),
    );
  }
}

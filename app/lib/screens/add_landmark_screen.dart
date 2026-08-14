import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/landmark.dart';
import '../providers/landmarks_provider.dart';
import '../services/location_service.dart';
import '../widgets/landmark_image.dart';
import '../widgets/offline_banner.dart';
import '../widgets/score_badge.dart';

/// Requirement 6 (Add Landmark): Title, Latitude & Longitude, Image, with
/// GPS auto-fetched for the new entry (but still editable, in case the
/// user is adding a landmark for a place they're not standing at).
/// Requirement 7 (Soft Delete Handling): also doubles as the "View /
/// manage my landmarks" screen, with Delete and Restore actions.
class AddLandmarkScreen extends StatefulWidget {
  const AddLandmarkScreen({super.key});

  @override
  State<AddLandmarkScreen> createState() => _AddLandmarkScreenState();
}

class _AddLandmarkScreenState extends State<AddLandmarkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  File? _pickedImage;
  bool _isFetchingLocation = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LandmarksProvider>().loadManagedList();
      _autoFillLocation(silent: true);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _autoFillLocation({bool silent = false}) async {
    setState(() => _isFetchingLocation = true);
    try {
      final position = await LocationService.getCurrentLocation();
      _latController.text = position.latitude.toStringAsFixed(6);
      _lonController.text = position.longitude.toStringAsFixed(6);
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() => _pickedImage = File(picked.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await context.read<LandmarksProvider>().createLandmark(
            title: _titleController.text.trim(),
            lat: double.parse(_latController.text.trim()),
            lon: double.parse(_lonController.text.trim()),
            imageFile: _pickedImage,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Landmark created!'), backgroundColor: Colors.green),
      );
      _titleController.clear();
      setState(() => _pickedImage = null);
      _autoFillLocation(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create landmark: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LandmarksProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Add / View Landmarks')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAddForm(),
                const SizedBox(height: 24),
                const Divider(),
                Text('My Landmarks', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (provider.managedIncludingDeleted.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text("You haven't added or synced any landmarks yet."),
                  )
                else
                  ...provider.managedIncludingDeleted.map(
                    (landmark) => _ManagedLandmarkTile(landmark: landmark),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add a new landmark', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (v) => double.tryParse(v?.trim() ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _lonController,
                      decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (v) => double.tryParse(v?.trim() ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isFetchingLocation ? null : () => _autoFillLocation(),
                  icon: _isFetchingLocation
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, size: 18),
                  label: const Text('Use current GPS location'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_pickedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_pickedImage!, width: 56, height: 56, fit: BoxFit.cover),
                    )
                  else
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.image_outlined),
                    ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _showImageSourceSheet,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(_pickedImage == null ? 'Add photo (optional)' : 'Change photo'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Landmark'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagedLandmarkTile extends StatelessWidget {
  final Landmark landmark;
  const _ManagedLandmarkTile({required this.landmark});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LandmarksProvider>();
    final (minScore, maxScore) = provider.scoreRange;

    return Card(
      color: landmark.isActive ? null : Colors.grey.shade100,
      child: ListTile(
        leading: LandmarkImage(imagePath: landmark.image, size: 48),
        title: Text(
          landmark.title,
          style: TextStyle(
            decoration: landmark.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Row(
          children: [
            ScoreBadge(score: landmark.score, minScore: minScore, maxScore: maxScore),
            const SizedBox(width: 8),
            if (!landmark.isActive)
              const Text('Deleted', style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        trailing: landmark.isActive
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete',
                onPressed: () => _handleDelete(context, landmark),
              )
            : IconButton(
                icon: const Icon(Icons.restore, color: Colors.green),
                tooltip: 'Restore',
                onPressed: () => _handleRestore(context, landmark),
              ),
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, Landmark landmark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete landmark?'),
        content: Text('"${landmark.title}" will be hidden from lists. You can restore it later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<LandmarksProvider>().deleteLandmark(landmark.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  Future<void> _handleRestore(BuildContext context, Landmark landmark) async {
    try {
      await context.read<LandmarksProvider>().restoreLandmark(landmark.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not restore: $e')));
    }
  }
}

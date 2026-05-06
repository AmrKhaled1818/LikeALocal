import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../data/models/post_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/posts_provider.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _tipsCtrl = TextEditingController();
  final _dishesCtrl = TextEditingController();

  File? _selectedImage;
  String _selectedCategory = 'Restaurant';
  bool _posting = false;
  double? _pickedLat;
  double? _pickedLng;

  static const _draftKey = 'create_post_draft';

  static const _categories = [
    'Restaurant',
    'Bar',
    'Café',
    'Park',
    'Viewpoint',
    'Shop',
  ];

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _titleCtrl.addListener(_saveDraft);
    _descCtrl.addListener(_saveDraft);
    _locationCtrl.addListener(_saveDraft);
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString(_draftKey);
    if (draft == null || !mounted) return;
    final parts = draft.split('\x00');
    if (parts.length >= 3) {
      setState(() {
        _titleCtrl.text = parts[0];
        _descCtrl.text = parts[1];
        _locationCtrl.text = parts[2];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Draft restored'),
            action: SnackBarAction(
              label: 'Discard',
              onPressed: _clearDraft,
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft =
        '${_titleCtrl.text}\x00${_descCtrl.text}\x00${_locationCtrl.text}';
    await prefs.setString(_draftKey, draft);
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    if (mounted) {
      setState(() {
        _titleCtrl.clear();
        _descCtrl.clear();
        _locationCtrl.clear();
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _tipsCtrl.dispose();
    _dishesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kDark,
        leading: TextButton(
          onPressed: () => context.pop(),
          child: const Text('Cancel',
              style: TextStyle(color: Colors.white, fontSize: 14)),
        ),
        title: const Text('New Post',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _posting
                ? const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)),
                  )
                : ElevatedButton(
                    onPressed: _submitPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kOrange,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Post',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: kMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: kMutedFg.withOpacity(0.3),
                        width: 1.5,
                        style: BorderStyle.solid),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_selectedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 48, color: kMutedFg),
                            SizedBox(height: 8),
                            Text('Add a photo (optional)',
                                style: TextStyle(
                                    color: kMutedFg, fontSize: 14)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Caption — F23 character counter
              _label('Caption'),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _titleCtrl,
                builder: (_, val, __) {
                  final count = val.text.length;
                  final isOver = count > 500;
                  return TextFormField(
                    controller: _titleCtrl,
                    maxLength: 500,
                    validator: (v) =>
                        Validators.validateNotEmpty(v, 'Title'),
                    decoration: InputDecoration(
                      hintText: 'Share what makes this place special...',
                      counterText: '$count/500',
                      counterStyle: TextStyle(
                        color: isOver ? kDestructive : kMutedFg,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              _label('Description'),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Tell us more about this place...',
                ),
              ),
              const SizedBox(height: 14),

              // Location
              _label('Location'),
              TextFormField(
                controller: _locationCtrl,
                validator: (v) =>
                    Validators.validateNotEmpty(v, 'Location'),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_on_outlined,
                      color: kMutedFg, size: 20),
                  hintText: 'Neighbourhood / area name',
                ),
              ),
              const SizedBox(height: 10),
              // Map pin picker
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<LatLng>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _LocationPickerScreen(
                        initial: (_pickedLat != null && _pickedLng != null)
                            ? LatLng(_pickedLat!, _pickedLng!)
                            : null,
                      ),
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      _pickedLat = result.latitude;
                      _pickedLng = result.longitude;
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: _pickedLat != null ? 160 : 48,
                  decoration: BoxDecoration(
                    color: kMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _pickedLat != null ? kOrange : kMutedFg.withValues(alpha: 0.3),
                      width: _pickedLat != null ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _pickedLat != null
                      ? Stack(
                          children: [
                            FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(_pickedLat!, _pickedLng!),
                                initialZoom: 15,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.none,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}.png?api_key={api_key}',
                                  additionalOptions: const {
                                    'api_key': AppConfig.stadiaApiKey
                                  },
                                  userAgentPackageName:
                                      'com.example.like_a_local',
                                ),
                                MarkerLayer(markers: [
                                  Marker(
                                    point: LatLng(_pickedLat!, _pickedLng!),
                                    width: 36,
                                    height: 36,
                                    child: const Icon(Icons.location_pin,
                                        color: kOrange, size: 36),
                                  ),
                                ]),
                              ],
                            ),
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_location_alt_outlined,
                                        size: 14, color: kOrange),
                                    SizedBox(width: 4),
                                    Text('Change pin',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: kOrange,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.pin_drop_outlined,
                                color: kMutedFg, size: 20),
                            SizedBox(width: 8),
                            Text('Tap to pin location on map',
                                style: TextStyle(
                                    color: kMutedFg, fontSize: 14)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Category grid
              _label('Type of Hidden Gem'),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final selected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedCategory = cat),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected ? kOrange : kMuted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? kOrange : Colors.transparent,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: selected ? Colors.white : kDark,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Local Tips (optional)
              _label('Local Tips (optional)'),
              TextFormField(
                controller: _tipsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Any insider knowledge?',
                ),
              ),
              const SizedBox(height: 14),

              // Recommended Dishes (optional)
              _label('Recommended Dishes (optional)'),
              TextFormField(
                controller: _dishesCtrl,
                decoration: const InputDecoration(
                  hintText: 'E.g. Tacos, Pad Thai (comma-separated)',
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 14, color: kDark),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      // F18 — Compress on pick: maxWidth 1080px + quality 72 targets ~300-420KB
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 72,
      );
      if (picked == null) return;
      final file = File(picked.path);
      final bytes = await file.length();
      if (bytes > 4 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Image still too large after compression. Choose a smaller photo.'),
              backgroundColor: kDestructive,
            ),
          );
        }
        return;
      }
      setState(() => _selectedImage = file);
      if (mounted) {
        final kb = (bytes / 1024).round();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image ready (${kb}KB)'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error picking image: $e'),
              backgroundColor: kDestructive),
        );
      }
    }
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _posting = true);
    try {
      final auth = context.read<AuthProvider>();
      final dishes = _dishesCtrl.text
          .split(',')
          .map((d) => d.trim())
          .where((d) => d.isNotEmpty)
          .toList();

      final post = PostModel(
        postId: '',
        userId: auth.uid,
        username: auth.userModel?.username ?? 'User',
        userAvatarUrl: auth.userModel?.avatarUrl ?? '',
        isSuperUser: auth.userModel?.isSuperUser ?? false,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        lat: _pickedLat ?? 0.0,
        lng: _pickedLng ?? 0.0,
        localTips: _tipsCtrl.text.trim(),
        recommendedDishes: dishes,
        category: _selectedCategory,
        createdAt: Timestamp.now(),
      );

      final id = await context
          .read<PostsProvider>()
          .createPost(post, _selectedImage);
      if (id != null && mounted) {
        await _clearDraft();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Post shared!'),
              backgroundColor: Colors.green),
        );
        context.go('/feed');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to post. Please try again.'),
              backgroundColor: kDestructive),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: kDestructive),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }
}

// ── Full-screen map location picker ──────────────────────────────────────────

class _LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const _LocationPickerScreen({this.initial});

  @override
  State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  static const _cairoCenter = LatLng(30.0444, 31.2357);
  LatLng? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kDark,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Pick Location',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _picked == null ? null : () => Navigator.pop(context, _picked),
            child: Text(
              'Confirm',
              style: TextStyle(
                color: _picked == null ? Colors.white38 : kOrange,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.initial ?? _cairoCenter,
              initialZoom: 14,
              onTap: (_, latLng) => setState(() => _picked = latLng),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}.png?api_key={api_key}',
                additionalOptions: const {'api_key': AppConfig.stadiaApiKey},
                userAgentPackageName: 'com.example.like_a_local',
              ),
              if (_picked != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _picked!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_pin,
                        color: kOrange, size: 40),
                  ),
                ]),
            ],
          ),
          // Instruction banner
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8)
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_outlined,
                      color: kOrange, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _picked == null
                        ? 'Tap anywhere on the map to drop a pin'
                        : 'Tap again to move the pin',
                    style: const TextStyle(fontSize: 13, color: kDark),
                  ),
                ],
              ),
            ),
          ),
          // Coordinates badge
          if (_picked != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: kDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: kOrange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_picked!.latitude.toStringAsFixed(5)}, ${_picked!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

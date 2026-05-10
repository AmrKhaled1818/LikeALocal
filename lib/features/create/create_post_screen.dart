import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../data/models/post_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/posts_provider.dart';

// Freemium limits
const int _kFreePostsPerDay = 3;

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

  final List<File> _selectedImages = [];
  static const int _maxImages = 5;
  String _selectedCategory = 'Restaurant';
  bool _posting = false;
  bool _checkingLimit = true;
  int _todayPostCount = 0;
  double? _pickedLat;
  double? _pickedLng;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDailyLimit());
  }

  Future<void> _checkDailyLimit() async {
    final auth = context.read<AuthProvider>();
    if (auth.uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final uid = auth.uid;
    final resetTime = prefs.getInt('post_reset_$uid') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    int count;
    if (now - resetTime >= 24 * 60 * 60 * 1000) {
      count = 0;
      await prefs.setInt('post_count_$uid', 0);
      await prefs.setInt('post_reset_$uid', now);
    } else {
      count = prefs.getInt('post_count_$uid') ?? 0;
    }
    if (mounted) {
      setState(() {
        _todayPostCount = count;
        _checkingLimit = false;
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
    final auth = context.watch<AuthProvider>();
    final isSuperUser = auth.userModel?.isSuperUser ?? false;
    final limitReached =
        !isSuperUser && _todayPostCount >= _kFreePostsPerDay;
    final canPost = !_posting && !_checkingLimit && !limitReached;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 90,
        leading: TextButton(
          onPressed: _cancelPost,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white, fontSize: 14),
            softWrap: false,
            overflow: TextOverflow.clip,
          ),
        ),
        title: const Text('New Post',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _posting || _checkingLimit
                ? const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)),
                  )
                : ElevatedButton(
                    onPressed: canPost ? _submitPost : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canPost ? kOrange : kMutedFg,
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
              // Freemium limit banner
              if (!isSuperUser) _buildFreemiumBanner(limitReached),
              _buildImagePicker(),
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
                      builder: (_) => LocationPickerScreen(
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
                                  fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  additionalOptions: const {
                                    'api_key': AppConfig.stadiaApiKey
                                  },
                                  userAgentPackageName:
                                      'com.likealocal.app',
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

  void _cancelPost() {
    _titleCtrl.clear();
    _descCtrl.clear();
    _locationCtrl.clear();
    _tipsCtrl.clear();
    _dishesCtrl.clear();
    setState(() {
      _selectedImages.clear();
      _pickedLat = null;
      _pickedLng = null;
      _selectedCategory = 'Restaurant';
    });
    context.go('/feed');
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  Widget _buildFreemiumBanner(bool limitReached) {
    final remaining = (_kFreePostsPerDay - _todayPostCount).clamp(0, _kFreePostsPerDay);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: limitReached
              ? [kDestructive.withOpacity(0.08), kDestructive.withOpacity(0.15)]
              : [kAmber.withOpacity(0.08), kOrange.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: limitReached ? kDestructive.withOpacity(0.4) : kAmber.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            limitReached ? Icons.lock_outline : Icons.stars_outlined,
            color: limitReached ? kDestructive : kAmber,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: limitReached
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily post limit reached (3/3)',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: kDestructive)),
                      Text('Earn 100 karma to unlock unlimited posting',
                          style: TextStyle(color: kMutedFg, fontSize: 12)),
                    ],
                  )
                : Text(
                    '$remaining of $_kFreePostsPerDay free posts remaining today',
                    style: const TextStyle(color: kMutedFg, fontSize: 12),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    final remaining = _maxImages - _selectedImages.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedImages.isNotEmpty) ...[
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length + (remaining > 0 ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _selectedImages.length) {
                  return _addMoreButton();
                }
                return _imageThumbnail(i);
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_selectedImages.length}/$_maxImages photos selected',
            style: const TextStyle(color: kMutedFg, fontSize: 12),
          ),
        ] else
          GestureDetector(
            onTap: _addImages,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: kMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kMutedFg.withOpacity(0.3), width: 1.5),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 48, color: kMutedFg),
                  SizedBox(height: 8),
                  Text('Add photos (optional, up to 5)',
                      style: TextStyle(color: kMutedFg, fontSize: 14)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _imageThumbnail(int index) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: index == 0
                ? Border.all(color: kOrange, width: 2)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(_selectedImages[index], fit: BoxFit.cover),
          ),
        ),
        if (index == 0)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: kOrange,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ),
        Positioned(
          top: 2,
          right: 10,
          child: GestureDetector(
            onTap: () => setState(() => _selectedImages.removeAt(index)),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addMoreButton() {
    return GestureDetector(
      onTap: _addImages,
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: kMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kMutedFg.withOpacity(0.3), width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: kMutedFg, size: 24),
            SizedBox(height: 4),
            Text('Add more', style: TextStyle(color: kMutedFg, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Future<void> _addImages() async {
    final remaining = _maxImages - _selectedImages.length;
    if (remaining <= 0) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 72,
      );
      if (picked.isEmpty) return;

      final toAdd = picked.take(remaining).toList();
      final files = <File>[];
      for (final x in toAdd) {
        final file = File(x.path);
        final bytes = await file.length();
        if (bytes > 4 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('One image was too large and was skipped.'),
                backgroundColor: kDestructive,
                duration: Duration(seconds: 2),
              ),
            );
          }
          continue;
        }
        files.add(file);
      }
      if (files.isNotEmpty) setState(() => _selectedImages.addAll(files));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e'), backgroundColor: kDestructive),
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

      // 45-second timeout so we never hang forever (Cloudinary + Firestore)
      final id = await context
          .read<PostsProvider>()
          .createPost(post, _selectedImages)
          .timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw Exception(
              'Upload timed out. Check your connection and try again.');
        },
      );

      if (id != null && mounted) {
        // Increment local post counter for daily limit
        final prefs = await SharedPreferences.getInstance();
        final uid = auth.uid;
        final newCount = (prefs.getInt('post_count_$uid') ?? 0) + 1;
        await prefs.setInt('post_count_$uid', newCount);
        Fluttertoast.showToast(
          msg: 'Post shared! Karma +10',
          toastLength: Toast.LENGTH_SHORT,
          backgroundColor: Colors.green,
          textColor: Colors.white,
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
              content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}'),
              backgroundColor: kDestructive,
              duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }
}

// ── Full-screen map location picker ──────────────────────────────────────────

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
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
                fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                additionalOptions: const {'api_key': AppConfig.stadiaApiKey},
                userAgentPackageName: 'com.likealocal.app',
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
                    style: const TextStyle(fontSize: 13, color: null),
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
                  color: null,
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

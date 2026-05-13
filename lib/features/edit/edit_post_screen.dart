import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/toast_utils.dart';
import '../../core/utils/validators.dart';
import '../../data/models/post_model.dart';
import '../../features/create/create_post_screen.dart';
import '../../shared/providers/posts_provider.dart';

class EditPostScreen extends StatefulWidget {
  final PostModel post;
  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _tipsCtrl;
  late final TextEditingController _dishesCtrl;

  // existing images from post (user may remove some)
  late List<String> _keptImageUrls;
  late List<String> _keptImagePublicIds;
  // new local files to upload on save
  final List<XFile> _newImages = [];
  static const int _maxImages = 5;

  late String _selectedCategory;
  late double? _pickedLat;
  late double? _pickedLng;
  bool _saving = false;

  static const _categories = [
    'Restaurant', 'Café', 'Park', 'Viewpoint', 'Shop', 'Mall',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    _titleCtrl = TextEditingController(text: p.title);
    _descCtrl = TextEditingController(text: p.description);
    _locationCtrl = TextEditingController(text: p.location);
    _tipsCtrl = TextEditingController(text: p.localTips);
    _dishesCtrl = TextEditingController(text: p.recommendedDishes.join(', '));
    _selectedCategory = p.category;
    _pickedLat = p.lat != 0 ? p.lat : null;
    _pickedLng = p.lng != 0 ? p.lng : null;
    _keptImageUrls = List<String>.from(p.allImageUrls);
    _keptImagePublicIds = List<String>.from(p.imagePublicIds);
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
      appBar: AppBar(
        leadingWidth: 90,
        leading: TextButton(
          onPressed: () => context.pop(),
          child: const Text('Cancel',
              style: TextStyle(color: Colors.white, fontSize: 14)),
        ),
        title: const Text('Edit Post',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _saving
                ? const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)))
                : ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kOrange,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Save',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
          ),
        ],
      ),
      body: ResponsiveBody(
        maxWidth: AppBreakpoints.maxFormWidth,
        child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageSection(),
              const SizedBox(height: 20),

              _label('Caption'),
              TextFormField(
                controller: _titleCtrl,
                maxLength: 500,
                validator: (v) => Validators.validateNotEmpty(v, 'Title'),
                decoration: const InputDecoration(
                  hintText: 'Share what makes this place special...',
                ),
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

              _label('Location'),
              TextFormField(
                controller: _locationCtrl,
                validator: (v) => Validators.validateNotEmpty(v, 'Location'),
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
                      color: _pickedLat != null
                          ? kOrange
                          : kMutedFg.withValues(alpha: 0.3),
                      width: _pickedLat != null ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _pickedLat != null
                      ? Stack(
                          children: [
                            FlutterMap(
                              options: MapOptions(
                                initialCenter:
                                    LatLng(_pickedLat!, _pickedLng!),
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.pin_drop_outlined,
                                color: kMutedFg, size: 20),
                            SizedBox(width: 8),
                            Text('Tap to pin location on map',
                                style:
                                    TextStyle(color: kMutedFg, fontSize: 14)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

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
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected ? kOrange : kMuted,
                        borderRadius: BorderRadius.circular(8),
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

              _label('Local Tips (optional)'),
              TextFormField(
                controller: _tipsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Any insider knowledge?',
                ),
              ),
              const SizedBox(height: 14),

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
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      );

  int get _totalImages => _keptImageUrls.length + _newImages.length;

  Widget _buildImageSection() {
    final canAdd = _totalImages < _maxImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_totalImages > 0) ...[
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // existing network images
                for (int i = 0; i < _keptImageUrls.length; i++)
                  _existingThumbnail(i),
                // new local files
                for (int i = 0; i < _newImages.length; i++)
                  _newThumbnail(i),
                // add more button
                if (canAdd) _addMoreButton(),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('$_totalImages/$_maxImages photos',
              style: const TextStyle(color: kMutedFg, fontSize: 12)),
        ] else
          GestureDetector(
            onTap: _addImages,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: kMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kMutedFg.withValues(alpha: 0.3), width: 1.5),
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

  Widget _existingThumbnail(int index) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: index == 0 ? Border.all(color: kOrange, width: 2) : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(imageUrl: _keptImageUrls[index], fit: BoxFit.cover),
          ),
        ),
        if (index == 0)
          Positioned(
            bottom: 4, left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(4)),
              child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ),
        Positioned(
          top: 2, right: 10,
          child: GestureDetector(
            onTap: () => setState(() {
              if (index < _keptImagePublicIds.length) _keptImagePublicIds.removeAt(index);
              _keptImageUrls.removeAt(index);
            }),
            child: Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _newThumbnail(int index) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: kIsWeb
                ? Image.network(_newImages[index].path, fit: BoxFit.cover)
                : Image.file(File(_newImages[index].path), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 2, right: 10,
          child: GestureDetector(
            onTap: () => setState(() => _newImages.removeAt(index)),
            child: Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
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
        width: 100, height: 100,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: kMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kMutedFg.withValues(alpha: 0.3), width: 1.5),
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
    final remaining = _maxImages - _totalImages;
    if (remaining <= 0) return;
    try {
      final picked = await ImagePicker().pickMultiImage(
        maxWidth: 1080, maxHeight: 1080, imageQuality: 72,
      );
      if (picked.isEmpty) return;
      final toAdd = picked.take(remaining).toList();
      final files = <XFile>[];
      for (final x in toAdd) {
        if (await x.length() > 4 * 1024 * 1024) continue;
        files.add(x);
      }
      if (files.isNotEmpty) setState(() => _newImages.addAll(files));
    } catch (e) {
      AppToast.error('Error picking images: $e');
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final dishes = _dishesCtrl.text
          .split(',')
          .map((d) => d.trim())
          .where((d) => d.isNotEmpty)
          .toList();

      final updated = widget.post.copyWith(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        lat: _pickedLat ?? 0.0,
        lng: _pickedLng ?? 0.0,
        category: _selectedCategory,
        localTips: _tipsCtrl.text.trim(),
        recommendedDishes: dishes,
        imageUrl: _keptImageUrls.isNotEmpty ? _keptImageUrls.first : '',
        imagePublicId: _keptImagePublicIds.isNotEmpty ? _keptImagePublicIds.first : '',
        imageUrls: _keptImageUrls,
        imagePublicIds: _keptImagePublicIds,
      );

      final ok = await context
          .read<PostsProvider>()
          .updatePost(updated, _newImages);

      if (mounted) {
        if (ok) {
          AppToast.success('Post updated!');
          context.pop();
        } else {
          AppToast.error('Failed to update. Please try again.');
        }
      }
    } catch (e) {
      AppToast.error('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

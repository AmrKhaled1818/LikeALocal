import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
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

  File? _newImage;
  late String _selectedCategory;
  late double? _pickedLat;
  late double? _pickedLng;
  bool _saving = false;

  static const _categories = [
    'Restaurant', 'Bar', 'Café', 'Park', 'Viewpoint', 'Shop',
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
                        color: kMutedFg.withOpacity(0.3), width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _newImage != null
                      ? Image.file(_newImage!, fit: BoxFit.cover)
                      : widget.post.imageUrl.isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: widget.post.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit, color: Colors.white, size: 12),
                                        SizedBox(width: 4),
                                        Text('Change photo',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
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
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      );

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 72,
      );
      if (picked == null) return;
      setState(() => _newImage = File(picked.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e'),
              backgroundColor: kDestructive),
        );
      }
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

      final updated = PostModel(
        postId: widget.post.postId,
        userId: widget.post.userId,
        username: widget.post.username,
        userAvatarUrl: widget.post.userAvatarUrl,
        isSuperUser: widget.post.isSuperUser,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        lat: _pickedLat ?? 0.0,
        lng: _pickedLng ?? 0.0,
        category: _selectedCategory,
        localTips: _tipsCtrl.text.trim(),
        recommendedDishes: dishes,
        imageUrl: widget.post.imageUrl,
        imagePublicId: widget.post.imagePublicId,
        upvotes: widget.post.upvotes,
        downvotes: widget.post.downvotes,
        upvotedBy: widget.post.upvotedBy,
        commentCount: widget.post.commentCount,
        createdAt: widget.post.createdAt,
      );

      final ok = await context
          .read<PostsProvider>()
          .updatePost(updated, _newImage);

      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Post updated!'),
                backgroundColor: Colors.green),
          );
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to update. Please try again.'),
                backgroundColor: kDestructive),
          );
        }
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
      if (mounted) setState(() => _saving = false);
    }
  }
}

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
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

  static const _categories = [
    'Restaurant',
    'Bar',
    'Café',
    'Park',
    'Viewpoint',
    'Shop',
  ];

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
                            Text('Add a photo',
                                style: TextStyle(
                                    color: kMutedFg, fontSize: 14)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Caption
              _label('Caption'),
              TextFormField(
                controller: _titleCtrl,
                validator: (v) =>
                    Validators.validateNotEmpty(v, 'Title'),
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

              // Location
              _label('Location'),
              TextFormField(
                controller: _locationCtrl,
                validator: (v) =>
                    Validators.validateNotEmpty(v, 'Location'),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_on_outlined,
                      color: kMutedFg, size: 20),
                  hintText: 'Where is this hidden gem?',
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
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        imageQuality: 80,
      );
      if (picked == null) return;
      final file = File(picked.path);
      final size = await file.length();
      if (size > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Image too large. Please choose a smaller image.'),
              backgroundColor: kDestructive,
            ),
          );
        }
        return;
      }
      setState(() => _selectedImage = file);
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
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a photo'),
          backgroundColor: kDestructive,
        ),
      );
      return;
    }

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
        localTips: _tipsCtrl.text.trim(),
        recommendedDishes: dishes,
        category: _selectedCategory,
        createdAt: Timestamp.now(),
      );

      final id = await context
          .read<PostsProvider>()
          .createPost(post, _selectedImage);
      if (id != null && mounted) {
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

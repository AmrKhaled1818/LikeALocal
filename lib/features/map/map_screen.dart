import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/post_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/posts_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  StreamSubscription<Position>? _locationSub;
  bool _following = false; // follow-me mode
  bool _startingLocation = false;
  String _selectedCategory = 'All';
  final _searchCtrl = TextEditingController();
  PostModel? _selectedPost;

  static const _cairoCenter = LatLng(30.0444, 31.2357);
  static const _defaultZoom = 15.0;

  static const _categories = ['All', 'Food', 'Cafes', 'Parks', 'Art', 'Shopping'];

  static const _categoryMap = {
    'Food': ['Restaurant', 'Bar'],
    'Cafes': ['Café'],
    'Parks': ['Park'],
    'Art': ['Viewpoint'],
    'Shopping': ['Shop'],
  };

  @override
  void dispose() {
    _locationSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showSnack('Location services are disabled.');
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      _showSnack('Location permission denied. Enable it in device settings.');
      return false;
    }
    return true;
  }

  Future<void> _toggleFollow() async {
    if (_following) {
      // Turn off follow mode
      _locationSub?.cancel();
      _locationSub = null;
      setState(() => _following = false);
      return;
    }

    setState(() => _startingLocation = true);
    if (!await _ensurePermission()) {
      setState(() => _startingLocation = false);
      return;
    }

    // Get initial position immediately
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
        _following = true;
        _startingLocation = false;
      });
      _mapController.move(LatLng(pos.latitude, pos.longitude), _defaultZoom);
    } catch (_) {
      if (mounted) {
        _showSnack('Could not get location.');
        setState(() => _startingLocation = false);
        return;
      }
    }

    // Start live stream
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 metres of movement
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _currentPosition = pos);
      if (_following) {
        _mapController.move(LatLng(pos.latitude, pos.longitude), _mapController.camera.zoom);
      }
    }, onError: (_) {});
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  void _zoomIn() {
    final c = _mapController.camera;
    _mapController.move(c.center, c.zoom + 1);
  }

  void _zoomOut() {
    final c = _mapController.camera;
    _mapController.move(c.center, c.zoom - 1);
  }

  List<PostModel> _getFilteredPosts(List<PostModel> posts) {
    final query = _searchCtrl.text.toLowerCase();
    return posts.where((p) {
      final matchSearch = query.isEmpty ||
          p.title.toLowerCase().contains(query) ||
          p.location.toLowerCase().contains(query);
      final matchCategory = _selectedCategory == 'All' ||
          (_categoryMap[_selectedCategory]?.contains(p.category) ?? false);
      return matchSearch && matchCategory && p.lat != 0;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PostsProvider>(
      builder: (context, posts, _) {
        final filtered = _getFilteredPosts(posts.feedPosts);

        final markers = filtered.map((post) {
          return Marker(
            point: LatLng(post.lat, post.lng),
            width: 36,
            height: 36,
            child: GestureDetector(
              onTap: () => setState(() => _selectedPost = post),
              child: Container(
                decoration: BoxDecoration(
                  color: post.isSuperUser ? kAmber : kOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: (post.isSuperUser ? kAmber : kOrange)
                          .withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.place, color: Colors.white, size: 18),
              ),
            ),
          );
        }).toList();

        if (_currentPosition != null) {
          markers.add(
            Marker(
              point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              width: 24,
              height: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Stack(
          children: [
            // Map — always starts at Cairo
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _cairoCenter,
                initialZoom: _defaultZoom,
                onTap: (_, __) => setState(() => _selectedPost = null),
                onPositionChanged: (_, hasGesture) {
                  // User dragged the map — stop auto-following
                  if (hasGesture && _following) {
                    setState(() => _following = false);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}.png?api_key={api_key}',
                  additionalOptions: const {'api_key': AppConfig.stadiaApiKey},
                  userAgentPackageName: 'com.example.like_a_local',
                  maxZoom: 20,
                ),
                MarkerLayer(markers: markers),
              ],
            ),

            // Search + locate button row
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                hintText: 'Search places...',
                                prefixIcon:
                                    Icon(Icons.search_outlined, color: kMutedFg),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                fillColor: Colors.transparent,
                                filled: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Follow-me button
                        _MapButton(
                          color: _following ? Colors.blue : kOrange,
                          onTap: _toggleFollow,
                          child: _startingLocation
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Icon(
                                  _following
                                      ? Icons.navigation
                                      : Icons.my_location,
                                  color: Colors.white,
                                  size: 20),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Category chips
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final cat = _categories[i];
                        final selected = cat == _selectedCategory;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? kOrange : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: selected ? Colors.white : kDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Zoom buttons — right side
            Positioned(
              right: 12,
              bottom: _selectedPost != null ? 230 : 100,
              child: Column(
                children: [
                  _MapButton(
                    color: Colors.white,
                    onTap: _zoomIn,
                    child: const Icon(Icons.add, color: kDark, size: 22),
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    color: Colors.white,
                    onTap: _zoomOut,
                    child: const Icon(Icons.remove, color: kDark, size: 22),
                  ),
                ],
              ),
            ),

            // Legend — left side
            Positioned(
              left: 12,
              bottom: _selectedPost != null ? 230 : 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendItem(kOrange, 'Regular Post'),
                    const SizedBox(height: 4),
                    _legendItem(kAmber, 'Super User Post'),
                    if (_currentPosition != null) ...[
                      const SizedBox(height: 4),
                      _legendItem(Colors.blue,
                          _following ? 'You (live)' : 'You'),
                    ],
                  ],
                ),
              ),
            ),

            // Selected post bottom sheet
            if (_selectedPost != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _PostBottomSheet(
                  post: _selectedPost!,
                  onClose: () => setState(() => _selectedPost = null),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 5, backgroundColor: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: kDark)),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  const _MapButton(
      {required this.color, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _PostBottomSheet extends StatelessWidget {
  final PostModel post;
  final VoidCallback onClose;

  const _PostBottomSheet({required this.post, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (post.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(Icons.image_not_supported_outlined,
                          color: kMutedFg),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: kMutedFg),
                        Expanded(
                          child: Text(post.location,
                              style: const TextStyle(
                                  color: kMutedFg, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/post/${post.postId}'),
                  child: const Text('View Post'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final auth = context.read<AuthProvider>();
                    context.read<PostsProvider>().savePost(auth.uid, post.postId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Pinned!'),
                          duration: Duration(seconds: 2)),
                    );
                  },
                  icon: const Icon(Icons.bookmark_outline, size: 18),
                  label: const Text('Pin for Later'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

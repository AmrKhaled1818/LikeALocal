import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/post_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/posts_provider.dart';

class MapScreen extends StatefulWidget {
  final String? focusPostId;
  const MapScreen({super.key, this.focusPostId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  StreamSubscription<Position>? _locationSub;
  bool _following = false;
  bool _startingLocation = false;
  String _selectedCategory = 'All';
  final _searchCtrl = TextEditingController();
  PostModel? _selectedPost;
  double? _maxDistanceKm; // F30 — null means no filter

  bool _darkMap = false;
  bool _focusListenerAdded = false;
  bool _showSuggestions = false;

  static const _cairoCenter = LatLng(30.0444, 31.2357);
  static const _defaultZoom = 15.0;

  static const _lightTileUrl =
      'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}.png?api_key={api_key}';
  static const _darkTileUrl =
      'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png?api_key={api_key}';

  static const _categories = ['All', 'Restaurant', 'Bar', 'Café', 'Park', 'Viewpoint', 'Shop'];

  static const _categoryMap = {
    'Restaurant': ['Restaurant'],
    'Bar': ['Bar'],
    'Café': ['Café', 'Cafe'],
    'Park': ['Park'],
    'Viewpoint': ['Viewpoint'],
    'Shop': ['Shop'],
  };

  List<PostModel> _getSuggestions(List<PostModel> allPosts) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    return allPosts
        .where((p) =>
            p.title.toLowerCase().startsWith(q) ||
            p.location.toLowerCase().startsWith(q) ||
            p.title.toLowerCase().contains(q) ||
            p.location.toLowerCase().contains(q))
        .take(6)
        .toList()
      ..sort((a, b) {
        final aStarts = a.title.toLowerCase().startsWith(q) ? 0 : 1;
        final bStarts = b.title.toLowerCase().startsWith(q) ? 0 : 1;
        return aStarts.compareTo(bStarts);
      });
  }

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    if (widget.focusPostId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryFocusPost();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toggleFollow();
      });
    }
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusPostId != oldWidget.focusPostId && widget.focusPostId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryFocusPost();
      });
    }
  }

  // Tries to focus on a post; retries once posts finish loading if needed.
  void _tryFocusPost() {
    if (widget.focusPostId == null || !mounted) return;
    final postsProvider = context.read<PostsProvider>();
    if (!postsProvider.isLoading) {
      _focusOnPost(widget.focusPostId!);
    } else if (!_focusListenerAdded) {
      _focusListenerAdded = true;
      postsProvider.addListener(_onPostsLoaded);
    }
  }

  void _onPostsLoaded() {
    if (!mounted) return;
    final postsProvider = context.read<PostsProvider>();
    if (!postsProvider.isLoading) {
      postsProvider.removeListener(_onPostsLoaded);
      _focusListenerAdded = false;
      _focusOnPost(widget.focusPostId!);
    }
  }

  void _focusOnPost(String postId) {
    final posts = context.read<PostsProvider>();
    final post = posts.getPostById(postId);
    if (post != null && post.lat != 0) {
      setState(() => _selectedPost = post);
      _mapController.move(LatLng(post.lat, post.lng), 16.0);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This post has no map location set.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadMapStyle() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _darkMap = prefs.getBool('map_dark') ?? false);
  }

  Future<void> _toggleMapStyle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _darkMap = !_darkMap);
    await prefs.setBool('map_dark', _darkMap);
  }

  @override
  void dispose() {
    if (_focusListenerAdded) {
      context.read<PostsProvider>().removeListener(_onPostsLoaded);
    }
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

  // F29 — distance from user to post
  double? _distanceKm(PostModel post) {
    if (_currentPosition == null || post.lat == 0) return null;
    final d = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      post.lat,
      post.lng,
    );
    return d / 1000;
  }

  String _fmtDist(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

  List<PostModel> _getFilteredPosts(List<PostModel> posts) {
    final query = _searchCtrl.text.toLowerCase();
    return posts.where((p) {
      final matchSearch = query.isEmpty ||
          p.title.toLowerCase().contains(query) ||
          p.location.toLowerCase().contains(query);
      final matchCategory = _selectedCategory == 'All' ||
          (_categoryMap[_selectedCategory]?.contains(p.category) ?? false);
      final dist = _distanceKm(p);
      final matchDist =
          _maxDistanceKm == null || dist == null || dist <= _maxDistanceKm!;
      return matchSearch && matchCategory && p.lat != 0 && matchDist;
    }).toList();
  }

  // F30 — show distance filter bottom sheet
  void _showDistanceFilter() {
    double sliderVal = _maxDistanceKm ?? 5.0;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filter by Distance',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton(
                    onPressed: () {
                      setState(() => _maxDistanceKm = null);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Clear',
                        style: TextStyle(color: kMutedFg)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Show places within ${sliderVal.toStringAsFixed(1)} km',
                style: const TextStyle(color: kMutedFg, fontSize: 14),
              ),
              Slider(
                value: sliderVal,
                min: 0.5,
                max: 20,
                divisions: 39,
                activeColor: kOrange,
                label: '${sliderVal.toStringAsFixed(1)} km',
                onChanged: (v) => setModal(() => sliderVal = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('0.5 km', style: TextStyle(color: kMutedFg, fontSize: 12)),
                  Text('20 km', style: TextStyle(color: kMutedFg, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _maxDistanceKm = sliderVal);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply Filter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show a scrollable bottom sheet listing all places in the selected category
  void _showCategoryList(String category, List<PostModel> allPosts) {
    final catPosts = allPosts.where((p) {
      return p.lat != 0 &&
          (_categoryMap[category]?.contains(p.category) ?? false);
    }).toList();

    // Sort by distance — nearest first
    catPosts.sort((a, b) {
      final dA = _distanceKm(a);
      final dB = _distanceKm(b);
      if (dA == null && dB == null) return a.title.compareTo(b.title);
      if (dA == null) return 1;
      if (dB == null) return -1;
      return dA.compareTo(dB);
    });

    if (catPosts.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.25,
        maxChildSize: 0.8,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text(
                    '$category (${catPosts.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: null),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, color: kMutedFg, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: catPosts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final post = catPosts[i];
                  final dist = _distanceKm(post);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: kOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.place,
                              color: kOrange, size: 22),
                        ),
                        const SizedBox(width: 12),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(post.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: null),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 11, color: kMutedFg),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(post.location,
                                        style: const TextStyle(
                                            color: kMutedFg, fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  if (dist != null) ...[
                                    const SizedBox(width: 6),
                                    Text(_fmtDist(dist),
                                        style: const TextStyle(
                                            color: kOrange,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Buttons
                        SizedBox(
                          height: 30,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() => _selectedPost = post);
                              _mapController.move(
                                  LatLng(post.lat, post.lng), 16.0);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kOrange,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            child: const Text('Map'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 30,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              context.push('/post/${post.postId}');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kDark,
                              side: const BorderSide(color: kOrange),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            child: const Text('Post'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PostsProvider>(
      builder: (context, posts, _) {
        final filtered = _getFilteredPosts(posts.feedPosts);

        // F29 — Build post markers with distance badges
        final postMarkers = filtered.map((post) {
          final dist = _distanceKm(post);
          final pinColor = post.isSuperUser ? kAmber : kOrange;
          return Marker(
            point: LatLng(post.lat, post.lng),
            width: 60,
            height: dist != null ? 56 : 36,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => setState(() => _selectedPost = post),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: pinColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: pinColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.place,
                        color: Colors.white, size: 18),
                  ),
                  if (dist != null) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 3)
                        ],
                      ),
                      child: Text(
                        _fmtDist(dist),
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: pinColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList();

        // F26 — Pulsing location dot (kept separate from clustered markers)
        final locationMarkers = _currentPosition != null
            ? [
                Marker(
                  point: LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude),
                  width: 40,
                  height: 40,
                  child: const _PulsingDot(),
                ),
              ]
            : <Marker>[];

        return Stack(
          children: [
            // Map — always starts at Cairo
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _cairoCenter,
                initialZoom: _defaultZoom,
                onTap: (_, __) => setState(() {
                  _selectedPost = null;
                  _showSuggestions = false;
                }),
                onPositionChanged: (_, hasGesture) {
                  // User dragged the map — stop auto-following
                  if (hasGesture && _following) {
                    setState(() => _following = false);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _darkMap ? _darkTileUrl : _lightTileUrl,
                  fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  additionalOptions: const {'api_key': AppConfig.stadiaApiKey},
                  userAgentPackageName: 'com.example.like_a_local',
                  maxZoom: 20,
                ),
                // F25 — Clustered post markers
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 45,
                    size: const Size(42, 42),
                    alignment: Alignment.center,
                    markers: postMarkers,
                    builder: (context, clusterMarkers) => Container(
                      decoration: BoxDecoration(
                        color: kOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: kOrange.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          clusterMarkers.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // F26 — Pulsing dot is never clustered
                MarkerLayer(markers: locationMarkers),
              ],
            ),

            // Search + locate button row
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Container(
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
                                  onChanged: (_) => setState(() => _showSuggestions = _searchCtrl.text.isNotEmpty),
                                  onTap: () => setState(() => _showSuggestions = _searchCtrl.text.isNotEmpty),
                                  decoration: InputDecoration(
                                    hintText: 'Search places...',
                                    prefixIcon: const Icon(Icons.search_outlined, color: kMutedFg),
                                    suffixIcon: _searchCtrl.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.close, color: kMutedFg, size: 18),
                                            onPressed: () => setState(() {
                                              _searchCtrl.clear();
                                              _showSuggestions = false;
                                            }),
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    fillColor: Colors.transparent,
                                    filled: true,
                                  ),
                                ),
                              ),
                              // Autocomplete suggestions dropdown
                              if (_showSuggestions)
                                Consumer<PostsProvider>(
                                  builder: (_, postsP, __) {
                                    final suggestions = _getSuggestions(postsP.feedPosts);
                                    if (suggestions.isEmpty) return const SizedBox.shrink();
                                    return Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.12),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: suggestions.map((post) {
                                          return InkWell(
                                            onTap: () {
                                              _searchCtrl.text = post.title;
                                              setState(() => _showSuggestions = false);
                                              if (post.lat != 0) {
                                                _mapController.move(LatLng(post.lat, post.lng), 16.0);
                                                setState(() => _selectedPost = post);
                                              }
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.place, color: kOrange, size: 16),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          post.title,
                                                          style: const TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              fontSize: 13,
                                                              color: null),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        Text(
                                                          post.location,
                                                          style: const TextStyle(
                                                              color: kMutedFg, fontSize: 11),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Text(
                                                    post.category,
                                                    style: const TextStyle(color: kMutedFg, fontSize: 11),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    );
                                  },
                                ),
                            ],
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
                        // Count posts matching this category
                        final allPosts = posts.feedPosts.where((p) => p.lat != 0).toList();
                        final count = cat == 'All'
                            ? allPosts.length
                            : allPosts.where((p) =>
                                _categoryMap[cat]?.contains(p.category) ?? false).length;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedCategory = cat);
                            if (cat != 'All') {
                              _showCategoryList(cat, posts.feedPosts);
                            }
                          },
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cat,
                                  style: TextStyle(
                                    color: selected ? Colors.white : kDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (count > 0) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.white.withValues(alpha: 0.3)
                                          : kOrange.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        color: selected ? Colors.white : kOrange,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Zoom + distance filter buttons — right side
            Positioned(
              right: 12,
              bottom: _selectedPost != null ? 230 : 100,
              child: Column(
                children: [
                  _MapButton(
                    color: Colors.white,
                    onTap: _zoomIn,
                    child: const Icon(Icons.add, color: Colors.black87, size: 22),
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    color: Colors.white,
                    onTap: _zoomOut,
                    child: const Icon(Icons.remove, color: Colors.black87, size: 22),
                  ),
                  const SizedBox(height: 8),
                  // F30 — distance filter button
                  _MapButton(
                    color: _maxDistanceKm != null ? kOrange : Colors.white,
                    onTap: _showDistanceFilter,
                    child: Icon(Icons.social_distance_outlined,
                        color: _maxDistanceKm != null ? Colors.white : kDark,
                        size: 20),
                  ),
                  const SizedBox(height: 8),
                  // F27 — map style toggle
                  _MapButton(
                    color: _darkMap ? const Color(0xFF1F2937) : Colors.white,
                    onTap: _toggleMapStyle,
                    child: Icon(
                      _darkMap ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      color: _darkMap ? Colors.white : kDark,
                      size: 20,
                    ),
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
                  color: Theme.of(context).colorScheme.surface,
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
        Text(label, style: const TextStyle(fontSize: 11)),
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

// F26 — Pulsing location dot
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing ring
          Container(
            width: 20 + _anim.value * 20,
            height: 20 + _anim.value * 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.25 * (1 - _anim.value)),
            ),
          ),
          // Inner dot
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.blue.withOpacity(0.5), blurRadius: 6),
              ],
            ),
          ),
        ],
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              if (post.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: double.infinity,
                      height: 150,
                      color: const Color(0xFFF3F4F6),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_not_supported_outlined, color: kMutedFg, size: 32),
                            SizedBox(height: 8),
                            Text('No image found or link broken', style: TextStyle(color: kMutedFg, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                  radius: 16,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close, size: 18, color: Colors.black87),
                    onPressed: onClose,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(post.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: kMutedFg),
              const SizedBox(width: 4),
              Expanded(
                child: Text(post.location,
                    style: const TextStyle(color: kMutedFg, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
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
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    final posts = context.read<PostsProvider>();
                    final isSuperUser = auth.userModel?.isSuperUser ?? false;
                    if (!isSuperUser) {
                      final saved = await posts.getSavedPosts(auth.uid);
                      if (!context.mounted) return;
                      if (saved.length >= 5) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Save limit reached (5/5). Earn 100 karma to unlock unlimited saves.'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                        return;
                      }
                    }
                    await posts.savePost(auth.uid, post.postId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Pinned!'),
                            duration: Duration(seconds: 2)),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kDark,
                    side: const BorderSide(color: kOrange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.bookmark_outline, size: 18, color: kOrange),
                  label: const Text('Pin for Later',
                      style: TextStyle(color: null, fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.parse(
                  'https://www.google.com/maps/dir/?api=1'
                  '&destination=${Uri.encodeComponent('${post.title}, ${post.location}')}'
                  '&travelmode=driving',
                );
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (_) {
                  try {
                    await launchUrl(url, mode: LaunchMode.platformDefault);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not open maps. Please fully restart the app (stop & rebuild).'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.directions, size: 18),
              label: const Text('Get Directions',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

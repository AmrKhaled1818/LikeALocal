import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/trip_planner_util.dart';
import '../../core/utils/vibe_score.dart';
import '../../data/models/post_model.dart';
import '../../data/models/trip_plan.dart';
import '../../data/services/ai_service.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/posts_provider.dart';
import '../../shared/widgets/crowd_badge.dart';
import '../../shared/widgets/vibe_badge.dart';

const _kPlanKey = 'last_trip_plan';

String _fmtMins(int mins) {
  if (mins < 60) return '$mins min';
  final h = mins ~/ 60;
  final m = mins % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}min';
}

class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({super.key});

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  // Form state
  int _minutes = 120;
  String _mood = '';
  String _budget = '';
  List<String> _categories = [];
  String _groupSize = '';
  String _transport = '';
  String _timeOfDay = '';
  double? _startLat;
  double? _startLng;

  // UI state
  bool _locating = false;
  bool _planning = false;
  bool _hasSavedPlan = false;

  // Results
  List<TripStop>? _stops;
  Map<String, PostModel> _byId = {};

  static const _timeOptions = [60, 120, 180, 240];
  static const _timeLabels = ['1 hr', '2 hrs', '3 hrs', '4 hrs'];
  static const _budgetOptions = ['', 'cheap', 'mid-range', 'fine dining'];
  static const _budgetLabels = ['Any', 'Budget', 'Mid-range', 'Fine Dining'];
  static const _categoryOptions = [
    'Restaurant', 'Café', 'Bar', 'Park', 'Viewpoint', 'Shop'
  ];
  static const _groupOptions = ['', 'solo', 'couple', 'small group', 'big group'];
  static const _groupLabels = ['Any', 'Solo', 'Couple', 'Small group (3–5)', 'Big group (6+)'];
  static const _transportOptions = ['', 'walking', 'short rides'];
  static const _transportLabels = ['Any', 'Walking only', 'Short rides OK'];
  static const _timeOfDayOptions = ['', 'morning', 'afternoon', 'evening', 'night'];
  static const _timeOfDayLabels = ['Any time', 'Morning', 'Afternoon', 'Evening', 'Night out'];

  @override
  void initState() {
    super.initState();
    _checkSavedPlan();
  }

  Future<void> _checkSavedPlan() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted && prefs.containsKey(_kPlanKey)) {
      setState(() => _hasSavedPlan = true);
    }
  }

  Future<void> _savePlan(List<TripStop> stops) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPlanKey,
      jsonEncode({
        'stops': stops.map((s) => s.toJson()).toList(),
        'minutes': _minutes,
        'mood': _mood,
        'budget': _budget,
        'categories': _categories,
        'groupSize': _groupSize,
        'transport': _transport,
        'timeOfDay': _timeOfDay,
        'startLat': _startLat,
        'startLng': _startLng,
      }),
    );
    if (mounted) setState(() => _hasSavedPlan = true);
  }

  Future<void> _loadLastPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPlanKey);
    if (saved == null) return;
    try {
      final data = jsonDecode(saved) as Map<String, dynamic>;
      final stops = (data['stops'] as List)
          .map((e) => TripStop.fromJson(e as Map<String, dynamic>))
          .toList();
      final candidates = context.read<PostsProvider>().feedPosts;
      if (candidates.isEmpty) {
        _showSnack('Load the feed first, then try again.');
        return;
      }
      final byId = {for (final p in candidates) p.postId: p};
      final valid = stops.where((s) => byId.containsKey(s.postId)).toList();
      if (valid.isEmpty) {
        _showSnack('Saved plan places are no longer available.');
        return;
      }
      setState(() {
        _minutes = (data['minutes'] as num?)?.toInt() ?? 120;
        _mood = data['mood'] as String? ?? '';
        _budget = data['budget'] as String? ?? '';
        _categories = (data['categories'] as List?)?.cast<String>() ?? [];
        _groupSize = data['groupSize'] as String? ?? '';
        _transport = data['transport'] as String? ?? '';
        _timeOfDay = data['timeOfDay'] as String? ?? '';
        _startLat = (data['startLat'] as num?)?.toDouble();
        _startLng = (data['startLng'] as num?)?.toDouble();
        _byId = byId;
        _stops = valid;
      });
    } catch (_) {
      _showSnack('Could not load saved plan.');
    }
  }

  Future<void> _getLocation() async {
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Location services are disabled.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('Location permission denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) {
        setState(() {
          _startLat = pos.latitude;
          _startLng = pos.longitude;
        });
      }
    } catch (_) {
      _showSnack('Could not get location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _planTrip() async {
    final candidates = context.read<PostsProvider>().feedPosts;
    if (candidates.isEmpty) {
      _showSnack('Load the feed first, then come back to plan a trip.');
      return;
    }
    setState(() => _planning = true);
    try {
      var stops = await AIService().planTrip(
        candidates: candidates,
        minutesAvailable: _minutes,
        mood: _mood,
        budget: _budget,
        startLat: _startLat,
        startLng: _startLng,
        categories: _categories,
        groupSize: _groupSize,
        transport: _transport,
        timeOfDay: _timeOfDay,
      );
      if (stops.isEmpty) {
        stops = greedyItinerary(
          candidates,
          startLat: _startLat,
          startLng: _startLng,
          minutesAvailable: _minutes,
          mood: _mood,
          preferredCategories: _categories,
        );
      }
      final byId = {for (final p in candidates) p.postId: p};
      if (mounted) {
        setState(() {
          _stops = stops;
          _byId = byId;
        });
        await _savePlan(stops);
      }
    } catch (_) {
      _showSnack('Planning failed — please try again.');
    } finally {
      if (mounted) setState(() => _planning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Trip Planner',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_stops != null)
            TextButton(
              onPressed: () => setState(() => _stops = null),
              child: const Text('New Trip',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _stops != null ? _buildResults() : _buildForm(),
    );
  }

  // ── Form ─────────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.route_outlined, color: kOrange, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plan Your Day Out',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text(
                        'Tell us what you want and AI will build the perfect route.',
                        style: TextStyle(color: kMutedFg, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // 1. Time budget
          _sectionLabel('How much time do you have?'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_timeOptions.length, (i) {
              final sel = _minutes == _timeOptions[i];
              return ChoiceChip(
                label: Text(_timeLabels[i]),
                selected: sel,
                onSelected: (_) =>
                    setState(() => _minutes = _timeOptions[i]),
                selectedColor: kOrange,
                labelStyle: TextStyle(
                  color: sel ? Colors.white : null,
                  fontWeight: FontWeight.w500,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // 2. Categories (multi-select)
          _sectionLabel('What kind of places? (pick all that apply)'),
          const SizedBox(height: 4),
          const Text('Leave empty for all types',
              style: TextStyle(color: kMutedFg, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categoryOptions.map((cat) {
              final sel = _categories.contains(cat);
              return FilterChip(
                label: Text(cat),
                selected: sel,
                onSelected: (v) => setState(() {
                  if (v) {
                    _categories.add(cat);
                  } else {
                    _categories.remove(cat);
                  }
                }),
                selectedColor: kOrange.withValues(alpha: 0.12),
                checkmarkColor: kOrange,
                labelStyle: TextStyle(
                  color: sel ? kOrange : null,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: sel ? kOrange : kMutedFg.withValues(alpha: 0.4),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 3. Mood / vibe
          _sectionLabel("What's your vibe today?"),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Any'),
                selected: _mood.isEmpty,
                onSelected: (_) => setState(() => _mood = ''),
                selectedColor: kOrange,
                labelStyle: TextStyle(
                  color: _mood.isEmpty ? Colors.white : null,
                  fontWeight: FontWeight.w500,
                ),
              ),
              ...kMoods.map((m) {
                final sel = _mood == m;
                return ChoiceChip(
                  label: Text(kMoodLabels[m] ?? m),
                  selected: sel,
                  onSelected: (_) => setState(() => _mood = m),
                  selectedColor: kOrange,
                  labelStyle: TextStyle(
                    color: sel ? Colors.white : null,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 24),

          // 4. Group size
          _sectionLabel("Who's coming?"),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_groupOptions.length, (i) {
              final sel = _groupSize == _groupOptions[i];
              return ChoiceChip(
                label: Text(_groupLabels[i]),
                selected: sel,
                onSelected: (_) =>
                    setState(() => _groupSize = _groupOptions[i]),
                selectedColor: kOrange,
                labelStyle: TextStyle(
                  color: sel ? Colors.white : null,
                  fontWeight: FontWeight.w500,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // 5. Budget
          _sectionLabel('Budget?'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_budgetOptions.length, (i) {
              final sel = _budget == _budgetOptions[i];
              return ChoiceChip(
                label: Text(_budgetLabels[i]),
                selected: sel,
                onSelected: (_) =>
                    setState(() => _budget = _budgetOptions[i]),
                selectedColor: kOrange,
                labelStyle: TextStyle(
                  color: sel ? Colors.white : null,
                  fontWeight: FontWeight.w500,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // 6. Transport preference
          _sectionLabel('How do you prefer to get around?'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_transportOptions.length, (i) {
              final sel = _transport == _transportOptions[i];
              return ChoiceChip(
                label: Text(_transportLabels[i]),
                selected: sel,
                onSelected: (_) =>
                    setState(() => _transport = _transportOptions[i]),
                selectedColor: kOrange,
                labelStyle: TextStyle(
                  color: sel ? Colors.white : null,
                  fontWeight: FontWeight.w500,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // 7. Time of day
          _sectionLabel('What time are you heading out?'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_timeOfDayOptions.length, (i) {
              final sel = _timeOfDay == _timeOfDayOptions[i];
              return ChoiceChip(
                label: Text(_timeOfDayLabels[i]),
                selected: sel,
                onSelected: (_) =>
                    setState(() => _timeOfDay = _timeOfDayOptions[i]),
                selectedColor: kOrange,
                labelStyle: TextStyle(
                  color: sel ? Colors.white : null,
                  fontWeight: FontWeight.w500,
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // 8. Start location
          _sectionLabel('Start point (optional)'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _locating ? null : _getLocation,
            icon: _locating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _startLat != null
                        ? Icons.location_on
                        : Icons.my_location,
                    color: _startLat != null ? kOrange : null,
                  ),
            label: Text(
              _startLat != null
                  ? '${_startLat!.toStringAsFixed(4)}, '
                      '${_startLng!.toStringAsFixed(4)}'
                  : 'Use my current location',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _startLat != null ? kOrange : null,
              side: BorderSide(
                  color: _startLat != null ? kOrange : kMutedFg),
            ),
          ),
          if (_startLat != null)
            TextButton.icon(
              onPressed: () => setState(() {
                _startLat = null;
                _startLng = null;
              }),
              icon: const Icon(Icons.clear, size: 14, color: kMutedFg),
              label: const Text('Remove',
                  style: TextStyle(color: kMutedFg, fontSize: 12)),
            ),

          const SizedBox(height: 40),

          // Build button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _planning ? null : _planTrip,
              icon: _planning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, color: Colors.white),
              label: Text(
                _planning ? 'Building your trip...' : 'Build My Trip',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kOrange,
                disabledBackgroundColor: kOrange.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // View last plan button
          if (_hasSavedPlan) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadLastPlan,
                icon: const Icon(Icons.history, size: 18, color: kOrange),
                label: const Text(
                  'View My Last Plan',
                  style: TextStyle(
                      color: kOrange, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: kOrange),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Results ───────────────────────────────────────────────────────────────

  Widget _buildResults() {
    final validStops = _stops!
        .where((s) => _byId.containsKey(s.postId))
        .toList();

    if (validStops.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: kMutedFg),
            const SizedBox(height: 12),
            const Text('No matching places found.',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _stops = null),
              child: const Text('Try different settings'),
            ),
          ],
        ),
      );
    }

    final mapPoints = <LatLng>[];
    if (_startLat != null && _startLng != null) {
      mapPoints.add(LatLng(_startLat!, _startLng!));
    }
    for (final s in validStops) {
      final p = _byId[s.postId]!;
      if (hasCoords(p)) mapPoints.add(LatLng(p.lat, p.lng));
    }

    final showMap = mapPoints.length >= 2;
    final totalMins = estimateTotalMinutes(
      validStops,
      _byId,
      startLat: _startLat,
      startLng: _startLng,
    );
    final prefs = context.read<AuthProvider>().userModel?.preferences;

    return Column(
      children: [
        if (showMap)
          SizedBox(
            height: 230,
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: mapPoints,
                  padding: const EdgeInsets.all(48),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}.png?api_key={api_key}',
                  fallbackUrl:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  additionalOptions: const {
                    'api_key': AppConfig.stadiaApiKey
                  },
                  userAgentPackageName: 'com.likealocal.app',
                ),
                PolylineLayer(polylines: [
                  Polyline(
                    points: mapPoints,
                    color: kOrange,
                    strokeWidth: 3,
                  ),
                ]),
                MarkerLayer(
                  markers: [
                    if (_startLat != null && _startLng != null)
                      Marker(
                        point: LatLng(_startLat!, _startLng!),
                        width: 32,
                        height: 32,
                        child: const Icon(Icons.my_location,
                            color: kOrange, size: 26),
                      ),
                    ...validStops.asMap().entries.expand((e) {
                      final p = _byId[e.value.postId]!;
                      if (!hasCoords(p)) return <Marker>[];
                      return [
                        Marker(
                          point: LatLng(p.lat, p.lng),
                          width: 28,
                          height: 28,
                          child: _NumberMarker(number: e.key + 1),
                        ),
                      ];
                    }),
                  ],
                ),
              ],
            ),
          ),

        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: kOrange,
          child: Row(
            children: [
              const Icon(Icons.route, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                '${validStops.length} stop${validStops.length == 1 ? '' : 's'}'
                ' · ~${_fmtMins(totalMins)} total',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_mood.isNotEmpty)
                Text(
                  kMoodLabels[_mood] ?? _mood,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 13),
                ),
            ],
          ),
        ),

        // Stop list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: validStops.length,
            itemBuilder: (_, i) {
              final s = validStops[i];
              final post = _byId[s.postId]!;
              return _StopCard(
                stop: s,
                post: post,
                number: i + 1,
                prefs: prefs,
                mood: _mood,
                isLast: i == validStops.length - 1,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      );
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _NumberMarker extends StatelessWidget {
  final int number;
  const _NumberMarker({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kOrange,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  final TripStop stop;
  final PostModel post;
  final int number;
  final Map<String, dynamic>? prefs;
  final String mood;
  final bool isLast;

  const _StopCard({
    required this.stop,
    required this.post,
    required this.number,
    required this.prefs,
    required this.mood,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final vibeScore = VibeScore.forPost(post, prefs, mood: mood);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                _NumberMarker(number: number),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: kOrange.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/post/${post.postId}'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              post.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          VibeBadge(score: vibeScore),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: kOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              post.category,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: kOrange,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.access_time_outlined,
                              size: 12, color: kMutedFg),
                          const SizedBox(width: 3),
                          Text(
                            _fmtMins(stop.stayMinutes),
                            style: const TextStyle(
                                fontSize: 12, color: kMutedFg),
                          ),
                          if (post.location.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: kMutedFg),
                            Expanded(
                              child: Text(
                                post.location,
                                style: const TextStyle(
                                    fontSize: 12, color: kMutedFg),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (stop.note.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.directions_walk_outlined,
                                size: 13, color: kMutedFg),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                stop.note,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kMutedFg,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      CrowdBadge(post: post),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'models/post_model.dart';

/// Pre-defined curated places to seed into the app.
/// These are added to Firestore on first run (or on demand)
/// so they appear as posts on the feed & map with correct coordinates.
class SeedPlaces {
  static const _seedUserId = 'like_a_local_official';
  static const _seedUsername = 'LikeALocal';
  static const _seedAvatar = '';

  /// Helper factory to reduce repetition when creating seed posts.
  static PostModel _createSeedPost({
    required String postId,
    required String title,
    required String description,
    required String localTips,
    required String imageUrl,
    required String location,
    required double lat,
    required double lng,
    required String category,
    List<String> recommendedDishes = const [],
  }) {
    return PostModel(
      postId: postId,
      userId: _seedUserId,
      username: _seedUsername,
      userAvatarUrl: _seedAvatar,
      isSuperUser: true,
      title: title,
      description: description,
      localTips: localTips,
      recommendedDishes: recommendedDishes,
      imageUrl: imageUrl,
      location: location,
      lat: lat,
      lng: lng,
      category: category,
      createdAt: Timestamp.now(),
    );
  }

  static List<PostModel> get all {
    return [
      // ── Batch 1 ────────────────────────────────────────────────
      _createSeedPost(
        postId: 'seed_cfc_mall',
        title: 'Cairo Festival City Mall (CFC)',
        description: 'A premier shopping and entertainment destination featuring international brands, a large IKEA, and a musical fountain.',
        localTips: 'The outdoor \'Village\' area is great for dining at night. Check the fountain show schedule for a great photo op.',
        imageUrl: 'https://images.unsplash.com/photo-1555529669-e69e7aa0ba9a?auto=format&fit=crop&w=1400&q=80',
        location: 'Fifth Settlement, New Cairo',
        lat: 30.0270,
        lng: 31.4080,
        category: 'Mall',
      ),
      _createSeedPost(
        postId: 'seed_kazoku',
        title: 'Kazoku',
        description: 'An upscale contemporary Japanese restaurant known for its minimalist design and high-quality sushi and wagyu beef.',
        localTips: 'Perfect for a date night. Be sure to try the Black Cod and make a reservation early, especially on weekends.',
        imageUrl: 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=1400&q=80',
        location: 'Swan Lake, New Cairo',
        lat: 30.0630,
        lng: 31.4420,
        category: 'Restaurant',
      ),
      _createSeedPost(
        postId: 'seed_zed_park',
        title: 'ZED Park',
        description: 'A massive green park featuring amusement rides, sports facilities, and the \'Winter Wonderland\' event.',
        localTips: 'The ferris wheel offers a panoramic view of Sheikh Zayed. It\'s a great spot for jogging in the early morning.',
        imageUrl: 'https://images.unsplash.com/photo-1563911302283-d2bc129e7570?auto=format&fit=crop&w=1400&q=80',
        location: 'Sheikh Zayed City',
        lat: 30.0240,
        lng: 30.9820,
        category: 'Park',
      ),
      _createSeedPost(
        postId: 'seed_gateway_mall',
        title: 'Gateway Mall',
        description: 'A modern commercial hub in Rehab providing retail therapy, banking services, and high-end cafes.',
        localTips: 'Less crowded than the older Rehab markets; great for a quick coffee meeting or quiet shopping.',
        imageUrl: 'https://images.unsplash.com/photo-1519567241046-7f570eee3ce6?auto=format&fit=crop&w=1400&q=80',
        location: 'Al Rehab City, New Cairo',
        lat: 30.0610,
        lng: 31.4880,
        category: 'Mall',
      ),
      _createSeedPost(
        postId: 'seed_bibliothek',
        title: 'Bibliothek Art Gallery',
        description: 'A cultural space and gallery that hosts contemporary art exhibitions, artist talks, and workshops.',
        localTips: 'Located inside Arkan Plaza, so you can combine an art visit with a high-end dinner or coffee.',
        imageUrl: 'https://images.unsplash.com/photo-1541367777708-7905fe3296c0?auto=format&fit=crop&w=1400&q=80',
        location: 'Arkan Plaza, Sheikh Zayed',
        lat: 30.0210,
        lng: 31.0010,
        category: 'Cultural',
      ),
      _createSeedPost(
        postId: 'seed_30_north',
        title: '30 North',
        description: 'A specialty coffee roastery and cafe known for its high-grade beans and artisanal brewing methods.',
        localTips: 'Try their V60 pour-over. The outdoor seating at Garden 8 is lush and very pet-friendly.',
        imageUrl: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=1400&q=80',
        location: 'Garden 8 Mall, New Cairo',
        lat: 30.0380,
        lng: 31.4450,
        category: 'Café',
      ),
      _createSeedPost(
        postId: 'seed_family_park',
        title: 'Family Park',
        description: 'A 70-acre edutainment park with green landscapes, a miniature train, and science centers for kids.',
        localTips: 'Ideal for a full-day family picnic. There is a small river where you can take boat rides.',
        imageUrl: 'https://images.unsplash.com/photo-1516627145497-ae6968895b74?auto=format&fit=crop&w=1400&q=80',
        location: 'Suez Road, New Cairo',
        lat: 30.0810,
        lng: 31.5030,
        category: 'Park',
      ),
      _createSeedPost(
        postId: 'seed_mall_of_egypt',
        title: 'Mall of Egypt',
        description: 'Home to Ski Egypt (the first indoor ski slope in Africa) and a massive range of luxury fashion brands.',
        localTips: 'If you plan to visit Ski Egypt, wear thick socks. Use the valet service on weekends as parking gets very busy.',
        imageUrl: 'https://images.unsplash.com/photo-1533900298318-6b8da08a523e?auto=format&fit=crop&w=1400&q=80',
        location: '6th of October City',
        lat: 29.9720,
        lng: 31.0180,
        category: 'Mall',
      ),
      _createSeedPost(
        postId: 'seed_opod_cafe',
        title: 'O-Pod Cafe',
        description: 'A futuristic-themed cafe with private pods for a unique social distancing experience or private meetings.',
        localTips: 'Great for remote work if you need a quiet space. The aesthetic is very Instagram-friendly.',
        imageUrl: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=1400&q=80',
        location: 'First Settlement, New Cairo',
        lat: 30.0520,
        lng: 31.4580,
        category: 'Café',
      ),

      // ── Batch 2 ────────────────────────────────────────────────
      _createSeedPost(
        postId: 'seed_tam_gallery',
        title: 'TAM.Gallery',
        description: 'One of the largest contemporary art spaces in Egypt, featuring thousands of artworks by established and emerging Egyptian artists.',
        localTips: 'They frequently host seasonal exhibitions and \'Cairo Art Fair\'. Check their schedule online before visiting.',
        imageUrl: 'https://images.unsplash.com/photo-1561214115-f2f134cc4912?auto=format&fit=crop&w=1400&q=80',
        location: 'Cairo-Alexandria Desert Road (near Sheikh Zayed)',
        lat: 30.0461,
        lng: 30.9852,
        category: 'Cultural',
      ),
      _createSeedPost(
        postId: 'seed_andrea',
        title: 'Andrea El Mariouteya',
        description: 'An iconic Egyptian restaurant famous for its authentic grilled chicken, quail, and fresh oriental meze, situated on a hill with a great view.',
        localTips: 'Go during sunset for the best views overlooking the city. Highly recommended for family lunches.',
        imageUrl: 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=1400&q=80',
        location: 'New Giza, 6th of October City',
        lat: 29.9961,
        lng: 31.0664,
        category: 'Restaurant',
      ),
      _createSeedPost(
        postId: 'seed_brown_nose',
        title: 'Brown Nose Coffee',
        description: 'A trendy specialty coffee shop serving exceptional espresso-based drinks, baked goods, and unique cold brews.',
        localTips: 'Their Flat White is highly rated. The outdoor seating is excellent for casual business meetings or morning reading.',
        imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=1400&q=80',
        location: 'The Waterway 2, Fifth Settlement, New Cairo',
        lat: 30.0384,
        lng: 31.4556,
        category: 'Café',
      ),
      _createSeedPost(
        postId: 'seed_arkan_plaza',
        title: 'Arkan Plaza',
        description: 'A premier commercial and lifestyle hub featuring upscale boutiques, fine dining, and pedestrian-friendly promenades.',
        localTips: 'Arkan is essentially the downtown of Sheikh Zayed. It\'s bustling on weekend evenings, so arrive early for easy parking.',
        imageUrl: 'https://images.unsplash.com/photo-1528698827591-e19ccd7bc23d?auto=format&fit=crop&w=1400&q=80',
        location: 'Sheikh Zayed City',
        lat: 30.0210,
        lng: 31.0010,
        category: 'Mall',
      ),
      _createSeedPost(
        postId: 'seed_picasso_east',
        title: 'Picasso East Art Gallery',
        description: 'A prominent art gallery in East Cairo dedicated to modern and contemporary Egyptian art, showcasing both pioneers and new talents.',
        localTips: 'A very quiet and inspiring space. The gallery owners are highly knowledgeable and happy to discuss the pieces.',
        imageUrl: 'https://images.unsplash.com/photo-1580136608073-b5dd0a7af48c?auto=format&fit=crop&w=1400&q=80',
        location: 'Villa 39 El Narges 3, Fifth Settlement, New Cairo',
        lat: 30.0150,
        lng: 31.4420,
        category: 'Cultural',
      ),
      _createSeedPost(
        postId: 'seed_hyde_park',
        title: 'Hyde Park (The Park)',
        description: 'A massive, lushly landscaped park within the Hyde Park compound, featuring walking trails, wide open green spaces, and recreational areas.',
        localTips: 'Perfect for a long afternoon walk or bringing pets. Check access rules, as some areas may require guest passes.',
        imageUrl: 'https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?auto=format&fit=crop&w=1400&q=80',
        location: 'South 90th Street, New Cairo',
        lat: 30.0075,
        lng: 31.5042,
        category: 'Park',
      ),
      _createSeedPost(
        postId: 'seed_smokery',
        title: 'The Smokery',
        description: 'A fine-dining restaurant offering an exquisite menu of seafood, sushi, and international cuisine, set overlooking a golf course.',
        localTips: 'Dress code is smart casual. An ideal spot for celebrations or romantic dinners due to the beautiful sunset views.',
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=1400&q=80',
        location: 'Katameya Heights, Fifth Settlement, New Cairo',
        lat: 30.0125,
        lng: 31.4053,
        category: 'Restaurant',
      ),
      _createSeedPost(
        postId: 'seed_walk_of_cairo',
        title: 'Walk of Cairo (WOC)',
        description: 'An open-air lifestyle destination blending shopping, dining, and green promenade spaces with interactive art installations.',
        localTips: 'Look out for the Museum of Illusions located here, and take a photo with the giant gorilla statue.',
        imageUrl: 'https://images.unsplash.com/photo-1479839672679-a46483c0e7c8?auto=format&fit=crop&w=1400&q=80',
        location: 'Cairo-Alexandria Desert Road, Sheikh Zayed City',
        lat: 30.0450,
        lng: 30.9650,
        category: 'Park',
      ),
      _createSeedPost(
        postId: 'seed_point_90',
        title: 'Point 90 Mall',
        description: 'A lively mall popular with the university crowd, featuring a large multiplex cinema, fashion retailers, and a wide array of eateries.',
        localTips: 'The Point 90 Cinema is one of the best in New Cairo. The mall gets very busy around the time university classes let out.',
        imageUrl: 'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?auto=format&fit=crop&w=1400&q=80',
        location: 'South 90th Street (Facing AUC), New Cairo',
        lat: 30.0189,
        lng: 31.4981,
        category: 'Mall',
      ),
      _createSeedPost(
        postId: 'seed_qahwa',
        title: 'Qahwa',
        description: 'A popular local cafe chain known for its vibrant atmosphere, hearty breakfast options, and excellent traditional and modern coffee.',
        localTips: 'Their breakfast menu is phenomenal — especially the eggs benedict and pancakes. It gets crowded on Friday mornings.',
        imageUrl: 'https://images.unsplash.com/photo-1521017432531-fbd92d768814?auto=format&fit=crop&w=1400&q=80',
        location: 'The Waterway, Fifth Settlement, New Cairo',
        lat: 30.0390,
        lng: 31.4560,
        category: 'Café',
      ),

      _createSeedPost(
        postId: 'seed_gem_museum',
        title: 'Grand Egyptian Museum (GEM)',
        description:
            'The world\'s largest archaeological museum, home to over 100,000 ancient Egyptian artefacts including the complete treasures of Tutankhamun.',
        localTips:
            'Book tickets online to skip the queue. Arrive early for the Tutankhamun galleries — they get very crowded by midday.',
        imageUrl:
            'https://images.unsplash.com/photo-1694621905584-e13cd7eb0ef7?auto=format&fit=crop&w=1400&q=80',
        location: 'Giza (near the Pyramids)',
        lat: 29.9884,
        lng: 31.1281,
        category: 'Cultural',
      ),

      // Sponsored content example
      PostModel(
        postId: 'seed_sponsored_kempinski',
        userId: _seedUserId,
        username: _seedUsername,
        userAvatarUrl: _seedAvatar,
        isSuperUser: true,
        isSponsoredContent: true,
        title: 'Kempinski Nile Hotel — Rooftop Experience',
        description:
            'Enjoy an exclusive rooftop dining experience at the Kempinski Nile Hotel with breathtaking views of the Nile and the Cairo skyline.',
        localTips:
            'Book the sunset time slot for the best views. The pool bar is open to non-guests with a minimum spend.',
        imageUrl:
            'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1400&q=80',
        location: 'Garden City, Cairo',
        lat: 30.0348,
        lng: 31.2253,
        category: 'Restaurant',
        createdAt: Timestamp.now(),
      ),
    ];
  }

  /// Upload all seed places to Firestore if they don't already exist.
  /// Also patches the [imageUrl] field on any existing seed document whose
  /// stored URL differs from the current value — this fixes previously-seeded
  /// broken / CORS-blocked URLs without requiring a Firestore wipe.
  ///
  /// Returns the number of documents that were newly added.
  static Future<int> seedToFirestore() async {
    final db = FirebaseFirestore.instance;
    final postsCollection = db.collection('posts');
    final placesToSeed = all;
    int added = 0;

    try {
      // 1. Build postId → imageUrl map from the local seed list
      final seedIds = placesToSeed.map((p) => p.postId).toList();

      // 2. Query Firestore once per chunk of 30 (whereIn limit)
      final chunks = <List<String>>[];
      for (var i = 0; i < seedIds.length; i += 30) {
        chunks.add(
          seedIds.sublist(i, i + 30 > seedIds.length ? seedIds.length : i + 30),
        );
      }
      final existingSnapshots = await Future.wait(
        chunks.map(
          (chunk) => postsCollection
              .where(FieldPath.documentId, whereIn: chunk)
              .get(),
        ),
      );
      // Map of existing docId → snapshot data
      final existingDocs = <String, Map<String, dynamic>>{};
      for (final snap in existingSnapshots) {
        for (final doc in snap.docs) {
          existingDocs[doc.id] = doc.data();
        }
      }

      // 3. Build a batch: add missing docs + patch stale imageUrls
      final batch = db.batch();

      for (final place in placesToSeed) {
        final existing = existingDocs[place.postId];
        if (existing == null) {
          // Document does not exist yet — create it
          batch.set(postsCollection.doc(place.postId), place.toMap());
          added++;
        } else {
          // Document exists — patch imageUrl/imageUrls or category if stale
          final updates = <String, dynamic>{};
          final storedUrl = (existing['imageUrl'] as String?) ?? '';
          if (storedUrl != place.imageUrl) {
            updates['imageUrl'] = place.imageUrl;
            // Always keep imageUrls in sync so allImageUrls reads the right URL
            updates['imageUrls'] = [place.imageUrl];
          }
          // Also fix imageUrls if it's missing or contains the wrong value
          final storedUrls = List<String>.from(existing['imageUrls'] ?? []);
          if (storedUrls.isEmpty || (storedUrls.length == 1 && storedUrls.first != place.imageUrl)) {
            updates['imageUrls'] = [place.imageUrl];
          }
          final storedCat = (existing['category'] as String?) ?? '';
          if (storedCat != place.category) updates['category'] = place.category;
          if (updates.isNotEmpty) {
            batch.update(postsCollection.doc(place.postId), updates);
            debugPrint('[SeedPlaces] Patching ${updates.keys.join(', ')} for ${place.postId}');
          }
        }
      }

      // 4. Commit everything in one round-trip
      await batch.commit();

      if (added > 0) {
        debugPrint(
            '[SeedPlaces] Successfully added $added new places to Firestore.');
      } else {
        debugPrint(
            '[SeedPlaces] All seed places already exist in Firestore. Checked for stale image URLs.');
      }
    } catch (e) {
      debugPrint('[SeedPlaces] Error seeding data to Firestore: $e');
      return 0;
    }

    return added;
  }
}

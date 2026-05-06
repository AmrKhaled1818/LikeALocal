import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/post_model.dart';

/// Pre-defined curated places to seed into the app.
/// These are added to Firestore on first run (or on demand)
/// so they appear as posts on the feed & map with correct coordinates.
class SeedPlaces {
  static const _seedUserId = 'like_a_local_official';
  static const _seedUsername = 'LikeALocal';
  static const _seedAvatar = '';

  static List<PostModel> get all => [
        // ── Batch 1 ────────────────────────────────────────────────
        PostModel(
          postId: 'seed_cfc_mall',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'Cairo Festival City Mall (CFC)',
          description:
              'A premier shopping and entertainment destination featuring international brands, a large IKEA, and a musical fountain.',
          localTips:
              'The outdoor \'Village\' area is great for dining at night. Check the fountain show schedule for a great photo op.',
          imageUrl:
              'https://www.festivalcitymallcairo.com/images/default-source/default-album/cfc-mall.jpg',
          location: 'Fifth Settlement, New Cairo',
          lat: 30.0270,
          lng: 31.4080,
          category: 'Shop',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_gem_museum',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'Grand Egyptian Museum (GEM)',
          description:
              'The world\'s largest archaeological museum dedicated to a single civilization, housing the full Tutankhamun collection.',
          localTips:
              'Book tickets online in advance to access the Grand Staircase and commercial area. The view of the Pyramids from the windows is unmatched.',
          imageUrl: 'https://visit-gem.com/gem_facade.jpg',
          location: 'Giza (near 6th of October City)',
          lat: 29.9944,
          lng: 31.1195,
          category: 'Viewpoint',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_kazoku',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'Kazoku',
          description:
              'An upscale contemporary Japanese restaurant known for its minimalist design and high-quality sushi and wagyu beef.',
          localTips:
              'Perfect for a date night. Be sure to try the Black Cod and make a reservation early, especially on weekends.',
          imageUrl: 'https://kazokuegypt.com/gallery/interior.jpg',
          location: 'Swan Lake, New Cairo',
          lat: 30.0630,
          lng: 31.4420,
          category: 'Restaurant',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_zed_park',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'ZED Park',
          description:
              'A massive green park featuring amusement rides, sports facilities, and the \'Winter Wonderland\' event.',
          localTips:
              'The ferris wheel offers a panoramic view of Sheikh Zayed. It\'s a great spot for jogging in the early morning.',
          imageUrl: 'https://oradevelopers.com/zed-park-hero.jpg',
          location: 'Sheikh Zayed City',
          lat: 30.0240,
          lng: 30.9820,
          category: 'Park',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_gateway_mall',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'Gateway Mall',
          description:
              'A modern commercial hub in Rehab providing retail therapy, banking services, and high-end cafes.',
          localTips:
              'Less crowded than the older Rehab markets; great for a quick coffee meeting or quiet shopping.',
          imageUrl:
              'https://talaatmoustafa.com/gateway-mall-rehab.jpg',
          location: 'Al Rehab City, New Cairo',
          lat: 30.0610,
          lng: 31.4880,
          category: 'Shop',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_bibliothek',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'Bibliothek Art Gallery',
          description:
              'A cultural space and gallery that hosts contemporary art exhibitions, artist talks, and workshops.',
          localTips:
              'Located inside Arkan Plaza, so you can combine an art visit with a high-end dinner or coffee.',
          imageUrl: 'https://bibliothek-eg.com/gallery_main.jpg',
          location: 'Arkan Plaza, Sheikh Zayed',
          lat: 30.0210,
          lng: 31.0010,
          category: 'Viewpoint',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_30_north',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: '30 North',
          description:
              'A specialty coffee roastery and cafe known for its high-grade beans and artisanal brewing methods.',
          localTips:
              'Try their V60 pour-over. The outdoor seating at Garden 8 is lush and very pet-friendly.',
          imageUrl: 'https://30north.coffee/garden8_cafe.jpg',
          location: 'Garden 8 Mall, New Cairo',
          lat: 30.0380,
          lng: 31.4450,
          category: 'Café',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_family_park',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'Family Park',
          description:
              'A 70-acre edutainment park with green landscapes, a miniature train, and science centers for kids.',
          localTips:
              'Ideal for a full-day family picnic. There is a small river where you can take boat rides.',
          imageUrl:
              'https://sitesint.com/projects/familypark_aerial.jpg',
          location: 'Suez Road, New Cairo',
          lat: 30.0810,
          lng: 31.5030,
          category: 'Park',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_mall_of_egypt',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'Mall of Egypt',
          description:
              'Home to Ski Egypt (the first indoor ski slope in Africa) and a massive range of luxury fashion brands.',
          localTips:
              'If you plan to visit Ski Egypt, wear thick socks. Use the valet service on weekends as parking gets very busy.',
          imageUrl:
              'https://www.mallofegypt.com/exterior_main.jpg',
          location: '6th of October City',
          lat: 29.9720,
          lng: 31.0180,
          category: 'Shop',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_opod_cafe',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'O-Pod Cafe',
          description:
              'A futuristic-themed cafe with private \'pods\' for a unique social distancing experience or private meetings.',
          localTips:
              'Great for remote work if you need a quiet space. The aesthetic is very Instagram-friendly.',
          imageUrl: 'https://example.com/opod_cafe_cairo.jpg',
          location: 'First Settlement, New Cairo',
          lat: 30.0520,
          lng: 31.4580,
          category: 'Café',
          createdAt: Timestamp.now(),
        ),

        // ── Batch 2 ────────────────────────────────────────────────
        PostModel(
          postId: 'seed_tam_gallery',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'TAM.Gallery',
          description:
              'One of the largest contemporary art spaces in Egypt, featuring thousands of artworks by established and emerging Egyptian artists.',
          localTips:
              'They frequently host seasonal exhibitions and \'Cairo Art Fair\'. Check their schedule online before visiting.',
          imageUrl:
              'https://tam.gallery/wp-content/uploads/gallery-space.jpg',
          location: 'Cairo-Alexandria Desert Road (near Sheikh Zayed)',
          lat: 30.0461,
          lng: 30.9852,
          category: 'Viewpoint',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_andrea',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'Andrea El Mariouteya',
          description:
              'An iconic Egyptian restaurant famous for its authentic grilled chicken, quail, and fresh oriental meze, situated on a hill with a great view.',
          localTips:
              'Go during sunset for the best views overlooking the city. Highly recommended for family lunches.',
          imageUrl:
              'https://andreaelmariouteya.com/images/newgiza-view.jpg',
          location: 'New Giza, 6th of October City',
          lat: 29.9961,
          lng: 31.0664,
          category: 'Restaurant',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_brown_nose',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'Brown Nose Coffee',
          description:
              'A trendy specialty coffee shop serving exceptional espresso-based drinks, baked goods, and unique cold brews.',
          localTips:
              'Their Flat White is highly rated. The outdoor seating is excellent for casual business meetings or morning reading.',
          imageUrl:
              'https://brownnosecoffee.com/assets/cafe-exterior.jpg',
          location: 'The Waterway 2, Fifth Settlement, New Cairo',
          lat: 30.0384,
          lng: 31.4556,
          category: 'Café',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_arkan_plaza',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'Arkan Plaza',
          description:
              'A premier commercial and lifestyle hub featuring upscale boutiques, fine dining, and pedestrian-friendly promenades.',
          localTips:
              'Arkan is essentially the \'downtown\' of Sheikh Zayed. It\'s bustling on weekend evenings, so arrive early for easy parking.',
          imageUrl: 'https://arkanplaza.com/images/arkan-night.jpg',
          location: 'Sheikh Zayed City',
          lat: 30.0210,
          lng: 31.0010,
          category: 'Shop',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_picasso_east',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'Picasso East Art Gallery',
          description:
              'A prominent art gallery in East Cairo dedicated to modern and contemporary Egyptian art, showcasing both pioneers and new talents.',
          localTips:
              'A very quiet and inspiring space. The gallery owners are highly knowledgeable and happy to discuss the pieces.',
          imageUrl:
              'https://picassoeast.com/images/exhibition-hall.jpg',
          location: 'Villa 39 El Narges 3, Fifth Settlement, New Cairo',
          lat: 30.0150,
          lng: 31.4420,
          category: 'Viewpoint',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_hyde_park',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'Hyde Park (The Park)',
          description:
              'A massive, lushly landscaped park within the Hyde Park compound, featuring walking trails, wide open green spaces, and recreational areas.',
          localTips:
              'Perfect for a long afternoon walk or bringing pets. Check access rules, as some areas may require guest passes.',
          imageUrl:
              'https://hydeparkdevelopments.com/images/the-park-landscape.jpg',
          location: 'South 90th Street, New Cairo',
          lat: 30.0075,
          lng: 31.5042,
          category: 'Park',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_smokery',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'The Smokery',
          description:
              'A fine-dining restaurant offering an exquisite menu of seafood, sushi, and international cuisine, set overlooking a golf course.',
          localTips:
              'Dress code is smart casual. An ideal spot for celebrations or romantic dinners due to the beautiful sunset views.',
          imageUrl:
              'https://thesmokery.com/katameya-golf-view.jpg',
          location: 'Katameya Heights, Fifth Settlement, New Cairo',
          lat: 30.0125,
          lng: 31.4053,
          category: 'Restaurant',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_walk_of_cairo',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'Walk of Cairo (WOC)',
          description:
              'An open-air lifestyle destination blending shopping, dining, and green promenade spaces with interactive art installations.',
          localTips:
              'Look out for the Museum of Illusions located here, and take a photo with the giant gorilla statue.',
          imageUrl:
              'https://walkofcairo.com/images/promenade.jpg',
          location: 'Cairo-Alexandria Desert Road, Sheikh Zayed City',
          lat: 30.0450,
          lng: 30.9650,
          category: 'Park',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_point_90',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'Point 90 Mall',
          description:
              'A lively mall popular with the university crowd, featuring a large multiplex cinema, fashion retailers, and a wide array of eateries.',
          localTips:
              'The Point 90 Cinema is one of the best in New Cairo. The mall gets very busy around the time university classes let out.',
          imageUrl: 'https://point90mall.com/images/facade.jpg',
          location: 'South 90th Street (Facing AUC), New Cairo',
          lat: 30.0189,
          lng: 31.4981,
          category: 'Shop',
          createdAt: Timestamp.now(),
        ),
        PostModel(
          postId: 'seed_qahwa',
          userId: _seedUserId,
          username: _seedUsername,
          userAvatarUrl: _seedAvatar,
          isSuperUser: true,
          title: 'Qahwa',
          description:
              'A popular local cafe chain known for its vibrant atmosphere, hearty breakfast options, and excellent traditional and modern coffee.',
          localTips:
              'Their breakfast menu is phenomenal—especially the eggs benedict and pancakes. It gets crowded on Friday mornings.',
          imageUrl:
              'https://qahwa-eg.com/images/waterway-branch.jpg',
          location: 'The Waterway, Fifth Settlement, New Cairo',
          lat: 30.0390,
          lng: 31.4560,
          category: 'Café',
          createdAt: Timestamp.now(),
        ),
      ];

  /// Upload all seed places to Firestore if they don't already exist.
  static Future<int> seedToFirestore() async {
    final db = FirebaseFirestore.instance;
    int added = 0;

    for (final place in all) {
      final doc = db.collection('posts').doc(place.postId);
      final snap = await doc.get();
      if (!snap.exists) {
        await doc.set(place.toMap());
        added++;
      }
    }
    return added;
  }
}

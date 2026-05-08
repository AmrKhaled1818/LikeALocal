import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/post_model.dart';

/// Opens navigation to [post] using the best available maps app on the device.
/// Tries Google Maps turn-by-turn → geo: URI (any maps app) → web fallback.
Future<void> launchDirections(BuildContext context, PostModel post) async {
  final query = Uri.encodeComponent('${post.title}, ${post.location}');
  final googleNav = Uri.parse('google.navigation:q=$query&mode=d');
  final geoUri = Uri.parse('geo:0,0?q=$query');
  final webUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$query&travelmode=driving');
  try {
    if (await canLaunchUrl(googleNav)) {
      await launchUrl(googleNav);
    } else if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
    } else {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a maps app on this device.')),
      );
    }
  }
}

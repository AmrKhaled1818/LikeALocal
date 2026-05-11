import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';
import '../../core/constants/app_config.dart';

class CloudinaryUploadResult {
  final String imageUrl;
  final String imagePublicId;

  const CloudinaryUploadResult({
    required this.imageUrl,
    required this.imagePublicId,
  });
}

class CloudinaryService {
  static const String _cloudName = AppConfig.cloudinaryCloudName;
  static const String _uploadPreset = AppConfig.cloudinaryUploadPreset;

  Future<CloudinaryUploadResult> uploadImage(File imageFile) async {
    return _upload(imageFile, 'likealocal/posts');
  }

  /// Upload multiple images concurrently. Returns results in the same order.
  Future<List<CloudinaryUploadResult>> uploadImages(List<File> files) async {
    return Future.wait(files.map((f) => _upload(f, 'likealocal/posts')));
  }

  Future<CloudinaryUploadResult> uploadAvatar(File imageFile) async {
    return _upload(imageFile, 'likealocal/avatars');
  }

  Future<CloudinaryUploadResult> _upload(File imageFile, String folder) async {
    if (!await imageFile.exists()) {
      throw Exception('Selected image file does not exist.');
    }

    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      throw Exception(
          'Cloudinary config is missing. Set CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET.');
    }

    final cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);

    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      return CloudinaryUploadResult(
        imageUrl: response.secureUrl,
        imagePublicId: response.publicId,
      );
    } on CloudinaryException catch (e) {
      throw Exception('Cloudinary upload failed: ${e.message}');
    }
  }
}

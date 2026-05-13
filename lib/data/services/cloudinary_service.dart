import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

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

  Future<CloudinaryUploadResult> uploadImage(XFile imageFile) async {
    return _upload(imageFile, 'likealocal/posts');
  }

  /// Upload multiple images concurrently. Returns results in the same order.
  Future<List<CloudinaryUploadResult>> uploadImages(List<XFile> files) async {
    return Future.wait(files.map((f) => _upload(f, 'likealocal/posts')));
  }

  Future<CloudinaryUploadResult> uploadAvatar(XFile imageFile) async {
    return _upload(imageFile, 'likealocal/posts');
  }

  Future<CloudinaryUploadResult> uploadVideo(XFile videoFile) async {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      throw Exception('Cloudinary config is missing.');
    }
    final cloudinary =
        CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
    try {
      CloudinaryFile file;
      if (kIsWeb) {
        final bytes = await videoFile.readAsBytes();
        file = CloudinaryFile.fromBytesData(
          bytes.toList(),
          identifier: videoFile.name,
          folder: 'likealocal/videos',
          resourceType: CloudinaryResourceType.Video,
        );
      } else {
        file = CloudinaryFile.fromFile(
          videoFile.path,
          folder: 'likealocal/videos',
          resourceType: CloudinaryResourceType.Video,
        );
      }
      final response = await cloudinary.uploadFile(file);
      return CloudinaryUploadResult(
        imageUrl: response.secureUrl,
        imagePublicId: response.publicId,
      );
    } on CloudinaryException catch (e) {
      throw Exception('Cloudinary video upload failed: ${e.message}');
    }
  }

  Future<CloudinaryUploadResult> _upload(XFile imageFile, String folder) async {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      throw Exception(
          'Cloudinary config is missing. Set CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET.');
    }

    final cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);

    try {
      CloudinaryFile file;
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        file = CloudinaryFile.fromBytesData(
          bytes.toList(),
          identifier: imageFile.name,
          folder: folder,
          resourceType: CloudinaryResourceType.Image,
        );
      } else {
        file = CloudinaryFile.fromFile(
          imageFile.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Image,
        );
      }
      final response = await cloudinary.uploadFile(file);

      return CloudinaryUploadResult(
        imageUrl: response.secureUrl,
        imagePublicId: response.publicId,
      );
    } on CloudinaryException catch (e) {
      throw Exception('Cloudinary upload failed: ${e.message}');
    }
  }
}

import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryUploadResult {
  final String imageUrl;
  final String imagePublicId;

  const CloudinaryUploadResult({
    required this.imageUrl,
    required this.imagePublicId,
  });
}

class CloudinaryService {
  static const String _cloudName = 'ddcajjlfg';
  static const String _uploadPreset = 'likealocal_unsigned';

  Future<CloudinaryUploadResult> uploadImage(File imageFile) async {
    if (!await imageFile.exists()) {
      throw Exception('Selected image file does not exist.');
    }

    final cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);

    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: 'likealocal/posts',
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

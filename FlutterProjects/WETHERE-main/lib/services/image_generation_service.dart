import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:wethere/utils/image_utils.dart';

class ImageGenerationService {
  // For local testing in emulator/simulator:
  // - Android Emulator: http://10.0.2.2:5000/generate-image
  // - iOS Simulator: http://localhost:5000/generate-image
  // For production/Colab: Use your ngrok URL
  static const String colabUrl = 'http://192.168.12.232:5000/generate-image'; 


  Future<String?> generateAndUploadImage(String title) async {
    try {
      debugPrint('Triggering image generation for: $title');
      
      final response = await http.post(
        Uri.parse(colabUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'title': title}),
      );

      if (response.statusCode == 200) {
        Uint8List bytes = response.bodyBytes;
        
        // Compress image before upload to solve size issues
        bytes = await ImageUtils.compressImage(bytes, quality: 60, maxWidth: 800);
        
        String? downloadUrl;
        
        // 1. Upload to Firebase Storage (Primary)
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('journey_images/${DateTime.now().millisecondsSinceEpoch}.jpg'); // Use .jpg
          
          final uploadTask = await storageRef.putData(bytes).timeout(const Duration(seconds: 30));
          downloadUrl = await uploadTask.ref.getDownloadURL();
          debugPrint('Image uploaded successfully: $downloadUrl');
        } catch (storageError) {
          debugPrint('Firebase Storage upload failed for journey image: $storageError');
          // Fallback: Local server
          try {
            final serverBase = colabUrl.replaceAll('/generate-image', '');
            final request = http.MultipartRequest(
              'POST', 
              Uri.parse('$serverBase/upload-profile-image'),
            );
            request.fields['uid'] = 'journey_${DateTime.now().millisecondsSinceEpoch}';
            request.files.add(http.MultipartFile.fromBytes(
              'image', 
              bytes,
              filename: 'journey.png',
            ));
            
            final streamedResponse = await request.send().timeout(const Duration(seconds: 5));
            final localResponse = await http.Response.fromStream(streamedResponse);
            
            if (localResponse.statusCode == 200) {
              final data = jsonDecode(localResponse.body);
              final path = data['local_path'].toString().replaceAll('\\', '/');
              // If path is like "static/uploads/...", it's already web-accessible
              downloadUrl = '$serverBase/$path';
              debugPrint('Journey image saved locally successfully: $downloadUrl');
            }
          } catch (localError) {
            debugPrint('Local failover also failed for journey: $localError');
          }
        }
        
        return downloadUrl ?? _getOnlineFallback(title);
      } else {
        debugPrint('Failed to generate image: ${response.statusCode} - ${response.body}');
        return _getOnlineFallback(title);
      }
    } catch (e) {
      debugPrint('Error in ImageGenerationService: $e');
      return _getOnlineFallback(title);
    }
  }

  String _getOnlineFallback(String title) {
    // Generate a suitable online image as fallback
    final keyword = title.split(' ').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final fallbackUrl = 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&q=80&w=800&q=$keyword';
    debugPrint('Using fallback online image: $fallbackUrl');
    return fallbackUrl;
  }
}

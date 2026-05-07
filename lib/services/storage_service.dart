import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class StorageService {
  final String cloudName = 'dyamivs35'; 
  final String uploadPreset = 'unidrive_ids';

  Future<String> uploadStudentId(String uid, File imageFile) async {
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'student_ids/$uid' 
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonMap = jsonDecode(responseString);

      if (response.statusCode == 200) {
        return jsonMap['secure_url']; 
      } else {
        throw Exception('Cloudinary error: ${jsonMap['error']['message']}');
      }
    } catch (e) {
      throw Exception('Failed to upload Student ID: ${e.toString()}');
    }
  }
}

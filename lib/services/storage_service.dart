import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();

  factory StorageService() => _instance;

  StorageService._internal();

  // Get app directory for storing files
  Future<Directory> getAppDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final filesDir = Directory('${appDir.path}/files');

    if (!await filesDir.exists()) {
      await filesDir.create(recursive: true);
    }

    return filesDir;
  }

  // Save file to local storage
  Future<String> saveFile(File file, String fileName) async {
    final directory = await getAppDirectory();
    final savedPath = '${directory.path}/$fileName';

    await file.copy(savedPath);
    return savedPath;
  }

  // Delete file from local storage
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // Get file from path
  Future<File?> getFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  // Generate unique filename
  String generateFileName(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_$timestamp';
  }

  // Clear all files (for testing)
  Future<void> clearAllFiles() async {
    final directory = await getAppDirectory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
      await directory.create(recursive: true);
    }
  }
}

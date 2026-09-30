import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/hive_service.dart';
import '../../features/loans/data/loan_models.dart';

class AttachmentService {
  final ImagePicker picker;
  AttachmentService({ImagePicker? picker}) : picker = picker ?? ImagePicker();

  /// Copies an image out of the temporary picker location into app-private storage.
  Future<String?> pickAndSaveImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery,
      maxWidth: 2200, imageQuality: 85);
    if (picked == null) return null;
    final id = const Uuid().v4();
    final directory = Directory('${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}proofs');
    await directory.create(recursive: true);
    final destination = '${directory.path}${Platform.pathSeparator}$id.jpg';
    await File(picked.path).copy(destination);
    await HiveService.attachmentsBox.put(id, AttachmentMetadata(id: id,
      localPath: destination, originalName: picked.name, mimeType: 'image/jpeg',
      createdAt: DateTime.now()));
    return destination;
  }
}

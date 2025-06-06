import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class PhotoService {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> showImagePickerOptions(BuildContext context) async {
    print('📸 Abriendo selector de opciones de imagen...');
    
    return await showModalBottomSheet<File?>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Wrap(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Adjuntar Factura',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selecciona cómo quieres agregar la foto',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: _buildOptionButton(
                            context,
                            icon: Icons.camera_alt_outlined,
                            label: 'Cámara',
                            subtitle: 'Tomar foto',
                            color: Colors.blue,
                            onTap: () async {
                              print('📸 Usuario seleccionó CÁMARA');
                              final file = await _takePicture(); 
                              print('📸 Resultado de cámara: ${file?.path ?? "null"}');
                              if (context.mounted) {
                                Navigator.pop(context, file); 
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildOptionButton(
                            context,
                            icon: Icons.photo_library_outlined,
                            label: 'Galería',
                            subtitle: 'Elegir foto',
                            color: Colors.green,
                            onTap: () async {
                              print('📸 Usuario seleccionó GALERÍA');
                              final file = await _pickFromGallery(); 
                              print('📸 Resultado de galería: ${file?.path ?? "null"}');
                              if (context.mounted) {
                                Navigator.pop(context, file); 
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        print('📸 Usuario canceló selección');
                        Navigator.pop(context); 
                      },
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildOptionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<File?> _takePicture() async {
    try {
      print('📸 Iniciando proceso de tomar foto...');
      
      print('📸 Verificando permisos de cámara...');
      final cameraStatus = await Permission.camera.request();
      print('📸 Estado del permiso de cámara: $cameraStatus');
      
      if (!cameraStatus.isGranted) {
        print('❌ Permiso de cámara DENEGADO');
        throw Exception('PERMISSION_DENIED: Los permisos de cámara fueron denegados');
      }

      print('✅ Permiso de cámara CONCEDIDO, abriendo cámara...');
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
        preferredCameraDevice: CameraDevice.rear,
      );

      print('📸 Imagen capturada: ${image?.path ?? "null"}');

      if (image != null) {
        print('📸 Guardando imagen localmente (desde _takePicture)...');
        // Aquí no guardamos directamente, solo devolvemos el XFile para que sea guardado por un método público si es necesario
        // O, si la lógica es que siempre se guarde tras tomarla, llamamos a saveImageLocally aquí.
        // Por ahora, mantenemos la lógica de devolver el archivo temporal y que la pantalla decida.
        // Para que funcione como antes, donde se guardaba inmediatamente:
        // final savedFile = await saveImageLocally(File(image.path));
        // print('✅ Imagen guardada exitosamente: ${savedFile.path}');
        // return savedFile;
        return File(image.path); // Devolvemos el archivo temporal, la pantalla lo guardará con el nombre final.
      } else {
        print('❌ Usuario canceló la captura de imagen');
        return null;
      }
    } catch (e) {
      print('❌ ERROR tomando foto: $e');
      if (e.toString().contains('PERMISSION_DENIED')) {
        rethrow;
      }
      print('❌ Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  static Future<File?> _pickFromGallery() async {
    try {
      print('📸 Iniciando proceso de seleccionar de galería...');
      
      print('📸 Verificando permisos de almacenamiento...');
      
      bool permissionGranted = false;
      
      if (Platform.isAndroid) {
        print('📸 Intentando permiso photos...');
        PermissionStatus photosStatus = await Permission.photos.request();
        print('📸 Estado photos: $photosStatus');
        
        if (photosStatus.isGranted) {
          permissionGranted = true;
          print('✅ Permiso photos concedido');
        } else {
          print('📸 Photos denegado, intentando permiso storage...');
          PermissionStatus storageStatus = await Permission.storage.request();
          print('📸 Estado storage: $storageStatus');
          
          if (storageStatus.isGranted) {
            permissionGranted = true;
            print('✅ Permiso storage concedido');
          }
        }
      } else {
        print('📸 iOS detectado, solicitando permiso de photos...');
        final status = await Permission.photos.request();
        permissionGranted = status.isGranted;
        print('📸 Estado iOS photos: $status');
      }
      
      if (!permissionGranted) {
        print('❌ Todos los permisos de almacenamiento fueron DENEGADOS');
        print('💡 Sugerencia: Ve a Configuración > Apps > Tu App > Permisos y activa el permiso de almacenamiento/fotos');
        throw Exception('PERMISSION_DENIED: Los permisos de galería fueron denegados');
      }

      print('✅ Permisos concedidos, abriendo galería...');

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      print('📸 Imagen seleccionada: ${image?.path ?? "null"}');

      if (image != null) {
         print('📸 Devolviendo archivo temporal de galería...');
        // Devolvemos el archivo temporal, la pantalla lo guardará con el nombre final.
        return File(image.path);
      } else {
        print('❌ Usuario canceló la selección de imagen');
        return null;
      }
    } catch (e) {
      print('❌ ERROR seleccionando foto de galería: $e');
      if (e.toString().contains('PERMISSION_DENIED')) {
        rethrow;
      }
      print('❌ Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  // MÉTODO HECHO PÚBLICO
  static Future<File> saveImageLocally(File imageFile) async {
    try {
      print('📸 (saveImageLocally) Obteniendo directorio de documentos...');
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/receipts');
      
      print('📸 (saveImageLocally) Directorio de imágenes: ${imagesDir.path}');
      
      if (!await imagesDir.exists()) {
        print('📸 (saveImageLocally) Creando directorio de imágenes...');
        await imagesDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'receipt_$timestamp.jpg'; // Asegurarse de que la extensión sea la correcta
      final localPath = '${imagesDir.path}/$fileName';
      
      print('📸 (saveImageLocally) Copiando imagen ${imageFile.path} a: $localPath');

      final savedFile = await imageFile.copy(localPath);
      print('✅ (saveImageLocally) Imagen guardada exitosamente en: $localPath');
      
      return savedFile;
    } catch (e) {
      print('❌ (saveImageLocally) ERROR guardando imagen localmente: $e');
      rethrow;
    }
  }

  static Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        print('🗑️ Imagen eliminada: $imagePath');
        return true;
      }
    } catch (e) {
      print('❌ Error eliminando imagen: $e');
    }
    return false;
  }

  static Future<bool> imageExists(String imagePath) async {
    if (imagePath.isEmpty) return false;
    final file = File(imagePath);
    return await file.exists();
  }

  static Future<double> getImageSizeMB(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        final bytes = await file.length();
        return bytes / (1024 * 1024); 
      }
    } catch (e) {
      print('❌ Error obteniendo tamaño de imagen: $e');
    }
    return 0.0;
  }
}
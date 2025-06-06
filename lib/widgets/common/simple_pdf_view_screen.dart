// lib/widgets/common/simple_pdf_view_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path/path.dart' as p; // Para obtener el nombre del archivo

class SimplePdfViewScreen extends StatefulWidget {
  final String filePath;

  const SimplePdfViewScreen({super.key, required this.filePath});

  @override
  State<SimplePdfViewScreen> createState() => _SimplePdfViewScreenState();
}

class _SimplePdfViewScreenState extends State<SimplePdfViewScreen> {
  bool _isLoading = true; // Comienza como true
  String _errorMessage = '';
  int? _pages = 0;
  int? _currentPage = 0;
  // PDFViewController? _pdfViewController; // Descomentar si necesitas el controlador

  @override
  void initState() {
    super.initState();
    _verifyFileAndAttemptLoad();
  }

  Future<void> _verifyFileAndAttemptLoad() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true; // Asegurarse de que isLoading esté true al inicio de la carga
      _errorMessage = '';
    });

    File pdfFile = File(widget.filePath);
    bool fileExists = false;
    int fileSize = 0;

    try {
      fileExists = await pdfFile.exists();
      if (fileExists) {
        fileSize = await pdfFile.length();
      }
    } catch (e) {
      print("SimplePdfViewScreen: Excepción al verificar archivo: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Error al acceder a la ruta del archivo: ${e.toString()}";
          _isLoading = false;
        });
      }
      return;
    }

    print("SimplePdfViewScreen: Verificando archivo PDF.");
    print("  Ruta: ${widget.filePath}");
    print("  Existe: $fileExists");
    print("  Tamaño: $fileSize bytes");

    if (!fileExists) {
      if (mounted) {
        setState(() {
          _errorMessage = "El archivo PDF no fue encontrado en la ruta:\n${widget.filePath}";
          _isLoading = false;
        });
      }
      return;
    }

    if (fileSize == 0) {
      if (mounted) {
        setState(() {
          _errorMessage = "El archivo PDF está vacío (0 bytes). Puede que no se haya generado o guardado correctamente.";
          _isLoading = false;
        });
      }
      return;
    }

    // Si el archivo existe y no está vacío, PDFView intentará cargarlo.
    // _isLoading será manejado por los callbacks onRender/onError de PDFView.
    // No es necesario hacer setState aquí para _isLoading si las comprobaciones pasan,
    // ya que el widget PDFView manejará el cambio de estado a través de sus callbacks.
  }

  @override
  Widget build(BuildContext context) {
    String pdfFileName = "Visor PDF";
    try {
      pdfFileName = p.basename(widget.filePath);
    } catch (e) {
      print("Error obteniendo nombre de archivo de la ruta: $e");
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(pdfFileName, style: const TextStyle(fontSize: 16.0)),
        elevation: 2.0,
      ),
      body: Stack(
        children: <Widget>[
          // Solo intenta construir PDFView si no hay errores de pre-verificación
          if (_errorMessage.isEmpty && _isLoading) // Muestra spinner mientras PDFView carga
            const Center(child: CircularProgressIndicator()),
          if (_errorMessage.isEmpty) // Si no hay error de pre-verificación, intenta mostrar PDFView
            PDFView(
              filePath: widget.filePath,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              pageSnap: true,
              fitPolicy: FitPolicy.BOTH,
              preventLinkNavigation: false,
              onViewCreated: (PDFViewController controller) {
                // if (mounted) { _pdfViewController = controller; } // Descomentar si necesitas el controlador
                print("SimplePdfViewScreen: PDFView creado.");
              },
              onRender: (pages) {
                if (mounted) {
                  setState(() {
                    _pages = pages;
                    _isLoading = false; // PDF cargado y renderizado
                    _errorMessage = ''; // Limpiar cualquier error previo
                  });
                }
                print("SimplePdfViewScreen: PDF renderizado. Páginas: $pages");
              },
              onError: (error) {
                if (mounted) {
                  setState(() {
                    _errorMessage = "Error de flutter_pdfview: ${error.toString()}";
                    _isLoading = false; // Error durante la carga/renderizado
                  });
                }
                print("SimplePdfViewScreen: PDFView onError: ${error.toString()}");
              },
              onPageError: (page, error) {
                if (mounted) {
                  setState(() {
                    _errorMessage = "Error de flutter_pdfview en página $page: ${error.toString()}";
                    _isLoading = false; // Error en una página específica
                  });
                }
                print("SimplePdfViewScreen: PDFView onPageError (página $page): ${error.toString()}");
              },
              onPageChanged: (int? page, int? total) {
                if (mounted) {
                  setState(() {
                    _currentPage = page;
                  });
                }
              },
            ),
          // Muestra el mensaje de error si existe Y NO está cargando.
          if (_errorMessage.isNotEmpty && !_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
                    const SizedBox(height: 15),
                    const Text(
                      "No se pudo cargar el PDF:",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: (_pages != null && _pages! > 0 && !_isLoading && _errorMessage.isEmpty)
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              color: Theme.of(context).bottomAppBarTheme.color ?? Colors.black.withOpacity(0.05),
              child: Text(
                "Página ${_currentPage != null ? _currentPage! + 1 : '-'} de $_pages",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
              ),
            )
          : null,
    );
  }
}
// ==============================================================================
// ✂️ EXECUTIVE SQUARE IMAGE CROPPER (WHATSAPP / TELEGRAM STYLE)
// ==============================================================================
// - 100% natural, uncompressed, distortion-free image rendering
// - Automatically covers the square frame initially (BoxFit.cover)
// - Strictly constrained: zero empty spaces / zero gaps allowed inside the frame
// - Unrestricted smooth pan and pinch-to-zoom within image bounds
// - 90° clockwise rotation with auto-recentering and aspect ratio preservation
// - Frosted glass blurred backdrop & margins
// - Crisp high-resolution square image output (RepaintBoundary at 2.5x)
// - 100% overflow-safe responsive action buttons
// ==============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Result object containing the cropped photo in multiple convenient formats
class CroppedImageResult {
  final XFile file;
  final Uint8List bytes;
  final String base64;

  const CroppedImageResult({
    required this.file,
    required this.bytes,
    required this.base64,
  });
}

class SquareImageCropper extends StatefulWidget {
  final Uint8List imageBytes;
  final String title;

  const SquareImageCropper({
    super.key,
    required this.imageBytes,
    this.title = 'تعديل الصورة الشخصية',
  });

  /// Static helper to open the cropper dialog from a [File], [XFile], or [Uint8List]
  static Future<CroppedImageResult?> cropImage(
    BuildContext context, {
    required dynamic imageSource,
    String title = 'تعديل الصورة الشخصية',
  }) async {
    Uint8List? bytes;
    if (imageSource is Uint8List) {
      bytes = imageSource;
    } else if (imageSource is XFile) {
      bytes = await imageSource.readAsBytes();
    } else if (imageSource is File) {
      bytes = await imageSource.readAsBytes();
    } else if (imageSource is String) {
      if (imageSource.startsWith('data:image')) {
        final b64 = imageSource.split(',').last.trim();
        bytes = base64Decode(b64);
      } else {
        final f = File(imageSource);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }
    }

    if (bytes == null || bytes.isEmpty) return null;

    if (!context.mounted) return null;

    return showDialog<CroppedImageResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => SquareImageCropper(
        imageBytes: bytes!,
        title: title,
      ),
    );
  }

  @override
  State<SquareImageCropper> createState() => _SquareImageCropperState();
}

class _SquareImageCropperState extends State<SquareImageCropper> {
  final GlobalKey _cropAreaKey = GlobalKey();
  final TransformationController _transformController =
      TransformationController();

  int _rotationQuarterTurns = 0;
  bool _isProcessing = false;
  int _imgWidth = 0;
  int _imgHeight = 0;
  bool _isImageLoaded = false;
  double _lastCropSize = 0.0;

  @override
  void initState() {
    super.initState();
    _decodeImageDimensions();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _decodeImageDimensions() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _imgWidth = frame.image.width;
          _imgHeight = frame.image.height;
          _isImageLoaded = true;
        });
        if (_lastCropSize > 0) {
          _recenterImage(_lastCropSize);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _imgWidth = 800;
          _imgHeight = 800;
          _isImageLoaded = true;
        });
      }
    }
  }

  void _recenterImage([double? cropSizeParam]) {
    final cropSize = cropSizeParam ?? _lastCropSize;
    if (cropSize <= 0 || _imgWidth <= 0 || _imgHeight <= 0) return;

    final double effW = (_rotationQuarterTurns % 2 == 0 ? _imgWidth : _imgHeight).toDouble();
    final double effH = (_rotationQuarterTurns % 2 == 0 ? _imgHeight : _imgWidth).toDouble();

    // Exact scale factor to cover the square frame with natural aspect ratio
    final double scaleFactor = math.max(cropSize / effW, cropSize / effH);
    final double renderW = effW * scaleFactor;
    final double renderH = effH * scaleFactor;

    final double dx = (cropSize - renderW) / 2.0;
    final double dy = (cropSize - renderH) / 2.0;

    _transformController.value = Matrix4.translationValues(dx, dy, 0.0);
  }

  void _rotateClockwise() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
    _recenterImage();
  }

  void _resetTransform() {
    setState(() {
      _rotationQuarterTurns = 0;
    });
    _recenterImage();
  }

  Future<void> _onSave() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final boundary = _cropAreaKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('تعذر التقاط مساحة الاقتصاص');
      }

      // Render at pixelRatio 2.5 for crisp HD output while keeping file size optimal
      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('تعذر تحويل الصورة المقصوصة');
      }

      final Uint8List croppedBytes = byteData.buffer.asUint8List();
      final String b64String = base64Encode(croppedBytes);

      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/cropped_profile_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(croppedBytes);

      final xFile = XFile(tempFile.path);

      if (mounted) {
        Navigator.of(context).pop(CroppedImageResult(
          file: xFile,
          bytes: croppedBytes,
          base64: b64String,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              textDirection: TextDirection.rtl,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'حدث خطأ أثناء حفظ الصورة: $e',
                    style: GoogleFonts.cairo(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double cropSize = (screenSize.width - 56).clamp(260.0, 340.0);

    if (_lastCropSize != cropSize) {
      _lastCropSize = cropSize;
      if (_isImageLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _recenterImage(cropSize);
        });
      }
    }

    final double effW = (_rotationQuarterTurns % 2 == 0 ? _imgWidth : _imgHeight).toDouble();
    final double effH = (_rotationQuarterTurns % 2 == 0 ? _imgHeight : _imgWidth).toDouble();

    double renderW = cropSize;
    double renderH = cropSize;

    if (_isImageLoaded && effW > 0 && effH > 0) {
      final double scaleFactor = math.max(cropSize / effW, cropSize / effH);
      renderW = effW * scaleFactor;
      renderH = effH * scaleFactor;
    }

    // Inside RotatedBox, width and height match the original unrotated image dimensions
    final double innerW = _rotationQuarterTurns % 2 == 0 ? renderW : renderH;
    final double innerH = _rotationQuarterTurns % 2 == 0 ? renderH : renderW;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1B36).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header: Close Button & Title Capsule
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: [
                    // Close / Cancel Button
                    InkWell(
                      onTap: _isProcessing
                          ? null
                          : () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.0,
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                    // Title Capsule
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFD49B1A),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD49B1A)
                                .withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.crop_rounded,
                            color: Color(0xFFD49B1A),
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.title,
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 36),
                  ],
                ),
                const SizedBox(height: 12),

                // Subtitle Instructions
                Text(
                  'اسحب وكبّر صورتك لتناسب الإطار المربع بدقة',
                  style: GoogleFonts.cairo(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Main Square Viewport Frame with RepaintBoundary & Boundary Constraints
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Frosted Margin & Glow
                    Container(
                      width: cropSize + 10,
                      height: cropSize + 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFD49B1A).withValues(alpha: 0.4),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD49B1A)
                                .withValues(alpha: 0.15),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),

                    // The Exact Cropped Area
                    RepaintBoundary(
                      key: _cropAreaKey,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: cropSize,
                          height: cropSize,
                          color: const Color(0xFF070E1C),
                          child: _isImageLoaded
                              ? InteractiveViewer(
                                  transformationController:
                                      _transformController,
                                  constrained: false,
                                  boundaryMargin: EdgeInsets.zero,
                                  minScale: 1.0,
                                  maxScale: 5.0,
                                  panEnabled: true,
                                  scaleEnabled: true,
                                  panAxis: PanAxis.free,
                                  clipBehavior: Clip.hardEdge,
                                  child: SizedBox(
                                    width: renderW,
                                    height: renderH,
                                    child: RotatedBox(
                                      quarterTurns: _rotationQuarterTurns,
                                      child: Image.memory(
                                        widget.imageBytes,
                                        width: innerW,
                                        height: innerH,
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                      ),
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFD49B1A),
                                  ),
                                ),
                        ),
                      ),
                    ),

                    // Overlay Corner Guides (WhatsApp / Telegram style L-shaped brackets)
                    IgnorePointer(
                      child: SizedBox(
                        width: cropSize,
                        height: cropSize,
                        child: CustomPaint(
                          painter: _SquareCropGuidesPainter(
                            borderColor: const Color(0xFFD49B1A),
                            cornerColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Floating Hint Capsule
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pinch_rounded,
                        color: Color(0xFFD49B1A),
                        size: 15,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'يمكنك التكبير والسحب بإصبعين بحرية',
                        style: GoogleFonts.cairo(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Rotate & Reset Quick Tools
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  textDirection: TextDirection.rtl,
                  children: [
                    InkWell(
                      onTap: _rotateClockwise,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.rotate_right_rounded,
                                color: Color(0xFFD49B1A), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'دوران 90°',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: _resetTransform,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.restart_alt_rounded,
                                color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'إعادة ضبط',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Bottom Action Buttons (100% Overflow-Safe)
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    // Save & Crop Button
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: _isProcessing ? null : _onSave,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD49B1A), Color(0xFFB8820E)],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFFDF7D),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD49B1A)
                                    .withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF0B1B36),
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_rounded,
                                          color: Color(0xFF0B1B36),
                                          size: 19,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'حفظ واقتصاص الصورة',
                                          style: GoogleFonts.cairo(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0B1B36),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Cancel Button
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _isProcessing
                            ? null
                            : () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                              width: 1.0,
                            ),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'إلغاء',
                                style: GoogleFonts.cairo(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter that draws WhatsApp/Telegram style corner brackets and grid lines
class _SquareCropGuidesPainter extends CustomPainter {
  final Color borderColor;
  final Color cornerColor;

  _SquareCropGuidesPainter({
    required this.borderColor,
    required this.cornerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Outer framing border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(14),
      ),
      borderPaint,
    );

    // Corner guides paint
    final cornerPaint = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    const cornerLen = 22.0;

    // Top-Left corner
    canvas.drawLine(
        const Offset(4, 4), const Offset(4 + cornerLen, 4), cornerPaint);
    canvas.drawLine(
        const Offset(4, 4), const Offset(4, 4 + cornerLen), cornerPaint);

    // Top-Right corner
    canvas.drawLine(Offset(size.width - 4, 4),
        Offset(size.width - 4 - cornerLen, 4), cornerPaint);
    canvas.drawLine(Offset(size.width - 4, 4),
        Offset(size.width - 4, 4 + cornerLen), cornerPaint);

    // Bottom-Left corner
    canvas.drawLine(Offset(4, size.height - 4),
        Offset(4 + cornerLen, size.height - 4), cornerPaint);
    canvas.drawLine(Offset(4, size.height - 4),
        Offset(4, size.height - 4 - cornerLen), cornerPaint);

    // Bottom-Right corner
    canvas.drawLine(Offset(size.width - 4, size.height - 4),
        Offset(size.width - 4 - cornerLen, size.height - 4), cornerPaint);
    canvas.drawLine(Offset(size.width - 4, size.height - 4),
        Offset(size.width - 4, size.height - 4 - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

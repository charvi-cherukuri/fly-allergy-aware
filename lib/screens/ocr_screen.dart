import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/product.dart';
import '../models/scan_record.dart';
import 'result_screen.dart';
import 'translate_screen.dart';

/// Read the label instead of the barcode.
///
/// This is the escape hatch for the two failures a barcode scanner cannot fix
/// on its own: a product no database has heard of, and no connection. The
/// recognition runs on the device and needs no network, and the label text is
/// never uploaded. ML Kit does send Google its own diagnostic data — device
/// and app info, timings, error codes — which cannot be switched off; the
/// privacy policy says so.
///
/// ## Why the capture works the way it does
///
/// The dependency set has no `image_picker` and no `camera` package, and
/// `mobile_scanner` 7.4 exposes no raw camera frames — its `barcodes` stream
/// only emits when a *barcode* is decoded, and `analyzeImage` needs a file path
/// this app has no way to produce. So the still is taken from the widget tree:
/// the live preview sits inside a [RepaintBoundary], which is rasterised with
/// `toImage()` and handed to ML Kit through `InputImage.fromBitmap` — the exact
/// route `google_mlkit_commons` documents for that constructor.
///
/// Rasterising a platform texture is not guaranteed on every device, so when it
/// comes back blank the screen falls through to a plainly-labelled manual path
/// rather than failing silently.
class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

enum _Stage { viewfinder, working, review }

class _OcrScreenState extends State<OcrScreen> with WidgetsBindingObserver {
  /// The preview only ever acts as a viewfinder here, so the format list is cut
  /// to a single unlikely one rather than left wide open.
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  final GlobalKey _previewKey = GlobalKey();
  final TextEditingController _textController = TextEditingController();

  _Stage _stage = _Stage.viewfinder;
  String? _captureNote;
  bool _cameraFailed = false;
  bool _englishConfirmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_stage != _Stage.viewfinder) return;
    if (!_controller.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed) {
      _startCamera();
    } else {
      _stopCamera();
    }
  }

  void _startCamera() {
    _controller.start().catchError((Object _) {});
  }

  void _stopCamera() {
    _controller.stop().catchError((Object _) {});
  }

  @override
  void deactivate() {
    _stopCamera();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _recognizer.close();
    _controller.dispose();
    super.dispose();
  }

  /// The photo the text came from, shown beside it for checking.
  String? _photoPath;

  // ------------------------------------------------------------------ capture

  /// Reads a full-resolution photo — from the iPhone camera, with its own
  /// focus and exposure, or from the photo library.
  ///
  /// This is the accurate path. The live-preview capture below rasterises the
  /// on-screen preview, so it only ever has screen resolution, and small print
  /// on a curved package comes out blurred; that is what produced misread
  /// ingredients.
  Future<void> _takePhoto(ImageSource source) async {
    _stopCamera();
    String? recognised;
    String? failure;
    String? path;
    try {
      final XFile? photo = await ImagePicker().pickImage(
        source: source,
        // Ample for small print, without handing ML Kit a 48-megapixel image.
        maxWidth: 3000,
        maxHeight: 3000,
        requestFullMetadata: false,
      );
      if (!mounted) return;
      if (photo == null) {
        _startCamera();
        return;
      }
      path = photo.path;
      setState(() {
        _stage = _Stage.working;
        _captureNote = null;
      });
      final result = await _recognizer.processImage(
        InputImage.fromFilePath(photo.path),
      );
      final text = _tidy(result.text);
      if (text.isEmpty) {
        failure = 'No text found in that photo.';
      } else {
        recognised = text;
      }
    } on Object catch (e) {
      failure = 'The photo could not be read ($e).';
    }
    if (!mounted) return;
    if (recognised == null) {
      setState(() {
        _stage = _Stage.viewfinder;
        _captureNote = '$failure Try again closer, in good light.';
      });
      _startCamera();
      return;
    }
    final String found = recognised;
    _englishConfirmed = false;
    _textController.text = found;
    setState(() {
      _photoPath = path;
      _stage = _Stage.review;
      // Very little text usually means a blurred or partial photo.
      _captureNote = found.length < 40
          ? 'Only a little text was found. If the list is longer, take the '
                'photo again, closer and in good light.'
          : null;
    });
  }

  Future<void> _capture() async {
    // Read anything that needs a BuildContext before the first await.
    final ratio = View.of(context).devicePixelRatio.clamp(1.0, 3.0).toDouble();

    setState(() {
      _stage = _Stage.working;
      _captureNote = null;
    });
    await HapticFeedback.selectionClick();

    String? recognised;
    String? failure;

    try {
      final object = _previewKey.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary) {
        failure = 'The preview was not ready.';
      } else {
        final image = await object.toImage(pixelRatio: ratio);
        final width = image.width;
        final height = image.height;
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();

        if (bytes == null || width == 0 || height == 0) {
          failure = 'Could not read the frame.';
        } else {
          final input = InputImage.fromBitmap(
            bitmap: bytes.buffer.asUint8List(),
            width: width,
            height: height,
          );
          final result = await _recognizer.processImage(input);
          final text = _tidy(result.text);
          if (text.isEmpty) {
            failure = 'No text in that frame.';
          } else {
            recognised = text;
          }
        }
      }
    } on Object catch (e) {
      failure = 'The label could not be read ($e).';
    }

    if (!mounted) return;

    if (recognised == null) {
      setState(() {
        _stage = _Stage.viewfinder;
        _captureNote = '$failure Type or paste instead.';
      });
      _startCamera();
      return;
    }

    _stopCamera();
    _englishConfirmed = false;
    _textController.text = recognised;
    setState(() {
      _stage = _Stage.review;
      _captureNote = null;
    });
  }

  /// ML Kit returns one line per printed line; ingredient lists wrap mid-word
  /// across a package, so soft-join the lines into a single readable run.
  static String _tidy(String raw) {
    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '';

    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i == 0) {
        buffer.write(line);
        continue;
      }
      if (buffer.toString().endsWith('-')) {
        // A hyphen at a line break is almost always a split word.
        final current = buffer.toString();
        buffer
          ..clear()
          ..write(current.substring(0, current.length - 1))
          ..write(line);
      } else {
        buffer
          ..write(' ')
          ..write(line);
      }
    }
    return buffer.toString().trim();
  }

  void _typeInstead() {
    _stopCamera();
    setState(() {
      _stage = _Stage.review;
      _captureNote = null;
    });
  }

  void _retake() {
    setState(() {
      _englishConfirmed = false;
      _photoPath = null;
      _stage = _Stage.viewfinder;
      _captureNote = null;
    });
    _startCamera();
  }

  /// Hands the scanned text to the translator with the check one tap away.
  Future<void> _translate() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => TranslateScreen(initialText: text),
      ),
    );
    if (!mounted) return;
    if (result == 'log-reaction') Navigator.of(context).pop(result);
  }

  Future<void> _check() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final product = Product.fromOcr(
      text,
      ingredientsLanguage: _englishConfirmed ? 'en' : null,
    );
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) =>
            ResultScreen(product: product, status: ScanStatus.found),
      ),
    );

    if (!mounted) return;
    if (result == 'log-reaction') {
      Navigator.of(context).pop(result);
    }
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final reviewing = _stage == _Stage.review;

    return Scaffold(
      appBar: AppBar(
        title: Text(reviewing ? 'Check the list' : 'Read the label'),
        actions: [
          if (!reviewing && !_cameraFailed)
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, _) {
                if (state.torchState == TorchState.unavailable) {
                  return const SizedBox.shrink();
                }
                final on = state.torchState == TorchState.on;
                return IconButton(
                  tooltip: on ? 'Torch off' : 'Torch on',
                  icon: Icon(
                    on
                        ? Icons.flashlight_on_rounded
                        : Icons.flashlight_off_rounded,
                  ),
                  onPressed: () => _controller.toggleTorch(),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: reviewing ? _buildReview(context) : _buildViewfinder(context),
      ),
    );
  }

  Widget _buildViewfinder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final working = _stage == _Stage.working;
    final note = _captureNote;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    key: _previewKey,
                    child: MobileScanner(
                      controller: _controller,
                      fit: BoxFit.cover,
                      placeholderBuilder: (_) => ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorBuilder: (context, error) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted || _cameraFailed) return;
                          setState(() => _cameraFailed = true);
                        });
                        return _CameraUnavailable(error: error);
                      },
                    ),
                  ),
                  if (!_cameraFailed)
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _FramingGuidePainter(color: Colors.white),
                      ),
                    ),
                  if (working)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.65),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 14),
                            Text(
                              'Reading the label',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (note != null) ...[
                _Notice(text: note, tone: _NoticeTone.warning),
                const SizedBox(height: 12),
              ],
              Text(
                'Photograph the whole ingredient list, close up and in good '
                'light.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: working
                    ? null
                    : () => _takePhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Take a clear photo'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: working
                    ? null
                    : () => _takePhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose a photo'),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: working || _cameraFailed ? null : _capture,
                icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                label: const Text('Quick read from the preview'),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: working ? null : _typeInstead,
                icon: const Icon(Icons.keyboard_alt_outlined),
                label: const Text('Type or paste instead'),
              ),
              const SizedBox(height: 14),
              const _OfflineNote(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = _textController.text.trim().isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          empty
              ? 'Type or paste the ingredient list'
              : 'Check this against the packaging',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          empty
              ? 'Copy it exactly, including any "may contain" line.'
              : 'Text recognition misreads small print. A dropped word is a '
                    'missed allergen.',
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (_captureNote != null) ...[
          const SizedBox(height: 12),
          _Notice(text: _captureNote!, tone: _NoticeTone.warning),
        ],
        if (_photoPath != null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    title: const Text('Your photo'),
                  ),
                  body: InteractiveViewer(
                    maxScale: 6,
                    child: Center(child: Image.file(File(_photoPath!))),
                  ),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(_photoPath!),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the photo to zoom and compare.',
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _textController,
          maxLines: null,
          minLines: 10,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() => _englishConfirmed = false),
          style: const TextStyle(fontSize: 16, height: 1.45),
          decoration: const InputDecoration(
            hintText:
                'Ingredients: wheat flour, sugar, palm oil… May contain nuts.',
          ),
        ),
        const SizedBox(height: 18),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'I checked that the full ingredient list is in English',
          ),
          value: _englishConfirmed,
          onChanged: (value) =>
              setState(() => _englishConfirmed = value ?? false),
        ),
        FilledButton.icon(
          onPressed: empty ? null : _check,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Check this list'),
        ),
        const SizedBox(height: 10),
        // The matcher reads English. A label in another language is unreadable
        // to it, so the honest route is to translate first and let the check
        // run on the translation — with the verdict capped accordingly.
        OutlinedButton.icon(
          onPressed: empty ? null : _translate,
          icon: const Icon(Icons.translate_rounded),
          label: const Text('This label is not in English'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _retake,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Use the camera again'),
        ),
        const SizedBox(height: 20),
        const _Notice(
          text:
              'Only printed text is read. Silence about shared equipment is '
              'not an assurance.',
          tone: _NoticeTone.neutral,
        ),
        const SizedBox(height: 12),
        const _OfflineNote(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_off_rounded, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Works offline.',
            style: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

enum _NoticeTone { neutral, warning }

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.tone});

  final String text;
  final _NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final warning = tone == _NoticeTone.warning;
    final background = warning
        ? scheme.errorContainer.withValues(alpha: 0.6)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final foreground = warning
        ? scheme.onErrorContainer
        : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 18,
            color: foreground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, height: 1.4, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Corner brackets over the preview. Not a scan window — the recogniser reads
/// the whole frame — just a hint about how close to hold the packaging.
class _FramingGuidePainter extends CustomPainter {
  const _FramingGuidePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.shortestSide * 0.08;
    final rect = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    final arm = size.shortestSide * 0.12;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void corner(Offset origin, double dx, double dy) {
      canvas
        ..drawLine(origin, origin.translate(arm * dx, 0), paint)
        ..drawLine(origin, origin.translate(0, arm * dy), paint);
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomLeft, 1, -1);
    corner(rect.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_FramingGuidePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.no_photography_outlined,
                size: 44,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 14),
              Text(
                denied
                    ? 'Camera access is off. Typing still works.'
                    : 'Camera unavailable. Typing still works.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

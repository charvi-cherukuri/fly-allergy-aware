import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/profile.dart';
import '../services/app_state.dart';
import '../theme.dart';
import 'ocr_screen.dart';
import 'result_screen.dart';

/// The barcode scanner.
///
/// Two things here are deliberate and unusual for the category:
///
/// 1. The active profile is always on screen. Scanning a snack against the
///    wrong family member's allergen list is a silent, total failure — the app
///    would say "no match" and be wrong about the only thing that matters.
/// 2. A barcode that resolves to nothing is not a dead end. `notFound` and
///    `offline` both push [ResultScreen] anyway so it can offer the label-photo
///    route, which needs no database and no connection.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    // Grocery packaging only. Restricting the formats keeps the detector from
    // locking onto QR codes on shelf tags and loyalty cards.
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// True from the moment a code is accepted until the result screen is closed
  /// and the camera has been restarted. Stops a second frame double-pushing.
  bool _handling = false;

  /// True only while the network lookup is in flight, for the progress veil.
  bool _lookingUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The MobileScanner widget only manages the lifecycle when it owns the
    // controller. We own it, so we do it here.
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        // Not while the lock is up. The overlay hides this screen, but the
        // camera would go on running behind it and a detected barcode would
        // push a result screen underneath the lock.
        if (!_handling && !context.read<AppState>().isLocked) _startCamera();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _stopCamera();
    }
  }

  /// Restarting an already-running controller throws; there is no way to ask
  /// whether a start is safe without racing it, so the throw is swallowed.
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
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- detection

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling || !mounted) return;
    // Belt and braces: a frame already in flight when the lock went up must
    // not navigate the app underneath it.
    if (context.read<AppState>().isLocked) return;

    String? code;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        code = value;
        break;
      }
    }
    if (code == null) return;

    _handling = true;
    await HapticFeedback.mediumImpact();
    _stopCamera();

    if (!mounted) {
      _handling = false;
      return;
    }
    setState(() => _lookingUp = true);

    final outcome = await context.read<AppState>().lookupBarcode(code);

    if (!mounted) return;
    setState(() => _lookingUp = false);

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => ResultScreen(
          product: outcome.product,
          status: outcome.status,
          message: outcome.message,
        ),
      ),
    );

    if (!mounted) return;

    // Let whoever pushed the scanner handle "log a reaction" — this screen has
    // no business owning that flow.
    if (result == 'log-reaction') {
      Navigator.of(context).pop(result);
      return;
    }

    _handling = false;
    _startCamera();
  }

  Future<void> _openLabelPhoto() async {
    if (_handling) return;
    _handling = true;
    _stopCamera();

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const OcrScreen()),
    );

    if (!mounted) return;
    if (result == 'log-reaction') {
      Navigator.of(context).pop(result);
      return;
    }
    _handling = false;
    _startCamera();
  }

  // ------------------------------------------------------------------ profile

  Future<void> _openProfileSheet() async {
    final app = context.read<AppState>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer<AppState>(
          builder: (innerContext, state, _) {
            final profiles = state.profiles;
            final activeId = state.activeProfile.id;
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SectionTitle('Scanning for'),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: profiles.length,
                      itemBuilder: (_, i) {
                        final p = profiles[i];
                        return _ProfileTile(
                          profile: p,
                          selected: p.id == activeId,
                          onTap: () async {
                            await app.setActiveProfile(p.id);
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------- permissions

  Future<void> _openAppSettings() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final uri = Uri.parse('app-settings:');
      final opened = await launchUrl(uri);
      if (!opened && mounted) {
        _showSettingsHint();
      }
      return;
    }
    if (!mounted) return;
    _showSettingsHint();
  }

  void _showSettingsHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Open Settings, find Fly Allergy Aware, and allow camera access.',
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scan a barcode'),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torch = state.torchState;
              if (torch == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: torch == TorchState.on ? 'Torch off' : 'Torch on',
                icon: Icon(
                  torch == TorchState.on
                      ? Icons.flashlight_on_rounded
                      : Icons.flashlight_off_rounded,
                ),
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
          IconButton(
            tooltip: 'Flip camera',
            icon: const Icon(Icons.cameraswitch_rounded),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final windowWidth = size.width * 0.82;
          final windowHeight =
              (windowWidth * 0.62).clamp(140.0, size.height / 3).toDouble();
          final scanWindow = Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.42),
            width: windowWidth,
            height: windowHeight,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                scanWindow: scanWindow,
                fit: BoxFit.cover,
                placeholderBuilder: (_) => const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
                errorBuilder: (context, error) => _CameraError(
                  error: error,
                  onOpenSettings: _openAppSettings,
                  onUseLabelPhoto: _openLabelPhoto,
                ),
              ),
              ScanWindowOverlay(
                controller: _controller,
                scanWindow: scanWindow,
                borderColor: Colors.white,
                borderRadius: BorderRadius.circular(18),
                borderWidth: 3,
                color: Colors.black.withValues(alpha: 0.55),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: scanWindow.bottom + 20,
                child: const _HintLine(),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActiveProfileBar(onTap: _openProfileSheet),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.surface,
                          foregroundColor: scheme.onSurface,
                        ),
                        onPressed: _openLabelPhoto,
                        icon: const Icon(Icons.document_scanner_outlined),
                        label: const Text('No barcode? Photograph the label'),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              if (_lookingUp)
                const _LookupVeil(),
            ],
          );
        },
      ),
    );
  }
}

/// The hint that sits under the cut-out.
class _HintLine extends StatelessWidget {
  const _HintLine();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'Point at the barcode',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(blurRadius: 8, color: Colors.black)],
          ),
        ),
      ),
    );
  }
}

/// Who this scan is being checked against. Tapping it switches profile.
class _ActiveProfileBar extends StatelessWidget {
  const _ActiveProfileBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profile = context.watch<AppState>().activeProfile;
    final allergens = profile.sorted;

    return Material(
      color: scheme.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  _initials(profile.name),
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Scanning for ${profile.name}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      allergens.isEmpty
                          ? 'No allergens set — every scan will read as unknown'
                          : allergens.map((a) => a.emoji).join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.unfold_more_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts =
        trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final Profile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Icon(
        profile.isChild
            ? Icons.child_care_rounded
            : Icons.person_outline_rounded,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(
        profile.name,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        profile.summary,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: scheme.primary)
          : null,
    );
  }
}

class _LookupVeil extends StatelessWidget {
  const _LookupVeil();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.7),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Checking the label',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown in place of the preview when the camera cannot run — most often
/// because permission was refused, which needs a route back rather than a
/// black rectangle.
class _CameraError extends StatelessWidget {
  const _CameraError({
    required this.error,
    required this.onOpenSettings,
    required this.onUseLabelPhoto,
  });

  final MobileScannerException error;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onUseLabelPhoto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final unsupported = error.errorCode == MobileScannerErrorCode.unsupported;

    final String title;
    final String body;
    if (denied) {
      title = 'Camera access is off';
      body = 'The camera is needed to read a barcode. Nothing from the '
          'camera leaves your phone — the scan happens on the device.';
    } else if (unsupported) {
      title = 'No camera available';
      body = 'This device has no usable camera. You can still check a '
          'label by typing the ingredient list in.';
    } else {
      title = 'The camera could not start';
      body = error.errorDetails?.message ?? error.errorCode.message;
    }

    return ColoredBox(
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  denied
                      ? Icons.no_photography_outlined
                      : Icons.videocam_off_outlined,
                  size: 56,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (denied)
                  FilledButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Open settings'),
                  ),
                if (denied) const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onUseLabelPhoto,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Read a label instead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

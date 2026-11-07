import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/opencode/opencode_endpoints.dart';
import '../../data/opencode/opencode_pairing.dart';
import '../../domain/entities/opencode.dart';
import '../../l10n/generated/app_localizations.dart';
import 'opencode_connections_controller.dart';
import 'opencode_failure_text.dart';

enum OpenCodePairMode { qr, manual }

class OpenCodePairScreen extends ConsumerStatefulWidget {
  const OpenCodePairScreen({this.initialMode = OpenCodePairMode.qr, super.key});

  final OpenCodePairMode initialMode;

  @override
  ConsumerState<OpenCodePairScreen> createState() => _OpenCodePairScreenState();
}

class _OpenCodePairScreenState extends ConsumerState<OpenCodePairScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _scanner = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  late OpenCodePairMode _mode = widget.initialMode;
  var _busy = false;
  var _pairingStarted = false;
  var _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_mode == OpenCodePairMode.qr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_startScanner());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_scanner.stop());
    unawaited(_scanner.dispose());
    _url.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_mode == OpenCodePairMode.qr && !_pairingStarted && !_busy) {
        unawaited(_startScanner());
      }
      return;
    }
    unawaited(_scanner.stop());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.openCodePairTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<OpenCodePairMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: OpenCodePairMode.qr,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(l10n.openCodePairModeQr),
                ),
                ButtonSegment(
                  value: OpenCodePairMode.manual,
                  icon: const Icon(Icons.keyboard_rounded),
                  label: Text(l10n.openCodePairModeManual),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _busy
                  ? null
                  : (selection) => _setMode(selection.first),
            ),
          ),
          Expanded(
            child: _mode == OpenCodePairMode.qr
                ? _buildQr(l10n)
                : _buildManual(l10n),
          ),
          if (_error != null)
            _ErrorBanner(message: _error!, onDismiss: _clearError),
        ],
      ),
    );
  }

  Widget _buildQr(AppLocalizations l10n) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scanner,
          onDetect: _onDetect,
          errorBuilder: (context, error) => _ScannerError(
            message: _scannerErrorMessage(l10n, error),
            onRetry: () => unawaited(_startScanner()),
          ),
          placeholderBuilder: (context) =>
              const Center(child: CircularProgressIndicator()),
        ),
        IgnorePointer(
          child: Container(color: Colors.black.withValues(alpha: 0.18)),
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                l10n.openCodeQrHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Colors.white, height: 1.4),
              ),
            ),
          ),
        ),
        if (_busy)
          Container(
            color: Colors.black.withValues(alpha: 0.58),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    l10n.openCodePairing,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildManual(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            l10n.openCodeServerUrl,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('openCodeUrlField'),
            controller: _url,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.url],
            decoration: InputDecoration(
              hintText: l10n.openCodeServerUrlHint,
              prefixIcon: const Icon(Icons.link_rounded),
              border: const OutlineInputBorder(),
            ),
            validator: _validateUrl,
          ),
          const SizedBox(height: 18),
          Text(
            l10n.openCodePassword,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('openCodePasswordField'),
            controller: _password,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                tooltip: _obscurePassword ? l10n.commonShow : l10n.commonHide,
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.openCodePasswordRequired;
              }
              return null;
            },
            onFieldSubmitted: (_) => unawaited(_submitManual()),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.openCodeName,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('openCodeNameField'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: l10n.openCodeNameHint,
              prefixIcon: const Icon(Icons.badge_outlined),
              border: const OutlineInputBorder(),
            ),
            onFieldSubmitted: (_) => unawaited(_submitManual()),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('openCodeConnectButton'),
            onPressed: _busy ? null : () => unawaited(_submitManual()),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login_rounded),
            label: Text(_busy ? l10n.openCodeConnecting : l10n.openCodeConnect),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }

  void _setMode(OpenCodePairMode mode) {
    if (mode == _mode) {
      return;
    }
    setState(() {
      _mode = mode;
      _error = null;
    });
    if (mode == OpenCodePairMode.qr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_startScanner());
      });
    } else {
      unawaited(_scanner.stop());
    }
  }

  Future<void> _startScanner() async {
    if (!mounted || _mode != OpenCodePairMode.qr || _pairingStarted || _busy) {
      return;
    }
    try {
      await _scanner.start();
    } on MobileScannerException {
      // The scanner widget renders the error through its errorBuilder.
    } on Exception {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context).openCodeScannerError,
        );
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_pairingStarted || _busy || _mode != OpenCodePairMode.qr) {
      return;
    }
    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        raw = value;
        break;
      }
    }
    if (raw == null) {
      setState(
        () => _error = AppLocalizations.of(context).openCodeQrUnreadable,
      );
      return;
    }
    _pairingStarted = true;
    unawaited(_pair(raw));
  }

  Future<void> _pair(String raw) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _scanner.stop();
    } catch (_) {
      // The pairing can still proceed if the camera is already stopping.
    }

    try {
      final pairing = const OpenCodePairingParser().parse(raw);
      await ref
          .read(openCodeConnectionsControllerProvider.notifier)
          .pair(pairing);
      if (!mounted) {
        return;
      }
      _leave();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _pairingStarted = false;
        _error = error is OpenCodeFailure
            ? openCodeFailureText(l10n, error)
            : l10n.openCodeFailureUnknown;
      });
      unawaited(_startScanner());
    }
  }

  Future<void> _submitManual() async {
    if (_busy || _formKey.currentState?.validate() != true) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(openCodeConnectionsControllerProvider.notifier)
          .connectManual(
            baseUrl: _url.text,
            password: _password.text,
            name: _name.text,
          );
      if (mounted) {
        _leave();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = error is OpenCodeFailure
            ? openCodeFailureText(l10n, error)
            : l10n.openCodeFailureUnknown;
      });
    }
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/opencode');
    }
  }

  String? _validateUrl(String? value) {
    final l10n = AppLocalizations.of(context);
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return l10n.openCodeUrlRequired;
    }
    try {
      normalizeOpenCodeBaseUrl(trimmed);
    } on OpenCodeFailure {
      return l10n.openCodeUrlInvalid;
    }
    return null;
  }

  String _scannerErrorMessage(
    AppLocalizations l10n,
    MobileScannerException error,
  ) {
    return switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => l10n.openCodeScannerPermission,
      MobileScannerErrorCode.unsupported => l10n.openCodeScannerUnavailable,
      _ => l10n.openCodeScannerError,
    };
  }

  void _clearError() {
    if (mounted) {
      setState(() => _error = null);
    }
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_outlined,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

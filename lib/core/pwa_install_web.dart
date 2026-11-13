import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'pwa_install_state.dart';

/// Pont vers `window.popoteInstall`, défini dans `web/index.html`.
extension type _Pwa._(JSObject _) implements JSObject {
  external bool available();
  external bool isStandalone();
  external bool isIos();
  external JSPromise<JSString> prompt();
  external set onChange(JSFunction? f);
}

@JS('popoteInstall')
external _Pwa? get _pwa;

PwaInstallState _compute() {
  final p = _pwa;
  if (p == null || p.isStandalone()) return PwaInstallState.none;
  if (p.available()) return PwaInstallState.available;
  if (p.isIos()) return PwaInstallState.ios;
  return PwaInstallState.none;
}

ValueNotifier<PwaInstallState> _init() {
  final notifier = ValueNotifier(_compute());
  void onChange() {
    notifier.value = _compute();
  }

  _pwa?.onChange = onChange.toJS;
  return notifier;
}

/// Mis à jour quand Chrome signale que l'installation est possible (ou faite).
final ValueNotifier<PwaInstallState> pwaInstall = _init();

/// Ouvre la fenêtre d'installation du navigateur (Android, desktop).
Future<void> promptPwaInstall() async {
  final p = _pwa;
  if (p == null) return;
  await p.prompt().toDart;
}

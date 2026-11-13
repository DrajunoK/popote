// Installation de la PWA : implémentation web, ou version vide sur Android / iOS natifs.
export 'pwa_install_state.dart';
export 'pwa_install_stub.dart' if (dart.library.js_interop) 'pwa_install_web.dart';

import 'package:flutter/foundation.dart';

import 'pwa_install_state.dart';

/// Hors web, il n'y a rien à installer.
final ValueNotifier<PwaInstallState> pwaInstall = ValueNotifier(PwaInstallState.none);

Future<void> promptPwaInstall() async {}

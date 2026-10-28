import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_store.dart';
import 'models.dart';

/// Configuration injectée à la compilation :
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Schéma d'URL de retour après la connexion Google (déclaré dans AndroidManifest et Info.plist).
const authRedirect = 'app.popote://login-callback';

/// Connexion Google via Supabase Auth (F-AUTH-01).
///
/// Sans URL ni clé Supabase, [configured] est faux : l'écran de connexion retombe sur un
/// profil local de démonstration, ce qui garde l'appli utilisable en développement.
class AuthService {
  AuthService(this._store);

  final AppStore _store;

  static bool get configured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static Future<void> init() async {
    if (!configured) return;
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  }

  /// Recopie la session Supabase (y compris celle restaurée au démarrage) dans le store local.
  void listen() {
    if (!configured) return;
    final auth = Supabase.instance.client.auth;
    _apply(auth.currentSession);
    auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedOut) {
        _store.signOut();
      } else {
        _apply(event.session);
      }
    });
  }

  void _apply(Session? session) {
    final user = session?.user;
    if (user == null) return;
    final meta = user.userMetadata ?? const {};
    final email = user.email ?? '';
    final name = (meta['full_name'] ?? meta['name'] ?? email.split('@').first).toString();
    _store.signIn(UserProfile(name: name, email: email));
  }

  /// Ouvre la page de connexion Google ; la session arrive ensuite par [listen].
  Future<void> signInWithGoogle() async {
    if (!configured) {
      _store.signIn(const UserProfile(name: 'Alex Martin', email: 'alex@example.com'));
      return;
    }
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      // Sur le web, sans URL explicite Supabase renvoie vers son « Site URL » et non vers l'appli.
      redirectTo: kIsWeb ? Uri.base.origin : authRedirect,
    );
  }

  Future<void> signOut() async {
    if (configured) await Supabase.instance.client.auth.signOut();
    _store.signOut();
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.read(appStoreProvider.notifier)));

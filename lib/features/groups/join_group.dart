import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_store.dart';
import '../../data/auth_service.dart';
import '../../data/sync_service.dart';
import '../../shared/widgets.dart';

/// Demande un code d'invitation et rejoint le groupe. Connecté, l'adhésion est immédiate ;
/// sinon le code est gardé et utilisé juste après la connexion.
/// Renvoie `true` si l'utilisateur a saisi un code accepté.
Future<bool> askAndJoinGroup(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!AuthService.configured) {
    messenger.showSnackBar(const SnackBar(content: Text('Rejoindre un groupe demande un compte : configurez Supabase (voir le README).')));
    return false;
  }
  final code = await askText(context, title: 'Code d’invitation', hint: 'Ex. 3F9A1C7B');
  if (code == null || code.isEmpty) return false;
  final signedIn = ref.read(appStoreProvider).user != null;
  final ok = await ref.read(syncServiceProvider).joinWithCode(code);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(!ok
          ? 'Code invalide ou expiré.'
          : signedIn
              ? 'Groupe rejoint.'
              : 'Code enregistré : connectez-vous pour rejoindre le groupe.'),
    ));
  return ok;
}

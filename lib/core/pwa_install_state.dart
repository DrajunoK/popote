/// Ce que l'écran de connexion doit proposer pour installer l'appli.
enum PwaInstallState {
  /// Rien : appli native, déjà installée, ou navigateur qui ne propose pas l'installation.
  none,

  /// Chrome / Edge / Android : un tap lance la fenêtre d'installation.
  available,

  /// iPhone / iPad : pas d'API, il faut expliquer « Partager → Sur l'écran d'accueil ».
  ios,
}

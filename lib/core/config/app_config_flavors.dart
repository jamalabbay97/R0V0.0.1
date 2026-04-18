enum AppFlavor { dev, staging, prod }

class AppConfig {
  AppConfig._(this.flavor);

  final AppFlavor flavor;

  static late final AppConfig instance;

  static void initialize(AppFlavor flavor) {
    instance = AppConfig._(flavor);
  }

  bool get isDev => flavor == AppFlavor.dev;
  bool get isStaging => flavor == AppFlavor.staging;
  bool get isProd => flavor == AppFlavor.prod;

  String get displayName {
    switch (flavor) {
      case AppFlavor.dev:
        return 'R0 (Dev)';
      case AppFlavor.staging:
        return 'R0 (Staging)';
      case AppFlavor.prod:
        return 'R0';
    }
  }

  String get environmentKey {
    switch (flavor) {
      case AppFlavor.dev:
        return 'dev';
      case AppFlavor.staging:
        return 'staging';
      case AppFlavor.prod:
        return 'prod';
    }
  }
}

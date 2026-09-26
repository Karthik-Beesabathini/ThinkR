import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/storage/local_storage.dart';
import 'games/game_catalog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = LocalStorage();
  await storage.init();
  // No onboarding, no splash theater: straight into the product.
  runApp(ThinkrApp(storage: storage, registry: buildGameCatalog()));
}

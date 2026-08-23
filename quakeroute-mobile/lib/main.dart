import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env — optional for foundation; fallback defaults in ApiClient if absent.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env missing is non-fatal at foundation stage; ApiClient uses defaults.
  }

  runApp(const ProviderScope(child: QuakeRouteApp()));
}

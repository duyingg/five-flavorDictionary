import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'core/platform/platform_fonts.dart';
import 'features/floating_search/floating_dictionary_app.dart';

@pragma('vm:entry-point')
void floatingDictionaryMain() => runFloatingDictionary();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter('wuwei_dictionary');
  await Hive.openBox<String>('skin_packages');
  await initializePlatformFonts();
  runApp(const ProviderScope(child: DictionaryApp()));
}

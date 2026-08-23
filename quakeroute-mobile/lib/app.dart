import 'package:flutter/material.dart';

import 'app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/constants.dart';

class QuakeRouteApp extends StatelessWidget {
  const QuakeRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: buildAppTheme(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}

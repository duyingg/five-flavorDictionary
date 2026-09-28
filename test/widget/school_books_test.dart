import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wuwei_dictionary/app/app_routes.dart';
import 'package:wuwei_dictionary/features/culture/culture_pages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var attempt = 0;
        attempt < 30 && finder.evaluate().isEmpty;
        attempt++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(finder, findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '));
  }

  testWidgets('学派详情展示对应典籍并能进入典籍页', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.cultureDetail('school-mo'),
      routes: [
        GoRoute(
          path: AppRoutes.cultureDetailPattern,
          builder: (_, state) =>
              CultureDetailPage(id: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await pumpUntilFound(tester, find.text('墨家'));
    await tester.scrollUntilVisible(
      find.text('相关典籍'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('相关典籍'), findsOneWidget);
    expect(find.text('《墨子》'), findsOneWidget);
    expect(find.text('《论语》'), findsNothing);

    await tester.ensureVisible(find.text('《墨子》'));
    await tester.tap(find.text('《墨子》'));
    for (var attempt = 0;
        attempt < 20 &&
            router.routeInformationProvider.value.uri.path !=
                AppRoutes.cultureDetail('classic-mozi');
        attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(router.routeInformationProvider.value.uri.path,
        AppRoutes.cultureDetail('classic-mozi'));
  });
}

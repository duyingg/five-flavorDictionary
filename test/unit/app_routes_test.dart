import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/app/app_routes.dart';

void main() {
  test('动态路由参数会进行 URI 编码', () {
    expect(AppRoutes.character('𠮷'), '/character/%F0%A0%AE%B7');
    expect(AppRoutes.word('银行'), '/word/%E9%93%B6%E8%A1%8C');
    expect(AppRoutes.solarTerm('立春'), '/solar-term/%E7%AB%8B%E6%98%A5');
    expect(
        AppRoutes.cultureDetail('id/with space'), '/culture/id%2Fwith%20space');
    expect(AppRoutes.poetryAuthor('唐', '李白'),
        '/poetry-author/%E5%94%90/%E6%9D%8E%E7%99%BD');
  });

  test('路由模式与固定入口保持稳定', () {
    expect(AppRoutes.characterPattern, '/character/:value');
    expect(AppRoutes.wordPattern, '/word/:value');
    expect(AppRoutes.indexPattern, '/index/:type');
    expect(AppRoutes.solarTermPattern, '/solar-term/:name');
    expect(AppRoutes.poetryAuthorPattern, '/poetry-author/:dynasty/:author');
    expect(AppRoutes.settingsGeneral, '/settings/general');
  });
}

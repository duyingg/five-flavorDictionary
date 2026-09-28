import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/core/design/app_theme.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('首次启动登记五个随应用提供的皮肤', () async {
    final loaded = await PreferencesStore().loadSettings();
    final prefs = await SharedPreferences.getInstance();

    expect(loaded.skin, AppSkin.parchment);
    expect(loaded.importedSkin, isNull);
    expect(
      loaded.importedSkins.map((skin) => skin.name),
      containsAll(<String>['丹阙鎏金', '华章正红', '鎏金墨玉·锦纹', '青篁晨露', '松月夜读']),
    );
    expect(loaded.importedSkins, hasLength(5));
    expect(prefs.getBool(PreferencesKeys.bundledSkinsSeeded), isTrue);
  });

  test('默认皮肤导入不会覆盖已有皮肤选择', () async {
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.skin: AppSkin.jade.name,
    });

    final loaded = await PreferencesStore().loadSettings();

    expect(loaded.skin, AppSkin.jade);
    expect(loaded.importedSkin, isNull);
    expect(loaded.importedSkins, hasLength(5));
  });

  test('简繁、字级和皮肤偏好可持久化', () async {
    final store = PreferencesStore();
    const imported = ImportedSkin(
      name: '测试皮肤',
      description: '测试',
      background: 0xFFF4F7F3,
      surface: 0xFFFFFFFF,
      primary: 0xFF315C4D,
      secondary: 0xFF9A6A45,
      text: 0xFF202723,
      border: 0xFFD3DDD7,
      icons: {'nav.home': 'cottage_outlined'},
      assets: {'paper': 'data:image/webp;base64,AQID'},
      backgroundAsset: 'paper',
      cardRadius: 20,
    );
    await store.saveSettings(const AppSettings(
      globalHanLookupEnabled: false,
      scriptDisplay: ScriptDisplay.traditional,
      maxCharacterLevel: 2,
      skin: AppSkin.imported,
      importedSkin: imported,
      importedSkins: [imported],
      sidebarWidth: 92,
      showPinyin: false,
      showZhuyin: false,
      showWubi: false,
      showRadical: false,
      showStrokeCount: false,
      showStructure: false,
      showUnicode: false,
      showStrokeOrder: false,
    ));
    final loaded = await store.loadSettings();
    expect(loaded.globalHanLookupEnabled, isFalse);
    expect(loaded.scriptDisplay, ScriptDisplay.traditional);
    expect(loaded.maxCharacterLevel, 2);
    expect(loaded.skin, AppSkin.imported);
    expect(loaded.importedSkin?.name, '测试皮肤');
    expect(loaded.importedSkin?.backgroundAsset, 'paper');
    expect(loaded.importedSkin?.cardRadius, 20);
    expect(loaded.importedSkins.map((skin) => skin.name), contains('测试皮肤'));
    expect(loaded.importedSkins, hasLength(6));
    expect(loaded.sidebarWidth, 92);
    expect(loaded.showPinyin, isFalse);
    expect(loaded.showZhuyin, isFalse);
    expect(loaded.showWubi, isFalse);
    expect(loaded.showRadical, isFalse);
    expect(loaded.showStrokeCount, isFalse);
    expect(loaded.showStructure, isFalse);
    expect(loaded.showUnicode, isFalse);
    expect(loaded.showStrokeOrder, isFalse);
    expect(
        AppSkinRegistry.of(loaded.skin, loaded.importedSkin)
            .hasIcon('nav.home'),
        isTrue);
  });

  test('查询历史最多保存100条', () async {
    final store = PreferencesStore();
    final values = List.generate(120, (index) => '字$index');
    await store.saveSearchHistory(values);
    expect(await store.loadSearchHistory(), hasLength(100));
  });

  test('造句便签保留汉字、正文和创作日期', () async {
    final store = PreferencesStore();
    final createdAt = DateTime(2026, 9, 21, 14, 35);
    final notes = [
      SentenceNote(
        id: 'note-1',
        character: '学',
        content: '我们每天认真学习。',
        createdAt: createdAt,
      ),
    ];

    await store.saveSentenceNotes(notes);
    final loaded = await store.loadSentenceNotes();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'note-1');
    expect(loaded.single.character, '学');
    expect(loaded.single.content, '我们每天认真学习。');
    expect(loaded.single.createdAt, createdAt);
  });

  test('皮肤图标覆盖可检测且缺失时回退', () {
    final jade = AppSkinRegistry.of(AppSkin.jade);
    final parchment = AppSkinRegistry.of(AppSkin.parchment);
    expect(jade.hasIcon('nav.home'), isTrue);
    expect(parchment.hasIcon('nav.home'), isFalse);
    expect(parchment.icon('nav.home', jade.iconOverrides['nav.home']!),
        jade.iconOverrides['nav.home']);
  });
}

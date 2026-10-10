import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/features/learning/favorite_item.dart';

void main() {
  test('旧汉字收藏和新词语诗词收藏能分别读回', () {
    expect(FavoriteItem.parse('汉')?.kind, FavoriteKind.character);
    for (final item in [
      const FavoriteItem(FavoriteKind.word, '自定义词语'),
      const FavoriteItem(FavoriteKind.poetry, 'poetry-123'),
    ]) {
      final restored = FavoriteItem.parse(item.storageKey);
      expect(restored?.kind, item.kind);
      expect(restored?.value, item.value);
    }
  });
}

enum FavoriteKind { character, word, poetry }

class FavoriteItem {
  const FavoriteItem(this.kind, this.value);

  final FavoriteKind kind;
  final String value;

  // Old character favorites are stored as plain characters. Keep that format
  // so existing local collections remain readable after the upgrade.
  String get storageKey => switch (kind) {
        FavoriteKind.character => value,
        FavoriteKind.word => 'word:${Uri.encodeComponent(value)}',
        FavoriteKind.poetry => 'poetry:${Uri.encodeComponent(value)}',
      };

  static FavoriteItem? parse(String key) {
    try {
      if (key.startsWith('word:')) {
        return FavoriteItem(
            FavoriteKind.word, Uri.decodeComponent(key.substring(5)));
      }
      if (key.startsWith('poetry:')) {
        return FavoriteItem(
            FavoriteKind.poetry, Uri.decodeComponent(key.substring(7)));
      }
    } on FormatException {
      return null;
    }
    return key.isEmpty ? null : FavoriteItem(FavoriteKind.character, key);
  }
}

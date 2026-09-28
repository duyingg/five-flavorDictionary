import 'dart:io';

void main() {
  final root = Directory('Aatime/Classical-Modern-data/双语数据');
  if (!root.existsSync()) {
    stderr.writeln('未找到 ${root.path}');
    exitCode = 1;
    return;
  }
  const imported = {'论语', '孟子', '大学章句集注', '中庸'};
  final books = root.listSync().whereType<Directory>().toList()
    ..sort((a, b) => _name(a).compareTo(_name(b)));
  var totalSections = 0;
  var totalPairs = 0;
  var totalBytes = 0;
  final rows = <String>[];
  for (final book in books) {
    final files = book.listSync(recursive: true).whereType<File>().toList();
    final sources = files.where((file) => _name(file) == 'source.txt').toList();
    final pairs = sources.fold<int>(
        0, (sum, file) => sum + file.readAsLinesSync().length);
    final bytes = files.fold<int>(0, (sum, file) => sum + file.lengthSync());
    totalSections += sources.length;
    totalPairs += pairs;
    totalBytes += bytes;
    final name = _name(book);
    rows.add(
        '| $name | ${sources.length} | $pairs | ${_size(bytes)} | ${imported.contains(name) ? '已导入' : '待选择'} |');
  }
  final output = '''# NiuTrans 古籍双语资源目录

生成时间：${DateTime.now().toIso8601String()}

- 来源：NiuTrans/Classical-Modern
- 许可证：MIT
- 官方完整压缩包：`Aatime/Classical-Modern-main.zip`
- 已解压双语数据：`Aatime/Classical-Modern-data/双语数据`
- 总计：${books.length} 部，$totalSections 个章节文件，$totalPairs 对古文—现代文句对，解压后约 ${_size(totalBytes)}
- “已导入”只表示已经接入应用；其他资源已经下载，但尚未实装。

| 典籍 | 章节文件 | 双语句对 | 大小 | 应用状态 |
|---|---:|---:|---:|---|
${rows.join('\n')}
''';
  File('项目文档/NiuTrans古籍双语资源目录.md').writeAsStringSync(output);
  stdout.writeln('已生成 ${books.length} 部古籍目录，共 $totalPairs 对双语句。');
}

String _name(FileSystemEntity entity) =>
    entity.uri.pathSegments.where((part) => part.isNotEmpty).last;

String _size(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

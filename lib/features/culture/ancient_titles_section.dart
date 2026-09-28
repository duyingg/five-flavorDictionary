import 'package:flutter/material.dart';

/// An offline reading guide. The kinship chart is drawn here rather than
/// copied from a source image, so the labels remain legible and selectable.
class AncientTitlesSection extends StatelessWidget {
  const AncientTitlesSection({super.key});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '读古文时，先辨明谁在说话、说的是谁，再看辈分、父系或母系、长幼和场合。同一个词在不同时代与地区可能有不同用法；下列是文献中较常见的汉语称谓，不能当作所有民族、所有时代通用的规则。',
            style: TextStyle(height: 1.8, fontSize: 16),
          ),
          const SizedBox(height: 28),
          Text('亲属关系图', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('以“我”为观察点；横向可滚动查看。连线表示亲子关系，堂、表按上一代的亲属路径区分。',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          const _KinshipTree(
            heading: '父系亲属',
            ancestor: '祖父母',
            parents: ['伯父／叔父', '父亲', '姑母'],
            peers: ['堂兄弟姊妹', '我', '姑表兄弟姊妹'],
          ),
          const SizedBox(height: 16),
          const _KinshipTree(
            heading: '母系亲属',
            ancestor: '外祖父母',
            parents: ['舅父', '母亲', '姨母'],
            peers: ['舅表兄弟姊妹', '我', '姨表兄弟姊妹'],
          ),
          const SizedBox(height: 30),
          Text('按关系查称谓', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('“父之兄”意为父亲的哥哥；表中亲属关系都从“我”出发。',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 52,
              columns: const [
                DataColumn(label: Text('与我的关系')),
                DataColumn(label: Text('常见称谓')),
              ],
              rows: const [
                ('父之父母', '祖父、祖母'),
                ('母之父母', '外祖父、外祖母'),
                ('父之兄／弟', '伯父／叔父'),
                ('父之姊妹', '姑母'),
                ('母之兄弟', '舅父'),
                ('母之姊妹', '姨母'),
                ('伯叔之子女', '堂兄弟、堂姊妹'),
                ('姑舅姨之子女', '表兄弟、表姊妹'),
                ('兄弟之子女', '侄子、侄女'),
                ('姊妹之子女', '外甥、外甥女'),
                ('子之子女', '孙子、孙女'),
                ('女之子女', '外孙、外孙女'),
              ]
                  .map((entry) => DataRow(cells: [
                        DataCell(Text(entry.$1)),
                        DataCell(Text(entry.$2)),
                      ]))
                  .toList(),
            ),
          ),
          const SizedBox(height: 30),
          Text('名、字、号与身份', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          const _Definition(
            term: '名与字',
            detail:
                '名是个人姓名的一部分；字是在名之外使用的称呼，常见于成年后的交往。李白名白、字太白。称字有时表示礼貌，但用法会随关系和时代变化。',
          ),
          const _Definition(
            term: '号',
            detail: '号多用来表达志趣或作为别称，可能由本人自取，也可能由别人称呼。苏轼号东坡居士。名、字、号不可互当作同一种称谓。',
          ),
          const _Definition(
            term: '官称与爵称',
            detail:
                '以任职官名、封爵或封地称人，可以表明其身份或表示尊重。官职可能前后变动，爵位制度也因朝代而异，需结合人物所在时代阅读。',
          ),
          const _Definition(
            term: '谥号与庙号',
            detail: '谥号是死后依礼制给予的称号，范仲淹谥“文正”；庙号用于帝王宗庙祭祀，如“唐太宗”。二者不同，也都不是生前的名或字。',
          ),
          const SizedBox(height: 26),
          Text('自谦与敬称', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const _Definition(
            term: '自己的亲属',
            detail:
                '向别人提到自己的父亲可称“家父”，母亲可称“家母”，弟弟可称“舍弟”，儿子可称“小儿”。“家”“舍”“小”在这些用法中带有谦意。',
          ),
          const _Definition(
            term: '对方的亲属',
            detail:
                '对方的父亲可称“令尊”，母亲可称“令堂”，儿子可称“令郎”，女儿可称“令爱”。“令”在这里是敬称，不能用“令尊”称自己的父亲。',
          ),
          const _Definition(
            term: '已故亲属',
            detail: '“先父”“先母”用于提及已故父母。古书中“考”“妣”的用法有时代差异，阅读具体文献时应结合语境判断。',
          ),
          const SizedBox(height: 24),
          Text('资料依据：《尔雅·释亲》、教育部《亲朋称呼表》、北京晚报《古代人名怎么称呼》等。图表与释义由本应用整理。',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _Definition extends StatelessWidget {
  const _Definition({required this.term, required this.detail});

  final String term;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(term,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(height: 1.75, fontSize: 15)),
        ]),
      );
}

class _KinshipTree extends StatelessWidget {
  const _KinshipTree({
    required this.heading,
    required this.ancestor,
    required this.parents,
    required this.peers,
  });

  final String heading;
  final String ancestor;
  final List<String> parents;
  final List<String> peers;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(heading, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 720,
              height: 230,
              child: Stack(children: [
                CustomPaint(
                  size: const Size(720, 230),
                  painter: _KinshipLines(colors.outline),
                ),
                _node(290, 0, ancestor, colors, false),
                for (var index = 0; index < 3; index++) ...[
                  _node(45 + index * 245, 83, parents[index], colors, false),
                  _node(
                      45 + index * 245, 170, peers[index], colors, index == 1),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _node(double left, double top, String label, ColorScheme colors,
          bool highlighted) =>
      Positioned(
        left: left,
        top: top,
        child: Container(
          width: 130,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: highlighted ? colors.primaryContainer : colors.surface,
            border: Border.all(
                color: highlighted ? colors.primary : colors.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                color:
                    highlighted ? colors.onPrimaryContainer : colors.onSurface,
              )),
        ),
      );
}

class _KinshipLines extends CustomPainter {
  const _KinshipLines(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);

    // One ancestor pair branches to three children; each branch continues to
    // the relative's child (or to "me" in the middle column).
    line(355, 48, 355, 65);
    line(110, 65, 600, 65);
    for (final x in [110.0, 355.0, 600.0]) {
      line(x, 65, x, 83);
      line(x, 131, x, 170);
    }
  }

  @override
  bool shouldRepaint(_KinshipLines oldDelegate) => oldDelegate.color != color;
}

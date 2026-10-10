import 'package:flutter/material.dart';

import 'ancient_titles_data.dart';

/// A reading guide to forms of address in historical Chinese texts.
class AncientTitlesSection extends StatefulWidget {
  const AncientTitlesSection({super.key});

  @override
  State<AncientTitlesSection> createState() => _AncientTitlesSectionState();
}

class _AncientTitlesSectionState extends State<AncientTitlesSection> {
  String query = '';
  String? selectedGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = ancientTitleEntries.where((entry) {
      if (selectedGroup != null && entry.group != selectedGroup) return false;
      final search = query.trim();
      return search.isEmpty ||
          '${entry.group}${entry.term}${entry.meaning}${entry.example}'
              .contains(search);
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(
        '读古文先看谁在说话、称呼谁、双方身份与所处时代。同一个词可能是敬称、自称、官名或亲属称呼，须结合语境判断。',
        style: TextStyle(height: 1.8, fontSize: 16),
      ),
      const SizedBox(height: 22),
      Text('称呼用法对照', style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('以说话者为中心，比较说自己、称对方和称君主的方向。', style: theme.textTheme.bodySmall),
      const SizedBox(height: 10),
      const _AddressMatrix(),
      const SizedBox(height: 24),
      Text('称谓速查', style: theme.textTheme.titleLarge),
      const SizedBox(height: 10),
      TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: '搜索称谓、含义或例子',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (value) => setState(() => query = value),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 4, children: [
        ChoiceChip(
          label: const Text('全部'),
          selected: selectedGroup == null,
          onSelected: (_) => setState(() => selectedGroup = null),
        ),
        for (final group in ancientTitleGroups)
          ChoiceChip(
            label: Text(group),
            selected: selectedGroup == group,
            onSelected: (_) => setState(
              () => selectedGroup = selectedGroup == group ? null : group,
            ),
          ),
      ]),
      const SizedBox(height: 16),
      if (matches.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('没有找到相关称谓，请换个词试试。'),
        ),
      for (final group in ancientTitleGroups)
        if (matches.any((entry) => entry.group == group)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(group, style: theme.textTheme.titleMedium),
          ),
          for (final entry in matches.where((entry) => entry.group == group))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.term,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 5),
                    Text(entry.meaning, style: const TextStyle(height: 1.6)),
                    const SizedBox(height: 5),
                    Text(entry.example,
                        style:
                            theme.textTheme.bodySmall?.copyWith(height: 1.6)),
                  ],
                ),
              ),
            ),
        ],
      const SizedBox(height: 16),
      Text(
        '资料参考：教育部《重编国语辞典修订本·亲朋称呼表》、北京师范大学出版科学研究院关于名、字、号的说明、清华大学人文学院关于帝王名号的讲座资料等。称谓随时代、地域和文体变化，本页列举常见用法。',
        style: theme.textTheme.bodySmall,
      ),
    ]);
  }
}

class _AddressMatrix extends StatelessWidget {
  const _AddressMatrix();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const rows = <(String, String, String)>[
      ('说自己的父母', '家父、家母', '谦称自己的亲属'),
      ('说对方的父母', '令尊、令堂', '敬称对方的亲属'),
      ('说自己的子女', '小儿、小女', '谦称自己的亲属'),
      ('说对方的子女', '令郎、令爱', '敬称对方的亲属'),
      ('臣下面对君主', '臣 → 陛下', '自称与对称配合'),
      ('晚辈面对前辈', '晚生 → 先生', '依身份与场合选择'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(colors.primaryContainer),
        columns: const [
          DataColumn(label: Text('说话方向')),
          DataColumn(label: Text('常见用语')),
          DataColumn(label: Text('如何理解')),
        ],
        rows: [
          for (final row in rows)
            DataRow(cells: [
              DataCell(Text(row.$1)),
              DataCell(Text(row.$2)),
              DataCell(Text(row.$3)),
            ]),
        ],
      ),
    );
  }
}

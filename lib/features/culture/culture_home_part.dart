part of 'culture_pages.dart';

class CulturePage extends ConsumerStatefulWidget {
  const CulturePage({super.key});
  @override
  ConsumerState<CulturePage> createState() => _CulturePageState();
}

class _CulturePageState extends ConsumerState<CulturePage> {
  var selected = CultureCategory.schools;
  var _sidebarVisible = true;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull ??
        const AppSettings();
    return SafeArea(
      child: Column(children: [
        _CultureHeading(
          sidebarVisible: _sidebarVisible,
          onToggleSidebar: () =>
              setState(() => _sidebarVisible = !_sidebarVisible),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_sidebarVisible) ...[
                      SizedBox(
                        width: settings.sidebarWidth,
                        child: ListView(children: [
                          for (final category in CultureCategory.values)
                            _CategoryButton(
                              category: category,
                              selected: selected == category,
                              onTap: () => setState(() => selected = category),
                            ),
                        ]),
                      ),
                      const VerticalDivider(width: 1),
                    ],
                    Expanded(
                      child: selected == CultureCategory.tangPoems
                          ? const PoetryBrowser()
                          : _CultureGrid(category: selected),
                    ),
                  ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _CultureHeading extends StatelessWidget {
  const _CultureHeading({
    required this.sidebarVisible,
    required this.onToggleSidebar,
  });
  final bool sidebarVisible;
  final VoidCallback onToggleSidebar;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final title = Text('文化',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 5,
                  ));
          final toggle = HoverOnlyTooltipIconButton(
            message: sidebarVisible ? '隐藏侧边栏' : '显示侧边栏',
            icon: Icon(sidebarVisible
                ? Icons.keyboard_double_arrow_left
                : Icons.keyboard_double_arrow_right),
            onPressed: onToggleSidebar,
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: constraints.maxWidth < 520
                ? Row(
                    children: [
                      toggle,
                      Expanded(child: Center(child: title)),
                      const _CultureModeSelector(),
                    ],
                  )
                : Stack(alignment: Alignment.center, children: [
                    title,
                    Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: toggle),
                    const Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _CultureModeSelector()),
                  ]),
          );
        },
      );
}

class _CultureModeSelector extends ConsumerWidget {
  const _CultureModeSelector();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modes = ref.watch(cultureDisplayModeProvider);
    return SegmentedButton<CultureDisplayMode>(
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 7, vertical: 4)),
        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
      ),
      showSelectedIcon: false,
      segments: [
        for (final value in CultureDisplayMode.values)
          ButtonSegment(value: value, label: Text(value.label)),
      ],
      multiSelectionEnabled: true,
      selected: modes,
      emptySelectionAllowed: true,
      onSelectionChanged: (value) {
        ref.read(cultureDisplayModeProvider.notifier).state = value;
      },
    );
  }
}

class _CultureGrid extends ConsumerWidget {
  const _CultureGrid({required this.category});
  final CultureCategory category;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = category == CultureCategory.classics
        ? ref.watch(sortedClassicsProvider)
        : ref.watch(cultureItemsProvider(category));
    return items.when(
      data: (values) {
        final visible = category == CultureCategory.schools
            ? values.where((item) => item.id.startsWith('school-')).toList()
            : values;
        return visible.isEmpty
            ? const EmptyState(title: '暂无内容', message: '该分类暂未收录')
            : GridView.builder(
                key: PageStorageKey(category),
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      MediaQuery.sizeOf(context).width >= 840 ? 2 : 1,
                  mainAxisExtent:
                      category == CultureCategory.schools ? 136 : 118,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 12,
                ),
                itemCount: visible.length,
                itemBuilder: (_, index) => _CultureCard(item: visible[index]),
              );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(title: '加载失败', message: '请检查本地文化资源'),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton(
      {required this.category, required this.selected, required this.onTap});
  final CultureCategory category;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 20),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: .09)
              : Colors.transparent,
          border: BorderDirectional(
              start: BorderSide(
            color: selected ? colors.primary : Colors.transparent,
            width: 3,
          )),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(category.label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? colors.primary : colors.onSurface,
              )),
        ),
      ),
    );
  }
}

class _CultureCard extends StatelessWidget {
  const _CultureCard({required this.item});
  final CultureItem item;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(AppRoutes.cultureDetail(item.id)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              if (item.category == CultureCategory.schools) ...[
                Container(
                  width: 66,
                  height: 90,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(item.title.substring(0, 1),
                      style: TextStyle(
                          fontSize: 30,
                          color: Theme.of(context).colorScheme.primary)),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 5),
                    Text(item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 5),
                    Text(item.summary,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ]),
          ),
        ),
      );
}

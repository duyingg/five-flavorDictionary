import 'package:flutter/material.dart';

double scrollProgress(ScrollController controller) {
  if (!controller.hasClients || controller.position.maxScrollExtent <= 0) {
    return 0;
  }
  return (controller.offset / controller.position.maxScrollExtent).clamp(0, 1);
}

void restoreScrollProgress(ScrollController controller, double progress) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!controller.hasClients) return;
    controller.jumpTo(controller.position.maxScrollExtent * progress);
  });
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 680;
    return Padding(
      padding:
          EdgeInsets.fromLTRB(20, compact ? 10 : 22, 20, compact ? 10 : 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 36),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: compact ? 24 : null,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 5,
                  ),
            ),
          ),
          SizedBox(width: 36, child: trailing),
        ],
      ),
    );
  }
}

class HoverOnlyTooltipIconButton extends StatefulWidget {
  const HoverOnlyTooltipIconButton({
    required this.message,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String message;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  State<HoverOnlyTooltipIconButton> createState() =>
      _HoverOnlyTooltipIconButtonState();
}

class _HoverOnlyTooltipIconButtonState
    extends State<HoverOnlyTooltipIconButton> {
  final _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => _tooltipKey.currentState?.ensureTooltipVisible(),
        onExit: (_) => Tooltip.dismissAllToolTips(),
        child: Tooltip(
          key: _tooltipKey,
          message: widget.message,
          triggerMode: TooltipTriggerMode.manual,
          child: IconButton(
            onPressed: widget.onPressed,
            icon: widget.icon,
          ),
        ),
      );
}

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent(
      {required this.child, super.key, this.maxWidth = 900});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {required this.title,
      required this.message,
      super.key,
      this.icon = Icons.inbox_outlined});

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 52, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
}

class InkWashDecoration extends StatelessWidget {
  const InkWashDecoration({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Opacity(
          opacity: .13,
          child: Align(
            alignment: Alignment.bottomRight,
            child: Icon(Icons.park_outlined,
                size: 150, color: Theme.of(context).colorScheme.primary),
          ),
        ),
      );
}

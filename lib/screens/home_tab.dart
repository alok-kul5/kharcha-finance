import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../insights/budgets.dart';
import '../insights/recurring.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/txn_tile.dart';
import '../widgets/ui.dart';
import 'settings_screen.dart';
import 'sheets.dart';

/// Home is a receipt of the month: a flat field with the total and one bar per day,
/// two ticket stubs (budgets, next recurring payment), then the categories the money
/// went to as full-width bands, sized by their share and marked against their budgets.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key, required this.onSeeAll});
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider);
    final budgets = ref.watch(budgetStatusProvider);
    final recurring = ref.watch(recurringProvider);
    final now = ref.watch(clockProvider)();
    final recent = (ref.watch(txnsProvider).value ?? const []).take(6).toList();
    final categories = summary?.byCategory ?? const <(String, int)>[];

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: _Field(summary: summary)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: FadeSlideIn(child: _Ticket.budget(context, budgets))),
              const SizedBox(width: 10),
              Expanded(child: FadeSlideIn(index: 1, child: _Ticket.upcoming(context, recurring, now))),
            ]),
          ),
        ),
      ),
      if (categories.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SectionHeader('Where it went')),
        SliverToBoxAdapter(child: _CategoryBands(categories: categories, total: summary!.spentPaise, budgets: budgets)),
      ],
      SliverToBoxAdapter(
        child: SectionHeader('Recent',
            trailing: TextButton(onPressed: onSeeAll, child: const Text('See all', style: TextStyle(fontWeight: FontWeight.w600)))),
      ),
      if (recent.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'Nothing here yet',
            message: 'Tap + to import bank SMS, scan a receipt or add one by hand.',
          ),
        )
      else
        SliverList.builder(
          itemCount: recent.length,
          itemBuilder: (context, i) => FadeSlideIn(
            index: i,
            child: TxnTile(
              txn: recent[i],
              showDate: true,
              position: GroupPosition.of(i, recent.length),
              onTap: () => showKSheet(context, TxnDetailSheet(txn: recent[i])),
            ),
          ),
        ),
      SliverToBoxAdapter(child: SizedBox(height: bottomClearance(context))),
    ]);
  }
}

/// The deep field at the top: the month's total, how it compares, and a bar per day.
class _Field extends ConsumerWidget {
  const _Field({required this.summary});
  final MonthSummary? summary;

  static const ground = Color(0xff0b1f47);
  static const accent = Color(0xffffb547);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    final s = summary;
    final month = ref.watch(selectedMonthProvider);
    final now = ref.watch(clockProvider)();
    final isCurrent = month.year == now.year && month.month == now.month;
    final soft = Colors.white.withAlpha(170);

    final parts = <String>[];
    if (s != null && s.previousDaily.isNotEmpty) {
      // Compare with last month at the same day, not the whole month.
      final day = s.daily.length.clamp(1, s.previousDaily.length);
      final prevAtDay = s.previousDaily[day - 1];
      if (prevAtDay > 0) {
        final pct = ((s.spentPaise - prevAtDay) * 100 / prevAtDay).round();
        final last = DateFormat.MMMM().format(DateTime(month.year, month.month - 1));
        parts.add(pct == 0 ? 'Level with $last at day $day' : '${pct.abs()}% ${pct > 0 ? 'more' : 'less'} than $last by day $day');
      }
    }
    if (s != null && s.incomePaise > 0) parts.add('${_short(s.incomePaise)} came in');
    parts.add('kept on this phone');

    return Container(
      decoration: const BoxDecoration(color: ground, borderRadius: BorderRadius.vertical(bottom: Radius.circular(Radii.hero))),
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const _Logo(),
          const SizedBox(width: 10),
          const Text('Kharcha', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          const Spacer(),
          GlassIconButton(
            icon: Icons.settings_rounded,
            tooltip: 'Settings',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ]),
        const SizedBox(height: 28),
        Row(children: [
          GlassIconButton(
              icon: Icons.chevron_left_rounded,
              size: 30,
              tooltip: 'Previous month',
              onTap: () => ref.read(selectedMonthProvider.notifier).shift(-1)),
          const SizedBox(width: 10),
          Text(isCurrent ? 'Spent this month' : 'Spent in ${DateFormat('MMMM yyyy').format(month)}',
              style: TextStyle(color: soft, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          if (!isCurrent)
            GlassIconButton(
                icon: Icons.chevron_right_rounded,
                size: 30,
                tooltip: 'Next month',
                onTap: () => ref.read(selectedMonthProvider.notifier).shift(1)),
        ]),
        const SizedBox(height: 10),
        AnimatedAmount(s?.spentPaise ?? 0,
            style: KText.amount(context, size: 60, color: Colors.white), decimalsColor: Colors.white.withAlpha(90)),
        const SizedBox(height: 10),
        Text(parts.join(' · '), style: TextStyle(color: soft, fontSize: 14.5, height: 1.4)),
        const SizedBox(height: 26),
        if (s != null) _DayStrip(daily: s.daily, month: month, today: isCurrent ? now.day : null) else const SizedBox(height: 120),
      ]),
    );
  }

  static String _short(int paise) {
    final r = paise / 100;
    if (r >= 100000) return '₹${(r / 100000).toStringAsFixed(r >= 1000000 ? 0 : 1)}L';
    if (r >= 1000) return '₹${(r / 1000).toStringAsFixed(r >= 10000 ? 0 : 1)}k';
    return '₹${r.round()}';
  }
}

/// One bar per day of the month, from that day's spend. Days still to come are dots;
/// today is the accent bar. The biggest day is named underneath.
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.daily, required this.month, required this.today});
  final List<int> daily;
  final DateTime month;
  final int? today;

  static final _tick = TextStyle(color: Colors.white.withAlpha(120), fontSize: 12, fontWeight: FontWeight.w500);

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final spend = [for (var i = 0; i < daily.length; i++) daily[i] - (i == 0 ? 0 : daily[i - 1])];
    final peak = spend.isEmpty ? 0 : spend.reduce((a, b) => a > b ? a : b);
    final peakDay = peak > 0 ? spend.indexOf(peak) + 1 : null;
    final fmt = NumberFormat.decimalPattern('en_IN');
    final reduced = Motion.reduced(context);

    Widget bar(int d) {
      if (d > spend.length) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(width: 3, height: 3, decoration: BoxDecoration(color: Colors.white.withAlpha(60), shape: BoxShape.circle)),
        );
      }
      final v = spend[d - 1];
      // Square-root heights, so one rent day doesn't flatten every other day.
      final f = peak <= 0 ? 0.0 : math.sqrt(v / peak);
      final color = d == today
          ? _Field.accent
          : d == peakDay
              ? Colors.white
              : Colors.white.withAlpha(v == 0 ? 40 : 120);
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: reduced ? f : 0, end: f),
        duration: reduced ? Duration.zero : Duration(milliseconds: 700 + d * 18),
        curve: Motion.signature,
        builder: (_, t, _) => Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: t.clamp(d == today ? 0.12 : 0.02, 1.0),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
                border: d == today ? Border.all(color: _Field.accent, width: 1) : null,
              ),
            ),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 92,
        child: Semantics(
          label: 'Spend per day this month',
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var d = 1; d <= days; d++) Expanded(child: bar(d))]),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Text('1', style: _tick),
        const Spacer(),
        if (today != null)
          Text('Today, ${DateFormat('d MMM').format(DateTime(month.year, month.month, today!))}', style: _tick.copyWith(color: _Field.accent)),
        const Spacer(),
        Text('$days', style: _tick),
      ]),
      if (peakDay != null) ...[
        const SizedBox(height: 14),
        Text('Biggest day: ${DateFormat('EEE d MMM').format(DateTime(month.year, month.month, peakDay))}, ₹${fmt.format(peak ~/ 100)}',
            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13.5, fontWeight: FontWeight.w500)),
      ],
    ]);
  }
}

/// The app mark: a ₹ on a flat white tile.
class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: const Text('₹', style: TextStyle(color: _Field.ground, fontSize: 19, fontWeight: FontWeight.w800)),
      );
}

/// A ticket stub: notched on both sides, with a perforation before its last line.
class _Ticket extends StatelessWidget {
  const _Ticket({required this.title, required this.value, required this.caption, this.valueColor});
  final String title;
  final String value;
  final String caption;
  final Color? valueColor;

  factory _Ticket.budget(BuildContext context, List<BudgetStatus> budgets) {
    final over = budgets.where((b) => b.level == BudgetLevel.over).length;
    final warn = budgets.where((b) => b.level == BudgetLevel.warning).length;
    final k = context.k;
    if (budgets.isEmpty) return const _Ticket(title: 'Budgets', value: 'None set', caption: 'Add one in Insights');
    return _Ticket(
      title: 'Budgets',
      value: over > 0 ? '$over over' : warn > 0 ? '$warn near limit' : 'On track',
      valueColor: over > 0 ? k.negative : warn > 0 ? k.caution : k.positive,
      caption: '${budgets.length} set this month',
    );
  }

  factory _Ticket.upcoming(BuildContext context, List<RecurringPayment> recurring, DateTime now) {
    final next = recurring.where((r) => !r.nextExpected.isBefore(DateTime(now.year, now.month, now.day))).firstOrNull;
    if (next == null) return const _Ticket(title: 'Recurring', value: 'None found', caption: 'Needs 3 or more payments');
    final days = next.nextExpected.difference(DateTime(now.year, now.month, now.day)).inDays;
    return _Ticket(
      title: 'Next recurring',
      value: next.merchant,
      caption: '${_rupees(next.typicalPaise)} ${days == 0 ? 'today' : days == 1 ? 'tomorrow' : 'in $days days'}',
    );
  }

  static String _rupees(int p) => '₹${NumberFormat.decimalPattern('en_IN').format(p ~/ 100)}';

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return ClipPath(
      clipper: const _StubClipper(),
      child: Container(
        color: k.surface,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.caption(context)),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: KText.display, fontSize: 24, height: 1.1, letterSpacing: -0.4, color: valueColor ?? k.ink)),
          const SizedBox(height: 14),
          _Perforation(color: k.separator),
          const SizedBox(height: 10),
          Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.caption(context).copyWith(fontSize: 12.5)),
        ]),
      ),
    );
  }
}

class _Perforation extends StatelessWidget {
  const _Perforation({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(height: 1.5, width: double.infinity, child: CustomPaint(painter: _DashPainter(color)));
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 4, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}

class _StubClipper extends CustomClipper<Path> {
  const _StubClipper();
  @override
  Path getClip(Size size) {
    const notch = 7.0;
    final y = size.height - 34;
    final card = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)));
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, y), radius: notch))
      ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: notch));
    return Path.combine(PathOperation.difference, card, holes);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Where the money went: each category is a band across the screen, filled to its share
/// of the biggest one, with its budget written on it when one is set.
class _CategoryBands extends StatelessWidget {
  const _CategoryBands({required this.categories, required this.total, required this.budgets});
  final List<(String, int)> categories;
  final int total;
  final List<BudgetStatus> budgets;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final fmt = NumberFormat.decimalPattern('en_IN');
    final top = categories.take(5).toList();
    final biggest = top.first.$2 <= 0 ? 1 : top.first.$2;
    final reduced = Motion.reduced(context);

    Widget band(int i, String name, int paise) {
      final color = CategoryVisuals.color(name);
      final share = total <= 0 ? 0 : (paise * 100 / total).round();
      final status = budgets.where((b) => b.budget.category == name).firstOrNull;
      final fill = paise / biggest;
      var note = '$share% of the month';
      Color? noteColor;
      if (status != null) {
        final left = status.remainingPaise;
        final limit = fmt.format(status.budget.limitPaise ~/ 100);
        note = left >= 0 ? '₹${fmt.format(left ~/ 100)} left of ₹$limit' : '₹${fmt.format(-left ~/ 100)} over ₹$limit';
        noteColor = status.level == BudgetLevel.over
            ? k.negative
            : status.level == BudgetLevel.warning
                ? k.caution
                : null;
      }
      final big = i == 0;
      return FadeSlideIn(
        index: i,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          height: big ? 96 : 76,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: k.surface, borderRadius: BorderRadius.circular(16)),
          child: Stack(children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: reduced ? fill : 0, end: fill),
              duration: reduced ? Duration.zero : Duration(milliseconds: 900 + i * 120),
              curve: Motion.signature,
              builder: (_, t, _) => FractionallySizedBox(
                widthFactor: t.clamp(0.0, 1.0),
                heightFactor: 1,
                alignment: Alignment.centerLeft,
                child: ColoredBox(color: color.withAlpha(context.isDark ? 70 : 46)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Container(width: 4, height: big ? 44 : 32, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.headline(context).copyWith(fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Text(note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KText.caption(context)
                            .copyWith(fontSize: 12.5, color: noteColor, fontWeight: noteColor == null ? null : FontWeight.w600)),
                  ]),
                ),
                const SizedBox(width: 12),
                Text('₹${fmt.format(paise ~/ 100)}',
                    style: TextStyle(
                        fontFamily: KText.display,
                        fontSize: big ? 30 : 23,
                        letterSpacing: -0.6,
                        color: k.ink,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [for (final (i, (name, paise)) in top.indexed) band(i, name, paise)]),
    );
  }
}

/// A budget line: icon, name, "₹spent of ₹limit", coloured track.
class BudgetRow extends StatelessWidget {
  const BudgetRow({super.key, required this.status, this.onTap});
  final BudgetStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final c = status.budget.category;
    final color = switch (status.level) {
      BudgetLevel.over => k.negative,
      BudgetLevel.warning => k.caution,
      BudgetLevel.ok => CategoryVisuals.color(c),
    };
    final fmt = NumberFormat.decimalPattern('en_IN');
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        IconTile(CategoryVisuals.icon(c), color: CategoryVisuals.color(c), size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(c, style: KText.headline(context).copyWith(fontSize: 15))),
              Text('${status.percent}%',
                  style: KText.amount(context, size: 14, color: status.level == BudgetLevel.ok ? k.secondaryLabel : color)),
            ]),
            const SizedBox(height: 6),
            ProgressTrack(value: status.ratio, color: color),
            const SizedBox(height: 5),
            Text(
              '₹${fmt.format(status.spentPaise ~/ 100)} of ₹${fmt.format(status.budget.limitPaise ~/ 100)}'
              '${status.remainingPaise >= 0 ? ' · ₹${fmt.format(status.remainingPaise ~/ 100)} left' : ' · ₹${fmt.format(-status.remainingPaise ~/ 100)} over'}',
              style: KText.caption(context).copyWith(fontSize: 12),
            ),
          ]),
        ),
      ]),
    );
    return onTap == null ? body : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(Radii.control), child: body);
  }
}

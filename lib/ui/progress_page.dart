import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/progression.dart';
import '../models/models.dart';
import '../utils/formatting.dart' as fmt;
import 'bodyweight_page.dart';
import 'widgets/bodyweight_dialog.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  String? _exerciseId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final trained = state.trainedExerciseIds;

    // Default to the most recently trained lift.
    final selected = (_exerciseId != null && trained.contains(_exerciseId))
        ? _exerciseId
        : (trained.isNotEmpty ? trained.first : null);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const _SectionLabel('WEEKLY VOLUME · ENERGY'),
          const SizedBox(height: 10),
          _WeeklyVolumeCard(state: state),
          const SizedBox(height: 24),
          const _SectionLabel('BODYWEIGHT'),
          const SizedBox(height: 10),
          _BodyweightCard(state: state),
          const SizedBox(height: 24),
          const _SectionLabel('MUSCLE COVERAGE · LAST 28 DAYS'),
          const SizedBox(height: 10),
          _MuscleCoverage(state: state),
          const SizedBox(height: 24),
          const _SectionLabel('VOLUME BY MUSCLE · LAST 28 DAYS'),
          const SizedBox(height: 10),
          _MuscleBreakdown(state: state),
          const SizedBox(height: 24),
          const _SectionLabel('STRENGTH TREND · LAST 120 DAYS'),
          const SizedBox(height: 10),
          _TrendDashboard(
            state: state,
            selected: selected,
            onPick: (id) => setState(() => _exerciseId = id),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('EXERCISE PROGRESS'),
          const SizedBox(height: 10),
          if (trained.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Log a few workouts and the strength curve for each lift '
                  'shows up here.',
                ),
              ),
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Exercise'),
              items: [
                for (final id in trained)
                  DropdownMenuItem(
                    value: id,
                    child: Text(
                      state.exerciseName(id),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _exerciseId = v),
            ),
            const SizedBox(height: 14),
            if (selected != null)
              _ExerciseProgress(
                key: ValueKey(selected),
                state: state,
                exerciseId: selected,
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _WeeklyVolumeCard extends StatelessWidget {
  const _WeeklyVolumeCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weeks = state.weeklyVolume(8);
    final maxV = weeks.fold(0.0, (a, w) => w.volume > a ? w.volume : a);
    final total = weeks.fold(0.0, (a, w) => a + w.volume);

    if (total == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No volume logged in the last 8 weeks.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    fmt.compact(weeks.last.volume),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'kg this week',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (weeks.last.kcal > 0)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 2),
                child: Text(
                  '~${fmt.kcal(weeks.last.kcal)} kcal burned, estimated from '
                  'the work and your bodyweight',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  maxY: maxV * 1.2,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxV <= 0 ? 1 : maxV / 2,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                        interval: maxV <= 0 ? 1 : maxV / 2,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            fmt.compact(value),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= weeks.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              fmt.shortDate(weeks[i].weekStart),
                              style: TextStyle(
                                fontSize: 9.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => scheme.inverseSurface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final w = weeks[group.x];
                        return BarTooltipItem(
                          '${fmt.compact(w.volume)} kg\n',
                          TextStyle(
                            color: scheme.onInverseSurface,
                            fontWeight: FontWeight.w700,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '${w.sessions} '
                                  '${w.sessions == 1 ? 'workout' : 'workouts'}'
                                  '${w.kcal > 0 ? '\n~${fmt.kcal(w.kcal)} kcal' : ''}',
                              style: TextStyle(
                                color: scheme.onInverseSurface.withValues(
                                  alpha: 0.8,
                                ),
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < weeks.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: weeks[i].volume,
                            width: 16,
                            color: i == weeks.length - 1
                                ? scheme.primary
                                : scheme.primary.withValues(alpha: 0.35),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Weight moves a kilo or two day to day, so the headline is the rolling
/// average rather than whatever the scale said this morning.
class _BodyweightCard extends StatelessWidget {
  const _BodyweightCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final series = state.bodyweightSeries;
    final average = state.averageBodyweight();
    final monthAgo = state.averageBodyweight(days: 28);
    final change = (average != null && monthAgo != null)
        ? average - monthAgo
        : null;

    if (series.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No weigh-ins yet. Bodyweight is one of the pull-up markers — '
                'less of you to lift is progress too.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => logBodyweightDialog(context, state),
                icon: const Icon(Icons.add),
                label: const Text('Log a weight'),
              ),
            ],
          ),
        ),
      );
    }

    final recent = series.length > 90
        ? series.sublist(series.length - 90)
        : series;
    final values = recent.map((e) => e.kg).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.3).clamp(0.5, 5.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    fmt.trimNum(double.parse(average!.toStringAsFixed(1))),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'kg · 7-day average',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  if (change != null && change.abs() >= 0.05)
                    Text(
                      '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: change < 0 ? scheme.primary : scheme.tertiary,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Text(
                '${recent.length} weigh-ins · latest '
                '${fmt.relativeDay(series.last.date, DateTime.now()).toLowerCase()}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 14),
            if (recent.length > 1)
              SizedBox(
                height: 150,
                child: LineChart(
                  LineChartData(
                    minY: minY - pad,
                    maxY: maxY + pad,
                    minX: 0,
                    maxX: (recent.length - 1).toDouble(),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: scheme.outlineVariant.withValues(alpha: 0.3),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              value.toStringAsFixed(0),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          interval: recent.length <= 6
                              ? 1
                              : (recent.length / 5).ceilToDouble(),
                          getTitlesWidget: (value, meta) {
                            final i = value.round();
                            if (i < 0 || i >= recent.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                fmt.shortDate(recent[i].date),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => scheme.inverseSurface,
                        getTooltipItems: (spots) => spots.map((s) {
                          final e = recent[s.x.round()];
                          return LineTooltipItem(
                            '${fmt.trimNum(e.kg)} kg\n',
                            TextStyle(
                              color: scheme.onInverseSurface,
                              fontWeight: FontWeight.w700,
                            ),
                            children: [
                              TextSpan(
                                text: fmt.dayMonth(e.date),
                                style: TextStyle(
                                  color: scheme.onInverseSurface.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < recent.length; i++)
                            FlSpot(i.toDouble(), recent[i].kg),
                        ],
                        isCurved: recent.length > 2,
                        curveSmoothness: 0.2,
                        preventCurveOverShooting: true,
                        barWidth: 3,
                        color: scheme.primary,
                        dotData: FlDotData(show: recent.length <= 20),
                        belowBarData: BarAreaData(
                          show: true,
                          color: scheme.primary.withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => logBodyweightDialog(context, state),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Log weight'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => openBodyweightPage(context),
                  child: Text('All ${series.length} weigh-ins'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Hard sets per muscle group — the view that catches "legs are miles ahead
/// of upper body".

/// Weekly hard sets per muscle against the volume landmarks, worst first.
///
/// This is the question "what am I neglecting?" answered with a dose rather
/// than a ranking: a muscle can top the tonnage chart and still sit under the
/// sets it needs, and another can look absent while collecting plenty of
/// indirect work.
/// Which lifts are moving and which are not, in one list.
///
/// The per-exercise chart below answers this one lift at a time, which means
/// finding a stall requires already suspecting it. This is the same data asked
/// the other way round: show me what is stuck.
class _TrendDashboard extends StatefulWidget {
  const _TrendDashboard({
    required this.state,
    required this.selected,
    required this.onPick,
  });

  final AppState state;
  final String? selected;
  final ValueChanged<String> onPick;

  @override
  State<_TrendDashboard> createState() => _TrendDashboardState();
}

class _TrendDashboardState extends State<_TrendDashboard> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final trends = widget.state.exerciseTrends();
    final scheme = Theme.of(context).colorScheme;

    if (trends.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Nothing logged yet. Once a lift has a few sessions behind it, '
            'whether it is still moving shows up here.',
          ),
        ),
      );
    }

    // Lifts with too little history are counted, not listed: a wall of "too
    // early to say" buries the handful of rows that mean something.
    final ready = trends
        .where((t) => t.verdict != TrendVerdict.tooSoon)
        .toList();
    final waiting = trends.length - ready.length;

    if (ready.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No lift has $trendMinimumSessions sessions behind it yet. Keep '
            'logging and the direction of each one shows up here.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final attention = ready.where((t) => t.verdict.needsAttention).length;
    final shown = _showAll ? ready : ready.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              attention == 0
                  ? 'Every lift is at or near its best.'
                  : '$attention of ${ready.length} '
                        '${attention == 1 ? 'lift needs' : 'lifts need'} a look.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: attention == 0 ? scheme.primary : scheme.error,
              ),
            ),
            const SizedBox(height: 14),
            for (final trend in shown)
              _TrendRow(
                trend: trend,
                selected: trend.def.id == widget.selected,
                onTap: () => widget.onPick(trend.def.id),
              ),
            if (ready.length > shown.length || _showAll)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(
                    _showAll ? 'Show fewer' : 'Show all ${ready.length}',
                  ),
                ),
              ),
            if (waiting > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '$waiting more ${waiting == 1 ? 'lift has' : 'lifts have'} '
                  'too little history to call yet.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({
    required this.trend,
    required this.selected,
    required this.onTap,
  });

  final ExerciseTrend trend;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (trend.verdict) {
      TrendVerdict.slipping || TrendVerdict.stalled => scheme.error,
      TrendVerdict.holding => scheme.tertiary,
      _ => scheme.primary,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trend.def.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      decoration: selected ? TextDecoration.underline : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  trend.verdict.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              _detail(trend),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            if (trend.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  trend.note!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.error.withValues(alpha: 0.9),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The verdict in this lift's own units, so "stuck" says stuck at what.
  static String _detail(ExerciseTrend trend) {
    final best = formatScore(trend.def, trend.best);
    return switch (trend.verdict) {
      TrendVerdict.climbing => 'New best last session — $best.',
      TrendVerdict.holding =>
        'Best $best, ${trend.sessionsSinceBest} session'
            '${trend.sessionsSinceBest == 1 ? '' : 's'} ago.',
      TrendVerdict.stalled =>
        '${trend.sessionsSinceBest} sessions since its '
            'best of $best.',
      TrendVerdict.slipping =>
        '${(trend.shortfall * 100).round()}% under its best of $best.',
      TrendVerdict.tooSoon =>
        'Only ${trend.sessions} session'
            '${trend.sessions == 1 ? '' : 's'} logged.',
    };
  }
}

class _MuscleCoverage extends StatelessWidget {
  const _MuscleCoverage({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Weekly averages off a few days of log are noise, not neglect.
    if (!state.coverageMeaningful) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Needs about two weeks of logs before weekly sets per muscle mean '
            'anything. Keep going.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final all = state.muscleCoverage();
    final short = all.where((m) => m.needsAttention).toList();
    final thin = all.where((m) => m.lowFrequency).toList();
    final fine = all.length - short.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              short.isEmpty
                  ? 'Every muscle is getting enough work.'
                  : '${short.length} '
                        '${short.length == 1 ? 'muscle is' : 'muscles are'} '
                        'under-served',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Hard sets per week, synergists counted as half a set.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            for (final m in short) _CoverageRow(volume: m),
            if (thin.isNotEmpty) ...[
              const Divider(height: 26),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.event_repeat, size: 16, color: scheme.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Enough sets but all on one day: '
                      '${thin.map((m) => m.muscle.label.toLowerCase()).join(', ')}'
                      '. Two sessions a week beats one at the same volume.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (fine > 0) ...[
              const Divider(height: 26),
              Text(
                '$fine ${fine == 1 ? 'muscle is' : 'muscles are'} inside the '
                'productive range.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Landmarks: about 4 sets a week maintains a muscle, about 10 is '
              'where growth reliably shows, and past about 20 the returns '
              'flatten.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({required this.volume});

  final MuscleVolume volume;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (volume.verdict) {
      VolumeVerdict.untrained || VolumeVerdict.neglected => scheme.error,
      VolumeVerdict.maintaining => scheme.tertiary,
      _ => scheme.primary,
    };

    final split = <String>[
      if (volume.directSets > 0) '${fmt.trimNum(volume.directSets)} direct',
      if (volume.indirectSets > 0)
        '${fmt.trimNum(volume.indirectSets)} indirect',
    ].join(' + ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  volume.muscle.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${fmt.trimNum(volume.weeklySets)}/wk',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _LandmarkBar(sets: volume.weeklySets, color: color),
          const SizedBox(height: 7),
          Text(
            '${volume.verdict.label} · ${volume.verdict.meaning}',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (split.isNotEmpty)
            Text(
              split,
              style: TextStyle(
                fontSize: 11.5,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          if (volume.missingFromPlan)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'Nothing in your routine targets it directly.',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.error.withValues(alpha: 0.9),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A track that runs from nothing to the productive ceiling, with a tick where
/// the sets start reliably building rather than just holding.
class _LandmarkBar extends StatelessWidget {
  const _LandmarkBar({required this.sets, required this.color});

  final double sets;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const span = VolumeLandmarks.productiveCeiling;
    final filled = (sets / span).clamp(0.0, 1.0);
    const mev = VolumeLandmarks.minimumEffective / span;

    return LayoutBuilder(
      builder: (context, box) => SizedBox(
        height: 8,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: filled,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Positioned(
              left: box.maxWidth * mev - 1,
              top: 0,
              bottom: 0,
              child: Container(
                width: 2,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MuscleBreakdown extends StatelessWidget {
  const _MuscleBreakdown({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = state.muscleBreakdown(28);

    if (rows.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Nothing logged in the last 4 weeks.'),
        ),
      );
    }

    final maxSets = rows.first.sets;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 82,
                      child: Text(
                        r.muscle.label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: maxSets == 0 ? 0 : r.sets / maxSets,
                          minHeight: 10,
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 62,
                      child: Text(
                        '${r.sets} sets',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(
                'Hypertrophy guideline: roughly 10–20 hard sets per muscle per '
                'week.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseProgress extends StatelessWidget {
  const _ExerciseProgress({
    super.key,
    required this.state,
    required this.exerciseId,
  });

  final AppState state;
  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final def = state.exerciseById(exerciseId);
    final points = state.pointsFor(exerciseId);
    final pr = state.personalRecord(exerciseId);

    if (points.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No completed sets recorded for this exercise yet.'),
        ),
      );
    }

    final values = points.map((p) => p.score).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.25).clamp(2.5, 40.0);
    final first = values.first;
    final last = values.last;
    final change = first == 0 ? 0.0 : ((last - first) / first) * 100;
    // On an assistance machine, less help is progress even though the logged
    // number falls — the score already accounts for it.
    final chartLabel = scoreAxisLabel(def);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                label: 'Best',
                value: pr == null ? '—' : _bestLabel(def, pr),
                sub: pr == null ? '' : formatScore(def, pr.score),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(
                label: 'Sessions',
                value: '${points.length}',
                sub:
                    'last ${fmt.relativeDay(points.last.date, DateTime.now()).toLowerCase()}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(
                label: 'Trend',
                value: '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}%',
                sub: scoreAxisLabel(def).toLowerCase(),
                highlight: change >= 0 ? scheme.primary : scheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 8),
                  child: Text(
                    chartLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(
                  height: 190,
                  child: LineChart(
                    LineChartData(
                      minY: (minY - pad).clamp(0, double.infinity),
                      maxY: maxY + pad,
                      minX: 0,
                      maxX: (points.length - 1).toDouble(),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: scheme.outlineVariant.withValues(alpha: 0.3),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                fmt.trimNum(value),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            interval: points.length <= 6
                                ? 1
                                : (points.length / 5).ceilToDouble(),
                            getTitlesWidget: (value, meta) {
                              final i = value.round();
                              if (i < 0 || i >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  fmt.shortDate(points[i].date),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => scheme.inverseSurface,
                          getTooltipItems: (spots) => spots.map((s) {
                            final p = points[s.x.round()];
                            return LineTooltipItem(
                              '${_bestLabel(def, p)}\n',
                              TextStyle(
                                color: scheme.onInverseSurface,
                                fontWeight: FontWeight.w700,
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      '${fmt.dayMonth(p.date)}'
                                      '${p.rpe != null ? ' · RPE ${fmt.trimNum(p.rpe!)}' : ''}',
                                  style: TextStyle(
                                    color: scheme.onInverseSurface.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontWeight: FontWeight.w400,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].score),
                          ],
                          isCurved: points.length > 2,
                          curveSmoothness: 0.25,
                          preventCurveOverShooting: true,
                          barWidth: 3,
                          color: scheme.primary,
                          dotData: FlDotData(
                            show: points.length <= 20,
                            getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                                  radius: 3.5,
                                  color: scheme.surface,
                                  strokeWidth: 2.5,
                                  strokeColor: scheme.primary,
                                ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: scheme.primary.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _SectionLabel('RECENT SESSIONS'),
        const SizedBox(height: 8),
        ...points.reversed
            .take(8)
            .map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          fmt.shortDate(p.date),
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _bestLabel(def, p),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (p.rpe != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(
                            'RPE ${fmt.trimNum(p.rpe!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      Text(
                        p.volume > 0 ? '${fmt.compact(p.volume)} kg' : '',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  static String _bestLabel(ExerciseDef def, ExercisePoint p) =>
      switch (def.tracking) {
        TrackingMode.weightReps =>
          '${fmt.trimNum(p.topWeight)} kg × ${p.topReps}',
        TrackingMode.bodyweightReps => '${p.topReps} reps',
        TrackingMode.duration => '${p.topDuration} s',
        TrackingMode.tempoReps => '${p.topReps} × ${fmt.trimNum(p.topTempo)} s',
      };
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.sub,
    this.highlight,
  });

  final String label;
  final String value;
  final String sub;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: highlight,
              ),
            ),
          ),
          if (sub.isNotEmpty)
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

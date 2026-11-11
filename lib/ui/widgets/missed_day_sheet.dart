import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../utils/formatting.dart' as fmt;
import 'backfill.dart';

/// Records why a scheduled day did not happen, whether it is still owed, or
/// that it happened after all and just needs writing down.
Future<void> showMissedDaySheet(BuildContext context, DateTime date) async {
  final day = fmt.dateOnly(date);
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _MissedDaySheet(date: day),
  );
  // Popped first so the backfill opens over the page, not over the sheet.
  if (action == 'backfill' && context.mounted) {
    await backfillWorkout(context, context.read<AppState>(), day);
  }
}

class _MissedDaySheet extends StatefulWidget {
  const _MissedDaySheet({required this.date});

  final DateTime date;

  @override
  State<_MissedDaySheet> createState() => _MissedDaySheetState();
}

class _MissedDaySheetState extends State<_MissedDaySheet> {
  MissReason? _reason;
  late final TextEditingController _note = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final status = state.statusOf(widget.date);
    final scheduled = state.plan.daysForWeekday(widget.date.weekday);
    final record = state.missedOn(widget.date);
    final isFuture = widget.date.isAfter(fmt.dateOnly(DateTime.now()));

    if (!_loaded && record != null) {
      // "Rest" is not one of the excuse chips, so it never preselects one.
      _reason = record.isRest ? null : record.reason;
      _note.text = record.note;
      _loaded = true;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fmt.dayMonth(widget.date),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                scheduled.isEmpty
                    ? 'Nothing scheduled — a rest day.'
                    : scheduled.map((d) => d.name).join(' or '),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              if (status == DayStatus.trained)
                _Note(
                  icon: Icons.check_circle,
                  color: scheme.primary,
                  text: 'You trained on this day — nothing to record.',
                )
              else if (scheduled.isEmpty) ...[
                _Note(
                  icon: Icons.info_outline,
                  color: scheme.onSurfaceVariant,
                  text: 'Rest days do not need a reason.',
                ),
                if (!isFuture) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop('backfill'),
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('Trained anyway? Log it'),
                    ),
                  ),
                ],
              ] else ...[
                if (record != null && record.isRest) ...[
                  _Note(
                    icon: Icons.bedtime_outlined,
                    color: scheme.tertiary,
                    text: 'Taken as a rest day — nothing is owed for it.',
                  ),
                  const SizedBox(height: 18),
                ],
                if (!isFuture) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop('backfill'),
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: const Text('I did train — log it now'),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Text(
                  isFuture
                      ? 'Know you will not make it? Record it now and the week '
                            'plans around it.'
                      : 'What got in the way?',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in MissReasonInfo.excuses)
                      ChoiceChip(
                        label: Text(r.label),
                        selected: _reason == r,
                        onSelected: (_) => setState(() => _reason = r),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _note,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Anything worth remembering (optional)',
                  ),
                ),
                if (_reason?.suggestsRest ?? false) ...[
                  const SizedBox(height: 14),
                  _Note(
                    icon: Icons.healing_outlined,
                    color: scheme.tertiary,
                    text:
                        'Illness, injury and deep fatigue are reasons to '
                        'take the day as rest rather than stack it onto the '
                        'week.',
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _save(context, state, writtenOff: true),
                        child: const Text('Let it go'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isFuture
                            ? null
                            : () => _save(context, state, writtenOff: false),
                        child: const Text('Still owe it'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.tertiary,
                      side: BorderSide(
                        color: scheme.tertiary.withValues(alpha: 0.5),
                      ),
                    ),
                    onPressed: () => _saveRest(context, state),
                    icon: const Icon(Icons.bedtime_outlined, size: 18),
                    label: const Text('Take it as a rest day'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Not a miss — the plan asks for one every 3–4 sessions.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (isFuture)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'A day still ahead can only be written off — you can '
                      'always train it anyway.',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (record != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        state.clearMissed(widget.date);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Remove this record'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _save(BuildContext context, AppState state, {required bool writtenOff}) {
    final scheduled = state.plan.daysForWeekday(widget.date.weekday);
    state.markMissed(
      widget.date,
      planDayId: scheduled.length == 1 ? scheduled.first.id : null,
      reason: _reason ?? MissReason.other,
      note: _note.text.trim(),
      writtenOff: writtenOff,
    );
    Navigator.of(context).pop();
  }

  void _saveRest(BuildContext context, AppState state) {
    final scheduled = state.plan.daysForWeekday(widget.date.weekday);
    state.markRest(
      widget.date,
      planDayId: scheduled.length == 1 ? scheduled.first.id : null,
      note: _note.text.trim(),
    );
    Navigator.of(context).pop();
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13, color: color)),
        ),
      ],
    );
  }
}

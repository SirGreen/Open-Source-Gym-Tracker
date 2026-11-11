import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../utils/formatting.dart' as fmt;
import 'widgets/bodyweight_dialog.dart';

/// The weigh-in log. Bodyweight feeds net pull on the assist machine, the
/// volume of every bodyweight movement and the pull-up goal marker, so a bad
/// reading needs to be removable rather than permanent.
class BodyweightPage extends StatelessWidget {
  const BodyweightPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final entries = state.bodyweights; // newest first
    final average = state.averageBodyweight();
    final monthAgo = state.averageBodyweight(days: 28);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weigh-ins'),
        actions: [
          IconButton(
            tooltip: 'Add a weigh-in',
            icon: const Icon(Icons.add),
            onPressed: () => logBodyweightDialog(context, state),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monitor_weight_outlined,
                      size: 48,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No weigh-ins yet.\nAdd one and the pull-up marker starts '
                      'moving with you.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
              itemCount: entries.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '7-DAY AVERAGE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  average == null
                                      ? '—'
                                      : '${average.toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            if (average != null && monthAgo != null)
                              Text(
                                '${average - monthAgo > 0 ? '+' : ''}'
                                '${(average - monthAgo).toStringAsFixed(1)} kg '
                                'in 28 days',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: average <= monthAgo
                                      ? scheme.primary
                                      : scheme.tertiary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final entry = entries[i - 1];
                final older = i < entries.length ? entries[i] : null;
                final delta = older == null ? null : entry.kg - older.kg;

                return Dismissible(
                  key: ValueKey('weigh-${entry.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  confirmDismiss: (_) async =>
                      await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete this weigh-in?'),
                          content: Text(
                            '${fmt.trimNum(entry.kg)} kg on '
                            '${fmt.dayMonth(entry.date)}.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ) ??
                      false,
                  onDismissed: (_) {
                    state.deleteBodyweight(entry.id);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            '${fmt.trimNum(entry.kg)} kg weigh-in deleted',
                          ),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () => state.restoreBodyweight(entry),
                          ),
                        ),
                      );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => logBodyweightDialog(
                          context,
                          state,
                          date: entry.date,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 96,
                                child: Text(
                                  fmt.relativeDay(entry.date, state.now),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Text(
                                '${fmt.trimNum(entry.kg)} kg',
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (delta != null && delta.abs() >= 0.05) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${delta > 0 ? '+' : ''}'
                                  '${delta.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (entry.note.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    entry.note,
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Kept out of the widget above so both Progress and Settings can link here.
void openBodyweightPage(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const BodyweightPage()));
}

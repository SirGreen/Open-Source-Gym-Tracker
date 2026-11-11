import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../utils/formatting.dart' as fmt;
import '../../utils/plates.dart';

void showPlateSheet(
  BuildContext context, {
  required ExerciseDef exercise,
  required double weight,
}) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _PlateSheet(exercise: exercise, initialWeight: weight),
  );
}

class _PlateSheet extends StatefulWidget {
  const _PlateSheet({required this.exercise, required this.initialWeight});

  final ExerciseDef exercise;
  final double initialWeight;

  @override
  State<_PlateSheet> createState() => _PlateSheetState();
}

class _PlateSheetState extends State<_PlateSheet> {
  late double _weight = widget.initialWeight;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final def = widget.exercise;

    // Barbells carry the bar; plate-loaded machines carry a sled or frame.
    final base = def.equipment == Equipment.barbell
        ? def.barKg
        : (def.baseLoadKg ?? 0);
    final baseLabel = def.equipment == Equipment.barbell
        ? 'bar'
        : 'machine base';

    final result = calculatePlates(
      target: _weight,
      barWeight: base,
      available: state.settings.plates,
    );
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            def.name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            base > 0
                ? '${fmt.trimNum(base)} kg $baseLabel · plates per side'
                : 'Plates per side',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filledTonal(
                onPressed: () =>
                    setState(() => _weight = (_weight - 2.5).clamp(0.0, 999.0)),
                icon: const Icon(Icons.remove),
              ),
              Column(
                children: [
                  Text(
                    '${fmt.trimNum(_weight)} kg',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'total on the machine',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              IconButton.filledTonal(
                onPressed: () => setState(() => _weight = _weight + 2.5),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (result.belowBar)
            _Notice(
              icon: Icons.info_outline,
              text: 'Target is lighter than the empty $baseLabel.',
              color: scheme.tertiary,
            )
          else if (result.perSide.isEmpty)
            _Notice(
              icon: Icons.check_circle_outline,
              text: 'Nothing to load — $baseLabel only.',
              color: scheme.primary,
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in result.perSide)
                  _PlateChip(plate: s.plate, count: s.count),
              ],
            ),
          if (!result.exact && !result.belowBar) ...[
            const SizedBox(height: 14),
            _Notice(
              icon: Icons.report_gmailerrorred_outlined,
              text:
                  'Closest loadable: ${fmt.trimNum(result.achieved)} kg '
                  '(${fmt.trimNum(result.leftover)} kg short).',
              color: scheme.error,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlateChip extends StatelessWidget {
  const _PlateChip({required this.plate, required this.count});

  final double plate;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count×',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${fmt.trimNum(plate)} kg',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}

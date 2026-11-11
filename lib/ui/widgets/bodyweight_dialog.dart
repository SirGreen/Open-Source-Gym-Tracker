import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../utils/formatting.dart' as fmt;

/// Records, corrects or removes a weigh-in. The date is editable so a reading
/// can be back-dated, and an existing entry for that day is overwritten rather
/// than duplicated.
Future<void> logBodyweightDialog(
  BuildContext context,
  AppState state, {
  DateTime? date,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _WeighInDialog(state: state, initialDate: date),
  );
}

class _WeighInDialog extends StatefulWidget {
  const _WeighInDialog({required this.state, this.initialDate});

  final AppState state;
  final DateTime? initialDate;

  @override
  State<_WeighInDialog> createState() => _WeighInDialogState();
}

class _WeighInDialogState extends State<_WeighInDialog> {
  late DateTime _date = fmt.dateOnly(widget.initialDate ?? widget.state.now);
  late final TextEditingController _kg = TextEditingController(
    text: _valueFor(_date),
  );
  late final TextEditingController _note = TextEditingController(
    text: _entryOn(_date)?.note ?? '',
  );

  String _valueFor(DateTime date) {
    final existing = _entryOn(date);
    return fmt.trimNum(
      existing?.kg ??
          double.parse(widget.state.currentBodyweight.toStringAsFixed(1)),
    );
  }

  BodyweightEntry? _entryOn(DateTime date) {
    for (final e in widget.state.bodyweights) {
      if (e.date == fmt.dateOnly(date)) return e;
    }
    return null;
  }

  @override
  void dispose() {
    _kg.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: fmt.dateOnly(widget.state.now),
    );
    if (picked == null) return;
    setState(() {
      _date = fmt.dateOnly(picked);
      _kg.text = _valueFor(_date);
      _note.text = _entryOn(_date)?.note ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final existing = _entryOn(_date);
    final isToday = fmt.sameDay(_date, widget.state.now);

    return AlertDialog(
      title: Text(isToday ? "Today's weight" : 'Weigh-in'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _pickDate,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.event, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Text(
                    '${fmt.dayMonth(_date)} ${_date.year}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    'Change',
                    style: TextStyle(fontSize: 12.5, color: scheme.primary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _kg,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(suffixText: 'kg'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Note (optional)'),
          ),
        ],
      ),
      actions: [
        if (existing != null)
          TextButton(
            onPressed: () {
              widget.state.deleteBodyweight(existing.id);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final kg = double.tryParse(_kg.text.replaceAll(',', '.'));
            if (kg != null && kg > 0) {
              widget.state.logBodyweight(
                kg,
                date: _date,
                note: _note.text.trim(),
              );
            }
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

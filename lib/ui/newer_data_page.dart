import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_state.dart';
import '../data/storage.dart';

/// Shown instead of the app when the database on this phone was written by a
/// newer version of Chalk.
///
/// The app is held here rather than started because starting it is the
/// damaging part: this build would read the parts it recognises, and the first
/// save would write those back and drop everything it did not. Nothing has
/// been read and nothing will be written while this screen is up, so the file
/// is still whole and the way out is to put the newer version back.
class NewerDataPage extends StatelessWidget {
  const NewerDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final found = state.heldBackSchema;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.history_toggle_off, size: 44, color: scheme.error),
                const SizedBox(height: 18),
                Text(
                  'This data is from a newer Chalk',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'The training log on this phone was written in format '
                  '${found ?? '?'}. This version of the app understands format '
                  '${Storage.schemaVersion}, so there is part of it here that '
                  'it cannot read.',
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nothing has been opened and nothing has been saved, so the '
                  'file is exactly as the newer version left it. Installing '
                  'that version again is the fix — everything will be there.',
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('Save a copy somewhere safe'),
                    onPressed: () => _rescue(context, state),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(
                        color: scheme.error.withValues(alpha: 0.5),
                      ),
                    ),
                    onPressed: () => _confirmOpen(context, state),
                    child: const Text('Open it here anyway'),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Opening it here keeps what this version understands and '
                  'discards the rest, permanently. Take the copy first.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _rescue(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await state.rescueRawFile();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          subject: 'Chalk data',
          text: 'Chalk data',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not copy it: $e')));
    }
  }

  Future<void> _confirmOpen(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard what cannot be read?'),
        content: const Text(
          'Whatever the newer version added is lost as soon as anything is '
          'saved. There is no undo, and the copy on this phone goes with it.\n\n'
          'Installing the newer version instead costs nothing and keeps all '
          'of it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it as it is'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard and open'),
          ),
        ],
      ),
    );
    if (ok == true) state.openAnyway();
  }
}

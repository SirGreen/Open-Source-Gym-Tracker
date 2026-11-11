import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/app_state.dart';
import 'package:gym_tracker/models/models.dart';
import 'package:gym_tracker/data/rest_timer.dart';
import 'package:gym_tracker/ui/progress_page.dart';
import 'package:gym_tracker/ui/session_page.dart';
import 'package:gym_tracker/ui/today_page.dart';
import 'package:gym_tracker/utils/formatting.dart' as fmt;
import 'package:provider/provider.dart';

import 'helpers.dart';

void main() {
  group('page rendering', () {
    final wednesday = DateTime(2026, 9, 2);

    Future<void> pumpPage(
      WidgetTester tester,
      AppState state,
      Widget page,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: ChangeNotifierProvider<AppState>.value(
            value: state,
            child: page,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Let the store's debounced save fire, so no timer outlives the test.
      await tester.pump(const Duration(seconds: 6));
    }

    Future<void> pumpToday(WidgetTester tester, AppState state) =>
        pumpPage(tester, state, const TodayPage());

    /// The session page needs the rest timer too, and a tall surface so the
    /// card under test is on screen without scrolling.
    Future<void> pumpSession(
      WidgetTester tester,
      AppState state,
      RestTimer rest,
      String sessionId,
    ) async {
      // The test font is monospaced squares and measures much wider than
      // Roboto, so this is deliberately roomier than a phone.
      tester.view.physicalSize = const Size(1800, 5400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      // Providers above the app, as in main.dart, so sheets and dialogs —
      // routes of their own — can reach them too.
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: state),
            ChangeNotifierProvider<RestTimer>.value(value: rest),
          ],
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark),
            home: SessionPage(sessionId: sessionId),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pumpProgress(WidgetTester tester, AppState state) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: ChangeNotifierProvider<AppState>.value(
            value: state,
            child: const ProgressPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Let the store's debounced save fire, so no timer outlives the test.
      await tester.pump(const Duration(seconds: 6));
    }

    testWidgets('the hold timer records what was actually held', (
      tester,
    ) async {
      var clock = DateTime(2026, 9, 6, 10, 0);
      final state = AppState(storage: MemoryStorage(), clock: () => clock);
      await state.load();

      final session = state.startFromDay(dayNamed(state, 'Push Day'));
      final plank = session.exercises.firstWhere(
        (e) => e.exerciseId == 'plank',
      );
      session.exercises.removeWhere((e) => e.id != plank.id);

      final rest = RestTimer();
      await pumpSession(tester, state, rest, session.id);

      // One stopwatch per set, and nothing running yet.
      expect(
        find.byIcon(Icons.timer_outlined),
        findsNWidgets(plank.sets.length),
      );
      expect(find.byIcon(Icons.stop_circle), findsNothing);

      await tester.tap(find.byIcon(Icons.timer_outlined).first);
      await tester.pump();
      expect(find.text('0s'), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle), findsOneWidget);

      clock = clock.add(const Duration(seconds: 47));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('47s'),
        findsOneWidget,
        reason: 'the clock is read, not the ticks counted',
      );

      await tester.tap(find.byIcon(Icons.stop_circle));
      await tester.pump();

      expect(plank.sets.first.durationSeconds, 47);
      expect(
        plank.sets.first.done,
        isTrue,
        reason: 'stopping the clock is finishing the hold',
      );
      expect(find.byIcon(Icons.stop_circle), findsNothing);

      rest.stop();
      await tester.pump(const Duration(seconds: 6));
    });

    /// One session cut down to a single weight-and-reps exercise, which is
    /// the shape almost every logging interaction has.
    ({AppState state, WorkoutSession session, SessionExercise se}) oneLift(
      AppState state,
    ) {
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final se = session.exercises.firstWhere(
        (e) => e.exerciseId == 'lat_pulldown',
      );
      session.exercises.removeWhere((e) => e.id != se.id);
      return (state: state, session: session, se: se);
    }

    testWidgets('the session lists the exercises of the day', (tester) async {
      final state = AppState(storage: MemoryStorage());
      await state.load();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));

      final rest = RestTimer();
      await pumpSession(tester, state, rest, session.id);

      expect(find.text('Lat pulldown'), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);

      rest.stop();
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('tapping the tick logs the set', (tester) async {
      final state = AppState(storage: MemoryStorage());
      await state.load();
      final lift = oneLift(state);
      lift.se.sets.removeRange(1, lift.se.sets.length);
      lift.se.sets.first.weight = 40;
      lift.se.sets.first.reps = 10;

      final rest = RestTimer();
      await pumpSession(tester, state, rest, lift.session.id);
      expect(lift.se.sets.first.done, isFalse);

      await tester.tap(find.byIcon(Icons.check_circle_outline).first);
      await tester.pumpAndSettle();

      expect(lift.se.sets.first.done, isTrue);
      expect(lift.session.doneSets, 1);

      rest.stop();
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('finishing celebrates what was actually done', (tester) async {
      final state = AppState(storage: MemoryStorage());
      await state.load();
      final lift = oneLift(state);
      lift.se.sets.removeRange(1, lift.se.sets.length);
      state.updateSet(lift.se.sets.first, weight: 40, reps: 10, done: true);
      state.setLastSetRpe(lift.se, 8);

      final rest = RestTimer();
      await pumpSession(tester, state, rest, lift.session.id);

      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      // The confirmation first, then the celebration. Scoped to the dialog:
      // the app bar button behind it says 'Finish' too.
      expect(find.text('Finish workout'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Finish'),
        ),
      );
      await tester.pumpAndSettle();

      // A first-ever session of this lift is a best with nothing to beat.
      expect(find.text('A new best'), findsOneWidget);
      expect(
        find.textContaining('kcal'),
        findsOneWidget,
        reason: 'the estimate is on the card that celebrates the session',
      );
      expect(find.text('Done'), findsOneWidget);
      expect(state.finishedSessions, hasLength(1));

      rest.stop();
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a workout with nothing ticked is discarded, not celebrated', (
      tester,
    ) async {
      final state = AppState(storage: MemoryStorage());
      await state.load();
      final lift = oneLift(state);

      final rest = RestTimer();
      await pumpSession(tester, state, rest, lift.session.id);

      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Finish'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A new best'), findsNothing);
      expect(state.finishedSessions, isEmpty);

      rest.stop();
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('an exercise can be pulled forward when its machine is taken', (
      tester,
    ) async {
      final state = AppState(storage: MemoryStorage());
      await state.load();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final wanted = session.exercises[3];

      final rest = RestTimer();
      await pumpSession(tester, state, rest, session.id);

      // The menu hangs off the card of the exercise being moved.
      await tester.tap(find.byTooltip('Exercise options').at(3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Do this one next'));
      await tester.pumpAndSettle();

      expect(session.exercises.first.id, wanted.id);

      rest.stop();
      await tester.pump(const Duration(seconds: 6));
    });

    Finder dialogField() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    testWidgets(
      'an unknown machine step can be filled in where it is asked for',
      (tester) async {
        final state = AppState(storage: MemoryStorage());
        await state.load();
        final legs = dayNamed(state, 'Leg Day');
        logSession(
          state,
          legs,
          exerciseId: 'hip_abductor',
          sets: [(40, 18), (40, 18), (40, 18), (40, 18)],
          rpe: 7,
        );
        final session = state.startFromDay(legs);
        session.exercises.removeWhere((e) => e.exerciseId != 'hip_abductor');

        final rest = RestTimer();
        await pumpSession(tester, state, rest, session.id);

        await tester.tap(find.text('Set increment'));
        await tester.pumpAndSettle();
        await tester.enterText(dialogField(), '5');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(state.exerciseById('hip_abductor').incrementKg, 5);
        expect(find.text('Set increment'), findsNothing);
        expect(find.textContaining('Move up to 45 kg'), findsOneWidget);

        rest.stop();
        await tester.pump(const Duration(seconds: 6));
      },
    );

    testWidgets('a lagging muscle is one tap from today\'s session', (
      tester,
    ) async {
      final state = await seededOn(DateTime(2026, 9, 2));
      logSession(
        state,
        dayNamed(state, 'Leg Day'),
        exerciseId: 'leg_press',
        sets: List.generate(12, (_) => (50.0, 12)),
      );
      final session = state.startFromDay(dayNamed(state, 'Push Day'));
      session.exercises.removeWhere((e) => e.exerciseId != 'db_bench');

      final rest = RestTimer();
      await pumpSession(tester, state, rest, session.id);

      expect(find.text('LAGGING MUSCLES'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(
        find.text('Triceps'),
        findsNothing,
        reason: 'only the worst three',
      );

      await tester.tap(find.text('Lat pulldown'));
      await tester.pumpAndSettle();

      expect(
        session.exercises.map((e) => e.exerciseId),
        contains('lat_pulldown'),
      );
      expect(find.text('Back'), findsNothing, reason: 'today works it now');
      expect(find.text('Triceps'), findsOneWidget, reason: 'the next moves up');

      rest.stop();
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('the bar is set from the workout and the plates follow', (
      tester,
    ) async {
      final state = AppState(storage: MemoryStorage());
      await state.load();
      final session = state.startFromDay(dayNamed(state, 'Push Day'));
      session.exercises.removeWhere((e) => e.exerciseId != 'incline_bb_bench');
      final def = state.exerciseById('incline_bb_bench');

      final rest = RestTimer();
      await pumpSession(tester, state, rest, session.id);

      Future<void> editTo(String text) async {
        await tester.tap(find.byTooltip('Exercise options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit bar weight'));
        await tester.pumpAndSettle();
        await tester.enterText(dialogField(), text);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byTooltip('Exercise options'));
      await tester.pumpAndSettle();
      expect(find.text('20 kg bar · saved to the exercise'), findsOneWidget);
      Navigator.of(tester.element(find.text('Edit bar weight'))).pop();
      await tester.pumpAndSettle();

      await editTo('15');
      expect(def.barWeight, 15);

      await editTo('0');
      expect(def.barWeight, 15, reason: 'no bar weighs nothing');

      await tester.tap(find.byTooltip('Plate calculator'));
      await tester.pumpAndSettle();
      expect(find.text('15 kg bar · plates per side'), findsOneWidget);

      rest.stop();
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a bodyweight lift asks only for what is held', (tester) async {
      final state = AppState(storage: MemoryStorage());
      await state.load();
      final session = state.startFromDay(dayNamed(state, 'Leg Day'));
      session.exercises.removeWhere(
        (e) => e.exerciseId != 'bulgarian_split_squat',
      );

      final rest = RestTimer();
      await pumpSession(tester, state, rest, session.id);

      expect(find.text('+KG'), findsOneWidget);
      expect(find.text('KG'), findsNothing);

      rest.stop();
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('the exercise menu edits and clears the machine step', (
      tester,
    ) async {
      final state = AppState(storage: MemoryStorage());
      await state.load();
      final lift = oneLift(state);
      final def = state.exerciseById(lift.se.exerciseId);

      final rest = RestTimer();
      await pumpSession(tester, state, rest, lift.session.id);

      Future<void> editTo(String text) async {
        await tester.tap(find.byTooltip('Exercise options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit increment'));
        await tester.pumpAndSettle();
        await tester.enterText(dialogField(), text);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byTooltip('Exercise options'));
      await tester.pumpAndSettle();
      expect(find.text('6 kg a step · saved to the exercise'), findsOneWidget);
      Navigator.of(tester.element(find.text('Edit increment'))).pop();
      await tester.pumpAndSettle();

      await editTo('2,5');
      expect(def.incrementKg, 2.5, reason: 'a decimal comma is a decimal');

      await editTo('');
      expect(def.incrementKg, isNull, reason: 'blank means unknown');

      rest.stop();
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a swiped set offers an undo that puts it back', (
      tester,
    ) async {
      final clock = DateTime(2026, 9, 6, 10, 0);
      final state = AppState(storage: MemoryStorage(), clock: () => clock);
      await state.load();

      final session = state.startFromDay(dayNamed(state, 'Push Day'));
      final plank = session.exercises.firstWhere(
        (e) => e.exerciseId == 'plank',
      );
      session.exercises.removeWhere((e) => e.id != plank.id);
      plank.sets[1].durationSeconds = 42;

      final rest = RestTimer();
      await pumpSession(tester, state, rest, session.id);
      expect(plank.sets, hasLength(3));

      // Start the swipe on the set-number column: a drag begun on the
      // seconds field is swallowed by the text field's own gestures.
      final row = tester.getRect(find.byType(Dismissible).at(1));
      await tester.dragFrom(
        Offset(row.left + 15, row.center.dy),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();

      expect(plank.sets, hasLength(2), reason: 'the swipe deleted it');
      expect(find.text('Set 2 deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(plank.sets, hasLength(3));
      expect(
        plank.sets[1].durationSeconds,
        42,
        reason: 'back in its old place, with what was typed in it',
      );

      rest.stop();
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('stopping a hold instantly logs nothing', (tester) async {
      final clock = DateTime(2026, 9, 6, 10, 0);
      final state = AppState(storage: MemoryStorage(), clock: () => clock);
      await state.load();

      final session = state.startFromDay(dayNamed(state, 'Push Day'));
      final plank = session.exercises.firstWhere(
        (e) => e.exerciseId == 'plank',
      );
      session.exercises.removeWhere((e) => e.id != plank.id);

      final planned = plank.sets.first.durationSeconds;
      final rest = RestTimer();
      await pumpSession(tester, state, rest, session.id);

      await tester.tap(find.byIcon(Icons.timer_outlined).first);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.stop_circle));
      await tester.pump();

      expect(
        plank.sets.first.durationSeconds,
        planned,
        reason: 'nothing was held, so nothing is overwritten',
      );
      expect(
        plank.sets.first.done,
        isFalse,
        reason: 'a mistaken tap should not tick a set',
      );

      rest.stop();
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('coverage waits for enough log to mean anything', (
      tester,
    ) async {
      final state = await seededOn(
        wednesday,
        trackingSince: wednesday.subtract(const Duration(days: 3)),
      );
      logSession(
        state,
        dayNamed(state, 'Push Day'),
        exerciseId: 'db_bench',
        sets: [(20.0, 10)],
      );

      await pumpProgress(tester, state);

      expect(find.textContaining('about two weeks of logs'), findsOneWidget);
    });

    testWidgets('the choice day shows which routine is already done', (
      tester,
    ) async {
      // The card only appears on a day with more than one routine, and it
      // reads the real clock, so put both on whatever weekday it is now.
      final today = DateTime.now();
      final state = await seededOn(
        fmt.dateOnly(today).add(const Duration(hours: 12)),
      );
      for (final d in state.plan.days) {
        d.weekdays.clear();
      }
      final push = dayNamed(state, 'Push Day')..weekdays.add(today.weekday);
      dayNamed(state, 'Leg Day').weekdays.add(today.weekday);

      await pumpToday(tester, state);
      expect(find.text('YOUR CALL TODAY'), findsOneWidget);
      expect(find.text('Whichever feels fresher.'), findsOneWidget);
      expect(find.textContaining('done today'), findsNothing);

      logSession(state, push, exerciseId: 'db_bench', sets: [(20.0, 10)]);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));

      expect(find.text('Whichever feels fresher.'), findsNothing);
      expect(find.textContaining('Push Day  ·  done today'), findsOneWidget);
      expect(find.textContaining('Leg Day  ·  9 exercises'), findsOneWidget);
      expect(find.textContaining('Leg Day is still there'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      // Resting is a call about a day you have not trained.
      expect(find.text('Taking a rest day'), findsNothing);
    });

    testWidgets('a planned day is not done because another routine was', (
      tester,
    ) async {
      // Push is what the plan asks for today; pull is what got trained.
      final today = DateTime.now();
      final state = await seededOn(
        fmt.dateOnly(today).add(const Duration(hours: 12)),
      );
      for (final d in state.plan.days) {
        d.weekdays.clear();
      }
      dayNamed(state, 'Push Day').weekdays.add(today.weekday);

      logSession(
        state,
        dayNamed(state, 'Pull Day'),
        exerciseId: 'lat_pulldown',
        sets: [(30.0, 10)],
      );

      await pumpToday(tester, state);

      expect(find.text('ON THE PLAN TODAY'), findsOneWidget);
      expect(find.text('Push Day'), findsOneWidget);
      expect(
        find.text('Done'),
        findsNothing,
        reason: 'the day on the card is the one that was not trained',
      );
      expect(
        find.textContaining('Pull Day done today instead'),
        findsOneWidget,
      );
      expect(
        find.text('Start workout'),
        findsOneWidget,
        reason: 'a first go at push is not a repeat',
      );
      expect(find.text('Train again'), findsNothing);
      // Resting is a call about a day you have not trained.
      expect(find.text('Taking a rest day'), findsNothing);
    });

    testWidgets('an abandoned session does not count as trained', (
      tester,
    ) async {
      final today = DateTime.now();
      final state = await seededOn(
        fmt.dateOnly(today).add(const Duration(hours: 12)),
      );
      for (final d in state.plan.days) {
        d.weekdays.clear();
      }
      dayNamed(state, 'Push Day').weekdays.add(today.weekday);
      dayNamed(state, 'Leg Day').weekdays.add(today.weekday);

      // Started and finished without ticking anything off.
      final session = state.startFromDay(dayNamed(state, 'Push Day'));
      for (final e in session.exercises) {
        for (final set in e.sets) {
          set.done = false;
        }
      }
      state.finishSession(session);

      await pumpToday(tester, state);

      expect(find.text('Whichever feels fresher.'), findsOneWidget);
      expect(find.textContaining('done today'), findsNothing);
    });

    testWidgets('coverage names the under-served muscles', (tester) async {
      final state = await seededOn(wednesday);
      logSession(
        state,
        dayNamed(state, 'Push Day'),
        exerciseId: 'db_bench',
        sets: List.generate(12, (_) => (20.0, 10)),
      );

      await pumpProgress(tester, state);

      expect(find.text('MUSCLE COVERAGE · LAST 28 DAYS'), findsOneWidget);
      expect(find.textContaining('under-served'), findsOneWidget);
      expect(
        find.textContaining('synergists counted as half a set'),
        findsOneWidget,
      );
      // Glutes have no direct work anywhere in this plan, so they lead.
      expect(find.text('Glutes'), findsOneWidget);
      expect(
        find.textContaining('Nothing in your routine targets it directly'),
        findsWidgets,
      );
    });
  });
}

class PlateStack {
  const PlateStack(this.plate, this.count);
  final double plate;
  final int count;
}

class PlateResult {
  const PlateResult({
    required this.perSide,
    required this.achieved,
    required this.target,
    required this.barWeight,
  });

  /// Plates to load on each side, heaviest first.
  final List<PlateStack> perSide;
  final double achieved;
  final double target;
  final double barWeight;

  bool get exact => (achieved - target).abs() < 0.01;
  double get leftover => target - achieved;
  bool get belowBar => target < barWeight;
}

/// Greedy per-side plate breakdown. Plate inventory is treated as unlimited,
/// which matches how a commercial gym rack actually behaves.
PlateResult calculatePlates({
  required double target,
  required double barWeight,
  required List<double> available,
}) {
  if (target < barWeight) {
    return PlateResult(
      perSide: const [],
      achieved: barWeight,
      target: target,
      barWeight: barWeight,
    );
  }

  final plates = [...available]..sort((a, b) => b.compareTo(a));
  var perSideRemaining = (target - barWeight) / 2;
  final stacks = <PlateStack>[];

  for (final p in plates) {
    if (p <= 0) continue;
    final count = (perSideRemaining / p).floor();
    if (count > 0) {
      stacks.add(PlateStack(p, count));
      perSideRemaining -= count * p;
    }
    if (perSideRemaining < 0.01) break;
  }

  final loaded = stacks.fold(0.0, (a, s) => a + s.plate * s.count);
  return PlateResult(
    perSide: stacks,
    achieved: barWeight + loaded * 2,
    target: target,
    barWeight: barWeight,
  );
}

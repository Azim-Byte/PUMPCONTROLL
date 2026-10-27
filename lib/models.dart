enum PumpMode { idle, counted, infinite, paused }

class CalibrationPoint {
  double volume;
  int pulses;
  CalibrationPoint(this.volume, this.pulses);

  Map<String, dynamic> toJson() => {'volume': volume, 'pulses': pulses};
  factory CalibrationPoint.fromJson(Map<String, dynamic> x) => CalibrationPoint(
      (x['volume'] as num).toDouble(), (x['pulses'] as num).toInt());
}

class PumpModel {
  String name;
  double volume;
  int periodMs;
  int done;
  int target;
  bool output;
  PumpMode mode;
  double a, b, r2;
  List<CalibrationPoint> points;
  DateTime? started;

  PumpModel(this.name, {
    this.volume = 0,
    this.periodMs = 500,
    this.done = 0,
    this.target = 0,
    this.output = false,
    this.mode = PumpMode.idle,
    this.a = 0,
    this.b = 0,
    this.r2 = 0,
    List<CalibrationPoint>? points,
  }) : points = points ?? [];

  int pulsesFor(double ml) {
    if (a == 0) return 0;
    final n = (a * ml + b).round();
    return n.clamp(1, 300000); // Расширили лимит до 300к
  }

  double get progress => target <= 0 ? 0 : (done / target).clamp(0, 1).toDouble();
  Duration get estimate => Duration(milliseconds: target * periodMs);
  Duration get elapsed => started == null ? Duration.zero : DateTime.now().difference(started!);

  Map<String, dynamic> toJson() => {
        'name': name,
        'volume': volume,
        'periodMs': periodMs,
        'a': a,
        'b': b,
        'r2': r2,
        'points': points.map((e) => e.toJson()).toList(),
      };

  factory PumpModel.fromJson(Map<String, dynamic> x) => PumpModel(
        x['name'] ?? 'Насос',
        volume: (x['volume'] ?? 0).toDouble(),
        periodMs: (x['periodMs'] ?? 500).toInt(),
        a: (x['a'] ?? 0).toDouble(),
        b: (x['b'] ?? 0).toDouble(),
        r2: (x['r2'] ?? 0).toDouble(),
        points: ((x['points'] ?? []) as List)
            .map((e) => CalibrationPoint.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class ProfileModel {
  String name;
  List<double> volumes;
  List<int> periods;
  List<bool> enabled;

  ProfileModel(this.name, this.volumes, this.periods, this.enabled);

  Map<String, dynamic> toJson() => {
        'name': name,
        'volumes': volumes,
        'periods': periods,
        'enabled': enabled,
      };

  factory ProfileModel.fromJson(Map<String, dynamic> x) => ProfileModel(
        x['name'] ?? 'Профиль',
        (x['volumes'] as List).map((e) => (e as num).toDouble()).toList(),
        (x['periods'] as List).map((e) => (e as num).toInt()).toList(),
        (x['enabled'] as List).map((e) => e as bool).toList(),
      );
}
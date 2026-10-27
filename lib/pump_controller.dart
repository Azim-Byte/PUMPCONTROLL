import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class PumpController extends ChangeNotifier {
  final List<PumpModel> pumps =
      List.generate(4, (i) => PumpModel('Насос ${i + 1}'));
  final List<ProfileModel> profiles = [];
  final List<String> journal = [];
  List<String> ports = [];
  String? selectedPort;
  SerialPort? _serial;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _serialSub;
  Timer? _ticker;

  // Исправленный буфер: собираем сначала сырые байты, чтобы избежать разрывов UTF-8 строк
  final List<int> _rxRawBuffer = [];
  bool connecting = false;
  int baud = 115200;

  bool get connected => _serial?.isOpen ?? false;

  void init() {
    _ticker = Timer.periodic(
        const Duration(milliseconds: 500), (_) => notifyListeners());
    _load();
    refreshPorts();
  }

  void disposeController() {
    _ticker?.cancel();
    _ticker = null; // ← Добавить обнуление
    _serialSub?.cancel();
    _serialSub = null;
    if (_serial?.isOpen ?? false) _serial!.close();
    _serial?.dispose();
    _serial = null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < 4; i++) {
      final raw = prefs.getString('pump_$i');
      if (raw != null) pumps[i] = PumpModel.fromJson(jsonDecode(raw));
    }
    final rawProfiles = prefs.getString('profiles');
    if (rawProfiles != null) {
      profiles.clear();
      profiles.addAll((jsonDecode(rawProfiles) as List)
          .map((e) => ProfileModel.fromJson(Map<String, dynamic>.from(e))));
    }
    notifyListeners();
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (int i = 0; i < 4; i++) {
        await prefs.setString('pump_$i', jsonEncode(pumps[i].toJson()));
      }
      await prefs.setString(
          'profiles', jsonEncode(profiles.map((e) => e.toJson()).toList()));
      notifyListeners();
    } catch (e) {
      log('Ошибка сохранения: $e', tag: 'ERROR');
    }
  }

  void refreshPorts() {
    ports = SerialPort.availablePorts;
    notifyListeners();
  }

  void setPort(String? port) {
    if (port != null && !ports.contains(port)) {
      log('Порт $port недоступен', tag: 'WARN');
      return;
    }
    selectedPort = port;
    notifyListeners();
  }

  void setBaud(int value) {
    baud = value;
    notifyListeners();
  }

  void log(String text, {String tag = 'INFO'}) {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    journal.insert(0, '$timeStr  [$tag]  $text');
    if (journal.length > 250) journal.removeLast();
    notifyListeners();
  }

  void clearJournal() {
    journal.clear();
    notifyListeners();
  }

  Future<void> toggleConnect() async {
    if (connected) {
      await _disconnect();
    } else {
      await _connect();
    }
  }

  Future<void> _connect() async {
    if (selectedPort == null || connecting) return;
    connecting = true;
    notifyListeners();

    final p = SerialPort(selectedPort!);
    final config = SerialPortConfig()
      ..baudRate = baud
      ..bits = 8
      ..stopBits = 1
      ..parity = SerialPortParity.none;

    if (!p.openReadWrite()) {
      log('Не удалось открыть $selectedPort: ${SerialPort.lastError}',
          tag: 'ERROR');
      p.dispose();
      connecting = false;
      notifyListeners();
      return;
    }

    p.config = config;
    _serial = p;
    _reader = SerialPortReader(p);
    _serialSub = _reader!.stream
        .listen(_onSerialData, onError: (e) => log('$e', tag: 'ERROR'));

    connecting = false;
    log('Подключение к $selectedPort установлено', tag: 'INFO');

    for (int i = 1; i <= 4; i++) {
      _send('$i:status');
    }
    notifyListeners();
  }

  Future<void> _disconnect() async {
    await _serialSub?.cancel();
    _serialSub = null;
    _reader = null;
    final p = _serial;
    _serial = null;
    if (p != null) {
      if (p.isOpen) p.close();
      p.dispose();
    }
    log('Соединение закрыто', tag: 'INFO');
    notifyListeners();
  }

  void _send(String command) {
    if (!connected) {
      log('Команда не отправлена — не подключено: $command', tag: 'WARN');
      return;
    }
    try {
      _serial!.write(Uint8List.fromList(utf8.encode('$command\n')));
      log(command, tag: 'TX');
    } catch (e) {
      log('Ошибка отправки: $e', tag: 'ERROR');
    }
  }

  void _onSerialData(Uint8List data) {
    _rxRawBuffer.addAll(data);

    // Ищем символ перевода строки (10 = '\n') в байтах
    while (_rxRawBuffer.contains(10)) {
      final index = _rxRawBuffer.indexOf(10);
      final lineBytes = _rxRawBuffer.sublist(0, index);
      _rxRawBuffer.removeRange(0, index + 1);

      final line = utf8.decode(lineBytes, allowMalformed: true).trim();
      if (line.isNotEmpty) {
        log(line, tag: 'RX');
        _parseStatus(line);
      }
    }
  }

  void _parseStatus(String line) {
    if (!line.startsWith('CH')) return;
    final a = line.split(':');
    if (a.length < 6) return;
    final channel = int.tryParse(a[0].substring(2));
    if (channel == null || channel < 1 || channel > 4) return;

    final p = pumps[channel - 1];
    p.mode = switch (a[1]) {
      'COUNTED' => PumpMode.counted,
      'INFINITE' => PumpMode.infinite,
      'PAUSED' => PumpMode.paused,
      _ => PumpMode.idle,
    };
    p.done = int.tryParse(a[2]) ?? p.done;
    p.target = int.tryParse(a[3]) ?? p.target;
    p.periodMs = int.tryParse(a[4]) ?? p.periodMs;
    p.output = a[5] == '1';

    if (p.mode == PumpMode.idle) {
      p.started = null;
    } else {
      p.started ??= DateTime.now();
    }
    notifyListeners();
  }

  void setPeriod(int i, int value) {
    pumps[i].periodMs = value.clamp(20, 5000);
    _send('${i + 1}:period:${pumps[i].periodMs}');
    save();
  }

  bool dose(int i) {
    final p = pumps[i];
    final n = p.pulsesFor(p.volume);
    if (n <= 0) {
      log('Насос ${i + 1}: сначала заполните калибровку', tag: 'WARN');
      return false;
    }
    p.target = n;
    p.done = 0;
    p.started = DateTime.now();
    _send('${i + 1}:dose:$n:period:${p.periodMs}');
    log('Насос ${i + 1}: дозирование ${p.volume.toStringAsFixed(2)} мл ($n имп.)',
        tag: 'PUMP${i + 1}');
    notifyListeners();
    return true;
  }

  void startContinuous(int i) {
    pumps[i].started = DateTime.now();
    _send('${i + 1}:start');
    log('Насос ${i + 1}: непрерывный режим', tag: 'PUMP${i + 1}');
    notifyListeners();
  }

  void pause(int i) => _send('${i + 1}:pause');
  void resume(int i) => _send('${i + 1}:resume');
  void stop(int i) => _send('${i + 1}:stop');
  void stopAll() {
    for (int i = 0; i < 4; i++) {
      stop(i);
    }
    log('EMERGENCY STOP — все каналы остановлены', tag: 'EMERGENCY');
  }

  void applyProfile(ProfileModel profile) {
    for (int i = 0; i < 4; i++) {
      pumps[i].volume = profile.volumes[i];
      pumps[i].periodMs = profile.periods[i];
      if (profile.enabled[i]) {
        dose(i);
      } else {
        stop(i);
      }
    }
    save();
    log('Профиль «${profile.name}» запущен', tag: 'PROFILE');
  }

  void addProfile(String name) {
    profiles.add(ProfileModel(
        name,
        pumps.map((e) => e.volume).toList(),
        pumps.map((e) => e.periodMs).toList(),
        pumps.map((e) => e.mode != PumpMode.idle).toList()));
    save();
  }

  void deleteProfile(ProfileModel p) {
    profiles.remove(p);
    save();
  }
}

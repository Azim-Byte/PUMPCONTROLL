// ============================================================
// ИМПОРТЫ
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'pump_controller.dart';

// ============================================================
// ГЛАВНАЯ ФУНКЦИЯ
// ============================================================
void main() => runApp(const PumpControlApp());

// ============================================================
// ГЛОБАЛЬНЫЕ КОНСТАНТЫ
// ============================================================
const bgDark = Color(0xFF091018);
const panelDark = Color(0xFF111B25);
const blue = Color(0xFF168CE2);

// ============================================================
// ПРИЛОЖЕНИЕ
// ============================================================
class PumpControlApp extends StatefulWidget {
  const PumpControlApp({super.key});

  @override
  State<PumpControlApp> createState() => _PumpControlAppState();
}

class _PumpControlAppState extends State<PumpControlApp> {
  ThemeMode themeMode = ThemeMode.dark;
  final PumpController controller = PumpController();

  @override
  void initState() {
    super.initState();
    controller.init();
  }

  @override
  void dispose() {
    controller.disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PUMPCONTROL INDUSTRIAL',
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDark,
        cardColor: panelDark,
      ),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return ControlShell(
            controller: controller,
            dark: themeMode == ThemeMode.dark,
            onTheme: () => setState(() {
              themeMode = themeMode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
            }),
          );
        },
      ),
    );
  }
}

// ============================================================
// ПЕРЕЧИСЛЕНИЕ СТРАНИЦ
// ============================================================
enum PageId {
  dashboard,
  pumps,
  calibration,
  profiles,
  journal,
  settings,
  about,
}

// ============================================================
// ОСНОВНАЯ ОБОЛОЧКА ПРИЛОЖЕНИЯ
// ============================================================
class ControlShell extends StatefulWidget {
  const ControlShell({
    super.key,
    required this.controller,
    required this.dark,
    required this.onTheme,
  });

  final PumpController controller;
  final bool dark;
  final VoidCallback onTheme;

  @override
  State<ControlShell> createState() => _ControlShellState();
}

class _ControlShellState extends State<ControlShell> {
  PageId page = PageId.dashboard;

  // --- Обработчики событий ---
  void _handleDose(int index) {
    final success = widget.controller.dose(index);
    if (!success) {
      _showMessage(
          'Для насоса ${index + 1} нет рабочего уравнения калибровки или объем равен 0.');
    }
  }

  void _handleEmergency() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ АВАРИЙНАЯ ОСТАНОВКА'),
        content: const Text('Вы уверены, что хотите остановить все насосы?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОТМЕНА'),
          ),
          FilledButton(
            onPressed: () {
              widget.controller.stopAll();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ОСТАНОВИТЬ ВСЕ'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String text) => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('PUMPCONTROL'),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  Future<void> _createProfile() async {
    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Новый профиль'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Название профиля'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОТМЕНА'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text.trim()),
            child: const Text('СОХРАНИТЬ'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      widget.controller.addProfile(name);
    }
  }

  void _openPumpSettings(int i) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PumpSettingsPage(
          pump: widget.controller.pumps[i],
          index: i,
          onSave: widget.controller.save,
        ),
      ),
    );
    setState(() {});
  }

  void _openCalibration(int i) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalibrationPage(
          pump: widget.controller.pumps[i],
          index: i,
          onSave: widget.controller.save,
        ),
      ),
    );
    setState(() {});
  }

  // --- Построение страниц ---
  Widget _buildPage() {
    final c = widget.controller;
    return switch (page) {
      PageId.dashboard => DashboardPage(
          pumps: c.pumps,
          onDose: _handleDose,
          onStart: c.startContinuous,
          onPause: c.pause,
          onResume: c.resume,
          onStop: c.stop,
          onPeriod: c.setPeriod,
          onSettings: _openPumpSettings,
        ),
      PageId.pumps => PumpsPage(
          pumps: c.pumps,
          onSettings: _openPumpSettings,
          onDose: _handleDose,
          onStop: c.stop,
        ),
      PageId.calibration => CalibrationListPage(
          pumps: c.pumps,
          onOpen: _openCalibration,
        ),
      PageId.profiles => ProfilesPage(
          profiles: c.profiles,
          onCreate: _createProfile,
          onApply: c.applyProfile,
          onDelete: c.deleteProfile,
        ),
      PageId.journal => JournalPage(
          entries: c.journal,
          onClear: c.clearJournal,
        ),
      PageId.settings => SettingsPage(controller: c),
      PageId.about => const AboutPage(),
    };
  }

  // --- Основной билд ---
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRailPanel(
              page: page,
              connected: c.connected,
              port: c.selectedPort,
              baud: c.baud,
              onPage: (p) => setState(() => page = p),
            ),
            Expanded(
              child: Column(
                children: [
                  TopBar(
                    port: c.selectedPort,
                    baud: c.baud,
                    connected: c.connected,
                    ports: c.ports,
                    onPort: c.setPort,
                    onBaud: c.setBaud,
                    onRefresh: c.refreshPorts,
                    onConnect: c.toggleConnect,
                    onEmergency: _handleEmergency,
                    dark: widget.dark,
                    onTheme: widget.onTheme,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                      child: _buildPage(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// НАВИГАЦИОННАЯ ПАНЕЛЬ
// ============================================================
class NavigationRailPanel extends StatelessWidget {
  const NavigationRailPanel({
    super.key,
    required this.page,
    required this.connected,
    required this.port,
    required this.baud,
    required this.onPage,
  });

  final PageId page;
  final bool connected;
  final String? port;
  final int baud;
  final ValueChanged<PageId> onPage;

  @override
  Widget build(BuildContext context) {
    final items = <(PageId, IconData, String)>[
      (PageId.dashboard, Icons.dashboard_outlined, 'ПАНЕЛЬ'),
      (PageId.pumps, Icons.water_drop_outlined, 'НАСОСЫ'),
      (PageId.calibration, Icons.speed_outlined, 'КАЛИБРОВКА'),
      (PageId.profiles, Icons.inventory_2_outlined, 'ПРОФИЛИ'),
      (PageId.journal, Icons.receipt_long_outlined, 'ЖУРНАЛ'),
      (PageId.settings, Icons.settings_outlined, 'НАСТРОЙКИ'),
      (PageId.about, Icons.info_outline, 'О ПРОГРАММЕ'),
    ];

    return Container(
      width: 188,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0D1721)
            : null,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          // --- Логотип ---
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 10, 22),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.water_drop,
                    size: 23,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PUMPCONTROL',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'INDUSTRIAL',
                      style: TextStyle(
                        fontSize: 10,
                        color: blue,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- Пункты меню ---
          ...items.map(
            (e) => _NavItem(
              icon: e.$2,
              label: e.$3,
              selected: page == e.$1,
              onTap: () => onPage(e.$1),
            ),
          ),

          const Spacer(),

          // --- Статус соединения ---
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 11,
                      color: connected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      connected ? 'СОЕДИНЕНИЕ' : 'НЕТ СВЯЗИ',
                      style: TextStyle(
                        fontSize: 10,
                        color: connected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${port ?? 'COM —'} / $baud',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ЭЛЕМЕНТ НАВИГАЦИИ
// ============================================================
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: selected ? blue.withValues(alpha: .16) : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? blue : Theme.of(context).iconTheme.color,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? blue : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ВЕРХНЯЯ ПАНЕЛЬ (TOPBAR)
// ============================================================
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.port,
    required this.baud,
    required this.connected,
    required this.ports,
    required this.onPort,
    required this.onBaud,
    required this.onRefresh,
    required this.onConnect,
    required this.onEmergency,
    required this.dark,
    required this.onTheme,
  });

  final String? port;
  final int baud;
  final bool connected;
  final List<String> ports;
  final ValueChanged<String?> onPort;
  final ValueChanged<int> onBaud;
  final VoidCallback onRefresh, onConnect, onEmergency, onTheme;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          // --- Выбор порта ---
          const Text('Порт:', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          SizedBox(
            width: 105,
            child: DropdownButtonFormField<String>(
              initialValue: ports.contains(port) ? port : null,
              isDense: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: ports
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onPort,
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
          ),

          const SizedBox(width: 10),

          // --- Выбор скорости ---
          const Text('Скорость:', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          SizedBox(
            width: 105,
            child: DropdownButtonFormField<int>(
              initialValue: baud,
              isDense: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 9600, child: Text('9600')),
                DropdownMenuItem(value: 19200, child: Text('19200')),
                DropdownMenuItem(value: 38400, child: Text('38400')),
                DropdownMenuItem(value: 57600, child: Text('57600')),
                DropdownMenuItem(value: 115200, child: Text('115200')),
              ],
              onChanged: (v) {
                if (v != null) onBaud(v);
              },
            ),
          ),

          const Spacer(),

          // --- Индикатор подключения ---
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? Colors.green : Colors.red,
              boxShadow: [
                BoxShadow(
                  color: (connected ? Colors.green : Colors.red)
                      .withValues(alpha: .45),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                connected ? 'ПОДКЛЮЧЕНО' : 'ОТКЛЮЧЕНО',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: connected ? Colors.green : Colors.red,
                ),
              ),
              const Text(
                'Arduino Nano',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),

          const SizedBox(width: 18),

          // --- Кнопка темы ---
          IconButton(
            onPressed: onTheme,
            icon: Icon(dark ? Icons.dark_mode : Icons.light_mode),
          ),

          const SizedBox(width: 8),

          // --- Кнопка подключения ---
          FilledButton.icon(
            onPressed: onConnect,
            icon: Icon(connected ? Icons.link_off : Icons.link, size: 17),
            label: Text(connected ? 'ОТКЛЮЧИТЬ' : 'ПОДКЛЮЧИТЬ'),
          ),

          const SizedBox(width: 8),

          // --- Кнопка аварийной остановки ---
          FilledButton.icon(
            onPressed: onEmergency,
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            icon: const Icon(Icons.pan_tool_outlined, size: 17),
            label: const Text('EMERGENCY STOP'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// СТРАНИЦА: ПАНЕЛЬ УПРАВЛЕНИЯ (DASHBOARD)
// ============================================================
class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.pumps,
    required this.onDose,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onPeriod,
    required this.onSettings,
  });

  final List<PumpModel> pumps;
  final void Function(int) onDose,
      onStart,
      onPause,
      onResume,
      onStop,
      onSettings;
  final void Function(int, int) onPeriod;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ПАНЕЛЬ УПРАВЛЕНИЯ',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (_, constraints) {
              return GridView.count(
                crossAxisCount: constraints.maxWidth > 1200
                    ? 4
                    : constraints.maxWidth > 760
                        ? 2
                        : 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: constraints.maxWidth > 1200 ? 1.0 : 1.15,
                children: List.generate(
                  4,
                  (i) => PumpCard(
                    index: i,
                    pump: pumps[i],
                    onDose: () => onDose(i),
                    onStart: () => onStart(i),
                    onPause: () => onPause(i),
                    onResume: () => onResume(i),
                    onStop: () => onStop(i),
                    onPeriod: (v) => onPeriod(i, v),
                    onSettings: () => onSettings(i),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// КОМПОНЕНТ: КАРТОЧКА НАСОСА (PumpCard)
// ============================================================
class PumpCard extends StatelessWidget {
  const PumpCard({
    super.key,
    required this.index,
    required this.pump,
    required this.onDose,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onPeriod,
    required this.onSettings,
  });

  final int index;
  final PumpModel pump;
  final VoidCallback onDose, onStart, onPause, onResume, onStop, onSettings;
  final ValueChanged<int> onPeriod;

  Color get accent => [blue, Colors.green, Colors.orange, Colors.purple][index];

  String fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final calc = pump.pulsesFor(pump.volume);
    final active = pump.mode != PumpMode.idle;
    final paused = pump.mode == PumpMode.paused;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: accent, width: 1.1),
      ),
      child: Column(
        children: [
          Container(height: 3, color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Заголовок ---
                  Row(
                    children: [
                      Container(
                        width: 27,
                        height: 27,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        pump.name.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onSettings,
                        icon: const Icon(Icons.settings, size: 19),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),

                  // --- Статус ---
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 9,
                        color: active
                            ? (paused ? Colors.orange : Colors.green)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        paused
                            ? 'PAUSE'
                            : active
                                ? (pump.mode == PumpMode.infinite
                                    ? 'RUN ∞'
                                    : 'RUN')
                                : 'IDLE',
                        style: TextStyle(
                          color: active
                              ? (paused ? Colors.orange : Colors.green)
                              : Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        pump.mode == PumpMode.counted ? 'ДОЗИРОВАНИЕ' : '',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // --- Метрики ---
                  _Metric(
                      'Объём (задан)', '${pump.volume.toStringAsFixed(2)} мл'),
                  _Metric('Импульсов (расчёт)', calc > 0 ? '$calc имп.' : '—'),
                  _Metric('Период импульса', '${pump.periodMs} мс'),
                  _Metric(
                    'Выполнено импульсов',
                    '${pump.done} / ${pump.target > 0 ? pump.target : calc}',
                  ),

                  const SizedBox(height: 5),

                  // --- Прогресс ---
                  LinearProgressIndicator(
                    value: pump.target > 0 ? pump.progress : 0,
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(4),
                    color: accent,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        '${(pump.progress * 100).round()}%',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Осталось: ${pump.target > 0 ? (pump.target - pump.done).clamp(0, pump.target) : calc} имп.',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  _Metric('Прошло времени', fmt(pump.elapsed)),
                  _Metric('Оценочное время', fmt(pump.estimate)),

                  const SizedBox(height: 2),

                  // --- Слайдер периода ---
                  Row(
                    children: [
                      const Text(
                        'Период',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Expanded(
                        child: Slider(
                          value: pump.periodMs.toDouble(),
                          min: 20,
                          max: 5000,
                          onChanged: (v) => onPeriod(v.round()),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // --- Кнопки управления ---
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: onDose,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                          ),
                          child: const Text('СТАРТ'),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: active && !paused
                              ? onPause
                              : paused
                                  ? onResume
                                  : null,
                          child: Text(paused ? 'ПРОДОЛЖИТЬ' : 'ПАУЗА'),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: FilledButton(
                          onPressed: active ? onStop : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                          ),
                          child: const Text('СТОП'),
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
    );
  }
}

// ============================================================
// КОМПОНЕНТ: МЕТРИКА (Metric)
// ============================================================
class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// СТРАНИЦА: НАСОСЫ (PUMPS)
// ============================================================
class PumpsPage extends StatelessWidget {
  const PumpsPage({
    super.key,
    required this.pumps,
    required this.onSettings,
    required this.onDose,
    required this.onStop,
  });

  final List<PumpModel> pumps;
  final void Function(int) onSettings, onDose, onStop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'НАСОСЫ',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: 4,
            separatorBuilder: (_, i) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final colors = [blue, Colors.green, Colors.orange, Colors.purple];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colors[i],
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(pumps[i].name),
                  subtitle: Text(
                    '${pumps[i].volume.toStringAsFixed(2)} мл  •  ${pumps[i].pulsesFor(pumps[i].volume)} имп.  •  ${pumps[i].periodMs} мс',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        onPressed: () => onSettings(i),
                        icon: const Icon(Icons.settings),
                      ),
                      FilledButton(
                        onPressed: () => onDose(i),
                        child: const Text('СТАРТ'),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => onStop(i),
                        icon: const Icon(Icons.stop_circle, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// СТРАНИЦА: КАЛИБРОВКА (СПИСОК)
// ============================================================
class CalibrationListPage extends StatelessWidget {
  const CalibrationListPage({
    super.key,
    required this.pumps,
    required this.onOpen,
  });

  final List<PumpModel> pumps;
  final void Function(int) onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = [blue, Colors.green, Colors.orange, Colors.purple];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'КАЛИБРОВКА',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Индивидуальная линейная зависимость количества импульсов от объёма.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            itemCount: 4,
            separatorBuilder: (_, i) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final p = pumps[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors[i].withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: colors[i],
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'N = ${p.a.toStringAsFixed(6)} × V + ${p.b.toStringAsFixed(6)}',
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                            Text(
                              'R² = ${p.r2.toStringAsFixed(6)}    •    Точек: ${p.points.length}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => onOpen(i),
                        icon: const Icon(Icons.science, size: 17),
                        label: const Text('ОТКРЫТЬ'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// СТРАНИЦА: КАЛИБРОВКА (РЕДАКТОР)
// ============================================================
class CalibrationPage extends StatefulWidget {
  const CalibrationPage({
    super.key,
    required this.pump,
    required this.index,
    required this.onSave,
  });

  final PumpModel pump;
  final int index;
  final VoidCallback onSave;

  @override
  State<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<CalibrationPage> {
  final volume = TextEditingController();
  final pulses = TextEditingController();

  @override
  void dispose() {
    volume.dispose();
    pulses.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- Расчёт коэффициентов ---
  void fit() {
    final pts = widget.pump.points;
    if (pts.length < 2) {
      setState(() {
        widget.pump.a = 0;
        widget.pump.b = 0;
        widget.pump.r2 = 0;
      });
      widget.onSave();
      return;
    }

    final xm = pts.map((p) => p.volume).reduce((a, b) => a + b) / pts.length;
    final ym = pts.map((p) => p.pulses.toDouble()).reduce((a, b) => a + b) /
        pts.length;

    double xy = 0, xx = 0, total = 0, res = 0;

    for (final p in pts) {
      xy += (p.volume - xm) * (p.pulses - ym);
      xx += (p.volume - xm) * (p.volume - xm);
    }

    if (xx == 0) return;

    final a = xy / xx;
    final b = ym - a * xm;

    for (final p in pts) {
      final e = p.pulses - (a * p.volume + b);
      res += e * e;
      total += (p.pulses - ym) * (p.pulses - ym);
    }

    setState(() {
      widget.pump.a = a;
      widget.pump.b = b;
      widget.pump.r2 = total == 0 ? 1 : 1 - res / total;
    });
    widget.onSave();
  }

  void add() {
    final v = double.tryParse(volume.text.replaceAll(',', '.'));
    final n = int.tryParse(pulses.text);

    // Проверка на пустые поля
    if (volume.text.trim().isEmpty || pulses.text.trim().isEmpty) {
      _showSnackBar('Заполните оба поля');
      return;
    }

    // Проверка на корректные числа
    if (v == null || n == null) {
      _showSnackBar('Введите корректные числа');
      return;
    }

    // Проверка на положительные значения
    if (v <= 0 || n <= 0) {
      _showSnackBar('Значения должны быть больше 0');
      return;
    }

    // Проверка на разумные пределы
    if (v > 1000) {
      _showSnackBar('Объём не должен превышать 1000 мл');
      return;
    }

    if (n > 1000000) {
      _showSnackBar('Слишком много импульсов (макс. 1 000 000)');
      return;
    }

    // Проверка на дубликаты
    if (widget.pump.points.any((p) => p.volume == v)) {
      _showSnackBar('Точка с таким объёмом уже существует', isError: false);
      return;
    }

    // Всё хорошо - добавляем точку
    setState(() => widget.pump.points.add(CalibrationPoint(v, n)));
    volume.clear();
    pulses.clear();
    fit();
    _showSnackBar('Точка добавлена!', isError: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('КАЛИБРОВКА НАСОСА ${widget.index + 1}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          // --- Блок параметров ---
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ПАРАМЕТРЫ КАЛИБРОВКИ',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Уравнение',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          'N = ${widget.pump.a.toStringAsFixed(6)} × V + ${widget.pump.b.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                            'a (коэффициент): ${widget.pump.a.toStringAsFixed(6)}'),
                        Text(
                            'b (смещение): ${widget.pump.b.toStringAsFixed(6)}'),
                        Text(
                            'R² (качество): ${widget.pump.r2.toStringAsFixed(6)}'),
                        const SizedBox(height: 12),
                        const Text(
                          'Рекомендуемый диапазон: 1–100 мл.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // --- Блок точек ---
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'КАЛИБРОВОЧНЫЕ ТОЧКИ',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: add,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('ДОБАВИТЬ'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: volume,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Объём (мл)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  helperText: 'Диапазон: 0.1 - 1000 мл',
                                  helperStyle: TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: pulses,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Импульсы',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  helperText: 'Диапазон: 1 - 1 000 000',
                                  helperStyle: TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...widget.pump.points.asMap().entries.map(
                              (e) => ListTile(
                                dense: true,
                                title: Text(
                                    '${e.value.volume.toStringAsFixed(2)} мл'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${e.value.pulses} имп.'),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          widget.pump.points.removeAt(e.key);
                                        });
                                        fit();
                                      },
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // --- Кнопки действий ---
          Row(
            children: [
              OutlinedButton(
                onPressed: fit,
                child: const Text('ПЕРЕСЧИТАТЬ УРАВНЕНИЕ'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  widget.onSave();
                  Navigator.pop(context);
                },
                child: const Text('СОХРАНИТЬ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// СТРАНИЦА: НАСТРОЙКИ НАСОСА
// ============================================================
class PumpSettingsPage extends StatefulWidget {
  const PumpSettingsPage({
    super.key,
    required this.pump,
    required this.index,
    required this.onSave,
  });

  final PumpModel pump;
  final int index;
  final VoidCallback onSave;

  @override
  State<PumpSettingsPage> createState() => _PumpSettingsPageState();
}

class _PumpSettingsPageState extends State<PumpSettingsPage> {
  late TextEditingController name, volume;
  double period = 500;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.pump.name);
    volume = TextEditingController(text: widget.pump.volume.toString());
    period = widget.pump.periodMs.toDouble();
  }

  @override
  void dispose() {
    name.dispose();
    volume.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.pump.pulsesFor(
      double.tryParse(volume.text.replaceAll(',', '.')) ?? 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('НАСОС ${widget.index + 1} — НАСТРОЙКИ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ПАРАМЕТРЫ НАСОСА',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Имя насоса',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: volume,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Объём (мл)',
                      border: OutlineInputBorder(),
                      suffixText: 'мл',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Импульсов (расчёт)'),
                    trailing: Text(
                      n > 0 ? '$n имп.' : '—',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  Text(
                    'Период импульса: ${period.round()} мс',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: period,
                    min: 20,
                    max: 5000,
                    divisions: 498,
                    onChanged: (v) => setState(() => period = v),
                  ),
                  const Text(
                    'Период — время между переходами ВКЛ и ВЫКЛ. Он регулирует скорость.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Оценочное время дозирования: ${(n * period.round() / 1000).toStringAsFixed(1)} сек.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ОТМЕНА'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  widget.pump.name = name.text.trim().isEmpty
                      ? 'Насос ${widget.index + 1}'
                      : name.text.trim();
                  widget.pump.volume = double.tryParse(
                        volume.text.replaceAll(',', '.'),
                      ) ??
                      0;
                  widget.pump.periodMs = period.round();
                  widget.onSave();
                  Navigator.pop(context);
                },
                child: const Text('СОХРАНИТЬ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// СТРАНИЦА: ПРОФИЛИ
// ============================================================
class ProfilesPage extends StatelessWidget {
  const ProfilesPage({
    super.key,
    required this.profiles,
    required this.onCreate,
    required this.onApply,
    required this.onDelete,
  });

  final List<ProfileModel> profiles;
  final VoidCallback onCreate;
  final ValueChanged<ProfileModel> onApply, onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ПРОФИЛИ',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('СОЗДАТЬ ПРОФИЛЬ'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: profiles.isEmpty
              ? const Center(child: Text('Профилей пока нет.'))
              : ListView.separated(
                  itemCount: profiles.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = profiles[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined),
                                const SizedBox(width: 10),
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                FilledButton.icon(
                                  onPressed: () => onApply(p),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('ЗАПУСТИТЬ'),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  onPressed: () => onDelete(p),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              children: List.generate(
                                4,
                                (j) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Насос ${j + 1}\n${p.volumes[j].toStringAsFixed(2)} мл\n${p.periods[j]} мс',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ============================================================
// СТРАНИЦА: ЖУРНАЛ
// ============================================================
class JournalPage extends StatelessWidget {
  const JournalPage({
    super.key,
    required this.entries,
    required this.onClear,
  });

  final List<String> entries;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ЖУРНАЛ СОБЫТИЙ',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline),
              label: const Text('ОЧИСТИТЬ'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => Clipboard.setData(
                ClipboardData(text: entries.join('\n')),
              ),
              icon: const Icon(Icons.copy),
              label: const Text('КОПИРОВАТЬ'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  entries[i],
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: entries[i].contains('[ERROR]')
                        ? Colors.red
                        : entries[i].contains('[TX]')
                            ? blue
                            : entries[i].contains('[RX]')
                                ? Colors.green
                                : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// СТРАНИЦА: НАСТРОЙКИ
// ============================================================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});

  final PumpController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          'НАСТРОЙКИ',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ПОСЛЕДОВАТЕЛЬНЫЙ ПОРТ',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            controller.ports.contains(controller.selectedPort)
                                ? controller.selectedPort
                                : null,
                        decoration: const InputDecoration(
                          labelText: 'COM-порт',
                          border: OutlineInputBorder(),
                        ),
                        items: controller.ports
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: controller.setPort,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: controller.baud,
                        decoration: const InputDecoration(
                          labelText: 'Скорость',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 9600, child: Text('9600 бод')),
                          DropdownMenuItem(
                              value: 19200, child: Text('19200 бод')),
                          DropdownMenuItem(
                              value: 38400, child: Text('38400 бод')),
                          DropdownMenuItem(
                              value: 57600, child: Text('57600 бод')),
                          DropdownMenuItem(
                              value: 115200, child: Text('115200 бод')),
                        ],
                        onChanged: (v) {
                          if (v != null) controller.setBaud(v);
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: controller.refreshPorts,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: controller.toggleConnect,
                  child: Text(
                    controller.connected ? 'ОТКЛЮЧИТЬ' : 'ПОДКЛЮЧИТЬ',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.usb),
            title: Text('Arduino Nano'),
            subtitle: Text('4 независимых канала • протокол 115200 бод'),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// СТРАНИЦА: О ПРОГРАММЕ
// ============================================================
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.water_drop, size: 55, color: blue),
              SizedBox(height: 12),
              Text(
                'PUMPCONTROL INDUSTRIAL',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              ),
              Text(
                'Версия 6.0.0',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../domain/services/prayer_engine.dart';
import '../../data/local/preferences_service.dart';

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  final _prefs = PreferencesService();
  
  late int _rakahDuration;
  late int _startLag;
  late int _bufferBeforeStart;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _prefs.initialize();
    setState(() {
      _rakahDuration = _prefs.getRakahDurationSeconds();
      _startLag = _prefs.getStartLagSeconds();
      _bufferBeforeStart = _prefs.getBufferBeforeStartSeconds();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Rak\'ah Estimation'),
          _buildDurationTile(
            'Rak\'ah Duration',
            _rakahDuration,
            'Average time per rak\'ah in seconds',
            min: 60,
            max: 300,
            divisions: 24,
            valueLabel: '${(_rakahDuration / 60).toStringAsFixed(1)} min',
            onChanged: (value) {
              setState(() => _rakahDuration = value.round());
              _prefs.setRakahDurationSeconds(_rakahDuration);
            },
          ),
          _buildDurationTile(
            'Imam Start Delay',
            _startLag,
            'Seconds after iqama before imam starts',
            min: 0,
            max: 300,
            divisions: 30,
            valueLabel: '$_startLag sec',
            onChanged: (value) {
              setState(() => _startLag = value.round());
              _prefs.setStartLagSeconds(_startLag);
            },
          ),
          const Divider(height: 32),
          
          _buildSectionHeader('Travel Time'),
          _buildDurationTile(
            'Arrival Buffer',
            _bufferBeforeStart,
            'Arrive this many seconds before prayer starts',
            min: 0,
            max: 300,
            divisions: 30,
            valueLabel: '$_bufferBeforeStart sec',
            onChanged: (value) {
              setState(() => _bufferBeforeStart = value.round());
              _prefs.setBufferBeforeStartSeconds(_bufferBeforeStart);
            },
          ),
          const Divider(height: 32),
          
          _buildSectionHeader('Default Rak\'ah Counts'),
          ..._buildRakahCountList(),
          
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.restore),
            label: const Text('Reset to Defaults'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDurationTile(
    String title,
    int value,
    String subtitle, {
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    valueLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: value.toDouble(),
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRakahCountList() {
    const defaults = {
      'Fajr': 2,
      'Dhuhr': 4,
      'Asr': 4,
      'Maghrib': 3,
      'Isha': 4,
      'Jumuah': 2,
    };

    return defaults.entries.map((entry) {
      return ListTile(
        leading: CircleAvatar(
          child: Text('${entry.value}'),
        ),
        title: Text(entry.key),
        subtitle: Text('${entry.value} rak\'aat'),
        trailing: const Icon(Icons.edit, size: 20),
        onTap: () => _editRakahCount(entry.key, entry.value),
      );
    }).toList();
  }

  void _editRakahCount(String prayer, int current) {
    final controller = TextEditingController(text: current.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $prayer Rak\'ah'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Number of Rak\'aat',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // Save the value
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings?'),
        content: const Text('This will reset all prayer settings to their default values.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _prefs.setRakahDurationSeconds(144);
              await _prefs.setStartLagSeconds(0);
              await _prefs.setBufferBeforeStartSeconds(30);
              Navigator.pop(context);
              _loadSettings();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

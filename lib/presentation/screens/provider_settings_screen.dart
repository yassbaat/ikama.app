import 'package:flutter/material.dart';
import '../../data/providers/prayer_data_provider.dart';
import '../../data/providers/official_api_provider.dart';
import '../../data/providers/community_wrapper_provider.dart';
import '../../data/providers/scraping_provider.dart';
import '../../data/local/preferences_service.dart';

class ProviderSettingsScreen extends StatefulWidget {
  const ProviderSettingsScreen({super.key});

  @override
  State<ProviderSettingsScreen> createState() => _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState extends State<ProviderSettingsScreen> {
  final _prefs = PreferencesService();
  String _selectedProvider = 'community_wrapper';
  bool _isTesting = false;
  String? _testResult;

  final Map<String, PrayerDataProvider> _providers = {
    'official_api': OfficialApiProvider(),
    'community_wrapper': CommunityWrapperProvider(),
    'scraping': ScrapingProvider(),
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _prefs.initialize();
    setState(() {
      _selectedProvider = _prefs.getActiveProvider() ?? 'community_wrapper';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Settings'),
      ),
      body: ListView(
        children: [
          _buildProviderSelector(),
          const Divider(),
          _buildProviderConfig(),
          if (_testResult != null) ...[
            const Divider(),
            _buildTestResult(),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select Data Source',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        RadioListTile<String>(
          title: const Text('Community Wrapper (Recommended)'),
          subtitle: const Text('Use a community API wrapper'),
          value: 'community_wrapper',
          groupValue: _selectedProvider,
          onChanged: _onProviderChanged,
        ),
        RadioListTile<String>(
          title: const Text('Official Mawaqit API'),
          subtitle: const Text('Direct API access (requires token)'),
          value: 'official_api',
          groupValue: _selectedProvider,
          onChanged: _onProviderChanged,
        ),
        RadioListTile<String>(
          title: const Text('Web Scraping (Fallback)'),
          subtitle: const Text('Scrape Mawaqit website directly'),
          value: 'scraping',
          groupValue: _selectedProvider,
          onChanged: _onProviderChanged,
        ),
      ],
    );
  }

  Widget _buildProviderConfig() {
    final provider = _providers[_selectedProvider];
    if (provider == null) return const SizedBox.shrink();

    final config = _prefs.getProviderConfig(_selectedProvider) ?? {};

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            provider.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            provider.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          ...provider.configSchema.map((field) => _buildConfigField(field, config)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check),
                  label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigField(ConfigField field, Map<String, dynamic> config) {
    final value = config[field.key] ?? field.defaultValue ?? '';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: TextEditingController(text: value.toString()),
        obscureText: field.type == ConfigFieldType.password,
        keyboardType: field.type == ConfigFieldType.number 
          ? TextInputType.number 
          : TextInputType.text,
        decoration: InputDecoration(
          labelText: field.label,
          helperText: field.description,
          border: const OutlineInputBorder(),
        ),
        onChanged: (newValue) {
          final updatedConfig = Map<String, dynamic>.from(config);
          if (field.type == ConfigFieldType.number) {
            updatedConfig[field.key] = int.tryParse(newValue) ?? newValue;
          } else {
            updatedConfig[field.key] = newValue;
          }
          _prefs.setProviderConfig(_selectedProvider, updatedConfig);
        },
      ),
    );
  }

  Widget _buildTestResult() {
    final isSuccess = _testResult?.toLowerCase().contains('success') ?? false;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSuccess ? Colors.green : Colors.red,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_testResult!),
          ),
        ],
      ),
    );
  }

  void _onProviderChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedProvider = value;
        _testResult = null;
      });
      _prefs.setActiveProvider(value);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final provider = _providers[_selectedProvider];
      if (provider == null) {
        setState(() => _testResult = 'Provider not found');
        return;
      }

      final config = _prefs.getProviderConfig(_selectedProvider) ?? {};
      await provider.initialize(config);
      
      final success = await provider.testConnection();
      
      setState(() {
        _testResult = success 
          ? 'Connection successful!' 
          : 'Connection failed. Check your settings.';
      });
      
      provider.dispose();
    } catch (e) {
      setState(() => _testResult = 'Error: $e');
    } finally {
      setState(() => _isTesting = false);
    }
  }
}

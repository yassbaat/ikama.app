import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'provider_settings_screen.dart';
import 'prayer_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Data Source'),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('Provider Settings'),
            subtitle: const Text('Configure API or scraping options'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProviderSettingsScreen()),
            ),
          ),
          const Divider(),
          
          _buildSectionHeader(context, 'Prayer Calculation'),
          ListTile(
            leading: const Icon(Icons.calculate),
            title: const Text('Prayer Settings'),
            subtitle: const Text('Rak\'ah duration, delays, notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrayerSettingsScreen()),
            ),
          ),
          const Divider(),
          
          _buildSectionHeader(context, 'About'),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Iqamah App'),
            subtitle: Text('Version 1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy'),
            subtitle: const Text('All data stored locally on device'),
            onTap: () => _showPrivacyDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Disclaimer'),
            subtitle: const Text('About LIVE estimates'),
            onTap: () => _showDisclaimerDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your privacy is important.'),
            SizedBox(height: 16),
            Text('This app stores all data locally on your device:'),
            SizedBox(height: 8),
            Text('• Mosque favorites'),
            Text('• Prayer time cache'),
            Text('• Your settings'),
            Text('• Travel time preferences'),
            SizedBox(height: 16),
            Text('No data is sent to any server except for prayer time API calls.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDisclaimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disclaimer'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LIVE Prayer Estimates'),
            SizedBox(height: 16),
            Text(
              'The "LIVE (estimated)" feature provides only an approximation of which rak\'ah the congregation may be in.',
            ),
            SizedBox(height: 8),
            Text(
              'Actual prayer times can vary based on:',
            ),
            SizedBox(height: 8),
            Text('• When the imam actually starts'),
            Text('• Congregation size'),
            Text('• Recitation length'),
            Text('• Individual prayer speed'),
            SizedBox(height: 16),
            Text(
              'Always go to the mosque—estimates are for planning only.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }
}

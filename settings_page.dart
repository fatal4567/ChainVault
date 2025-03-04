import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart'; // For biometric authentication
import 'package:file_picker/file_picker.dart'; // For backup/restore

class SettingsPage extends StatefulWidget {
  final String publicAddress; // User's public address
  final String seedPhrase;    // User's seed phrase (handled securely)

  const SettingsPage({
    required this.publicAddress,
    required this.seedPhrase,
    super.key,
  });

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isSeedPhraseVisible = false; // Controls seed phrase visibility
  bool _isBiometricEnabled = false;  // Controls biometric login toggle
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  // Check if biometric authentication is available on the device
  Future<void> _checkBiometricAvailability() async {
    bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
    setState(() {
      _isBiometricEnabled = canCheckBiometrics;
    });
  }

  // Show seed phrase after displaying a security warning
  void _revealSeedPhrase() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Warning'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your seed phrase can be used to access your wallet and funds. Never share it with anyone.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to reveal your seed phrase?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _isSeedPhraseVisible = true);
              Navigator.pop(context);
            },
            child: const Text('Reveal'),
          ),
        ],
      ),
    );
  }

  // Backup transactions (placeholder for actual backup logic)
  void _backupTransactions() async {
    // Example: Export transactions as a JSON file
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transactions backed up! (Demo)')),
    );
  }

  // Restore transactions (placeholder for actual restore logic)
  void _restoreTransactions() async {
    // Example: Import transactions from a JSON file
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transactions restored! (Demo)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section: Account Details
          _buildSectionHeader('Account Details'),
          _buildPublicAddressItem(),
          _buildSeedPhraseItem(),
          const Divider(),

          // Section: Security
          _buildSectionHeader('Security'),
          _buildBiometricToggle(),
          const Divider(),

          // Section: Data Management
          _buildSectionHeader('Data Management'),
          _buildBackupItem(),
          _buildRestoreItem(),
          const Divider(),

          // Section: Other
          _buildSectionHeader('Other'),
          _buildLogoutItem(),
        ],
      ),
    );
  }

  // Helper: Build section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }

  // Helper: Build public address item
  Widget _buildPublicAddressItem() {
    return ListTile(
      leading: const Icon(Icons.vpn_key),
      title: const Text('Public Address'),
      subtitle: Text(widget.publicAddress),
    );
  }

  // Helper: Build seed phrase item with reveal button
  Widget _buildSeedPhraseItem() {
    return ListTile(
      leading: const Icon(Icons.lock),
      title: const Text('Seed Phrase'),
      subtitle: _isSeedPhraseVisible
          ? Text(widget.seedPhrase)
          : const Text('Hidden for security'),
      trailing: _isSeedPhraseVisible
          ? null
          : ElevatedButton(
              onPressed: _revealSeedPhrase,
              child: const Text('Reveal'),
            ),
    );
  }

  // Helper: Build biometric toggle
  Widget _buildBiometricToggle() {
    return ListTile(
      leading: const Icon(Icons.fingerprint),
      title: const Text('Enable Biometric Login'),
      trailing: Switch(
        value: _isBiometricEnabled,
        onChanged: (value) {
          setState(() => _isBiometricEnabled = value);
          // Add logic to enable/disable biometric login here
        },
      ),
    );
  }

  // Helper: Build backup item
  Widget _buildBackupItem() {
    return ListTile(
      leading: const Icon(Icons.backup),
      title: const Text('Backup Transactions'),
      onTap: _backupTransactions,
    );
  }

  // Helper: Build restore item
  Widget _buildRestoreItem() {
    return ListTile(
      leading: const Icon(Icons.restore),
      title: const Text('Restore Transactions'),
      onTap: _restoreTransactions,
    );
  }

  // Helper: Build logout item
  Widget _buildLogoutItem() {
    return ListTile(
      leading: const Icon(Icons.exit_to_app),
      title: const Text('Logout'),
      onTap: () {
        // Add logout logic here
      },
    );
  }
}
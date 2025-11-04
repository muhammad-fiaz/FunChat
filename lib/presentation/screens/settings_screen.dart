import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_providers.dart';
import 'auth/signin_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSection(context, 'Account', [
            FutureBuilder(
              future: authService.getCurrentUser(),
              builder: (context, snapshot) {
                final user = snapshot.data;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    backgroundImage: user?.profileImage != null
                        ? FileImage(File(user!.profileImage!))
                        : null,
                    child: user?.profileImage == null
                        ? Text(
                            user?.displayName[0].toUpperCase() ?? 'U',
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                  title: Text(user?.displayName ?? 'Not logged in'),
                  subtitle: Text(user?.email ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                await authService.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ]),
          _buildSection(context, 'Appearance', [
            SwitchListTile(
              secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
              title: const Text('Dark Mode'),
              subtitle: const Text('Switch between light and dark theme'),
              value: isDark,
              onChanged: (value) {
                ref.read(themeProvider.notifier).setDark(value);
              },
            ),
          ]),
          _buildSection(context, 'Privacy', [
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Blocked Contacts'),
              subtitle: const Text('Manage blocked users'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Last Seen'),
              subtitle: const Text('Control who can see your last seen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.done_all),
              title: const Text('Read Receipts'),
              subtitle: const Text('Show when you\'ve read messages'),
              trailing: Switch(value: true, onChanged: (value) {}),
            ),
          ]),
          _buildSection(context, 'Security', [
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('Identity Key'),
              subtitle: const Text('View your public identity key'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showIdentityKey(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.verified_user),
              title: const Text('Verify Contact'),
              subtitle: const Text('Verify encryption keys with contacts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),
          _buildSection(context, 'Storage', [
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('Manage Storage'),
              subtitle: const Text('Clear cache and manage media'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),
          _buildSection(context, 'About', [
            const ListTile(
              leading: Icon(Icons.info),
              title: Text('Version'),
              subtitle: Text('1.0.0'),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Developer'),
              subtitle: const Text('Muhammad Fiaz'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDeveloperInfo(context),
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.gavel),
              title: const Text('Terms of Service'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }

  void _showDeveloperInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Muhammad Fiaz',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('contact@muhammadfiaz.com'),
              contentPadding: EdgeInsets.zero,
              onTap: () =>
                  launchUrl(Uri.parse('mailto:contact@muhammadfiaz.com')),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('muhammad-fiaz/funchat'),
              contentPadding: EdgeInsets.zero,
              onTap: () => launchUrl(
                Uri.parse('https://github.com/muhammad-fiaz/funchat'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showIdentityKey(BuildContext context, WidgetRef ref) {
    final crypto = ref.read(signalProtocolProvider);
    final publicKey = crypto.getPublicIdentityKey();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Identity Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share this key with contacts to verify your identity:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                publicKey,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

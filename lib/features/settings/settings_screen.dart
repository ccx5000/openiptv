import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/library_controller.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_service.dart';
import '../playlists/playlists_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final sync = context.read<SyncService>();
    final auth = context.watch<AuthService>();

    return ListView(
      children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.person_rounded),
          title: const Text('Angemeldet als'),
          subtitle: Text(auth.client.auth.currentUser?.email ?? '-'),
        ),
        ListTile(
          leading: const Icon(Icons.sync_rounded),
          title: sync.syncing
              ? const Text('Synchronisiere…')
              : const Text('Sync-Status'),
          subtitle: Text(
            sync.lastError != null
                ? 'Fehler: ${sync.lastError}'
                : sync.lastSyncAt == null
                    ? 'Noch nicht synchronisiert'
                    : 'Zuletzt: ${sync.lastSyncAt!.toLocal()}',
          ),
          trailing: IconButton(
            tooltip: 'Jetzt synchronisieren',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              await sync.fullSync();
              if (mounted) setState(() {});
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.format_list_bulleted_rounded),
          title: const Text('Playlisten verwalten'),
          subtitle: Text('${lib.playlists.length} Abos'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PlaylistsScreen()),
          ),
        ),
        const ListTile(
          leading: Icon(Icons.family_restroom_rounded),
          title: Text('Parental Control'),
          subtitle: Text('Kategorien lassen sich in Live TV direkt sperren.'),
        ),
        ListTile(
          leading: const Icon(Icons.logout_rounded),
          title: const Text('Abmelden'),
          onTap: () => auth.signOut(),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'OpenIPTV — ein Player, kein Content-Anbieter. '
            'Bitte nur legale Inhalte nutzen.',
            style: TextStyle(fontSize: 12, color: Colors.white38),
          ),
        ),
      ],
    );
  }
}

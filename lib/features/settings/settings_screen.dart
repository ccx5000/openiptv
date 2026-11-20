import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/library_controller.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_service.dart';
import '../playlists/playlists_screen.dart';
import '../profiles/profile_gate.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _accent = Color(0xFF4F8CFF);

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final sync = context.watch<SyncService>();
    final auth = context.watch<AuthService>();

    return ListView(
      children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.person_rounded),
          title: const Text('Profil wechseln'),
          subtitle: Text(lib.activeProfileId != null
              ? 'Aktives Profil wechseln'
              : 'Noch kein Profil'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileGate()),
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
        const Divider(),
        _syncSection(context, auth, sync),
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

  Widget _syncSection(BuildContext context, AuthService auth, SyncService sync) {
    if (!auth.syncEnabled) {
      return ListTile(
        leading: const Icon(Icons.cloud_off_rounded),
        title: const Text('Geräte-Sync'),
        subtitle: const Text(
            'Aus — die App läuft komplett offline. Favoriten, Historie und '
            'Playlisten bleiben auf diesem Gerät.'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _connectDialog(context, auth),
      );
    }

    return Column(children: [
      FutureBuilder<List<String?>>(
        future: Future.wait([auth.serverUrl(), auth.serverUsername()]),
        builder: (context, snap) {
          final url = snap.data?[0];
          final user = snap.data?[1];
          return ListTile(
            leading: const Icon(Icons.cloud_done_rounded, color: _accent),
            title: const Text('Geräte-Sync aktiv'),
            subtitle: Text(
                user != null && user.isNotEmpty ? '$user · $url' : (url ?? '')),
          );
        },
      ),
      ListTile(
        leading: sync.syncing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.sync_rounded),
        title: Text(sync.syncing
            ? 'Synchronisiere…'
            : sync.lastError != null
                ? 'Sync-Fehler'
                : 'Jetzt synchronisieren'),
        subtitle: sync.lastError != null
            ? Text(sync.lastError!,
                style: const TextStyle(color: Colors.redAccent))
            : Text(sync.lastSyncAt == null
                ? 'Noch nicht synchronisiert'
                : 'Zuletzt: ${sync.lastSyncAt!.toLocal()}'),
        onTap: sync.syncing ? null : () async => await sync.fullSync(),
      ),
      ListTile(
        leading: const Icon(Icons.link_off_rounded),
        title: const Text('Sync trennen (weiter offline nutzen)'),
        onTap: () => _disconnect(context, auth),
      ),
    ]);
  }

  Future<void> _connectDialog(BuildContext context, AuthService auth) async {
    final url = TextEditingController(text: AppConfig.backendUrl);
    final user = TextEditingController();
    final pass = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geräte-Sync einrichten'),
        content: ListenableBuilder(
          listenable: auth,
          builder: (ctx, _) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Verbindet dieses Gerät mit deinem Sync-Server. Ein '
                  'Benutzername genügt — das Konto wird beim ersten Verbinden '
                  'automatisch erstellt. Passwort optional.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.white.withOpacity(0.6)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: url,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Server-URL',
                    prefixIcon: Icon(Icons.dns_rounded),
                    hintText: 'http://192.168.1.50:8080',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: user,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Benutzername',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pass,
                  obscureText: true,
                  onSubmitted: (_) => Navigator.pop(ctx, true),
                  decoration: const InputDecoration(
                    labelText: 'Passwort (optional)',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
                  Text(auth.error!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          auth.busy ? null : () => Navigator.pop(ctx, false),
                      child: const Text('Abbrechen'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed:
                          auth.busy ? null : () => Navigator.pop(ctx, true),
                      child: auth.busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Verbinden'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (ok != true || !context.mounted) return;
    final success = await auth.connectSync(
      url.text.trim(),
      user.text.trim(),
      pass.text,
    );
    if (!success || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'Sync aktiviert — Favoriten, Historie und Playlisten werden jetzt '
          'auf allen verbundenen Geräten synchronisiert.'),
    ));
    setState(() {});
  }

  Future<void> _disconnect(BuildContext context, AuthService auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sync trennen?'),
        content: const Text(
            'Dieses Gerät kehrt in den Offline-Modus zurück. Daten auf dem '
            'Server und auf anderen Geräten bleiben erhalten.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Trennen')),
        ],
      ),
    );
    if (ok == true) {
      await auth.disconnectSync();
      if (context.mounted) setState(() {});
    }
  }
}

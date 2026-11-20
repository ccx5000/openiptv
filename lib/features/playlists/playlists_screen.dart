import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/library_controller.dart';
import '../../core/models/models.dart';

/// Playlist management: add Xtream Codes or M3U(+EPG) subscriptions,
/// refresh, delete. Reached from the settings screen.
class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Playlisten')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            _busy || lib.loadingLibrary ? null : () => _addPlaylist(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Playlist hinzufügen'),
      ),
      body: lib.loadingLibrary
          ? const Center(child: CircularProgressIndicator())
          : lib.playlists.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Noch keine Playlisten.\nXtream-Logins oder M3U-URLs '
                      'deiner Abos lassen sich hier kombinieren — '
                      'mehrere Subscriptions, eine Plattform.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: lib.playlists.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = lib.playlists[i];
                    final count = lib
                        .channels(MediaKind.live)
                        .where((c) => c.playlistId == p.id)
                        .length;
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          p.isXtream
                              ? Icons.dns_rounded
                              : Icons.format_list_bulleted_rounded,
                        ),
                        title: Text(p.name),
                        subtitle: Text(
                          p.isXtream
                              ? 'Xtream · ${p.host} · $count Kanäle'
                              : 'M3U · $count Kanäle',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Aktualisieren',
                              icon: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh_rounded),
                              onPressed:
                                  _busy ? null : () => _refresh(context, p),
                            ),
                            IconButton(
                              tooltip: 'Löschen',
                              icon:
                                  const Icon(Icons.delete_outline_rounded),
                              onPressed: () => lib.deletePlaylist(p.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _refresh(BuildContext context, Playlist p) async {
    final lib = context.read<LibraryController>();
    setState(() => _busy = true);
    try {
      await lib.refresh(p);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${p.name} aktualisiert')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPlaylist(BuildContext context) async {
    final kind = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Art der Playlist'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'xtream'),
            child: const Text('Xtream Codes (Server, Nutzer, Passwort)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'm3u'),
            child: const Text('M3U/M3U8-URL (+ optionale EPG-URL)'),
          ),
        ],
      ),
    );
    if (kind == null || !context.mounted) return;
    final lib = context.read<LibraryController>();

    final nameC = TextEditingController();
    final hostC = TextEditingController();
    final userC = TextEditingController();
    final passC = TextEditingController();
    final epgC = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(kind == 'xtream' ? 'Xtream Codes' : 'M3U-Playlist'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration:
                    const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              if (kind == 'xtream') ...[
                TextField(
                  controller: hostC,
                  decoration: const InputDecoration(
                      labelText: 'Server (host:port)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: userC,
                  decoration: const InputDecoration(labelText: 'Nutzer'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passC,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Passwort'),
                ),
              ] else ...[
                TextField(
                  controller: hostC,
                  decoration:
                      const InputDecoration(labelText: 'M3U-URL'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: epgC,
                  decoration: const InputDecoration(
                      labelText: 'EPG-URL (optional, XMLTV)'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hinzufügen')),
        ],
      ),
    );

    if (added != true || !context.mounted) return;
    setState(() => _busy = true);
    try {
      if (kind == 'xtream') {
        await lib.addXtream(
            nameC.text.trim(), hostC.text.trim(), userC.text, passC.text);
      } else {
        await lib.addM3u(nameC.text.trim(), hostC.text.trim(), epgC.text.trim());
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Playlist geladen')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

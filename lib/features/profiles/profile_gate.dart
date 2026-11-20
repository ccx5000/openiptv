import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app.dart';
import '../../core/library_controller.dart';
import '../../core/models/models.dart';
import '../../core/services/auth_service.dart';

/// Profile picker (Netflix-style): every account can have several users;
/// each of them syncs independently across all devices.
class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  List<UserProfile>? _profiles;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profiles = await context.read<AuthService>().fetchProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Profile konnten nicht geladen werden: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _profiles;
    if (profiles == null) {
      return Scaffold(
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!),
                    ),
                    FilledButton(
                        onPressed: _load, child: const Text('Erneut versuchen')),
                  ],
                ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wer schaut?'),
        actions: [
          IconButton(
            tooltip: 'Profil hinzufügen',
            onPressed: () => _addProfile(context),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          IconButton(
            tooltip: 'Abmelden',
            onPressed: () async {
              await context.read<AuthService>().signOut();
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        itemCount: profiles.length,
        itemBuilder: (context, i) {
          final p = profiles[i];
          return _ProfileTile(
            profile: p,
            onTap: () async {
              await context.read<LibraryController>().setActiveProfile(p.id);
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AppShell()),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addProfile(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neues Profil'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await context.read<AuthService>().addProfile(name);
      await _load();
    }
  }
}

class _ProfileTile extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onTap;

  const _ProfileTile({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(int.tryParse(
            profile.avatarColor.replaceFirst('#', '0xff')) ??
        0xFF4F8CFF);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(profile.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (profile.isKids)
            const Text('Kinderprofil', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

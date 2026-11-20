import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _modeSignIn = true;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final narrow = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: narrow ? 420 : 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.live_tv_rounded,
                    size: 72, color: Color(0xFF4F8CFF)),
                const SizedBox(height: 8),
                Text(
                  'OpenIPTV',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ein Account, alle Geräte, mehrere Profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _email,
                  autofillHints: const [AutofillHints.email],
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-Mail',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  autofillHints: const [AutofillHints.password],
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Passwort',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                if (auth.error != null) ...[
                  Text(
                    auth.error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: auth.busy ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: auth.busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_modeSignIn ? 'Anmelden' : 'Registrieren'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: auth.busy
                      ? null
                      : () => setState(() => _modeSignIn = !_modeSignIn),
                  child: Text(_modeSignIn
                      ? 'Neu hier? Konto erstellen'
                      : 'Ich habe schon ein Konto'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final auth = context.read<AuthService>();
    final ok = _modeSignIn
        ? await auth.signIn(_email.text.trim(), _password.text)
        : await auth.signUp(_email.text.trim(), _password.text);
    if (ok && mounted && !_modeSignIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Konto erstellt. Prüfe ggf. deine E-Mail zur Bestätigung.'),
      ));
    }
  }
}

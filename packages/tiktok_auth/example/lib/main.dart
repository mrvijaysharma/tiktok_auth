import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tiktok_auth/tiktok_auth.dart';
import 'package:tiktok_auth_example/tiktok_config.dart';

void main() {
  runApp(const TikTokAuthExampleApp());
}

class TikTokAuthExampleApp extends StatelessWidget {
  const TikTokAuthExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TikTok Auth Example',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFFE2C55),
        useMaterial3: true,
      ),
      home: const SignInPage(),
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  String? _setupError;
  bool _ready = false;
  bool? _tiktokInstalled;
  bool _busy = false;
  TikTokAuthorization? _authorization;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await TikTokAuth.instance.initialize(tiktokConfig);
      final installed = await TikTokAuth.instance.isTikTokInstalled();
      // Finish a sign-in that completed while the app was not running.
      final pending = await TikTokAuth.instance.getPendingAuthorization();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _tiktokInstalled = installed;
        _authorization = pending;
      });
    } on TikTokAuthException catch (error) {
      if (!mounted) return;
      setState(() => _setupError = error.message);
    }
  }

  Future<void> _signIn({required bool preferWebAuth}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final authorization = await TikTokAuth.instance.signIn(
        scopes: {TikTokScope.userInfoBasic},
        preferWebAuth: preferWebAuth,
      );
      // In a real app, send authorization.authCode, .codeVerifier and
      // .redirectUri to your backend here.
      setState(() => _authorization = authorization);
    } on TikTokAuthException catch (error) {
      if (error.code == TikTokAuthErrorCode.cancelled) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Sign-in cancelled')));
        }
      } else {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorization = _authorization;
    return Scaffold(
      appBar: AppBar(title: const Text('TikTok Auth Example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(
            setupError: _setupError,
            ready: _ready,
            tiktokInstalled: _tiktokInstalled,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _ready && !_busy
                ? () => _signIn(preferWebAuth: false)
                : null,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: const Text('Continue with TikTok'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _ready && !_busy
                ? () => _signIn(preferWebAuth: true)
                : null,
            child: const Text('Continue in browser'),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 16),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (authorization != null) ...[
            const SizedBox(height: 16),
            _AuthorizationCard(authorization: authorization),
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.setupError,
    required this.ready,
    required this.tiktokInstalled,
  });

  final String? setupError;
  final bool ready;
  final bool? tiktokInstalled;

  @override
  Widget build(BuildContext context) {
    final error = setupError;
    if (error != null) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(error),
        ),
      );
    }
    if (!ready) return const LinearProgressIndicator();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: const Text('TikTok Login is configured'),
        subtitle: Text(
          tiktokInstalled ?? false
              ? 'TikTok app installed: the app will be used.'
              : 'TikTok app not installed: a browser tab will be used.',
        ),
      ),
    );
  }
}

class _AuthorizationCard extends StatelessWidget {
  const _AuthorizationCard({required this.authorization});

  final TikTokAuthorization authorization;

  @override
  Widget build(BuildContext context) {
    String preview(String value) =>
        value.length <= 12 ? value : '${value.substring(0, 12)}…';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Signed in',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Auth code: ${preview(authorization.authCode)}'),
            Text('Code verifier: ${preview(authorization.codeVerifier)}'),
            Text('Granted scopes: ${authorization.grantedScopes.join(', ')}'),
            Text('Browser flow: ${authorization.usedWebAuth}'),
            const SizedBox(height: 8),
            const Text(
              'Send the auth code, code verifier and redirect URI to your '
              'backend to exchange them for an access token.',
            ),
          ],
        ),
      ),
    );
  }
}

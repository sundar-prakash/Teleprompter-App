import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_info.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static final _version = PackageInfo.fromPlatform();

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No app found to open $url')));
    }
  }

  Future<void> _rate(BuildContext context) async {
    final market = await launchUrl(
      Uri.parse(AppInfo.playStoreMarket),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!market && context.mounted) await _open(context, AppInfo.playStore);
  }

  Future<void> _email(BuildContext context) => _open(
    context,
    Uri(
      scheme: 'mailto',
      path: AppInfo.supportEmail,
      query: 'subject=${Uri.encodeComponent('${AppInfo.name} feedback')}',
    ).toString(),
  );

  void _share() => SharePlus.instance.share(
    ShareParams(
      text:
          'I use ${AppInfo.name} to read scripts while recording. '
          'Free, no ads, and you can customise everything: ${AppInfo.playStore}',
      subject: AppInfo.name,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // Header
              const SizedBox(height: 8),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 88,
                    height: 88,
                    semanticLabel: '${AppInfo.name} logo',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                AppInfo.name,
                textAlign: TextAlign.center,
                style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              FutureBuilder<PackageInfo>(
                future: _version,
                builder: (_, s) => Text(
                  s.hasData
                      ? 'Version ${s.data!.version} (${s.data!.buildNumber})'
                      : ' ',
                  textAlign: TextAlign.center,
                  style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppInfo.tagline,
                textAlign: TextAlign.center,
                style: t.titleMedium?.copyWith(color: c.primary),
              ),
              const SizedBox(height: 16),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(Icons.volunteer_activism_outlined, 'Free forever'),
                  _Pill(Icons.block, 'No ads'),
                  _Pill(Icons.tune, 'Fully customisable'),
                  _Pill(Icons.lock_outline, 'Private & offline'),
                  _Pill(Icons.code, 'Open source'),
                ],
              ),

              // Story
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Why this app exists', style: t.titleMedium),
                      const SizedBox(height: 8),
                      const Text(
                        'Most teleprompter apps lock the useful parts behind a '
                        'subscription, fill the screen with ads, or ask you to '
                        'sign up before you can read a single line.\n\n'
                        'This one doesn\'t. Every feature is free: importing, '
                        'all five reading modes, camera recording, the floating '
                        'window and every font, colour and layout option. No '
                        'ads, no account, no tracking. Your scripts never leave '
                        'your phone.\n\n'
                        'If it helps you, the best thanks is a rating on '
                        'Google Play or telling a friend.',
                      ),
                    ],
                  ),
                ),
              ),

              // Developer
              const _Section('Made by'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: c.primaryContainer,
                            child: Text(
                              'SP',
                              style: TextStyle(
                                color: c.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppInfo.developer, style: t.titleMedium),
                                Text(
                                  AppInfo.developerRole,
                                  style: t.bodySmall?.copyWith(
                                    color: c.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'I build fast, polished web and mobile apps, from the '
                        'database to the Play Store. Need an app or website '
                        'built? Have a look at my work.',
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.language),
                            label: const Text('Portfolio'),
                            onPressed: () => _open(context, AppInfo.portfolio),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.code),
                            label: const Text('GitHub'),
                            onPressed: () => _open(context, AppInfo.github),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Support
              const _Section('Support the app'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _Link(
                      Icons.star_outline,
                      'Rate on Google Play',
                      'It really helps others find the app',
                      () => _rate(context),
                    ),
                    _Link(
                      Icons.share_outlined,
                      'Share with a friend',
                      null,
                      _share,
                    ),
                    _Link(
                      Icons.lightbulb_outline,
                      'Suggest a feature or report a bug',
                      'On GitHub',
                      () => _open(context, AppInfo.issues),
                    ),
                    _Link(
                      Icons.mail_outline,
                      'Email support',
                      AppInfo.supportEmail,
                      () => _email(context),
                    ),
                  ],
                ),
              ),

              // Legal
              const _Section('More'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _Link(
                      Icons.public,
                      'Website',
                      'teleprompter.sundarprakash.in',
                      () => _open(context, AppInfo.website),
                    ),
                    _Link(
                      Icons.privacy_tip_outlined,
                      'Privacy policy',
                      'No data collected',
                      () => _open(context, AppInfo.privacy),
                    ),
                    _Link(
                      Icons.gavel_outlined,
                      'Terms of use',
                      null,
                      () => _open(context, AppInfo.terms),
                    ),
                    _Link(
                      Icons.code,
                      'Source code',
                      'MIT License',
                      () => _open(context, AppInfo.sourceCode),
                    ),
                    _Link(
                      Icons.description_outlined,
                      'Open-source licences',
                      null,
                      () => showLicensePage(
                        context: context,
                        applicationName: AppInfo.name,
                        applicationLegalese: '© 2026 ${AppInfo.developer}',
                      ),
                      external: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Made with care in Chennai, India',
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: c.onSecondaryContainer,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(
    this.icon,
    this.title,
    this.subtitle,
    this.onTap, {
    this.external = true,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool external;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: Icon(
      external ? Icons.open_in_new : Icons.chevron_right,
      size: 18,
    ),
    onTap: onTap,
  );
}

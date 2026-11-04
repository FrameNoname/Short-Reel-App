import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../l10n/app_language.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/text.dart';
import '../../widgets/verified_badge.dart';
import '../auth/login_view.dart';
import '../feed/speed_sheet.dart';
import 'edit_profile_view.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  void _open(BuildContext context, Widget view) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => view));
  }

  Future<void> _logOut(BuildContext context) async {
    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'You can log back in any time.',
      confirmLabel: 'Log out',
      cancelLabel: 'Stay',
    );
    if (!confirmed) return;
    navigator.popUntil((route) => route.isFirst);
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final settings = context.watch<SettingsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
        children: [
          const _SectionLabel('Account'),
          if (user == null)
            _Row(
              icon: Icons.login_rounded,
              title: 'Log in',
              subtitle: 'Save films and unlock episodes',
              onTap: () => _open(context, const LoginView()),
            )
          else ...[
            AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primarySoft,
                    child: Text(
                      user.username[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ChannelName(
                          user.displayName ?? user.username,
                          verified: user.isVerified,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '@${user.username} · ${user.role.name}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _Row(
              icon: Icons.edit_rounded,
              title: 'Edit profile',
              subtitle: 'Change your name and bio',
              onTap: () => _open(context, const EditProfileView()),
            ),
          ],
          const _SectionLabel('Playback'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Default speed',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Every film starts at this speed. You can still change it '
                  'from the Speed button.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final speed in playbackSpeeds)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: speed == playbackSpeeds.last ? 0 : 6,
                          ),
                          child: _SpeedOption(
                            label: speedLabel(speed),
                            selected: speed == settings.defaultSpeed,
                            onTap: () => settings.setDefaultSpeed(speed),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            child: MergeSemantics(
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Haptic feedback',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'A small buzz when you hold for 2x speed',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    key: const Key('settings-haptics'),
                    activeThumbColor: AppColors.primary,
                    value: settings.haptics,
                    onChanged: (value) => settings.setHaptics(enabled: value),
                  ),
                ],
              ),
            ),
          ),
          const _SectionLabel('About'),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Short Reel',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'AI short films, one episode at a time.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                SizedBox(height: 10),
                Text(
                  'This is a demo build. Payments are simulated and no real '
                  'money is charged.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (user != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              key: const Key('settings-logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
              onPressed: () => _logOut(context),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log out'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        context.tr(text).toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.link),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _SpeedOption extends StatelessWidget {
  const _SpeedOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Default speed $label',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

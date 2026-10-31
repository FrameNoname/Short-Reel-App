import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../l10n/app_language.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/text.dart';

/// Lets a person change the channel name and bio others see.
class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  static const maxName = 30;
  static const maxBio = 80;

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  late final _name = TextEditingController(
    text:
        context.read<AuthController>().user?.displayName ??
        context.read<AuthController>().user?.username,
  );
  late final _bio = TextEditingController(
    text: context.read<AuthController>().user?.bio,
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty && !_busy;

  Future<void> _save() async {
    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.updateProfile(displayName: _name.text, bio: _bio.text);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Profile saved.')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  (user?.username ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '@${user?.username ?? ''}',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 22),
          const FieldLabel('Name'),
          TextField(
            key: const Key('profile-name'),
            controller: _name,
            maxLength: EditProfileView.maxName,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(counterText: ''),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Bio'),
          TextField(
            key: const Key('profile-bio'),
            controller: _bio,
            maxLength: EditProfileView.maxBio,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: context.tr('Tell people what you make'),
              counterText: '${_bio.text.length}/${EditProfileView.maxBio}',
              counterStyle: const TextStyle(color: AppColors.muted),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: FilledButton(
            onPressed: _canSave ? _save : null,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
        ),
      ),
    );
  }
}

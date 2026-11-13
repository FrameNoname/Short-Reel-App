import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/admin_controller.dart';
import '../../data/app_repository.dart';
import '../../services/errors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/text.dart';

/// Series Jeen prices, the demo top-up and the coin packs viewers can buy.
class AdminSettingsView extends StatefulWidget {
  const AdminSettingsView({super.key});

  @override
  State<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends State<AdminSettingsView> {
  final _free = TextEditingController();
  final _price = TextEditingController();
  final _demo = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _free.dispose();
    _price.dispose();
    _demo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final admin = context.read<AdminController>();
    await admin.loadSettings();
    if (!mounted) return;
    final s = admin.settings;
    _free.text = '${s.catalogFreeEpisodes}';
    _price.text = '${s.catalogPriceCoins}';
    _demo.text = '${s.demoTopUpCoins}';
    setState(() => _error = null);
  }

  Future<void> _save() async {
    final free = int.tryParse(_free.text.trim());
    final price = int.tryParse(_price.text.trim());
    final demo = int.tryParse(_demo.text.trim());
    if (free == null || free > 1000) {
      setState(() => _error = 'Free episodes must be 0 to 1000.');
      return;
    }
    if (price == null || price < 1 || price > 10000) {
      setState(() => _error = 'A price must be 1 to 10000 coins.');
      return;
    }
    if (demo == null || demo < 1 || demo > 10000) {
      setState(() => _error = 'Demo coins must be 1 to 10000.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AdminController>().saveSettings(
        AdminSettings(
          demoTopUpCoins: demo,
          catalogFreeEpisodes: free,
          catalogPriceCoins: price,
        ),
      );
      messenger.showSnackBar(const SnackBar(content: Text('Changes saved.')));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _editPack([AdminCoinPack? pack]) async {
    final admin = context.read<AdminController>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<(String, int, double)>(
      context: context,
      builder: (_) => _PackDialog(pack: pack),
    );
    if (result == null) return;
    final (name, coins, priceUsd) = result;
    try {
      await admin.saveCoinPack(
        id: pack?.id,
        name: name,
        coins: coins,
        priceUsd: priceUsd,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Changes saved.')));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  Future<void> _deletePack(AdminCoinPack pack) async {
    final admin = context.read<AdminController>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this coin pack?',
      message: 'Viewers will no longer be able to buy it.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await admin.deleteCoinPack(pack);
      messenger.showSnackBar(
        const SnackBar(content: Text('Coin pack deleted.')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  Widget _numberField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Prices and coin packs')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
        children: [
          if (admin.settingsLoading) const LinearProgressIndicator(),
          if (admin.settingsError != null)
            AppCard(
              child: Row(
                children: [
                  Expanded(child: Text(admin.settingsError!)),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            ),
          const _Heading('Series Jeen'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _numberField('Free episodes per series', _free),
                _numberField('Price of each later episode (coins)', _price),
                _numberField('Demo top-up (coins)', _demo),
                if (_error != null) FieldError(_error!),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving || admin.settingsLoading ? null : _save,
                    child: const Text('Save changes'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: _Heading('Coin packs')),
              TextButton.icon(
                onPressed: () => _editPack(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add pack'),
              ),
            ],
          ),
          for (final p in admin.coinPacks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  title: Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${p.coins} coins · \$${p.priceUsd.toStringAsFixed(2)} · '
                    'sold ${p.soldCount}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => _editPack(p),
                  trailing: IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    onPressed: () => _deletePack(p),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PackDialog extends StatefulWidget {
  const _PackDialog({this.pack});

  final AdminCoinPack? pack;

  @override
  State<_PackDialog> createState() => _PackDialogState();
}

class _PackDialogState extends State<_PackDialog> {
  late final _name = TextEditingController(text: widget.pack?.name ?? '');
  late final _coins = TextEditingController(
    text: widget.pack == null ? '' : '${widget.pack!.coins}',
  );
  late final _price = TextEditingController(
    text: widget.pack == null ? '' : widget.pack!.priceUsd.toStringAsFixed(2),
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _coins.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final coins = int.tryParse(_coins.text.trim());
    final price = double.tryParse(_price.text.trim());
    if (name.isEmpty || name.length > 30) {
      setState(() => _error = 'A name must be 1 to 30 characters.');
      return;
    }
    if (coins == null || coins < 1 || coins > 65535) {
      setState(() => _error = 'Coins must be 1 to 65535.');
      return;
    }
    if (price == null || price <= 0 || price > 9999.99) {
      setState(() => _error = 'Enter a price above 0.');
      return;
    }
    Navigator.of(context).pop((name, coins, price));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.pack == null ? 'New coin pack' : 'Edit coin pack'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('Name'),
            TextField(controller: _name, maxLength: 30),
            const FieldLabel('Coins'),
            TextField(
              controller: _coins,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            const FieldLabel('Price (USD, simulated)'),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
            if (_error != null) FieldError(_error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

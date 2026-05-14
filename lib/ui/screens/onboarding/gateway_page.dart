import 'package:flutter/material.dart';
import 'package:flutterclaw/l10n/l10n_extension.dart';

class GatewayPageResult {
  final String host;
  final int port;
  final bool autoStart;

  const GatewayPageResult({
    required this.host,
    required this.port,
    required this.autoStart,
  });
}

class GatewayPage extends StatefulWidget {
  final String initialHost;
  final int initialPort;
  final bool initialAutoStart;
  final ValueChanged<GatewayPageResult> onChanged;

  const GatewayPage({
    super.key,
    this.initialHost = '127.0.0.1',
    this.initialPort = 18789,
    this.initialAutoStart = false,
    required this.onChanged,
  });

  @override
  State<GatewayPage> createState() => _GatewayPageState();
}

class _GatewayPageState extends State<GatewayPage> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late bool _autoStart;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.initialHost);
    _portController = TextEditingController(text: '${widget.initialPort}');
    _autoStart = widget.initialAutoStart;
    _emitChange();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _emitChange() {
    widget.onChanged(
      GatewayPageResult(
        host: _hostController.text.trim().isEmpty
            ? '127.0.0.1'
            : _hostController.text.trim(),
        port: int.tryParse(_portController.text.trim()) ?? 18789,
        autoStart: _autoStart,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          context.l10n.gatewayConfiguration,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.gatewayConfigDesc,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        // Info card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.tertiaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: colors.tertiary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.defaultSettingsNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        TextField(
          controller: _hostController,
          decoration: InputDecoration(
            labelText: context.l10n.host,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.dns),
            hintText: '127.0.0.1',
          ),
          onChanged: (_) => _emitChange(),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _portController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.l10n.port,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.numbers),
            hintText: '18789',
          ),
          onChanged: (_) => _emitChange(),
        ),
        const SizedBox(height: 24),

        SwitchListTile(
          title: Text(context.l10n.autoStartGateway),
          subtitle: Text(context.l10n.autoStartGatewayDesc),
          value: _autoStart,
          onChanged: (val) {
            setState(() => _autoStart = val);
            _emitChange();
          },
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

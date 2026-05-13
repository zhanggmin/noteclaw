import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutterclaw/services/blinko_auth_service.dart';
import 'package:flutterclaw/services/secure_key_store.dart';

class BlinkoLoginPage extends StatefulWidget {
  const BlinkoLoginPage({super.key, this.onLoginSuccess});

  final VoidCallback? onLoginSuccess;

  @override
  State<BlinkoLoginPage> createState() => _BlinkoLoginPageState();
}

class _BlinkoLoginPageState extends State<BlinkoLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _baseUrlCtl = TextEditingController(
    text: BlinkoAuthService.defaultBaseUrl,
  );
  final _nameCtl = TextEditingController();
  final _passwordCtl = TextEditingController();

  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _baseUrlCtl.dispose();
    _nameCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final baseUrl = BlinkoAuthService.normalizeBaseUrl(_baseUrlCtl.text);
      final name = _nameCtl.text.trim();
      if (kDebugMode) {
        debugPrint('[BlinkoLoginPage] submit login');
        debugPrint('[BlinkoLoginPage] baseUrl: $baseUrl');
        debugPrint('[BlinkoLoginPage] name: $name');
      }

      final service = BlinkoAuthService(baseUrl: baseUrl);
      final result = await service.login(
        name: name,
        password: _passwordCtl.text,
      );

      await SecureKeyStore.saveApiKey('blinko', result.token);
      await SecureKeyStore.saveSecret('blinko_base_url', baseUrl);
      if (kDebugMode) {
        debugPrint('[BlinkoLoginPage] login success, token saved');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful, token saved.')),
      );
      widget.onLoginSuccess?.call();
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BlinkoLoginPage] login failed: $e');
      }
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blinko 登录')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _baseUrlCtl,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  border: OutlineInputBorder(),
                  hintText: 'https://your-blinko-host.com',
                  helperText: '填写 Blinko 实例根地址，不要填写文档地址',
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return '请输入 Base URL';
                  final uri = Uri.tryParse(value);
                  if (uri == null || (!uri.hasScheme || !uri.hasAuthority)) {
                    return 'Base URL 格式不正确';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: '账号 / 邮箱',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入账号或邮箱' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: '密码',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _login,
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('登录'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

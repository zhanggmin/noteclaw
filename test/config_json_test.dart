import 'package:flutter_test/flutter_test.dart';
import 'package:flutterclaw/data/models/config.dart';

void main() {
  test('parses numeric config fields saved as strings', () {
    final config = FlutterClawConfig.fromJson({
      'agents': {
        'defaults': {
          'max_tokens': '4096',
          'max_tool_iterations': '12',
          'max_tool_result_tokens': '25000',
        },
      },
      'model_list': [
        {
          'model_name': 'custom',
          'model': 'custom/model',
          'request_timeout': '45',
        },
      ],
      'tools': {
        'web': {
          'brave': {'max_results': '8'},
        },
        'browser': {
          'max_profile_size_mb': '10',
          'max_tabs': '7',
          'network_log_max_entries': '500',
        },
      },
      'heartbeat': {'interval': '15'},
      'gateway': {'port': '18888'},
      'agent_profiles': [
        {
          'id': 'agent-1',
          'name': 'Assistant',
          'emoji': 'A',
          'workspace_path': 'agents/agent-1',
          'model_name': 'custom',
          'max_tokens': '2048',
          'max_tool_iterations': '6',
          'created_at': '2026-06-19T00:00:00.000Z',
          'last_used_at': '2026-06-19T00:00:00.000Z',
        },
      ],
      'email_accounts': [
        {
          'id': 'email-1',
          'label': 'Mail',
          'email': 'user@example.com',
          'smtp_host': 'smtp.example.com',
          'smtp_port': '2525',
          'imap_host': 'imap.example.com',
          'imap_port': '1993',
        },
      ],
    });

    expect(config.agents.defaults.maxTokens, 4096);
    expect(config.agents.defaults.maxToolIterations, 12);
    expect(config.agents.defaults.maxToolResultTokens, 25000);
    expect(config.modelList.single.requestTimeout, 45);
    expect(config.tools.web.brave.maxResults, 8);
    expect(config.tools.browser.maxProfileSizeMb, 10);
    expect(config.tools.browser.maxTabs, 7);
    expect(config.tools.browser.networkLogMaxEntries, 500);
    expect(config.heartbeat.interval, 15);
    expect(config.gateway.port, 18888);
    expect(config.agentProfiles.single.maxTokens, 2048);
    expect(config.agentProfiles.single.maxToolIterations, 6);
    expect(config.emailAccounts.single.smtpPort, 2525);
    expect(config.emailAccounts.single.imapPort, 1993);
  });
}

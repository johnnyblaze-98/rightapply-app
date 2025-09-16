import 'package:flutter/material.dart';
import 'services/api.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';
import 'dart:io';
import 'utils/mac.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;
  bool _obscure = true;
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _welcomeName = 'there';
  String _platform = '';
  String _model = '';
  String _os = '';
  Timer? _lookupTimer;
  bool _showUsers = false;
  List<Map<String, dynamic>> _users = const [];
  bool? _allowed; // Device approval status for current username/mac
  bool? _bound;   // Whether current device is linked to the current username

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _usernameCtrl.addListener(_onUsernameChanged);
    _ensureMacSet();
    _prefillFromUsersIfObvious();
    _prefillFromLinkedDevice();
  }

  @override
  void dispose() {
    _lookupTimer?.cancel();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _prefillFromLinkedDevice() async {
    try {
      final linked = await ApiService.lookupUserByMac();
      if (!mounted || linked == null) return;
      final user = linked['user'] as Map<String, dynamic>?;
      // Update chips from linked endpoint if present
      if (linked.containsKey('allowed')) {
        _allowed = linked['allowed'] is bool ? linked['allowed'] as bool : null;
      }
      if (linked.containsKey('bound')) {
        _bound = linked['bound'] is bool ? linked['bound'] as bool : null;
      }
      if (user != null) {
        final uname = (user['username'] ?? '').toString();
        final name = (user['name'] ?? '').toString();
        if (uname.isNotEmpty) {
          _usernameCtrl.text = uname;
        }
        if (name.isNotEmpty) {
          setState(() => _welcomeName = name);
        }
        // Ensure UI reflects chips
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _prefillFromUsersIfObvious() async {
    try {
      if (_usernameCtrl.text.trim().isNotEmpty) return;
      final list = await ApiService.listUsers();
      if (!mounted) return;
      // If exactly one user exists, prefill it
      if (list.length == 1) {
        final uname = (list.first['username'] ?? '').toString();
        final name = (list.first['name'] ?? '').toString();
        if (uname.isNotEmpty) {
          _usernameCtrl.text = uname;
          _onUsernameChanged();
          if (name.isNotEmpty) {
            setState(() => _welcomeName = name);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _ensureMacSet() async {
    try {
      final current = await getPrimaryMacOrId();
      if (current.isNotEmpty) {
        ApiService.setDeviceMac(current);
      }
    } catch (_) {}
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final plugin = DeviceInfoPlugin();
      String plat = '', model = '', os = '';
      if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        plat = 'Windows';
        model = info.computerName;
        os = "${info.majorVersion}.${info.minorVersion} (Build ${info.buildNumber})";
      } else if (Platform.isMacOS) {
        final info = await plugin.macOsInfo;
        plat = 'macOS';
        model = info.model;
        os = info.osRelease;
      } else if (Platform.isLinux) {
        final info = await plugin.linuxInfo;
        plat = 'Linux';
        model = info.prettyName;
        os = info.version ?? '';
      } else if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        plat = 'Android';
        model = info.model;
        os = info.version.release;
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        plat = 'iOS';
        model = info.utsname.machine;
        os = info.systemVersion;
      }
      if (!mounted) return;
      setState(() {
        _platform = plat;
        _model = model;
        _os = os;
      });
    } catch (_) {}
  }

  void _onUsernameChanged() {
    _lookupTimer?.cancel();
    final u = _usernameCtrl.text.trim();
    if (u.length < 2) {
      setState(() {
        _welcomeName = 'there';
        _allowed = null;
        _bound = null;
      });
      return;
    }
    _lookupTimer = Timer(const Duration(milliseconds: 400), () async {
      final info = await ApiService.lookupUserInfo(u);
      if (!mounted) return;
      setState(() {
        final name = (info['name'] is String) ? (info['name'] as String) : null;
        _welcomeName = (name == null || name.isEmpty) ? 'there' : name;
        _allowed = info['allowed'] is bool ? info['allowed'] as bool : null;
        _bound = info['bound'] is bool ? info['bound'] as bool : null;
      });
    });
  }

  Future<void> _toggleUsers() async {
    setState(() => _showUsers = !_showUsers);
    if (_showUsers && _users.isEmpty) {
      final list = await ApiService.listUsers();
      if (!mounted) return;
      setState(() => _users = list);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final resp = await ApiService.authLogin(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (resp['success'] == true) {
        if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        _showError(resp['error']?.toString() ?? 'Login failed');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildStatusChip({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
  }) {
    return Container
      (
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: foreground.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in'),
        actions: [
          IconButton(
            tooltip: 'Admin',
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => Navigator.pushNamed(context, '/admin'),
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3F6FF), Color(0xFFE6ECFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 6,
              margin: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 22.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: const Icon(Icons.verified_user, color: Colors.deepPurple, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Welcome, \u200B$_welcomeName',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text([
                                  if (_platform.isNotEmpty) _platform,
                                  if (_model.isNotEmpty) _model,
                                  if (_os.isNotEmpty) _os,
                                ].join(' • '),
                                    style: TextStyle(color: Colors.grey.shade700)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildStatusChip(
                                      label: _allowed == true
                                          ? 'Device approved'
                                          : _allowed == false
                                              ? 'Device not approved'
                                              : 'Device status unknown',
                                      icon: _allowed == true
                                          ? Icons.check_circle
                                          : _allowed == false
                                              ? Icons.cancel
                                              : Icons.help_outline,
                                      background: _allowed == true
                                          ? Colors.green.shade50
                                          : _allowed == false
                                              ? Colors.orange.shade50
                                              : Colors.grey.shade100,
                                      foreground: _allowed == true
                                          ? Colors.green.shade800
                                          : _allowed == false
                                              ? Colors.orange.shade800
                                              : Colors.grey.shade700,
                                    ),
                                    _buildStatusChip(
                                      label: _bound == true
                                          ? 'Linked to this user'
                                          : _bound == false
                                              ? 'Not linked to this user'
                                              : 'Link status unknown',
                                      icon: _bound == true
                                          ? Icons.link
                                          : _bound == false
                                              ? Icons.link_off
                                              : Icons.help_outline,
                                      background: _bound == true
                                          ? Colors.blue.shade50
                                          : _bound == false
                                              ? Colors.grey.shade100
                                              : Colors.grey.shade100,
                                      foreground: _bound == true
                                          ? Colors.blue.shade800
                                          : _bound == false
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade700,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(height: 1, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _usernameCtrl,
                        onChanged: (_) => _onUsernameChanged(),
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        obscureText: _obscure,
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _loading ? null : _submit,
                              icon: const Icon(Icons.login),
                              label: const Text('Login'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _loading ? null : () => Navigator.pushNamed(context, '/admin'),
                          icon: const Icon(Icons.admin_panel_settings),
                          label: const Text('Admin'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ExpansionPanelList(
                        elevation: 0,
                        expansionCallback: (i, isOpen) async {
                          await _toggleUsers();
                        },
                        children: [
                          ExpansionPanel(
                            canTapOnHeader: true,
                            isExpanded: _showUsers,
                            headerBuilder: (ctx, isOpen) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.table_chart_outlined),
                              title: const Text('Test: Users Table'),
                              subtitle: const Text('Shows first 50 users (username, name, role)'),
                            ),
                            body: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Username')),
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Role')),
                                  DataColumn(label: Text('Created')),
                                ],
                                rows: _users
                                    .map((u) {
                                      final uname = (u['username'] ?? '').toString();
                                      return DataRow(
                                        onSelectChanged: (_) {
                                          _usernameCtrl.text = uname;
                                          _onUsernameChanged();
                                        },
                                        cells: [
                                          DataCell(Text(uname)),
                                          DataCell(Text((u['name'] ?? '').toString())),
                                          DataCell(Text((u['role'] ?? '').toString())),
                                          DataCell(Text((u['createdAt'] ?? '').toString())),
                                        ],
                                      );
                                    })
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/screens/auth/onboarding_screen.dart';

List<Map<String, dynamic>> _mapList(dynamic value) =>
    (value as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

class DeviceSessionsScreen extends StatefulWidget {
  const DeviceSessionsScreen({super.key});

  @override
  State<DeviceSessionsScreen> createState() => _DeviceSessionsScreenState();
}

class _DeviceSessionsScreenState extends State<DeviceSessionsScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> sessions = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && sessions.isEmpty && error == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(context).api.sessions();
      if (mounted) setState(() => sessions = _mapList(response['sessions']));
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> session) async {
    final current = session['current'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(current ? 'Sign out this device?' : 'Sign out device?'),
        content: Text(
          current
              ? 'You will return to the login screen on this device.'
              : 'The selected device will need OTP to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppScope.of(
        context,
      ).api.deleteSession((session['id'] as num).toInt());
      if (!mounted) return;
      if (current) {
        await AppScope.of(context).auth.logout();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (_) => false,
        );
      } else {
        await _load();
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Login & security')),
    body: loading && sessions.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : error != null && sessions.isEmpty
        ? Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: sessions
                  .map(
                    (session) => ListTile(
                      leading: const CircleAvatar(
                        child: Icon(LucideIcons.smartphone),
                      ),
                      title: Text('${session['device'] ?? 'Unknown device'}'),
                      subtitle: Text(
                        session['current'] == true
                            ? 'This device · ${session['last_used_ago'] ?? ''}'
                            : 'Last used ${session['last_used_ago'] ?? ''}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Sign out',
                        onPressed: () => _remove(session),
                        icon: const Icon(LucideIcons.logOut),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
  );
}

class TeamMembersScreen extends StatefulWidget {
  const TeamMembersScreen({super.key});

  @override
  State<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends State<TeamMembersScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> members = const [];
  List<String> roles = const ['manager', 'recruiter'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && members.isEmpty && error == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(context).api.team();
      if (!mounted) return;
      setState(() {
        members = _mapList(response['members']);
        final apiRoles = (response['roles'] as List? ?? const [])
            .map((item) => '$item')
            .toList();
        if (apiRoles.isNotEmpty) roles = apiRoles;
      });
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _add() async {
    final api = AppScope.of(context).api;
    final name = TextEditingController();
    final phone = TextEditingController();
    var role = roles.last;
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add team member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(labelText: 'Mobile number'),
              ),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: roles
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => role = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    final memberName = name.text.trim();
    final memberPhone = phone.text.replaceAll(RegExp(r'\D'), '');
    name.dispose();
    phone.dispose();
    if (submit != true) return;
    if (memberName.isEmpty || !RegExp(r'^[6-9]\d{9}$').hasMatch(memberPhone)) {
      _message('Enter a name and valid 10-digit mobile number.');
      return;
    }
    try {
      await api.addTeamMember(name: memberName, phone: memberPhone, role: role);
      await _load();
    } catch (exception) {
      _message('$exception');
    }
  }

  Future<void> _changeRole(Map<String, dynamic> member, String role) async {
    try {
      await AppScope.of(
        context,
      ).api.updateTeamMember((member['id'] as num).toInt(), role);
      await _load();
    } catch (exception) {
      _message('$exception');
    }
  }

  Future<void> _remove(Map<String, dynamic> member) async {
    try {
      await AppScope.of(
        context,
      ).api.removeTeamMember((member['id'] as num).toInt());
      await _load();
    } catch (exception) {
      _message('$exception');
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Team members'),
      actions: [
        IconButton(onPressed: _add, icon: const Icon(LucideIcons.userPlus)),
      ],
    ),
    body: loading && members.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : error != null && members.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: members.isEmpty
                  ? const [
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No team members yet.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ]
                  : members
                        .map(
                          (member) => ListTile(
                            leading: const CircleAvatar(
                              child: Icon(LucideIcons.userRound),
                            ),
                            title: Text('${member['name'] ?? ''}'),
                            subtitle: Text(
                              '${member['phone'] ?? ''} · ${member['added_ago'] ?? ''}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) => value == 'remove'
                                  ? _remove(member)
                                  : _changeRole(member, value),
                              itemBuilder: (context) => [
                                ...roles.map(
                                  (role) => PopupMenuItem(
                                    value: role,
                                    child: Text(
                                      role == member['role']
                                          ? '$role ✓'
                                          : 'Make $role',
                                    ),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text(
                                    'Remove',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
            ),
          ),
  );
}

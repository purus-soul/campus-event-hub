import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, String> _user = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AuthService.getCurrentUser();
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log Out')),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          const Center(
            child: CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48)),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(_user['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(_user['register_no'] ?? '', style: const TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 32),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Department'),
                  subtitle: Text(_user['department']?.isNotEmpty == true ? _user['department']! : 'Not set'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Batch'),
                  subtitle: Text(_user['batch']?.isNotEmpty == true ? _user['batch']! : 'Not set'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

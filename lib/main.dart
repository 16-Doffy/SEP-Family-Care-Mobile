import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:4000/api',
);

void main() => runApp(const FamilyCareMobileApp());

class FamilyCareMobileApp extends StatefulWidget {
  const FamilyCareMobileApp({super.key});

  @override
  State<FamilyCareMobileApp> createState() => _FamilyCareMobileAppState();
}

class _FamilyCareMobileAppState extends State<FamilyCareMobileApp> {
  final client = ApiClient(apiBaseUrl);
  Session? session;

  void setSession(Session value) => setState(() => session = value);
  void clearSession() => setState(() => session = null);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Care',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2563eb)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: session == null
          ? AuthScreen(client: client, onSignedIn: setSession)
          : HomeScreen(client: client, session: session!, onLogout: clearSession),
    );
  }
}

class ApiClient {
  ApiClient(this.baseUrl);
  final String baseUrl;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {String? token}) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers(token),
      body: jsonEncode(body),
    );
    return decode(response);
  }

  Future<dynamic> get(String path, {String? token}) async {
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: headers(token));
    return decode(response);
  }

  Map<String, String> headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  dynamic decode(http.Response response) {
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = body is Map ? body['message'] ?? body['error'] : 'Request failed';
      throw Exception(message);
    }
    return body;
  }
}

class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        user: json['user'] as Map<String, dynamic>,
      );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.client, required this.onSignedIn});
  final ApiClient client;
  final ValueChanged<Session> onSignedIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController(text: 'parent@demo.com');
  final password = TextEditingController(text: 'demo1234');
  final displayName = TextEditingController(text: 'Parent Demo');
  final familyName = TextEditingController(text: 'Gia dinh Demo');
  bool registerMode = false;
  bool loading = false;

  Future<void> submit() async {
    setState(() => loading = true);
    try {
      final data = registerMode
          ? await widget.client.post('/auth/register', {
              'email': email.text.trim(),
              'password': password.text,
              'displayName': displayName.text.trim(),
              'familyName': familyName.text.trim(),
            })
          : await widget.client.post('/auth/login', {
              'email': email.text.trim(),
              'password': password.text,
            });
      widget.onSignedIn(Session.fromJson(data));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 28),
            Text('Family Care', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(registerMode ? 'Tao family workspace moi' : 'Dang nhap de quan ly gia dinh'),
            const SizedBox(height: 28),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Mat khau')),
            if (registerMode) ...[
              const SizedBox(height: 12),
              TextField(controller: displayName, decoration: const InputDecoration(labelText: 'Ten hien thi')),
              const SizedBox(height: 12),
              TextField(controller: familyName, decoration: const InputDecoration(labelText: 'Ten gia dinh')),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: loading ? null : submit,
              icon: loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
              label: Text(registerMode ? 'Dang ky' : 'Dang nhap'),
            ),
            TextButton(
              onPressed: loading ? null : () => setState(() => registerMode = !registerMode),
              child: Text(registerMode ? 'Da co tai khoan? Dang nhap' : 'Chua co tai khoan? Dang ky'),
            ),
            const SizedBox(height: 16),
            Text('API: ${widget.client.baseUrl}', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.client, required this.session, required this.onLogout});
  final ApiClient client;
  final Session session;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardTab(client: widget.client, session: widget.session),
      DataTab(title: 'Tasks', icon: Icons.check_circle, path: '/tasks', client: widget.client, session: widget.session),
      DataTab(title: 'Wallets', icon: Icons.account_balance_wallet, path: '/wallets', client: widget.client, session: widget.session),
      SosTab(client: widget.client, session: widget.session),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Care'),
        actions: [IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout))],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.wallet), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.sos), label: 'SOS'),
        ],
      ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key, required this.client, required this.session});
  final ApiClient client;
  final Session session;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: client.get('/auth/me', token: session.accessToken),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final user = snapshot.data as Map<String, dynamic>;
        final member = user['familyMember'] as Map<String, dynamic>?;
        final family = member?['family'] as Map<String, dynamic>?;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Xin chao, ${user['displayName']}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            InfoCard(title: 'Family', value: family?['name']?.toString() ?? 'Chua co family', icon: Icons.groups),
            InfoCard(title: 'Role', value: user['role']?.toString() ?? '-', icon: Icons.verified_user),
            InfoCard(title: 'Plan', value: family?['plan']?.toString() ?? '-', icon: Icons.workspace_premium),
          ],
        );
      },
    );
  }
}

class DataTab extends StatelessWidget {
  const DataTab({super.key, required this.title, required this.icon, required this.path, required this.client, required this.session});
  final String title;
  final IconData icon;
  final String path;
  final ApiClient client;
  final Session session;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: client.get(path, token: session.accessToken),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
        final data = snapshot.data;
        final items = data is List ? data : data is Map && data['items'] is List ? data['items'] as List : data is Map && data['wallets'] is List ? data['wallets'] as List : const [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (items.isEmpty) const Text('Chua co du lieu'),
            for (final item in items)
              Card(
                child: ListTile(
                  leading: Icon(icon),
                  title: Text((item is Map ? item['title'] ?? item['name'] ?? item['reason'] : item).toString()),
                  subtitle: Text(item is Map ? item.entries.take(3).map((e) => '${e.key}: ${e.value}').join('\n') : ''),
                ),
              ),
          ],
        );
      },
    );
  }
}

class SosTab extends StatefulWidget {
  const SosTab({super.key, required this.client, required this.session});
  final ApiClient client;
  final Session session;

  @override
  State<SosTab> createState() => _SosTabState();
}

class _SosTabState extends State<SosTab> {
  bool sending = false;

  Future<void> sendSos() async {
    setState(() => sending = true);
    try {
      await widget.client.post('/sos', {'message': 'SOS from Flutter mobile'}, token: widget.session.accessToken);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Da gui SOS')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(180, 56)),
        onPressed: sending ? null : sendSos,
        icon: const Icon(Icons.sos),
        label: Text(sending ? 'Dang gui...' : 'Gui SOS'),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}

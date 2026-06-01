import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:4000/api',
);

const ink = Color(0xff172033);
const muted = Color(0xff667085);
const line = Color(0xffe6eaf0);
const bg = Color(0xfff5f7fb);
const primary = Color(0xff2563eb);
const teal = Color(0xff0f766e);
const danger = Color(0xffdc2626);
const amber = Color(0xffd97706);

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
    final textTheme = GoogleFonts.interTextTheme();
    return MaterialApp(
      title: 'Family Care',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light),
        textTheme: textTheme.apply(bodyColor: ink, displayColor: ink),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: primary, width: 1.4)),
        ),
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
    final response = await http.post(Uri.parse('$baseUrl$path'), headers: headers(token), body: jsonEncode(body));
    return decode(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body, {String? token}) async {
    final response = await http.patch(Uri.parse('$baseUrl$path'), headers: headers(token), body: jsonEncode(body));
    return decode(response) as Map<String, dynamic>;
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
  const Session({required this.accessToken, required this.refreshToken, required this.user});
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
          : await widget.client.post('/auth/login', {'email': email.text.trim(), 'password': password.text});
      widget.onSignedIn(Session.fromJson(data));
    } catch (e) {
      if (mounted) showToast(context, e.toString(), danger);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xffeef7ff), Color(0xfff8fbff), Color(0xfffffbf3)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
            children: [
              Row(
                children: [
                  const BrandMark(size: 52),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Family Care', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      const Text('Quan ly gia dinh moi ngay', style: TextStyle(color: muted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: panelDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(registerMode ? 'Tao family workspace' : 'Dang nhap', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(registerMode ? 'Khoi tao tai khoan quan ly gia dinh' : 'Tiep tuc voi tai khoan demo hoac tai khoan cua ban', style: const TextStyle(color: muted)),
                    const SizedBox(height: 18),
                    AppField(controller: email, label: 'Email', icon: LucideIcons.mail),
                    const SizedBox(height: 12),
                    AppField(controller: password, label: 'Mat khau', icon: LucideIcons.lockKeyhole, obscure: true),
                    if (registerMode) ...[
                      const SizedBox(height: 12),
                      AppField(controller: displayName, label: 'Ten hien thi', icon: LucideIcons.userRound),
                      const SizedBox(height: 12),
                      AppField(controller: familyName, label: 'Ten gia dinh', icon: LucideIcons.house),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                        onPressed: loading ? null : submit,
                        child: loading
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(registerMode ? LucideIcons.userRoundPlus : LucideIcons.logIn),
                                  const SizedBox(width: 10),
                                  Text(registerMode ? 'Dang ky' : 'Dang nhap', style: const TextStyle(fontWeight: FontWeight.w800)),
                                ],
                              ),
                      ),
                    ),
                    TextButton(
                      onPressed: loading ? null : () => setState(() => registerMode = !registerMode),
                      child: Text(registerMode ? 'Da co tai khoan? Dang nhap' : 'Chua co tai khoan? Dang ky'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InfoStrip(icon: LucideIcons.plugZap, text: 'API ${widget.client.baseUrl}'),
            ],
          ),
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
      DashboardTab(client: widget.client, session: widget.session, onLogout: widget.onLogout, onSelectTab: (value) => setState(() => index = value)),
      DataTab(title: 'Tasks', accent: primary, icon: LucideIcons.listChecks, path: '/tasks', client: widget.client, session: widget.session),
      WalletTab(client: widget.client, session: widget.session),
      GpsTab(client: widget.client, session: widget.session),
      SosTab(client: widget.client, session: widget.session),
    ];
    return Scaffold(
      extendBody: true,
      body: pages[index],
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: NavigationBar(
              height: 70,
              elevation: 0,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xffdbeafe),
              selectedIndex: index,
              onDestinationSelected: (value) => setState(() => index = value),
              destinations: [
                NavigationDestination(icon: Icon(LucideIcons.house), selectedIcon: Icon(LucideIcons.house500), label: 'Home'),
                NavigationDestination(icon: Icon(LucideIcons.listChecks), selectedIcon: Icon(LucideIcons.listChecks500), label: 'Tasks'),
                NavigationDestination(icon: Icon(LucideIcons.wallet), selectedIcon: Icon(LucideIcons.wallet500), label: 'Wallet'),
                NavigationDestination(icon: Icon(LucideIcons.mapPin), selectedIcon: Icon(LucideIcons.mapPinCheck), label: 'GPS'),
                NavigationDestination(icon: Icon(LucideIcons.siren), selectedIcon: Icon(LucideIcons.siren500), label: 'SOS'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key, required this.client, required this.session, required this.onLogout, required this.onSelectTab});
  final ApiClient client;
  final Session session;
  final VoidCallback onLogout;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: client.get('/auth/me', token: session.accessToken),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingScreen();
        final user = snapshot.data as Map<String, dynamic>;
        final member = user['familyMember'] as Map<String, dynamic>?;
        final family = member?['family'] as Map<String, dynamic>?;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 58, 18, 104),
          children: [
            Row(
              children: [
                CircleAvatar(radius: 27, backgroundColor: const Color(0xffdbeafe), child: Text(initials(user['displayName']?.toString() ?? 'FC'), style: const TextStyle(color: primary, fontWeight: FontWeight.w900))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Xin chao, ${user['displayName']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const Text('Hom nay minh quan ly gia dinh nhe', style: TextStyle(color: muted)),
                    ],
                  ),
                ),
                IconButton.filledTonal(onPressed: onLogout, icon: Icon(LucideIcons.logOut)),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(colors: [Color(0xff2563eb), Color(0xff0f766e)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: primary.withValues(alpha: .22), blurRadius: 28, offset: const Offset(0, 16))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(LucideIcons.house, color: Colors.white), const SizedBox(width: 10), const Text('Family Workspace', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700))]),
                  const SizedBox(height: 18),
                  Text(family?['name']?.toString() ?? 'Chua co family', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      LightBadge(icon: LucideIcons.shieldCheck, text: user['role']?.toString() ?? '-'),
                      LightBadge(icon: LucideIcons.crown, text: 'Plan ${family?['plan'] ?? '-'}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('Tac vu nhanh', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                ActionCard(icon: LucideIcons.listChecks, color: primary, title: 'Task hom nay', subtitle: 'Theo doi viec nha', onTap: () => onSelectTab(1)),
                ActionCard(icon: LucideIcons.wallet, color: teal, title: 'Vi gia dinh', subtitle: 'So du & giao dich', onTap: () => onSelectTab(2)),
                ActionCard(icon: LucideIcons.mapPin, color: amber, title: 'GPS', subtitle: 'Vi tri thanh vien', onTap: () => onSelectTab(3)),
                ActionCard(icon: LucideIcons.siren, color: danger, title: 'SOS', subtitle: 'Canh bao khan cap', onTap: () => onSelectTab(4)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class DataTab extends StatelessWidget {
  const DataTab({super.key, required this.title, required this.accent, required this.icon, required this.path, required this.client, required this.session});
  final String title;
  final Color accent;
  final IconData icon;
  final String path;
  final ApiClient client;
  final Session session;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: client.get(path, token: session.accessToken),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const LoadingScreen();
        if (snapshot.hasError) return ErrorState(message: snapshot.error.toString());
        final data = snapshot.data;
        final items = data is List ? data : data is Map && data['items'] is List ? data['items'] as List : data is Map && data['wallets'] is List ? data['wallets'] as List : const [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 58, 18, 104),
          children: [
            SectionHeader(title: title, icon: icon, color: accent),
            const SizedBox(height: 16),
            if (items.isEmpty) EmptyState(icon: icon, title: 'Chua co du lieu', text: 'Du lieu se hien thi o day khi backend co ban ghi.'),
            for (final item in items)
              ModernListTile(
                icon: icon,
                accent: accent,
                title: (item is Map ? item['title'] ?? item['name'] ?? item['reason'] ?? item['id'] : item).toString(),
                subtitle: item is Map ? item.entries.take(4).map((e) => '${e.key}: ${e.value}').join('\n') : '',
              ),
          ],
        );
      },
    );
  }
}

class WalletTab extends StatefulWidget {
  const WalletTab({super.key, required this.client, required this.session});
  final ApiClient client;
  final Session session;

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  late Future<dynamic> future = widget.client.get('/wallets', token: widget.session.accessToken);
  bool busy = false;

  void reload() => setState(() => future = widget.client.get('/wallets', token: widget.session.accessToken));

  Future<void> deposit(Map<String, dynamic> wallet) async {
    final result = await showWalletAmountSheet(context, title: 'Nap tien vao ${walletTitle(wallet)}', action: 'Nap tien');
    if (result == null) return;
    setState(() => busy = true);
    try {
      await widget.client.post('/wallets/deposit', {'walletId': wallet['id'], ...result}, token: widget.session.accessToken);
      if (mounted) showToast(context, 'Da nap tien vao vi', teal);
      reload();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), danger);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> transfer(List<Map<String, dynamic>> wallets) async {
    final result = await showTransferSheet(context, wallets);
    if (result == null) return;
    setState(() => busy = true);
    try {
      await widget.client.post('/wallets/transfer', result, token: widget.session.accessToken);
      if (mounted) showToast(context, 'Da chuyen tien giua cac vi', teal);
      reload();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), danger);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const LoadingScreen();
        if (snapshot.hasError) return ErrorState(message: snapshot.error.toString());
        final wallets = parseList(snapshot.data).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        final total = wallets.fold<double>(0, (sum, wallet) => sum + moneyValue(wallet['balance']));
        final primaryWallet = wallets.isEmpty ? null : wallets.first;

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 58, 18, 104),
          children: [
            SectionHeader(title: 'Vi gia dinh', icon: LucideIcons.wallet, color: teal),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(colors: [Color(0xff0f766e), Color(0xff2563eb)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: teal.withValues(alpha: .2), blurRadius: 28, offset: const Offset(0, 16))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(LucideIcons.badgeDollarSign, color: Colors.white), const SizedBox(width: 10), const Text('Tong so du', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700))]),
                const SizedBox(height: 12),
                Text(formatMoney(total), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  LightBadge(icon: LucideIcons.walletCards, text: '${wallets.length} vi dang hoat dong'),
                  LightBadge(icon: LucideIcons.shieldCheck, text: 'Kiem soat boi phu huynh'),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: QuickButton(icon: LucideIcons.plus, text: 'Nap tien', color: teal, onTap: primaryWallet == null || busy ? null : () => deposit(primaryWallet))),
              const SizedBox(width: 10),
              Expanded(child: QuickButton(icon: LucideIcons.arrowLeftRight, text: 'Chuyen vi', color: primary, onTap: wallets.length < 2 || busy ? null : () => transfer(wallets))),
            ]),
            const SizedBox(height: 20),
            Text('Danh sach vi', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (wallets.isEmpty) const EmptyState(icon: LucideIcons.wallet, title: 'Chua co vi', text: 'Tao vi tu backend/web de mobile hien so du va giao dich.'),
            for (final wallet in wallets)
              ModernListTile(
                icon: wallet['type'] == 'JOINT' ? LucideIcons.usersRound : LucideIcons.userRound,
                accent: wallet['type'] == 'JOINT' ? teal : primary,
                title: walletTitle(wallet),
                subtitle: 'So du: ${formatMoney(moneyValue(wallet['balance']))}\nLoai vi: ${wallet['type'] ?? '-'}\nChu vi: ${wallet['owner'] is Map ? wallet['owner']['displayName'] ?? '-' : '-'}',
              ),
            const SizedBox(height: 6),
            InfoStrip(icon: LucideIcons.info, text: 'Nap tien va chuyen vi goi truc tiep API /wallets. Neu bi tu choi, hay kiem tra role PARENT hoac so du vi nguon.'),
          ],
        );
      },
    );
  }
}

class GpsTab extends StatefulWidget {
  const GpsTab({super.key, required this.client, required this.session});
  final ApiClient client;
  final Session session;

  @override
  State<GpsTab> createState() => _GpsTabState();
}

class _GpsTabState extends State<GpsTab> {
  late Future<dynamic> future = widget.client.get('/location/family', token: widget.session.accessToken);
  bool busy = false;

  void reload() => setState(() => future = widget.client.get('/location/family', token: widget.session.accessToken));

  Future<void> toggleSharing(bool value) async {
    setState(() => busy = true);
    try {
      await widget.client.patch('/location/toggle', {'isSharing': value}, token: widget.session.accessToken);
      if (mounted) showToast(context, value ? 'Da bat chia se vi tri' : 'Da tat chia se vi tri', value ? teal : amber);
      reload();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), danger);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> updateDemoLocation() async {
    setState(() => busy = true);
    try {
      await widget.client.post('/location/update', {'latitude': 10.7769, 'longitude': 106.7009, 'accuracy': 18}, token: widget.session.accessToken);
      if (mounted) showToast(context, 'Da cap nhat toa do mau', teal);
      reload();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), danger);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const LoadingScreen();
        if (snapshot.hasError) return ErrorState(message: snapshot.error.toString());
        final shares = parseList(snapshot.data, key: 'shares');
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 58, 18, 104),
          children: [
            SectionHeader(title: 'GPS gia dinh', icon: LucideIcons.mapPin, color: amber),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: QuickButton(icon: LucideIcons.radioTower, text: 'Bat chia se', color: teal, onTap: busy ? null : () => toggleSharing(true))),
              const SizedBox(width: 10),
              Expanded(child: QuickButton(icon: LucideIcons.crosshair, text: 'Cap nhat', color: amber, onTap: busy ? null : updateDemoLocation)),
            ]),
            const SizedBox(height: 16),
            if (shares.isEmpty) const EmptyState(icon: LucideIcons.mapPinOff, title: 'Chua co vi tri', text: 'Bat chia se va cap nhat toa do de gia dinh thay ban tren GPS.'),
            for (final share in shares)
              ModernListTile(
                icon: LucideIcons.mapPinned,
                accent: amber,
                title: share is Map && share['user'] is Map ? share['user']['displayName']?.toString() ?? 'Thanh vien' : 'Thanh vien',
                subtitle: share is Map ? 'Lat: ${share['latitude'] ?? '-'}\nLng: ${share['longitude'] ?? '-'}\nCap nhat: ${share['updatedAt'] ?? '-'}' : share.toString(),
              ),
            const SizedBox(height: 6),
            QuickButton(icon: LucideIcons.powerOff, text: 'Tat chia se vi tri', color: danger, onTap: busy ? null : () => toggleSharing(false)),
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
  late Future<dynamic> future = widget.client.get('/sos', token: widget.session.accessToken);

  void reload() => setState(() => future = widget.client.get('/sos', token: widget.session.accessToken));

  Future<void> sendSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gui SOS khan cap?'),
        content: const Text('Canh bao se duoc gui toi tat ca thanh vien trong family workspace.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huy')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: danger), onPressed: () => Navigator.pop(context, true), child: const Text('Gui ngay')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => sending = true);
    try {
      await widget.client.post('/sos', {'message': 'SOS from Flutter mobile', 'address': 'Mobile app'}, token: widget.session.accessToken);
      if (mounted) showToast(context, 'Da gui SOS den gia dinh', teal);
      reload();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), danger);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> updateAlert(String id, String status) async {
    setState(() => sending = true);
    try {
      await widget.client.patch('/sos/$id', {'status': status}, token: widget.session.accessToken);
      if (mounted) showToast(context, 'Da cap nhat trang thai SOS', teal);
      reload();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), danger);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        final alerts = snapshot.hasData ? parseList(snapshot.data, key: 'alerts') : const [];
        final activeAlerts = alerts.where((alert) => alert is Map && ['ACTIVE', 'ACKNOWLEDGED'].contains(alert['status'])).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 58, 18, 104),
          children: [
            SectionHeader(title: 'SOS Khan cap', icon: LucideIcons.siren, color: danger),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xfffff1f2),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xffffcdd4)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: danger, boxShadow: [BoxShadow(color: danger.withValues(alpha: .26), blurRadius: 30, offset: const Offset(0, 12))]),
                    child: Icon(LucideIcons.siren500, color: Colors.white, size: 54),
                  ),
                  const SizedBox(height: 18),
                  Text('Gui canh bao khan cap', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Thong bao realtime va push notification se gui den cac thanh vien trong gia dinh.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                      onPressed: sending ? null : sendSos,
                      icon: sending ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(LucideIcons.radioTower),
                      label: const Text('GUI SOS NGAY', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: StatusPill(icon: LucideIcons.activity, value: '${activeAlerts.length}', label: 'dang xu ly', color: danger)),
              const SizedBox(width: 10),
              Expanded(child: StatusPill(icon: LucideIcons.history, value: '${alerts.length}', label: 'lich su', color: primary)),
            ]),
            const SizedBox(height: 16),
            InfoStrip(icon: LucideIcons.phoneCall, text: 'Sau khi gui SOS, hay goi nguoi than hoac so khan cap dia phuong neu tinh huong nguy hiem.'),
            const SizedBox(height: 20),
            Text('Lich su SOS', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (snapshot.connectionState != ConnectionState.done) const LoadingScreen(),
            if (snapshot.hasError) ErrorState(message: snapshot.error.toString()),
            if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError && alerts.isEmpty)
              const EmptyState(icon: LucideIcons.shieldCheck, title: 'Chua co SOS', text: 'Khi co canh bao, lich su va trang thai xu ly se nam o day.'),
            for (final alert in alerts.take(8))
              if (alert is Map)
                SosAlertCard(
                  alert: Map<String, dynamic>.from(alert),
                  busy: sending,
                  onAck: () => updateAlert(alert['id'].toString(), 'ACKNOWLEDGED'),
                  onResolve: () => updateAlert(alert['id'].toString(), 'RESOLVED'),
                ),
          ],
        );
      },
    );
  }
}

class AppField extends StatelessWidget {
  const AppField({super.key, required this.controller, required this.label, required this.icon, this.obscure = false});
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(prefixIcon: Icon(icon, color: muted), labelText: label),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const LinearGradient(colors: [primary, teal])),
      child: Icon(LucideIcons.heartPulse, color: Colors.white, size: size * .52),
    );
  }
}

class LightBadge extends StatelessWidget {
  const LightBadge({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: Colors.white), const SizedBox(width: 6), Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.icon, required this.color});
  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon, color: color, size: 30), const SizedBox(width: 10), Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))]);
  }
}

class ActionCard extends StatelessWidget {
  const ActionCard({super.key, required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: panelDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color)),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class QuickButton extends StatelessWidget {
  const QuickButton({super.key, required this.icon, required this.text, required this.color, required this.onTap});
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: onTap == null ? muted : color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.icon, required this.value, required this.label, required this.color});
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: panelDecoration(),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 12))])),
      ]),
    );
  }
}

class SosAlertCard extends StatelessWidget {
  const SosAlertCard({super.key, required this.alert, required this.busy, required this.onAck, required this.onResolve});
  final Map<String, dynamic> alert;
  final bool busy;
  final VoidCallback onAck;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final status = alert['status']?.toString() ?? 'ACTIVE';
    final sender = alert['sender'] is Map ? alert['sender']['displayName']?.toString() ?? 'Thanh vien' : 'Thanh vien';
    final active = status == 'ACTIVE' || status == 'ACKNOWLEDGED';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: panelDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: danger.withValues(alpha: .1), borderRadius: BorderRadius.circular(16)), child: Icon(LucideIcons.siren, color: active ? danger : muted)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$sender - $status', style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${alert['message'] ?? 'SOS'}\n${alert['address'] ?? alert['createdAt'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 12, height: 1.35)),
          ])),
        ]),
        if (active) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: busy || status == 'ACKNOWLEDGED' ? null : onAck, child: const Text('Da nhan'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: teal), onPressed: busy ? null : onResolve, child: const Text('Da xu ly'))),
          ]),
        ],
      ]),
    );
  }
}

class ModernListTile extends StatelessWidget {
  const ModernListTile({super.key, required this.icon, required this.accent, required this.title, required this.subtitle});
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: panelDecoration(),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: accent.withValues(alpha: .1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: accent)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 12, height: 1.35))])),
      ]),
    );
  }
}

class InfoStrip extends StatelessWidget {
  const InfoStrip({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .72), borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
      child: Row(children: [Icon(icon, color: primary, size: 19), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(color: muted, fontSize: 12)))]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: panelDecoration(),
      child: Column(children: [Icon(icon, color: muted, size: 44), const SizedBox(height: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: muted))]),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: danger))));
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

BoxDecoration panelDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: line),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .045), blurRadius: 22, offset: const Offset(0, 10))],
    );

String initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((e) => e[0].toUpperCase()).join();
}

List<dynamic> parseList(dynamic data, {String? key}) {
  if (data is List) return data;
  if (data is Map && key != null && data[key] is List) return data[key] as List;
  if (data is Map && data['items'] is List) return data['items'] as List;
  if (data is Map && data['wallets'] is List) return data['wallets'] as List;
  if (data is Map && data['alerts'] is List) return data['alerts'] as List;
  if (data is Map && data['shares'] is List) return data['shares'] as List;
  return const [];
}

double moneyValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String formatMoney(num value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    final left = rounded.length - i;
    buffer.write(rounded[i]);
    if (left > 1 && left % 3 == 1) buffer.write('.');
  }
  return '$buffer VND';
}

String walletTitle(Map<String, dynamic> wallet) => wallet['name']?.toString() ?? wallet['type']?.toString() ?? 'Vi gia dinh';

Future<Map<String, dynamic>?> showWalletAmountSheet(BuildContext context, {required String title, required String action}) {
  final amount = TextEditingController(text: '100000');
  final description = TextEditingController(text: action);
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(context).viewInsets.bottom + 18),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        AppField(controller: amount, label: 'So tien', icon: LucideIcons.badgeDollarSign),
        const SizedBox(height: 12),
        AppField(controller: description, label: 'Mo ta', icon: LucideIcons.receiptText),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () {
              final parsed = double.tryParse(amount.text.trim());
              if (parsed == null || parsed <= 0) return;
              Navigator.pop(context, {'amount': parsed, 'description': description.text.trim()});
            },
            child: Text(action, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ]),
    ),
  ).whenComplete(() {
    amount.dispose();
    description.dispose();
  });
}

Future<Map<String, dynamic>?> showTransferSheet(BuildContext context, List<Map<String, dynamic>> wallets) {
  final amount = TextEditingController(text: '50000');
  final description = TextEditingController(text: 'Chuyen tien noi bo');
  var from = wallets.first;
  var to = wallets.length > 1 ? wallets[1] : wallets.first;
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(context).viewInsets.bottom + 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Chuyen tien giua cac vi', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: from,
            decoration: const InputDecoration(labelText: 'Vi nguon', prefixIcon: Icon(LucideIcons.wallet)),
            items: wallets.map((wallet) => DropdownMenuItem(value: wallet, child: Text(walletTitle(wallet)))).toList(),
            onChanged: (value) => setSheetState(() => from = value ?? from),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: to,
            decoration: const InputDecoration(labelText: 'Vi nhan', prefixIcon: Icon(LucideIcons.walletCards)),
            items: wallets.map((wallet) => DropdownMenuItem(value: wallet, child: Text(walletTitle(wallet)))).toList(),
            onChanged: (value) => setSheetState(() => to = value ?? to),
          ),
          const SizedBox(height: 12),
          AppField(controller: amount, label: 'So tien', icon: LucideIcons.badgeDollarSign),
          const SizedBox(height: 12),
          AppField(controller: description, label: 'Mo ta', icon: LucideIcons.receiptText),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () {
                final parsed = double.tryParse(amount.text.trim());
                if (parsed == null || parsed <= 0 || from['id'] == to['id']) return;
                Navigator.pop(context, {'fromWalletId': from['id'], 'toWalletId': to['id'], 'amount': parsed, 'description': description.text.trim()});
              },
              child: const Text('Chuyen tien', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
    ),
  ).whenComplete(() {
    amount.dispose();
    description.dispose();
  });
}

void showToast(BuildContext context, String message, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating));
}



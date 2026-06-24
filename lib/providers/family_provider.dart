import 'package:flutter/material.dart';
import '../services/api_client.dart';

class FamilyMember {
  final String id;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String familyRole; // FAMILY_MANAGER | DEPUTY_MEMBER | FAMILY_MEMBER
  final String status;

  const FamilyMember({
    required this.id,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.familyRole,
    required this.status,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return FamilyMember(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? user?['id']?.toString() ?? '',
      displayName: json['displayName'] as String? ??
          user?['fullName'] as String? ??
          'Thành viên',
      avatarUrl: user?['avatarUrl'] as String?,
      familyRole: json['familyRole'] as String? ?? 'FAMILY_MEMBER',
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }

  bool get isManager => familyRole == 'FAMILY_MANAGER';
  bool get isDeputy  => familyRole == 'DEPUTY_MEMBER';

  String get roleLabel => switch (familyRole) {
        'FAMILY_MANAGER' => 'Trưởng nhóm',
        'DEPUTY_MEMBER'  => 'Phó nhóm',
        _                => 'Thành viên',
      };
}

class FamilyDetail {
  final String id;
  final String name;
  final String? description;
  final List<FamilyMember> members;

  const FamilyDetail({
    required this.id,
    required this.name,
    this.description,
    this.members = const [],
  });

  factory FamilyDetail.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List<dynamic>? ?? [];
    return FamilyDetail(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      members: rawMembers
          .whereType<Map>()
          .map((m) => FamilyMember.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

class FamilyInvitation {
  final String id;
  final String email;
  final String status;
  final String familyRole;
  final String relationship;
  final String? claimedByName;
  final String? createdAt;

  const FamilyInvitation({
    required this.id,
    required this.email,
    required this.status,
    required this.familyRole,
    required this.relationship,
    this.claimedByName,
    this.createdAt,
  });

  factory FamilyInvitation.fromJson(Map<String, dynamic> json) {
    final invitee = json['invitee'] is Map ? json['invitee'] as Map : {};
    final acceptedBy =
        json['acceptedBy'] is Map ? json['acceptedBy'] as Map : {};
    final claimedBy = json['claimedBy'] is Map ? json['claimedBy'] as Map : {};
    return FamilyInvitation(
      id: json['id']?.toString() ?? json['invitationId']?.toString() ?? '',
      email: json['email']?.toString() ??
          json['invitedEmail']?.toString() ??
          invitee['email']?.toString() ??
          '',
      status: json['status']?.toString() ?? 'PENDING',
      familyRole: json['familyRole']?.toString() ?? 'FAMILY_MEMBER',
      relationship: json['relationship']?.toString() ?? 'OTHER',
      claimedByName: acceptedBy['fullName']?.toString() ??
          acceptedBy['displayName']?.toString() ??
          claimedBy['fullName']?.toString() ??
          claimedBy['displayName']?.toString() ??
          invitee['fullName']?.toString() ??
          invitee['displayName']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }

  String get roleLabel => switch (familyRole) {
        'FAMILY_MANAGER' => 'Truong nhom',
        'DEPUTY_MEMBER' => 'Pho nhom',
        _ => 'Thành viên',
      };
}

class FamilyProvider extends ChangeNotifier {
  String? _familyId;

  FamilyDetail? _family;
  List<FamilyInvitation> _invitations = [];
  bool _loading = false;
  String? _error;

  FamilyDetail? get family => _family;
  List<FamilyInvitation> get invitations => _invitations;
  List<FamilyInvitation> get claimedInvitations =>
      _invitations.where((i) => i.status == 'CLAIMED').toList();
  bool get isLoading => _loading;
  String? get error => _error;
  List<FamilyMember> get members => _family?.members ?? [];

  set familyId(String id) {
    if (_familyId != id) {
      _familyId = id;
      fetchFamily();
    }
  }

  // ─── Families ─────────────────────────────────────────────────────────────

  Future<String> createFamily({
    required String name,
    String description = '',
    String? avatarUrl,
  }) async {
    final data = await ApiClient.instance.post('/families', {
      'name': name,
      if (description.isNotEmpty) 'description': description,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    final id = (data is Map ? data['id']?.toString() : null) ?? '';
    return id;
  }

  Future<void> fetchFamily() async {
    if (_familyId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/families/$_familyId');
      if (data is Map<String, dynamic>) {
        _family = FamilyDetail.fromJson(data);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateFamily({
    String? name,
    String? description,
    String? avatarUrl,
  }) async {
    if (_familyId == null) return;
    await ApiClient.instance.patch('/families/$_familyId', {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    await fetchFamily();
  }

  Future<void> removeMember(String userId) async {
    if (_familyId == null) return;
    await ApiClient.instance.delete('/families/$_familyId/members/$userId');
    await fetchFamily();
  }

  // ─── Invitations ──────────────────────────────────────────────────────────

  // Returns the invite token so the caller can display a shareable link
  Future<String> inviteMember(
    String email, {
    String familyRole = 'FAMILY_MEMBER',
    String relationship = 'OTHER',
    String? invitedPhone,
  }) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    final data = await ApiClient.instance.post('/families/$_familyId/invitations', {
      'email': email,
      'familyRole': familyRole,
      'relationship': relationship,
      if (invitedPhone != null && invitedPhone.isNotEmpty) 'invitedPhone': invitedPhone,
    });
    final map = data is Map ? data : {};
    final token = map['token']?.toString() ?? map['inviteToken']?.toString() ?? map['data']?['token']?.toString() ?? '';
    return token;
  }

  Future<void> fetchInvitations({String? status}) async {
    if (_familyId == null) return;
    final data = await ApiClient.instance.get(
      '/families/$_familyId/invitations',
      params: status != null ? {'status': status} : null,
    );
    final list = _extractList(data);
    _invitations = list
        .whereType<Map>()
        .map((e) => FamilyInvitation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    notifyListeners();
  }

  Future<void> approveInvitation(FamilyInvitation invitation) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$_familyId/invitations/${invitation.id}/approve',
      {
        'familyRole': invitation.familyRole,
        'relationship': invitation.relationship,
      },
    );
    await fetchInvitations(status: 'CLAIMED');
    await fetchFamily();
  }

  Future<void> rejectClaimedInvitation(String invitationId) async {
    if (_familyId == null) throw Exception('Chưa có gia đình');
    await ApiClient.instance.post(
      '/families/$_familyId/invitations/$invitationId/reject',
    );
    await fetchInvitations(status: 'CLAIMED');
  }

  Future<Map<String, dynamic>> lookupInvitation(String token) async {
    final data = await ApiClient.instance.get('/invitations/$token');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<void> acceptInvitation(String token) async {
    await ApiClient.instance.post('/invitations/$token/claim');
  }

  Future<void> rejectInvitation(String _) async {
    // The current backend no longer exposes a public token reject endpoint.
    // Ignoring the invite locally is enough for the invitee flow.
  }

  static List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is! Map) return const <dynamic>[];
    for (final key in const ['items', 'data', 'invitations', 'results']) {
      final value = data[key];
      if (value is List) return value;
      if (value is Map) {
        final nested = _extractList(value);
        if (nested.isNotEmpty) return nested;
      }
    }
    return const <dynamic>[];
  }
}

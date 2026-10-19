import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_model.dart';
import '../../models/reservation_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'all'; // 'all', 'player', 'admin'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: AppTheme.primary),
            tooltip: 'Add New User',
            onPressed: () => _showAddUserDialog(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: StreamBuilder<List<UserModel>>(
          stream: _firestoreService.getAllUsers(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }

            final allUsers = snapshot.data!;
            final totalUsers = allUsers.length;
            final totalPlayers =
                allUsers.where((u) => u.role == 'player').length;
            final totalAdmins = allUsers.where((u) => u.role == 'admin').length;

            // Apply search & role filters
            final filteredUsers = allUsers.where((u) {
              final matchesRole = _roleFilter == 'all' || u.role == _roleFilter;
              final query = _searchQuery.toLowerCase();
              final matchesQuery = query.isEmpty ||
                  u.name.toLowerCase().contains(query) ||
                  u.email.toLowerCase().contains(query) ||
                  (u.phone ?? '').toLowerCase().contains(query);
              return matchesRole && matchesQuery;
            }).toList();

            return Column(
              children: [
                // ── Summary Stats ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Users',
                          totalUsers.toString(),
                          Icons.people_alt_rounded,
                          AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          'Players',
                          totalPlayers.toString(),
                          Icons.sports_tennis_rounded,
                          AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          'Admins',
                          totalAdmins.toString(),
                          Icons.admin_panel_settings_rounded,
                          AppTheme.statusReserved,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Search & Filter Bar ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search by name, email, or phone...',
                        hintStyle: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppTheme.textSecondary, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    color: AppTheme.textMuted, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ),

                // ── Role Filter Tabs ─────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      _filterTab('All ($totalUsers)', 'all'),
                      const SizedBox(width: 8),
                      _filterTab('Players ($totalPlayers)', 'player'),
                      const SizedBox(width: 8),
                      _filterTab('Admins ($totalAdmins)', 'admin'),
                    ],
                  ),
                ),

                // ── User Cards List ──────────────────────────────────────────
                Expanded(
                  child: filteredUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_rounded,
                                  size: 50,
                                  color: AppTheme.textMuted.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              const Text(
                                'No users found matching filter',
                                style: TextStyle(
                                    color: AppTheme.textSecondary, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: filteredUsers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final isMe = currentUser?.uid == user.uid;

                            return _UserCard(
                              user: user,
                              isCurrentUser: isMe,
                              onRoleChanged: (newRole) =>
                                  _updateRole(context, user, newRole),
                              onEdit: () => _showEditUserDialog(context, user),
                              onViewBookings: () =>
                                  _showUserBookings(context, user),
                              onDelete: () => _confirmDeleteUser(context, user),
                            ).animate().fadeIn(
                                delay: Duration(milliseconds: index * 30),
                                duration: 250.ms);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterTab(String label, String role) {
    final isSelected = _roleFilter == role;
    return GestureDetector(
      onTap: () => setState(() => _roleFilter = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.15)
              : AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _updateRole(
      BuildContext context, UserModel user, String newRole) async {
    await _firestoreService.updateUserRole(user.uid, newRole);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.name} role changed to ${newRole.toUpperCase()}'),
          backgroundColor: AppTheme.card,
        ),
      );
    }
  }

  void _showEditUserDialog(BuildContext context, UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    String selectedRole = user.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit User Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Role Permissions',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Player'),
                        selected: selectedRole == 'player',
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedRole = 'player');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Admin'),
                        selected: selectedRole == 'admin',
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedRole = 'admin');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updated = user.copyWith(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  role: selectedRole,
                );
                await _firestoreService.updateUser(updated);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedRole = 'player';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add New User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Account Role',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Player'),
                        selected: selectedRole == 'player',
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedRole = 'player');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Admin'),
                        selected: selectedRole == 'admin',
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedRole = 'admin');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty ||
                    emailCtrl.text.trim().isEmpty) {
                  return;
                }
                final newUser = UserModel(
                  uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim().toLowerCase(),
                  phone: phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  role: selectedRole,
                );
                await _firestoreService.createUser(newUser);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Create User'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserBookings(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UserBookingsSheet(
        user: user,
        firestoreService: _firestoreService,
      ),
    );
  }

  void _confirmDeleteUser(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User Account'),
        content: Text(
          'Are you sure you want to delete ${user.name} (${user.email})? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusInUse,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _firestoreService.deleteUser(user.uid);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('User ${user.name} removed'),
                    backgroundColor: AppTheme.statusInUse,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final bool isCurrentUser;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onEdit;
  final VoidCallback onViewBookings;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.isCurrentUser,
    required this.onRoleChanged,
    required this.onEdit,
    required this.onViewBookings,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == 'admin';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAdmin
              ? AppTheme.primary.withOpacity(0.35)
              : AppTheme.cardBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar ──
              CircleAvatar(
                radius: 22,
                backgroundColor: isAdmin
                    ? AppTheme.primary.withOpacity(0.18)
                    : AppTheme.accent.withOpacity(0.18),
                child: Text(
                  user.name.isNotEmpty
                      ? user.name.substring(0, 1).toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: isAdmin ? AppTheme.primary : AppTheme.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ── User Info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.phone != null && user.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded,
                              color: AppTheme.textMuted, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            user.phone!,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ── Role Badge ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAdmin
                      ? AppTheme.primary.withOpacity(0.15)
                      : AppTheme.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isAdmin
                        ? AppTheme.primary.withOpacity(0.4)
                        : AppTheme.accent.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAdmin
                          ? Icons.admin_panel_settings_rounded
                          : Icons.person_rounded,
                      size: 12,
                      color: isAdmin ? AppTheme.primary : AppTheme.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isAdmin ? 'Admin' : 'Player',
                      style: TextStyle(
                        color: isAdmin ? AppTheme.primary : AppTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: AppTheme.cardBorder, height: 1),
          const SizedBox(height: 10),

          // ── Quick Actions ──
          Row(
            children: [
              // View Bookings Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewBookings,
                  icon: const Icon(Icons.history_rounded, size: 14),
                  label: const Text('Bookings', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Edit Button
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppTheme.textSecondary, size: 18),
                tooltip: 'Edit Profile',
                onPressed: onEdit,
              ),

              // Promote / Demote Role Toggle
              IconButton(
                icon: Icon(
                  isAdmin
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: isAdmin ? AppTheme.statusReserved : AppTheme.primary,
                  size: 18,
                ),
                tooltip: isAdmin ? 'Change to Player' : 'Promote to Admin',
                onPressed: () {
                  final newRole = isAdmin ? 'player' : 'admin';
                  onRoleChanged(newRole);
                },
              ),

              // Delete Button (disabled for self)
              if (!isCurrentUser)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.statusInUse, size: 18),
                  tooltip: 'Delete User',
                  onPressed: onDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserBookingsSheet extends StatelessWidget {
  final UserModel user;
  final FirestoreService firestoreService;

  const _UserBookingsSheet({
    required this.user,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppTheme.cardBorder, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${user.name}'s Bookings",
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: AppTheme.cardBorder, height: 1),

          // List of Bookings
          Flexible(
            child: StreamBuilder<List<ReservationModel>>(
              stream: firestoreService.getUserReservations(user.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  );
                }

                final reservations = snapshot.data!;
                if (reservations.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 40,
                              color: AppTheme.textMuted.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          const Text(
                            'No bookings found for this user',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final totalSpent = reservations.fold<double>(
                    0, (sum, r) => sum + (r.isCancelled ? 0 : r.amount));

                return Column(
                  children: [
                    // Summary Banner
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${reservations.length}',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'Total Bookings',
                                style: TextStyle(
                                    color: AppTheme.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                          Container(
                              height: 24,
                              width: 1,
                              color: AppTheme.cardBorder),
                          Column(
                            children: [
                              Text(
                                '₱${totalSpent.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'Total Spent',
                                style: TextStyle(
                                    color: AppTheme.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Reservation items
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: reservations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final r = reservations[index];
                          final isUpcoming = r.isUpcoming;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isUpcoming
                                        ? AppTheme.primary.withOpacity(0.12)
                                        : AppTheme.cardBorder.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.sports_tennis_rounded,
                                    color: isUpcoming
                                        ? AppTheme.primary
                                        : AppTheme.textMuted,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${r.courtName} • ${DateHelpers.toShortDate(r.startTime)}',
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        DateHelpers.toTimeRange(
                                            r.startTime, r.endTime),
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₱${r.amount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      r.status.toUpperCase(),
                                      style: TextStyle(
                                        color: r.status == 'cancelled'
                                            ? AppTheme.statusInUse
                                            : isUpcoming
                                                ? AppTheme.primary
                                                : AppTheme.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

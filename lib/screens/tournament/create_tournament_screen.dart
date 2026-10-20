import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/court_provider.dart';
import '../../providers/tournament_provider.dart';
import '../../models/player_model.dart';
import '../../models/court_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/constants/app_constants.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() =>
      _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _playerNameCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  CourtModel? _selectedCourt;
  final List<PlayerModel> _players = [];
  bool _isSubmitting = false;
  bool _includeSelf = true;
  bool _hasInitializedSelf = false;

  String _format = AppConstants.formatQualifyingRounds;
  int _qualifyingRounds = 5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitializedSelf) {
      _hasInitializedSelf = true;
      final user = context.read<AuthProvider>().currentUser;
      if (user != null && _includeSelf) {
        _players.add(PlayerModel(
          uid: user.uid,
          name: user.name.isNotEmpty ? user.name : 'You',
          email: user.email,
        ));
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _playerNameCtrl.dispose();
    super.dispose();
  }

  void _toggleIncludeSelf(bool? val) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    setState(() {
      _includeSelf = val ?? false;
      if (_includeSelf) {
        if (!_players.any((p) => p.uid == user.uid)) {
          _players.insert(
            0,
            PlayerModel(
              uid: user.uid,
              name: user.name.isNotEmpty ? user.name : 'You',
              email: user.email,
            ),
          );
        }
      } else {
        _players.removeWhere((p) => p.uid == user.uid);
      }
    });
  }

  void _addPlayer() {
    final name = _playerNameCtrl.text.trim();
    if (name.isEmpty) return;
    if (_players.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Player already added')),
      );
      return;
    }
    setState(() {
      _players.add(PlayerModel(
        uid: 'manual_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
      ));
      _playerNameCtrl.clear();
    });
  }

  void _removePlayer(int index) {
    final user = context.read<AuthProvider>().currentUser;
    setState(() {
      if (user != null && _players[index].uid == user.uid) {
        _includeSelf = false;
      }
      _players.removeAt(index);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least 2 players to generate tournament bracket'),
          backgroundColor: AppTheme.statusReserved,
        ),
      );
      return;
    }

    final user = context.read<AuthProvider>().currentUser;

    setState(() => _isSubmitting = true);
    final success = await context.read<TournamentProvider>().createTournament(
          name: _nameCtrl.text,
          date: _selectedDate,
          players: _players,
          format: _format,
          qualifyingRoundsCount: _qualifyingRounds,
          description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
          courtId: _selectedCourt?.id,
          courtName: _selectedCourt?.name,
          creatorId: user?.uid,
          creatorName: user?.name,
        );

    if (mounted) setState(() => _isSubmitting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tournament event created successfully!'),
          backgroundColor: AppTheme.statusAvailable,
        ),
      );
      Navigator.of(context).pop();
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              context.read<TournamentProvider>().error ?? 'Failed to create'),
          backgroundColor: AppTheme.statusInUse,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final courts = context.watch<CourtProvider>().courts;
    final currentUser = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Tournament / Event'),
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: AppTheme.textPrimary, size: 20),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Tournament Info ──────────────────────────────────────────
              _sectionTitle('Event Details'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCard,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Tournament / Event Name',
                        prefixIcon: Icon(Icons.emoji_events_outlined),
                        hintText: 'e.g. Weekend Club Championship',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a tournament or event name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description / Event Info (optional)',
                        prefixIcon: Icon(Icons.description_outlined),
                        hintText: 'e.g. Friendly community event for all players',
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Court Selector
                    DropdownButtonFormField<CourtModel?>(
                      value: _selectedCourt,
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Designated Court (optional)',
                        prefixIcon: Icon(Icons.sports_tennis_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<CourtModel?>(
                          value: null,
                          child: Text('Any / TBD Court',
                              style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                        ...courts.map((c) => DropdownMenuItem<CourtModel?>(
                              value: c,
                              child: Text(c.name,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary)),
                            )),
                      ],
                      onChanged: (c) => setState(() => _selectedCourt = c),
                    ),
                    const SizedBox(height: 14),
                    // Date picker
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined,
                                color: AppTheme.textSecondary, size: 20),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Event Date',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12)),
                                Text(
                                  DateHelpers.toShortDate(_selectedDate),
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.edit_outlined,
                                size: 16, color: AppTheme.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Tournament Format & Rounds ───────────────────────────────
              _sectionTitle('Tournament Format & Stage Setup'),
              const SizedBox(height: 12),
              _buildFormatSelector(),
              const SizedBox(height: 24),

              // ── Player Participation Option ──────────────────────────────
              if (currentUser != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.how_to_reg_outlined,
                          color: AppTheme.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Join as a Player',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Include ${currentUser.name.isNotEmpty ? currentUser.name : "myself"} in the tournament bracket',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _includeSelf,
                        activeColor: AppTheme.primary,
                        onChanged: _toggleIncludeSelf,
                      ),
                    ],
                  ),
                ),

              // ── Players ──────────────────────────────────────────────────
              Row(
                children: [
                  _sectionTitle('Players / Participants'),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_players.length}',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Recommended: ${AppConstants.validBracketSizes.join(', ')} players (min. 2 to generate bracket)',
                style:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              // Add player input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCard,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _playerNameCtrl,
                            style: const TextStyle(
                                color: AppTheme.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Add Player Name',
                              prefixIcon: Icon(Icons.person_add_outlined),
                            ),
                            onFieldSubmitted: (_) => _addPlayer(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _addPlayer,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: AppTheme.background, size: 20),
                          ),
                        ),
                      ],
                    ),
                    if (_players.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(color: AppTheme.cardBorder),
                      const SizedBox(height: 8),
                      ..._players.asMap().entries.map(
                            (e) {
                              final isUser = currentUser != null &&
                                  e.value.uid == currentUser.uid;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color:
                                            AppTheme.primary.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${e.key + 1}',
                                          style: const TextStyle(
                                            color: AppTheme.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text(
                                            e.value.name,
                                            style: const TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontSize: 14),
                                          ),
                                          if (isUser) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'YOU',
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
                                    ),
                                    GestureDetector(
                                      onTap: () => _removePlayer(e.key),
                                      child: const Icon(
                                        Icons.remove_circle_outline,
                                        color: AppTheme.statusInUse,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Submit
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppTheme.background,
                          ),
                        )
                      : Icon(
                          _format == AppConstants.formatQualifyingRounds
                              ? Icons.military_tech_rounded
                              : Icons.account_tree_rounded,
                          size: 20),
                  label: Text(
                    _isSubmitting
                        ? 'Creating Event...'
                        : (_format == AppConstants.formatQualifyingRounds
                            ? 'Create Tournament ($_qualifyingRounds Rounds → QF)'
                            : 'Generate Bracket & Create Event'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatSelector() {
    final isQualifying = _format == AppConstants.formatQualifyingRounds;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Option 1: Qualifying Rounds -> Quarter-Finals
          _buildFormatOptionTile(
            title: 'Qualifying Rounds → Quarter-Finals',
            subtitle:
                'Bawat player maglalaro ng $_qualifyingRounds rounds. Ang Top 8 ay awtomatikong aabante sa Quarter-Finals.',
            icon: Icons.military_tech_rounded,
            isSelected: isQualifying,
            onTap: () => setState(
                () => _format = AppConstants.formatQualifyingRounds),
          ),
          if (isQualifying) ...[
            const SizedBox(height: 14),
            const Divider(color: AppTheme.cardBorder, height: 1),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.repeat_rounded,
                    size: 16, color: AppTheme.primary),
                SizedBox(width: 8),
                Text(
                  'Number of Rounds per Player:',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [3, 4, 5, 6, 7].map((r) {
                final isSelected = _qualifyingRounds == r;
                return InkWell(
                  onTap: () => setState(() => _qualifyingRounds = r),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withOpacity(0.18)
                          : AppTheme.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.cardBorder,
                      ),
                    ),
                    child: Text(
                      '$r Rounds${r == 5 ? ' (Default)' : ''}',
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Lahat ng players ay maglalaro ng exactly $_qualifyingRounds rounds. Ang scores & wins ay mag-uupdate sa live Leaderboard. Ang Top 8 ay maglalaban sa Quarter-Finals knockout bracket.',
                style: const TextStyle(
                    color: AppTheme.primary, fontSize: 11, height: 1.3),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Option 2: Single Elimination
          _buildFormatOptionTile(
            title: 'Single Elimination (Direct Knockout)',
            subtitle:
                'Traditional elimination bracket. Pag natalo sa laban, eliminated agad.',
            icon: Icons.account_tree_outlined,
            isSelected: !isQualifying,
            onTap: () => setState(
                () => _format = AppConstants.formatSingleElimination),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.1)
              : AppTheme.card.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.2)
                    : AppTheme.cardBorder.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontSize: 13.5,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Radio<bool>(
              value: true,
              groupValue: isSelected,
              activeColor: AppTheme.primary,
              onChanged: (_) => onTap(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      );
}

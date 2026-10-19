import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../models/reservation_model.dart';
import '../../widgets/countdown_timer_widget.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/qr_downloader.dart';
import '../../core/utils/qr_image_decoder.dart';
import '../../widgets/reschedule_dialog.dart';
import '../admin/admin_qr_scanner_screen.dart';

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  int _adminScope = 0; // 0 = All Player Bookings, 1 = My Own Bookings
  int _categoryFilter = 0; // 0 = All, 1 = Today, 2 = Yesterday, 3 = Upcoming, 4 = Past
  DateTime? _calendarFilterDay;
  bool _showCalendar = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final uid = auth.currentUser?.uid;
      if (uid != null) {
        context.read<ReservationProvider>().loadUserReservations(uid);
      }
      if (auth.isAdmin) {
        context.read<ReservationProvider>().loadAllReservations();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isToday(DateTime d) => DateHelpers.isSameDay(d, DateTime.now());
  bool _isYesterday(DateTime d) =>
      DateHelpers.isSameDay(d, DateTime.now().subtract(const Duration(days: 1)));

  DateTime _parseResDate(ReservationModel r) {
    try {
      return DateTime.parse(r.date);
    } catch (_) {
      return r.startTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final isAdmin = auth.isAdmin;
    final resProvider = context.watch<ReservationProvider>();

    final List<ReservationModel> rawList;
    if (isAdmin && _adminScope == 0) {
      rawList = resProvider.allReservations;
    } else {
      rawList = user != null
          ? resProvider.userReservations
              .where((r) =>
                  r.userId == user.uid ||
                  (user.name.isNotEmpty &&
                      r.userName.toLowerCase() == user.name.toLowerCase()))
              .toList()
          : <ReservationModel>[];
    }

    // 1. Search filter
    final searchedList = rawList.where((r) {
      if (_searchQuery.isEmpty) return true;
      final name = r.userName.toLowerCase();
      final court = r.courtName.toLowerCase();
      final date = r.date.toLowerCase();
      final ref = r.paymentReference.toLowerCase();
      return name.contains(_searchQuery) ||
          court.contains(_searchQuery) ||
          date.contains(_searchQuery) ||
          ref.contains(_searchQuery);
    }).toList();

    // 2. Calendar specific day filter (if active)
    final calendarFilteredList = searchedList.where((r) {
      if (_calendarFilterDay == null) return true;
      final rDate = _parseResDate(r);
      return DateHelpers.isSameDay(rDate, _calendarFilterDay!);
    }).toList();

    // Categorize without dropping any booking
    final todayItems =
        calendarFilteredList.where((r) => _isToday(_parseResDate(r))).toList();
    final yesterdayItems = calendarFilteredList
        .where((r) =>
            !todayItems.contains(r) && _isYesterday(_parseResDate(r)))
        .toList();
    final upcomingItems = calendarFilteredList
        .where((r) =>
            !todayItems.contains(r) &&
            !yesterdayItems.contains(r) &&
            (r.isUpcoming ||
                r.isActive ||
                _parseResDate(r).isAfter(DateTime.now())))
        .toList();
    final pastItems = calendarFilteredList
        .where((r) =>
            !todayItems.contains(r) &&
            !yesterdayItems.contains(r) &&
            !upcomingItems.contains(r))
        .toList();

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAdmin ? 'LPC Court Bookings' : 'My LPC Bookings',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          isAdmin
                              ? 'Lifestyle Pickleball Court • All Player Bookings'
                              : 'Lifestyle Pickleball Court • Your Court Sessions',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary, width: 1.2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.file_upload_outlined, size: 16),
                          label: const Text(
                            'Upload QR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: () => _uploadAndVerifyQr(context),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: AppTheme.background,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.camera_alt_rounded, size: 16),
                          label: const Text(
                            'Scan QR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminQrScannerScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // ── Admin Scope Selector (All vs My Own) ─────────────────────
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    _buildScopeChip('All Player Bookings', 0),
                    const SizedBox(width: 8),
                    _buildScopeChip('My Own Bookings', 1),
                  ],
                ),
              ),

            // ── Search Bar & Calendar Toggle ────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search player, court, or ref...',
                          hintStyle: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 20, color: AppTheme.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18, color: AppTheme.textMuted),
                                  onPressed: () => _searchCtrl.clear(),
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Calendar Toggle Button
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showCalendar = !_showCalendar),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _calendarFilterDay != null || _showCalendar
                            ? AppTheme.primary
                            : AppTheme.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _calendarFilterDay != null || _showCalendar
                              ? AppTheme.primary
                              : AppTheme.cardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 18,
                            color: _calendarFilterDay != null || _showCalendar
                                ? Colors.black
                                : AppTheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _calendarFilterDay != null
                                ? DateHelpers.toMonthDay(_calendarFilterDay!)
                                : 'Date',
                            style: TextStyle(
                              color: _calendarFilterDay != null || _showCalendar
                                  ? Colors.black
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Expandable Calendar Picker ──────────────────────────────
            if (_showCalendar)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: _buildCalendarWidget(),
              ),

            // ── Active Date Filter Clear Chip ───────────────────────────
            if (_calendarFilterDay != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Date: ${DateHelpers.toShortDate(_calendarFilterDay!)}',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _calendarFilterDay = null),
                            child: const Icon(Icons.close_rounded,
                                size: 14, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ── Categories Horizontal Filter Bar ────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildCategoryChip('All (${calendarFilteredList.length})', 0),
                    const SizedBox(width: 8),
                    _buildCategoryChip('Today (${todayItems.length})', 1,
                        highlightColor: AppTheme.statusAvailable),
                    const SizedBox(width: 8),
                    _buildCategoryChip('Yesterday (${yesterdayItems.length})', 2,
                        highlightColor: AppTheme.statusReserved),
                    const SizedBox(width: 8),
                    _buildCategoryChip('Upcoming (${upcomingItems.length})', 3),
                    const SizedBox(width: 8),
                    _buildCategoryChip('Past (${pastItems.length})', 4),
                  ],
                ),
              ),
            ),

            // ── Categorized Bookings List ────────────────────────────────
            Expanded(
              child: calendarFilteredList.isEmpty
                  ? _buildEmpty(isAdmin)
                  : _buildCategorizedListView(
                      today: todayItems,
                      yesterday: yesterdayItems,
                      upcoming: upcomingItems,
                      past: pastItems,
                      allFiltered: calendarFilteredList,
                      isAdmin: isAdmin,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeChip(String label, int index) {
    final selected = _adminScope == index;
    return GestureDetector(
      onTap: () => setState(() => _adminScope = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, int index, {Color? highlightColor}) {
    final selected = _categoryFilter == index;
    final color = highlightColor ?? AppTheme.primary;

    return GestureDetector(
      onTap: () => setState(() => _categoryFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color
              : (highlightColor != null
                  ? highlightColor.withOpacity(0.08)
                  : AppTheme.card),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? color
                : (highlightColor != null
                    ? highlightColor.withOpacity(0.3)
                    : AppTheme.cardBorder),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (highlightColor ?? AppTheme.textSecondary),
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarWidget() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 30)),
        lastDay: DateTime.now().add(const Duration(days: 90)),
        focusedDay: _calendarFilterDay ?? DateTime.now(),
        currentDay: DateTime.now(),
        calendarFormat: CalendarFormat.month,
        selectedDayPredicate: (d) =>
            _calendarFilterDay != null &&
            DateHelpers.isSameDay(d, _calendarFilterDay!),
        onDaySelected: (day, _) {
          setState(() {
            _calendarFilterDay = day;
            _showCalendar = false;
          });
        },
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle:
              TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          leftChevronIcon:
              Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary),
          rightChevronIcon:
              Icon(Icons.chevron_right_rounded, color: AppTheme.textPrimary),
        ),
        calendarStyle: const CalendarStyle(
          selectedDecoration: BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle:
              TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          todayDecoration: BoxDecoration(
            color: Color(0x2522C55E),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
              color: AppTheme.primary, fontWeight: FontWeight.w700),
          defaultTextStyle: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          weekendTextStyle:
              TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildCategorizedListView({
    required List<ReservationModel> today,
    required List<ReservationModel> yesterday,
    required List<ReservationModel> upcoming,
    required List<ReservationModel> past,
    required List<ReservationModel> allFiltered,
    required bool isAdmin,
  }) {
    // If a specific category tab is selected (not "All"):
    if (_categoryFilter == 1) {
      return _buildSingleGroupList(
          title: "Today's Bookings (Ngayong Araw)",
          items: today,
          isAdmin: isAdmin,
          emptyMsg: "No bookings found for Today.");
    }
    if (_categoryFilter == 2) {
      return _buildSingleGroupList(
          title: "Yesterday's Bookings (Kahapon)",
          items: yesterday,
          isAdmin: isAdmin,
          emptyMsg: "No bookings found for Yesterday.");
    }
    if (_categoryFilter == 3) {
      return _buildSingleGroupList(
          title: "Upcoming Sessions",
          items: upcoming,
          isAdmin: isAdmin,
          emptyMsg: "No upcoming bookings found.");
    }
    if (_categoryFilter == 4) {
      return _buildSingleGroupList(
          title: "Past Sessions",
          items: past,
          isAdmin: isAdmin,
          emptyMsg: "No past bookings found.");
    }

    // Default: "All" view with clear category headers
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // ── Today ──
        if (today.isNotEmpty) ...[
          _sectionHeader("⚡ TODAY'S BOOKINGS (Ngayong Araw)",
              count: today.length, color: AppTheme.statusAvailable),
          const SizedBox(height: 10),
          ...today.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReservationCard(
                    reservation: e.value,
                    index: e.key,
                    isAdmin: isAdmin,
                    dateTag: 'TODAY',
                    tagColor: AppTheme.statusAvailable,
                  ),
                ),
              ),
          const SizedBox(height: 8),
        ],

        // ── Yesterday ──
        if (yesterday.isNotEmpty) ...[
          _sectionHeader("⏱️ YESTERDAY'S BOOKINGS (Kahapon)",
              count: yesterday.length, color: AppTheme.statusReserved),
          const SizedBox(height: 10),
          ...yesterday.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReservationCard(
                    reservation: e.value,
                    index: e.key,
                    isAdmin: isAdmin,
                    isPast: true,
                    dateTag: 'YESTERDAY',
                    tagColor: AppTheme.statusReserved,
                  ),
                ),
              ),
          const SizedBox(height: 8),
        ],

        // ── Upcoming ──
        if (upcoming.isNotEmpty) ...[
          _sectionHeader("📅 UPCOMING SESSIONS",
              count: upcoming.length, color: AppTheme.accent),
          const SizedBox(height: 10),
          ...upcoming.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReservationCard(
                    reservation: e.value,
                    index: e.key,
                    isAdmin: isAdmin,
                    dateTag: 'UPCOMING',
                    tagColor: AppTheme.accent,
                  ),
                ),
              ),
          const SizedBox(height: 8),
        ],

        // ── Past ──
        if (past.isNotEmpty) ...[
          _sectionHeader("📜 PAST SESSIONS",
              count: past.length, color: AppTheme.textMuted),
          const SizedBox(height: 10),
          ...past.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReservationCard(
                    reservation: e.value,
                    index: e.key,
                    isPast: true,
                    isAdmin: isAdmin,
                    dateTag: 'PAST',
                    tagColor: AppTheme.textMuted,
                  ),
                ),
              ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSingleGroupList({
    required String title,
    required List<ReservationModel> items,
    required bool isAdmin,
    required String emptyMsg,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48, color: AppTheme.textMuted.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              emptyMsg,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        _sectionHeader(title, count: items.length),
        const SizedBox(height: 10),
        ...items.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReservationCard(
                  reservation: e.value,
                  index: e.key,
                  isAdmin: isAdmin,
                  isPast: _categoryFilter == 2 || _categoryFilter == 4,
                ),
              ),
            ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionHeader(String title, {int? count, Color? color}) {
    final displayColor = color ?? AppTheme.textSecondary;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: displayColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: displayColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: displayColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmpty(bool isAdmin) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 60,
            color: AppTheme.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No matching bookings found'
                : (isAdmin ? 'No bookings found' : 'No bookings yet'),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try searching with another player name or court'
                : (isAdmin
                    ? 'Reservations made by players will appear here'
                    : 'Book a court to get started'),
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final ReservationModel reservation;
  final int index;
  final bool isPast;
  final bool isAdmin;
  final String? dateTag;
  final Color? tagColor;

  const _ReservationCard({
    required this.reservation,
    required this.index,
    this.isPast = false,
    this.isAdmin = false,
    this.dateTag,
    this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(reservation.status);
    final resDate = DateTime.tryParse(reservation.date) ?? reservation.startTime;

    String smartDateTag = dateTag ?? '';
    Color smartTagColor = tagColor ?? statusColor;

    if (smartDateTag.isEmpty) {
      if (DateHelpers.isToday(resDate)) {
        smartDateTag = 'TODAY';
        smartTagColor = AppTheme.statusAvailable;
      } else if (DateHelpers.isSameDay(
          resDate, DateTime.now().subtract(const Duration(days: 1)))) {
        smartDateTag = 'YESTERDAY';
        smartTagColor = AppTheme.statusReserved;
      } else if (DateHelpers.isSameDay(
          resDate, DateTime.now().add(const Duration(days: 1)))) {
        smartDateTag = 'TOMORROW';
        smartTagColor = AppTheme.accent;
      }
    }

    return GestureDetector(
      onTap: () => _showQrDialog(context, reservation),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top accent bar
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Court icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.sports_tennis_rounded,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    reservation.courtName,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (smartDateTag.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: smartTagColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color:
                                              smartTagColor.withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      smartDateTag,
                                      style: TextStyle(
                                        color: smartTagColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            // Player Name (Prominently displayed)
                            Row(
                              children: [
                                const Icon(Icons.person_rounded,
                                    size: 13, color: AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  reservation.userName.isNotEmpty
                                      ? reservation.userName
                                      : 'Player',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${DateHelpers.toShortDate(resDate)} • ${DateHelpers.toTimeRange(reservation.startTime, reservation.endTime)}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (reservation.amount > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                '₱${reservation.amount.toStringAsFixed(2)} • ${reservation.paymentMethod == 'paymongo' ? 'PayMongo (QR Ph)' : 'Paid'}',
                                style: TextStyle(
                                  color: AppTheme.primary.withOpacity(0.85),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Status + countdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _StatusPill(
                              status: reservation.status, color: statusColor),
                          if (reservation.isActive &&
                              reservation.endTime.isAfter(DateTime.now())) ...[
                            const SizedBox(height: 6),
                            InlineCountdown(endTime: reservation.endTime),
                          ],
                        ],
                      ),
                    ],
                  ),

                  // ── Action Buttons Footer ─────────────────────────────────
                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.cardBorder, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Click to scan QR Button (Opens Camera for Admin, Opens Pass for Player)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary.withOpacity(0.15),
                            foregroundColor: AppTheme.primary,
                            elevation: 0,
                            side: const BorderSide(
                                color: AppTheme.primary, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: Icon(
                            isAdmin
                                ? Icons.camera_alt_rounded
                                : Icons.qr_code_rounded,
                            size: 18,
                          ),
                          label: Text(
                            isAdmin
                                ? 'CLICK TO SCAN QR (CAMERA)'
                                : 'VIEW CHECK-IN QR PASS',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          onPressed: () {
                            if (isAdmin) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AdminQrScannerScreen(),
                                ),
                              );
                            } else {
                              _showQrDialog(context, reservation);
                            }
                          },
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.file_upload_outlined,
                              color: AppTheme.primary, size: 22),
                          tooltip: 'Upload QR Image to Check-In',
                          onPressed: () => _uploadAndVerifyQr(context),
                        ),
                        IconButton(
                          icon: const Icon(Icons.qr_code_2_rounded,
                              color: AppTheme.primary, size: 22),
                          tooltip: 'Preview QR Pass',
                          onPressed: () => _showQrDialog(context, reservation),
                        ),
                      ],
                      if (!isPast && reservation.isUpcoming) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => RescheduleDialog.show(context, reservation),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppTheme.primary.withOpacity(0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_calendar_rounded,
                                    color: AppTheme.primary, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Reschedule',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _confirmCancel(context, reservation),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.statusInUse.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppTheme.statusInUse.withOpacity(0.25)),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppTheme.statusInUse,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: index * 50), duration: 350.ms)
        .slideY(
            begin: 0.05,
            end: 0,
            delay: Duration(milliseconds: index * 50),
            duration: 350.ms);
  }

  void _showQrDialog(BuildContext context, ReservationModel reservation) {
    final qrData = 'pickleball_reservation:${reservation.id}';
    final qrUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=400x400&color=16a34a&bgcolor=ffffff&data=$qrData';

    showDialog(
      context: context,
      builder: (ctx) {
        bool isDownloading = false;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.cardBorder),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded,
                        color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PLAYER CHECK-IN QR PASS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: AppTheme.primary,
                          ),
                        ),
                        Text(
                          reservation.courtName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Player Info Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Booked By:',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12)),
                              Text(
                                reservation.userName.isNotEmpty
                                    ? reservation.userName
                                    : 'Player',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Date & Time:',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12)),
                              Text(
                                '${DateHelpers.toShortDate(DateTime.parse(reservation.date))} ${DateHelpers.toTimeRange(reservation.startTime, reservation.endTime)}',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (reservation.paymentReference.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Payment Ref:',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11)),
                                Text(
                                  reservation.paymentReference,
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // QR Code Frame
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.12),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          qrUrl,
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 200,
                              height: 200,
                              color: Colors.white,
                              child: const Center(
                                child: CircularProgressIndicator(
                                    color: AppTheme.primary),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Present or scan this QR pass upon arrival on your scheduled date and time to verify payment and complete player check-in.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Download Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: isDownloading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.background,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 20),
                        label: Text(
                          isDownloading
                              ? 'Downloading...'
                              : 'Download Check-In QR Pass',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: isDownloading
                            ? null
                            : () async {
                                setDialogState(() => isDownloading = true);
                                final success =
                                    await QrDownloader.downloadQrImage(
                                  qrUrl: qrUrl,
                                  fileName:
                                      'court_checkin_qr_${reservation.id}.png',
                                );
                                setDialogState(() => isDownloading = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'QR Code downloaded successfully!'
                                            : 'Failed to download QR code.',
                                      ),
                                      backgroundColor: success
                                          ? AppTheme.statusAvailable
                                          : AppTheme.statusInUse,
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmCancel(BuildContext context, ReservationModel reservation) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel or Reschedule?'),
        content: Text(
            'Instead of cancelling your booking at ${reservation.courtName} on ${DateHelpers.toShortDate(reservation.startTime)}, would you like to reschedule to another date or time at no extra charge?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context
                  .read<ReservationProvider>()
                  .cancelReservation(reservation);
            },
            child: const Text('Cancel Booking',
                style: TextStyle(color: AppTheme.statusInUse)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.background,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              RescheduleDialog.show(context, reservation);
            },
            label: const Text('Reschedule Booking'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.statusAvailable;
      case 'confirmed':
        return AppTheme.primary;
      case 'pending':
        return AppTheme.statusReserved;
      case 'cancelled':
        return AppTheme.statusInUse;
      case 'completed':
        return AppTheme.textMuted;
      default:
        return AppTheme.textMuted;
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusPill({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

Future<void> _uploadAndVerifyQr(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await QrImageDecoder.pickAndDecode();
  if (result.userCanceled) return;

  if (result.isSuccess) {
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdminQrScannerScreen(initialQrData: result.data),
        ),
      );
    }
  } else {
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.error ?? 'No valid QR code found in selected image.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.statusInUse,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}


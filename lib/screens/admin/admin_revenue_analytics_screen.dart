import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/reservation_model.dart';
import '../../providers/reservation_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import 'admin_walk_in_dialog.dart';

enum ReportPeriod { daily, weekly, monthly, allTime }

class AdminRevenueAnalyticsScreen extends StatefulWidget {
  const AdminRevenueAnalyticsScreen({super.key});

  @override
  State<AdminRevenueAnalyticsScreen> createState() =>
      _AdminRevenueAnalyticsScreenState();
}

class _AdminRevenueAnalyticsScreenState
    extends State<AdminRevenueAnalyticsScreen> {
  ReportPeriod _selectedPeriod = ReportPeriod.weekly;
  DateTime _referenceDate = DateTime.now();
  String _paymentFilter = 'all'; // 'all', 'cash', 'gcash', 'paymongo', 'maya'
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReservationProvider>().loadAllReservations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Filtering Logic ────────────────────────────────────────────────────────
  List<ReservationModel> _filterReservations(List<ReservationModel> all) {
    // Only include confirmed, active, or completed bookings (exclude cancelled)
    final valid = all.where((r) => r.status != 'cancelled').toList();

    return valid.where((r) {
      final resDate = r.startTime;

      // Period matching
      bool matchesPeriod = false;
      switch (_selectedPeriod) {
        case ReportPeriod.daily:
          matchesPeriod = resDate.year == _referenceDate.year &&
              resDate.month == _referenceDate.month &&
              resDate.day == _referenceDate.day;
          break;
        case ReportPeriod.weekly:
          // Find start of week (Monday)
          final startOfWeek = _referenceDate
              .subtract(Duration(days: _referenceDate.weekday - 1));
          final monday = DateTime(
              startOfWeek.year, startOfWeek.month, startOfWeek.day, 0, 0, 0);
          final sunday = monday.add(const Duration(days: 7));
          matchesPeriod =
              resDate.isAfter(monday.subtract(const Duration(seconds: 1))) &&
                  resDate.isBefore(sunday);
          break;
        case ReportPeriod.monthly:
          matchesPeriod = resDate.year == _referenceDate.year &&
              resDate.month == _referenceDate.month;
          break;
        case ReportPeriod.allTime:
          matchesPeriod = true;
          break;
      }

      if (!matchesPeriod) return false;

      // Payment method matching
      if (_paymentFilter != 'all') {
        final pm = r.paymentMethod.toLowerCase();
        if (_paymentFilter == 'cash' &&
            !(pm == 'cash' || pm.contains('cash'))) {
          return false;
        }
        if (_paymentFilter == 'gcash' && !pm.contains('gcash')) {
          return false;
        }
        if (_paymentFilter == 'maya' && !pm.contains('maya')) {
          return false;
        }
        if (_paymentFilter == 'paymongo' && !pm.contains('paymongo')) {
          return false;
        }
      }

      // Search query matching
      final q = _searchController.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final matchUser = r.userName.toLowerCase().contains(q);
        final matchCourt = r.courtName.toLowerCase().contains(q);
        final matchRef = r.paymentReference.toLowerCase().contains(q);
        if (!matchUser && !matchCourt && !matchRef) return false;
      }

      return true;
    }).toList();
  }

  // ─── Period Navigation ──────────────────────────────────────────────────────
  void _prevPeriod() {
    setState(() {
      switch (_selectedPeriod) {
        case ReportPeriod.daily:
          _referenceDate = _referenceDate.subtract(const Duration(days: 1));
          break;
        case ReportPeriod.weekly:
          _referenceDate = _referenceDate.subtract(const Duration(days: 7));
          break;
        case ReportPeriod.monthly:
          _referenceDate = DateTime(
              _referenceDate.year, _referenceDate.month - 1, _referenceDate.day);
          break;
        case ReportPeriod.allTime:
          break;
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      switch (_selectedPeriod) {
        case ReportPeriod.daily:
          _referenceDate = _referenceDate.add(const Duration(days: 1));
          break;
        case ReportPeriod.weekly:
          _referenceDate = _referenceDate.add(const Duration(days: 7));
          break;
        case ReportPeriod.monthly:
          _referenceDate = DateTime(
              _referenceDate.year, _referenceDate.month + 1, _referenceDate.day);
          break;
        case ReportPeriod.allTime:
          break;
      }
    });
  }

  String get _periodLabel {
    switch (_selectedPeriod) {
      case ReportPeriod.daily:
        final isToday = _referenceDate.year == DateTime.now().year &&
            _referenceDate.month == DateTime.now().month &&
            _referenceDate.day == DateTime.now().day;
        return isToday
            ? 'Today (${DateFormat('MMM d, yyyy').format(_referenceDate)})'
            : DateFormat('EEEE, MMM d, yyyy').format(_referenceDate);
      case ReportPeriod.weekly:
        final startOfWeek =
            _referenceDate.subtract(Duration(days: _referenceDate.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '${DateFormat('MMM d').format(startOfWeek)} – ${DateFormat('MMM d, yyyy').format(endOfWeek)}';
      case ReportPeriod.monthly:
        return DateFormat('MMMM yyyy').format(_referenceDate);
      case ReportPeriod.allTime:
        return 'All Recorded History';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allReservations =
        context.watch<ReservationProvider>().allReservations;
    final filtered = _filterReservations(allReservations);

    // Compute key statistics
    final totalRevenue = filtered.fold<double>(0.0, (sum, r) => sum + r.amount);
    final totalBookings = filtered.length;
    final walkInRevenue = filtered
        .where((r) =>
            r.paymentMethod == 'cash' ||
            r.paymentMethod.contains('walk_in') ||
            r.userId.startsWith('walk_in'))
        .fold<double>(0.0, (sum, r) => sum + r.amount);
    final digitalRevenue = (totalRevenue - walkInRevenue).clamp(0.0, double.infinity);
    final avgRevenue =
        totalBookings > 0 ? (totalRevenue / totalBookings) : 0.0;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.background,
        icon: const Icon(Icons.point_of_sale_rounded),
        label: const Text(
          '+ Walk-In Payment',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        onPressed: () => AdminWalkInDialog.show(context),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────────────────────
              SliverAppBar(
                backgroundColor: Colors.transparent,
                pinned: true,
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
                title: const Text('Revenue & Financial Reports'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.point_of_sale_rounded,
                        color: AppTheme.primary),
                    tooltip: 'New Walk-In Payment',
                    onPressed: () => AdminWalkInDialog.show(context),
                  ),
                ],
              ),

              // ── Period Selector Tabs ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: _buildPeriodSelector(),
                ),
              ),

              // ── Date Stepper Banner ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildDateStepper(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── KPI Summary Cards ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSummaryCards(
                    totalRevenue: totalRevenue,
                    totalBookings: totalBookings,
                    walkInRevenue: walkInRevenue,
                    digitalRevenue: digitalRevenue,
                    avgRevenue: avgRevenue,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Bar Chart Breakdown (Weekly / Daily) ─────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildChartSection(filtered),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Payment Methods & Court Distribution ─────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildPaymentMethodBreakdown(filtered, totalRevenue)),
                      const SizedBox(width: 14),
                      Expanded(child: _buildCourtRevenueBreakdown(filtered, totalRevenue)),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── Transaction Ledger Section Header & Filters ──────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Financial Transactions',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${filtered.length} entries',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSearchAndFilters(),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Transactions List ────────────────────────────────────────
              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.receipt_long_rounded,
                            size: 48, color: AppTheme.textMuted),
                        SizedBox(height: 12),
                        Text(
                          'No payment transactions found',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Change date period or record a walk-in payment.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final res = filtered[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TransactionCard(
                            reservation: res,
                            onTap: () => _showReceiptDetails(context, res),
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Period Selector (Pills) ────────────────────────────────────────────────
  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          _periodButton('Daily', ReportPeriod.daily, Icons.calendar_view_day_rounded),
          _periodButton('Weekly', ReportPeriod.weekly, Icons.calendar_view_week_rounded),
          _periodButton('Monthly', ReportPeriod.monthly, Icons.calendar_view_month_rounded),
          _periodButton('All Time', ReportPeriod.allTime, Icons.all_inclusive_rounded),
        ],
      ),
    );
  }

  Widget _periodButton(String label, ReportPeriod period, IconData icon) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = period),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? AppTheme.background : AppTheme.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.background : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Date Stepper ───────────────────────────────────────────────────────────
  Widget _buildDateStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF162330),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary),
            onPressed: _selectedPeriod == ReportPeriod.allTime ? null : _prevPeriod,
            visualDensity: VisualDensity.compact,
          ),
          Row(
            children: [
              const Icon(Icons.event_note_rounded, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                _periodLabel,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.textPrimary),
            onPressed: _selectedPeriod == ReportPeriod.allTime ? null : _nextPeriod,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ─── Summary Cards ──────────────────────────────────────────────────────────
  Widget _buildSummaryCards({
    required double totalRevenue,
    required int totalBookings,
    required double walkInRevenue,
    required double digitalRevenue,
    required double avgRevenue,
  }) {
    return Column(
      children: [
        // Top Main Card (Total Revenue Hero)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F3A2E), Color(0xFF132533)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Color(0xFF10B981), size: 32),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL REVENUE COLLECTED',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱ ${NumberFormat('#,##0.00').format(totalRevenue)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Across $totalBookings paid court sessions',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 3 Sub-Metric Cards
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                icon: Icons.storefront_rounded,
                label: 'Walk-In / Cash',
                value: '₱${NumberFormat('#,##0').format(walkInRevenue)}',
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.qr_code_2_rounded,
                label: 'Online / Digital',
                value: '₱${NumberFormat('#,##0').format(digitalRevenue)}',
                color: const Color(0xFF007DFE),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.analytics_rounded,
                label: 'Avg / Booking',
                value: '₱${NumberFormat('#,##0').format(avgRevenue)}',
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Bar Chart Section ──────────────────────────────────────────────────────
  Widget _buildChartSection(List<ReservationModel> items) {
    if (_selectedPeriod == ReportPeriod.weekly) {
      return _buildWeeklyBarChart(items);
    } else if (_selectedPeriod == ReportPeriod.monthly) {
      return _buildMonthlyWeeksChart(items);
    } else {
      return _buildDailyHourlyChart(items);
    }
  }

  Widget _buildWeeklyBarChart(List<ReservationModel> items) {
    // 7 Days: Mon(1) to Sun(7)
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dailyTotals = List<double>.filled(7, 0.0);

    for (final r in items) {
      final weekdayIndex = r.startTime.weekday - 1; // 0 to 6
      if (weekdayIndex >= 0 && weekdayIndex < 7) {
        dailyTotals[weekdayIndex] += r.amount;
      }
    }

    final maxVal = dailyTotals.reduce((a, b) => a > b ? a : b);
    final highestDayIndex = dailyTotals.indexOf(maxVal);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Revenue Trend (Mon – Sun)',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (maxVal > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Peak: ${days[highestDayIndex]} (₱${maxVal.toStringAsFixed(0)})',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final amount = dailyTotals[i];
                final frac = maxVal > 0 ? (amount / maxVal) : 0.0;
                final isPeak = i == highestDayIndex && maxVal > 0;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (amount > 0)
                      Text(
                        '₱${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: isPeak ? const Color(0xFF10B981) : AppTheme.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 24,
                      height: (frac * 90).clamp(4.0, 90.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPeak
                              ? [const Color(0xFF10B981), const Color(0xFF34D399)]
                              : [AppTheme.primary.withOpacity(0.6), AppTheme.primary],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      days[i],
                      style: TextStyle(
                        color: isPeak ? Colors.white : AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: isPeak ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyWeeksChart(List<ReservationModel> items) {
    // 4 Weeks breakdown
    final weekTotals = [0.0, 0.0, 0.0, 0.0];
    for (final r in items) {
      final day = r.startTime.day;
      final weekIndex = ((day - 1) ~/ 7).clamp(0, 3);
      weekTotals[weekIndex] += r.amount;
    }
    final maxVal = weekTotals.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Revenue (Weekly Buckets)',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Column(
            children: List.generate(4, (i) {
              final amount = weekTotals[i];
              final frac = maxVal > 0 ? (amount / maxVal) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        'Week ${i + 1}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppTheme.cardBorder.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: frac.clamp(0.02, 1.0),
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 80,
                      child: Text(
                        '₱ ${NumberFormat('#,##0').format(amount)}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyHourlyChart(List<ReservationModel> items) {
    final morning = items.where((r) => r.startTime.hour < 12).fold<double>(0.0, (s, r) => s + r.amount);
    final afternoon = items.where((r) => r.startTime.hour >= 12 && r.startTime.hour < 17).fold<double>(0.0, (s, r) => s + r.amount);
    final evening = items.where((r) => r.startTime.hour >= 17).fold<double>(0.0, (s, r) => s + r.amount);
    final maxVal = [morning, afternoon, evening].reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Time-of-Day Distribution (Today)',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _timeBucketRow('Morning (7 AM – 12 PM)', morning, maxVal, const Color(0xFFF59E0B)),
          const SizedBox(height: 10),
          _timeBucketRow('Afternoon (12 PM – 5 PM)', afternoon, maxVal, const Color(0xFF3B82F6)),
          const SizedBox(height: 10),
          _timeBucketRow('Evening (5 PM – Midnight)', evening, maxVal, const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _timeBucketRow(String label, double amount, double maxVal, Color color) {
    final frac = maxVal > 0 ? (amount / maxVal) : 0.0;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ),
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: frac.clamp(0.02, 1.0),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 70,
          child: Text(
            '₱ ${amount.toStringAsFixed(0)}',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  // ─── Payment Methods Breakdown Card ─────────────────────────────────────────
  Widget _buildPaymentMethodBreakdown(List<ReservationModel> items, double total) {
    double cash = 0, gcash = 0, maya = 0, paymongo = 0;
    for (final r in items) {
      final pm = r.paymentMethod.toLowerCase();
      if (pm == 'cash' || pm.contains('cash') || r.userId.startsWith('walk_in')) {
        cash += r.amount;
      } else if (pm.contains('gcash')) {
        gcash += r.amount;
      } else if (pm.contains('maya')) {
        maya += r.amount;
      } else if (pm.contains('paymongo')) {
        paymongo += r.amount;
      } else {
        cash += r.amount;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Methods',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _methodProgressRow('Cash (Walk-In)', cash, total, const Color(0xFF10B981)),
          const SizedBox(height: 8),
          _methodProgressRow('GCash (QR)', gcash, total, const Color(0xFF007DFE)),
          const SizedBox(height: 8),
          _methodProgressRow('Maya / Card', maya, total, const Color(0xFF7C3AED)),
          const SizedBox(height: 8),
          _methodProgressRow('PayMongo', paymongo, total, AppTheme.primary),
        ],
      ),
    );
  }

  Widget _methodProgressRow(String label, double amount, double total, Color color) {
    final pct = total > 0 ? (amount / total * 100) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            Text(
              '₱${amount.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}%)',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? (amount / total) : 0.0,
            backgroundColor: AppTheme.cardBorder.withOpacity(0.4),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  // ─── Court Revenue Breakdown Card ───────────────────────────────────────────
  Widget _buildCourtRevenueBreakdown(List<ReservationModel> items, double total) {
    final Map<String, double> courtMap = {};
    for (final r in items) {
      courtMap[r.courtName] = (courtMap[r.courtName] ?? 0.0) + r.amount;
    }
    final sortedCourts = courtMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Court Earnings',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (sortedCourts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No court data',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ),
            )
          else
            ...sortedCourts.take(4).map((entry) {
              final pct = total > 0 ? (entry.value / total * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        Text('₱${entry.value.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}%)',
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total > 0 ? (entry.value / total) : 0.0,
                        backgroundColor: AppTheme.cardBorder.withOpacity(0.4),
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── Search & Filters ───────────────────────────────────────────────────────
  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search player, court, or ref number...',
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.textSecondary),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            filled: true,
            fillColor: AppTheme.card,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.cardBorder),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('All Methods', 'all'),
              const SizedBox(width: 6),
              _filterChip('💵 Cash (Walk-In)', 'cash'),
              const SizedBox(width: 6),
              _filterChip('📱 GCash', 'gcash'),
              const SizedBox(width: 6),
              _filterChip('💳 Maya', 'maya'),
              const SizedBox(width: 6),
              _filterChip('⚡ PayMongo', 'paymongo'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _paymentFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.background : AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showReceiptDetails(BuildContext context, ReservationModel res) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF131E29),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transaction Receipt',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Ref: ${res.paymentReference.isNotEmpty ? res.paymentReference : res.id}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: AppTheme.cardBorder, height: 24),
            _receiptLine('Player / Customer', res.userName),
            _receiptLine('Court Assigned', res.courtName),
            _receiptLine('Booking Schedule', DateHelpers.toTimeRange(res.startTime, res.endTime)),
            _receiptLine('Booking Date', DateHelpers.toDisplayDate(res.startTime)),
            _receiptLine('Payment Method', res.paymentMethod.toUpperCase().replaceAll('_', ' ')),
            _receiptLine('Status', res.status.toUpperCase(), valueColor: const Color(0xFF10B981)),
            const Divider(color: AppTheme.cardBorder, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount Paid:', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                Text(
                  '₱ ${NumberFormat('#,##0.00').format(res.amount)}',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.card),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptLine(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Single Transaction Card ──────────────────────────────────────────────────
class _TransactionCard extends StatelessWidget {
  final ReservationModel reservation;
  final VoidCallback onTap;

  const _TransactionCard({required this.reservation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isWalkIn = reservation.paymentMethod == 'cash' ||
        reservation.paymentMethod.contains('walk_in') ||
        reservation.userId.startsWith('walk_in');

    final (pmColor, pmLabel, pmIcon) = _getPaymentMethodMeta(reservation.paymentMethod);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            // Payment method icon indicator
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: pmColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(pmIcon, color: pmColor, size: 20),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          reservation.userName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isWalkIn) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'WALK-IN',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${reservation.courtName} • ${DateHelpers.toTimeRange(reservation.startTime, reservation.endTime)}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                  if (reservation.paymentReference.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ref: ${reservation.paymentReference}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
            // Amount & Date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+ ₱${NumberFormat('#,##0.00').format(reservation.amount)}',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: pmColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: pmColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    pmLabel,
                    style: TextStyle(
                      color: pmColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (Color, String, IconData) _getPaymentMethodMeta(String pm) {
    final lower = pm.toLowerCase();
    if (lower == 'cash' || lower.contains('cash')) {
      return (const Color(0xFF10B981), 'CASH', Icons.payments_rounded);
    }
    if (lower.contains('gcash')) {
      return (const Color(0xFF007DFE), 'GCASH', Icons.qr_code_2_rounded);
    }
    if (lower.contains('maya')) {
      return (const Color(0xFF7C3AED), 'MAYA', Icons.credit_card_rounded);
    }
    if (lower.contains('paymongo')) {
      return (AppTheme.primary, 'PAYMONGO', Icons.bolt_rounded);
    }
    return (AppTheme.accent, 'ONLINE', Icons.account_balance_wallet_rounded);
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/court_model.dart';
import '../../models/reservation_model.dart';
import '../../providers/court_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../services/court_service.dart';
import '../../services/lcd_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/constants/app_constants.dart';

class AdminWalkInDialog extends StatefulWidget {
  final CourtModel? preselectedCourt;

  const AdminWalkInDialog({super.key, this.preselectedCourt});

  static Future<void> show(BuildContext context, {CourtModel? court}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminWalkInDialog(preselectedCourt: court),
    );
  }

  @override
  State<AdminWalkInDialog> createState() => _AdminWalkInDialogState();
}

class _AdminWalkInDialogState extends State<AdminWalkInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _customAmountController = TextEditingController();
  final _tenderedController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  CourtModel? _selectedCourt;
  DateTime _selectedDate = DateTime.now();
  int _startHour = DateTime.now().hour;
  int _durationHours = 1;
  String _paymentMethod = 'cash'; // 'cash', 'walk_in_gcash', 'walk_in_maya'
  bool _immediateCheckIn = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Default start hour to current or opening hour
    if (_startHour < AppConstants.openingHour) {
      _startHour = AppConstants.openingHour;
    } else if (_startHour >= AppConstants.closingHour - 1) {
      _startHour = AppConstants.closingHour - 1;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final courts = context.read<CourtProvider>().courts;
      if (widget.preselectedCourt != null) {
        setState(() => _selectedCourt = widget.preselectedCourt);
      } else if (courts.isNotEmpty) {
        setState(() => _selectedCourt = courts.first);
      }
      _updateCalculatedAmount();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _customAmountController.dispose();
    _tenderedController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateCalculatedAmount() {
    if (_selectedCourt != null) {
      final total = _selectedCourt!.pricePerHour * _durationHours;
      _customAmountController.text = total.toStringAsFixed(0);
    }
  }

  double get _totalAmount {
    return double.tryParse(_customAmountController.text) ??
        ((_selectedCourt?.pricePerHour ?? 250) * _durationHours);
  }

  double get _changeAmount {
    final tendered = double.tryParse(_tenderedController.text) ?? 0.0;
    final total = _totalAmount;
    return (tendered - total).clamp(0.0, 999999.0);
  }

  DateTime get _startTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startHour,
      0,
    );
  }

  DateTime get _endTime {
    return _startTime.add(Duration(hours: _durationHours));
  }

  @override
  Widget build(BuildContext context) {
    final courts = context.watch<CourtProvider>().courts;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        decoration: BoxDecoration(
          color: const Color(0xFF131E29),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.cardBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────────────
              _buildHeader(context),

              // ── Body Scrollable ─────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Details
                        _buildSectionTitle(Icons.person_rounded, 'Walk-In Player Info'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _nameController,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                                decoration: _inputDecoration(
                                  label: 'Player Full Name *',
                                  hint: 'e.g. Juan Dela Cruz',
                                  icon: Icons.badge_outlined,
                                ),
                                validator: (val) =>
                                    (val == null || val.trim().isEmpty) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                                decoration: _inputDecoration(
                                  label: 'Contact No. (Optional)',
                                  hint: '09xxxxxxxxx',
                                  icon: Icons.phone_android_rounded,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Court Selection & Date
                        _buildSectionTitle(Icons.sports_tennis_rounded, 'Court & Schedule'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<CourtModel>(
                                value: _selectedCourt,
                                dropdownColor: const Color(0xFF1B2A38),
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                decoration: _inputDecoration(
                                  label: 'Select Court',
                                  icon: Icons.stadium_rounded,
                                ),
                                items: courts.map((court) {
                                  return DropdownMenuItem<CourtModel>(
                                    value: court,
                                    child: Text('${court.name} (₱${court.pricePerHour.toStringAsFixed(0)}/hr)'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedCourt = val;
                                    _updateCalculatedAmount();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                                  decoration: BoxDecoration(
                                    color: AppTheme.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          DateHelpers.toShortDate(_selectedDate),
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Time Slot & Duration
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _startHour,
                                dropdownColor: const Color(0xFF1B2A38),
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                decoration: _inputDecoration(
                                  label: 'Start Time',
                                  icon: Icons.access_time_rounded,
                                ),
                                items: List.generate(
                                  AppConstants.closingHour - AppConstants.openingHour,
                                  (index) {
                                    final hour = AppConstants.openingHour + index;
                                    final dummy = DateTime(2026, 1, 1, hour, 0);
                                    return DropdownMenuItem<int>(
                                      value: hour,
                                      child: Text(DateHelpers.toTimeString(dummy)),
                                    );
                                  },
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _startHour = val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _durationHours,
                                dropdownColor: const Color(0xFF1B2A38),
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                decoration: _inputDecoration(
                                  label: 'Duration',
                                  icon: Icons.timelapse_rounded,
                                ),
                                items: const [
                                  DropdownMenuItem(value: 1, child: Text('1 Hour')),
                                  DropdownMenuItem(value: 2, child: Text('2 Hours')),
                                  DropdownMenuItem(value: 3, child: Text('3 Hours')),
                                  DropdownMenuItem(value: 4, child: Text('4 Hours')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _durationHours = val;
                                      _updateCalculatedAmount();
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),

                        // Schedule info summary tag
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Slot: ${DateHelpers.toTimeString(_startTime)} – ${DateHelpers.toTimeString(_endTime)} (${_durationHours}h)',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Payment Details
                        _buildSectionTitle(Icons.payments_rounded, 'Payment & Settlement'),
                        const SizedBox(height: 10),

                        // Payment Method Selector
                        Row(
                          children: [
                            _buildPaymentMethodOption(
                              label: 'Cash (Counter)',
                              icon: Icons.money_rounded,
                              value: 'cash',
                              color: const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 8),
                            _buildPaymentMethodOption(
                              label: 'GCash (QR)',
                              icon: Icons.qr_code_2_rounded,
                              value: 'walk_in_gcash',
                              color: const Color(0xFF007DFE),
                            ),
                            const SizedBox(width: 8),
                            _buildPaymentMethodOption(
                              label: 'Maya / POS',
                              icon: Icons.credit_card_rounded,
                              value: 'walk_in_maya',
                              color: const Color(0xFF7C3AED),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Total Price & Cash Tendered calculation
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Amount Due:',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: TextFormField(
                                      controller: _customAmountController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      decoration: const InputDecoration(
                                        prefixText: '₱ ',
                                        prefixStyle: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),

                              // If Cash: show Tendered and Change calculator
                              if (_paymentMethod == 'cash') ...[
                                const Divider(color: AppTheme.cardBorder, height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Cash Tendered:',
                                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: TextFormField(
                                        controller: _tenderedController,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        decoration: const InputDecoration(
                                          prefixText: '₱ ',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Quick tender chip buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _buildTenderChip('Exact', _totalAmount.toStringAsFixed(0)),
                                    const SizedBox(width: 6),
                                    _buildTenderChip('₱500', '500'),
                                    const SizedBox(width: 6),
                                    _buildTenderChip('₱1,000', '1000'),
                                  ],
                                ),
                                const Divider(color: AppTheme.cardBorder, height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Change (Sukli):',
                                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    Text(
                                      '₱ ${_changeAmount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: _changeAmount > 0 ? const Color(0xFF10B981) : AppTheme.textSecondary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                const Divider(color: AppTheme.cardBorder, height: 20),
                                TextFormField(
                                  controller: _referenceController,
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                  decoration: _inputDecoration(
                                    label: '${_paymentMethod == 'walk_in_gcash' ? 'GCash' : 'Maya'} Ref / Trans No.',
                                    hint: 'e.g. 100234857210',
                                    icon: Icons.receipt_long_rounded,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Immediate check-in toggle
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _immediateCheckIn ? AppTheme.accent.withOpacity(0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _immediateCheckIn ? AppTheme.accent.withOpacity(0.3) : AppTheme.cardBorder,
                            ),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppTheme.accent,
                            title: const Text(
                              'Activate Court Immediately',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: const Text(
                              'Start timer now and show player on court LCD',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                            value: _immediateCheckIn,
                            onChanged: (val) => setState(() => _immediateCheckIn = val),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Action Buttons ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F1821),
                  border: Border(top: BorderSide(color: AppTheme.cardBorder)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.background,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _isSubmitting ? null : _submitWalkInBooking,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.background),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 20),
                        label: Text(
                          _isSubmitting ? 'Processing...' : 'Confirm & Collect ₱${_totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF162330),
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.point_of_sale_rounded, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Walk-In Booking & Payment',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Cash / GCash counter reservation',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodOption({
    required String label,
    required IconData icon,
    required String value,
    required Color color,
  }) {
    final isSelected = _paymentMethod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppTheme.cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? color : AppTheme.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTenderChip(String label, String amountStr) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _tenderedController.text = amountStr;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.cardBorder.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 18, color: AppTheme.textSecondary) : null,
      isDense: true,
      labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      filled: true,
      fillColor: AppTheme.card,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              onPrimary: AppTheme.background,
              surface: Color(0xFF1B2A38),
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitWalkInBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a court.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final playerName = _nameController.text.trim();
      final totalAmount = _totalAmount;
      final startTime = _startTime;
      final endTime = _endTime;
      final court = _selectedCourt!;
      final ref = _referenceController.text.trim().isNotEmpty
          ? _referenceController.text.trim()
          : 'WALK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final status = _immediateCheckIn ? AppConstants.statusActive : AppConstants.statusConfirmed;

      // Create reservation via ReservationProvider
      final res = await context.read<ReservationProvider>().createReservation(
            court: court,
            userId: 'walk_in_${DateTime.now().millisecondsSinceEpoch}',
            userName: playerName,
            date: _selectedDate,
            startTime: startTime,
            endTime: endTime,
            status: status,
            paymentMethod: _paymentMethod,
            paymentReference: ref,
            amount: totalAmount,
          );

      if (res != null && mounted) {
        // If immediate check-in, update IoT court status to In-Use immediately
        if (_immediateCheckIn) {
          try {
            await CourtService().updateCourtStatus(
              courtId: court.id,
              isOccupied: true,
              reservationId: res.id,
              reservedByName: playerName,
              bookedUntil: endTime,
              occupiedSince: DateTime.now(),
            );
            await LcdService.logCheckIn(
              courtId: court.id,
              playerName: playerName,
              endTime: endTime,
            );
          } catch (_) {}
        }

        if (mounted) {
          Navigator.of(context).pop();
          _showReceiptDialog(context, res, _changeAmount);
        }
      } else {
        if (!mounted) return;
        final err = context.read<ReservationProvider>().error ?? 'Slot is unavailable.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppTheme.statusInUse),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to book walk-in: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showReceiptDialog(BuildContext context, ReservationModel res, double change) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131E29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 10),
            Text(
              'Payment Recorded!',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Walk-in session successfully confirmed & logged.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                children: [
                  _receiptRow('Player:', res.userName),
                  const SizedBox(height: 6),
                  _receiptRow('Court:', res.courtName),
                  const SizedBox(height: 6),
                  _receiptRow('Time:', DateHelpers.toTimeRange(res.startTime, res.endTime)),
                  const SizedBox(height: 6),
                  _receiptRow('Payment Method:', res.paymentMethod.toUpperCase().replaceAll('_', ' ')),
                  const Divider(color: AppTheme.cardBorder, height: 16),
                  _receiptRow('Total Paid:', '₱${res.amount.toStringAsFixed(2)}', isBold: true, color: const Color(0xFF10B981)),
                  if (change > 0) ...[
                    const SizedBox(height: 6),
                    _receiptRow('Change Given:', '₱${change.toStringAsFixed(2)}', color: AppTheme.accent),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done & Print Receipt'),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            color: color ?? AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

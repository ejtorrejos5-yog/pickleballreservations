import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/court_model.dart';
import '../../models/court_status_model.dart';
import '../../services/court_service.dart';
import '../../services/lcd_service.dart';
import '../../core/theme/app_theme.dart';

/// Bottom sheet that gives the admin full manual control over what a court's
/// LCD display shows.  Covers five actions:
///   1. Display Timer directly on the LCD (live countdown clock)
///   2. Set a custom 2-line message (stored in lcd_override/{courtId})
///   3. Set the "Next Player" name (stored in court_status/{courtId})
///   4. Force the court to Available (clears court_status)
///   5. Force the court to Occupied (manual check-in with duration)
class AdminLcdControlSheet extends StatefulWidget {
  final CourtModel court;
  final CourtStatusModel status;

  const AdminLcdControlSheet({
    super.key,
    required this.court,
    required this.status,
  });

  static Future<void> show(
    BuildContext context, {
    required CourtModel court,
    required CourtStatusModel status,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminLcdControlSheet(court: court, status: status),
    );
  }

  @override
  State<AdminLcdControlSheet> createState() => _AdminLcdControlSheetState();
}

class _AdminLcdControlSheetState extends State<AdminLcdControlSheet> {
  // ── expansion state ──
  _ActivePanel _open = _ActivePanel.none;

  // ── live timer ticker ──
  Timer? _tickTimer;

  // ── custom message ──
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  bool _savingCustom = false;

  // ── next player ──
  final _nextCtrl = TextEditingController();
  bool _savingNext = false;

  // ── force occupied / timer ──
  final _playerCtrl = TextEditingController();
  final _minutesCtrl = TextEditingController(text: '60');
  bool _savingOccupied = false;

  // ── force available ──
  bool _savingAvailable = false;

  // ── live state that may be updated after actions ──
  late CourtStatusModel _status;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _nextCtrl.text = _status.nextPlayerName ?? '';
    _playerCtrl.text = _status.reservedByName ?? '';
    _line1Ctrl.text = widget.court.name.toUpperCase();
    _line2Ctrl.text = '';
    LcdService.setActiveCourt(
      courtId: widget.court.id,
      courtName: widget.court.name,
    );
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _nextCtrl.dispose();
    _playerCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────── Helpers ────────────────────────────────────────────

  /// Pads / truncates to exactly 16 chars (simulates LCD column limit).
  String _lcdRow(String s) {
    if (s.length > 16) return s.substring(0, 16);
    return s.padRight(16);
  }

  String get _previewRow0 {
    if (_status.isOccupied && _status.reservedByName != null) {
      final prefix = widget.court.name.length >= 2
          ? '${widget.court.name.substring(0, 2).toUpperCase()}:'
          : '${widget.court.name.toUpperCase()}:';
      return _lcdRow('$prefix${_status.reservedByName}');
    }
    return _lcdRow(' [${widget.court.name.toUpperCase()}] ');
  }

  String get _previewRow1 {
    if (_status.isOccupied) {
      final rem = _status.secondsRemaining;
      final h = rem ~/ 3600;
      final m = (rem % 3600) ~/ 60;
      final s = rem % 60;
      if (h > 0) {
        return _lcdRow('\u23F0 ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} left');
      }
      return _lcdRow('\u23F0 ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} left   ');
    }
    return _lcdRow('  >> AVAILABLE <<');
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.statusInUse : AppTheme.statusAvailable,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─────────────────────── Actions ────────────────────────────────────────────

  Future<void> _saveCustomMessage() async {
    final l1 = _line1Ctrl.text.trim();
    final l2 = _line2Ctrl.text.trim();
    final defaultHeader = widget.court.name.toUpperCase();
    if (l2.isEmpty && (l1.isEmpty || l1 == defaultHeader)) {
      _showSnack('Please enter a custom message', error: true);
      return;
    }
    setState(() => _savingCustom = true);
    try {
      await LcdService.setCustomMessage(
        courtId: widget.court.id,
        line1: l1,
        line2: l2,
      );
      _showSnack('Custom message sent to LCD ✓');
      setState(() => _open = _ActivePanel.none);
    } catch (e) {
      _showSnack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingCustom = false);
    }
  }

  Future<void> _clearCustomMessage() async {
    setState(() => _savingCustom = true);
    try {
      await LcdService.clearOverride(courtId: widget.court.id);
      _showSnack('LCD override cleared — auto mode restored ✓');
    } catch (e) {
      _showSnack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingCustom = false);
    }
  }

  Future<void> _restartLcd() async {
    try {
      await LcdService.restartLcd(courtId: widget.court.id);
      _showSnack('Restart command sent! LCD is rebooting... 🔄');
    } catch (e) {
      _showSnack('Error: $e', error: true);
    }
  }

  Future<void> _saveNextPlayer() async {
    final name = _nextCtrl.text.trim();
    setState(() => _savingNext = true);
    try {
      await CourtService().setNextPlayer(widget.court.id, name.isEmpty ? null : name);
      await LcdService.setNextPlayer(
        courtId: widget.court.id,
        nextPlayerName: name.isEmpty ? null : name,
      );
      _showSnack(
        name.isEmpty
            ? 'Next player cleared ✓'
            : 'Next player set to "$name" ✓',
      );
      setState(() {
        _status = CourtStatusModel(
          courtId: _status.courtId,
          isOccupied: _status.isOccupied,
          occupiedSince: _status.occupiedSince,
          bookedUntil: _status.bookedUntil,
          reservationId: _status.reservationId,
          reservedByName: _status.reservedByName,
          nextPlayerName: name.isEmpty ? null : name,
        );
        _open = _ActivePanel.none;
      });
    } catch (e) {
      _showSnack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingNext = false);
    }
  }

  Future<void> _displayTimerOnLcd({int? durationMinutes, String? playerName}) async {
    setState(() => _savingOccupied = true);
    try {
      // If currently occupied and no new duration requested, restore live countdown display
      if (_status.isOccupied && durationMinutes == null) {
        await LcdService.clearOverride(courtId: widget.court.id);
        await LcdService.restartLcd(courtId: widget.court.id);
        _showSnack('LCD set to display live countdown timer! ⏱️');
        setState(() => _open = _ActivePanel.none);
        return;
      }

      final mins = durationMinutes ?? int.tryParse(_minutesCtrl.text.trim()) ?? 60;
      if (mins <= 0) {
        _showSnack('Enter valid minutes', error: true);
        return;
      }

      final name = (playerName ?? _playerCtrl.text.trim()).isNotEmpty
          ? (playerName ?? _playerCtrl.text.trim())
          : (_status.reservedByName?.isNotEmpty == true ? _status.reservedByName! : 'Player');

      final endTime = DateTime.now().add(Duration(minutes: mins));

      await CourtService().updateCourtStatus(
        courtId: widget.court.id,
        isOccupied: true,
        reservedByName: name,
        bookedUntil: endTime,
        occupiedSince: DateTime.now(),
      );
      await LcdService.logCheckIn(
        courtId: widget.court.id,
        playerName: name,
        endTime: endTime,
      );
      await LcdService.clearOverride(courtId: widget.court.id);
      await LcdService.restartLcd(courtId: widget.court.id);

      _showSnack('Timer ($mins min) active! Displayed on LCD ⏱️');
      setState(() {
        _status = CourtStatusModel(
          courtId: widget.court.id,
          isOccupied: true,
          reservedByName: name,
          bookedUntil: endTime,
          occupiedSince: DateTime.now(),
          nextPlayerName: _status.nextPlayerName,
        );
        _open = _ActivePanel.none;
      });
    } catch (e) {
      _showSnack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingOccupied = false);
    }
  }

  Future<void> _addTimerMinutes(int additionalMinutes) async {
    if (!_status.isOccupied || _status.bookedUntil == null) {
      await _displayTimerOnLcd(durationMinutes: additionalMinutes);
      return;
    }
    setState(() => _savingOccupied = true);
    try {
      final currentEnd = _status.bookedUntil!.isAfter(DateTime.now())
          ? _status.bookedUntil!
          : DateTime.now();
      final newEnd = currentEnd.add(Duration(minutes: additionalMinutes));
      final name = _status.reservedByName ?? 'Player';

      await CourtService().updateCourtStatus(
        courtId: widget.court.id,
        isOccupied: true,
        reservedByName: name,
        bookedUntil: newEnd,
        occupiedSince: _status.occupiedSince ?? DateTime.now(),
      );
      await LcdService.logCheckIn(
        courtId: widget.court.id,
        playerName: name,
        endTime: newEnd,
      );
      await LcdService.clearOverride(courtId: widget.court.id);
      await LcdService.restartLcd(courtId: widget.court.id);

      final remMin = newEnd.difference(DateTime.now()).inMinutes;
      _showSnack('+$additionalMinutes mins added! New timer: $remMin mins remaining ⏱️');
      setState(() {
        _status = CourtStatusModel(
          courtId: widget.court.id,
          isOccupied: true,
          reservedByName: name,
          bookedUntil: newEnd,
          occupiedSince: _status.occupiedSince ?? DateTime.now(),
          nextPlayerName: _status.nextPlayerName,
        );
      });
    } catch (e) {
      _showSnack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingOccupied = false);
    }
  }

  Future<void> _forceAvailable() async {
    setState(() => _savingAvailable = true);
    try {
      await CourtService().clearCourtStatus(widget.court.id);
      await LcdService.logAvailable(courtId: widget.court.id);
      await LcdService.clearOverride(courtId: widget.court.id);
      _showSnack('Court forced to AVAILABLE — LCD updated ✓');
      setState(() {
        _status = CourtStatusModel.empty(widget.court.id);
        _open = _ActivePanel.none;
      });
    } catch (e) {
      _showSnack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingAvailable = false);
    }
  }

  Future<void> _forceOccupied() async {
    final playerName = _playerCtrl.text.trim();
    if (playerName.isEmpty) {
      _showSnack('Enter a player name', error: true);
      return;
    }
    final minutes = int.tryParse(_minutesCtrl.text.trim()) ?? 60;
    if (minutes <= 0) {
      _showSnack('Enter valid minutes', error: true);
      return;
    }

    setState(() => _savingOccupied = true);
    final endTime = DateTime.now().add(Duration(minutes: minutes));
    try {
      await CourtService().updateCourtStatus(
        courtId: widget.court.id,
        isOccupied: true,
        reservedByName: playerName,
        bookedUntil: endTime,
        occupiedSince: DateTime.now(),
      );
      await LcdService.logCheckIn(
        courtId: widget.court.id,
        playerName: playerName,
        endTime: endTime,
      );
      await LcdService.clearOverride(courtId: widget.court.id);
      _showSnack('Court forced to OCCUPIED — LCD updated ✓');
      setState(() {
        _status = CourtStatusModel(
          courtId: widget.court.id,
          isOccupied: true,
          reservedByName: playerName,
          bookedUntil: endTime,
          occupiedSince: DateTime.now(),
        );
        _open = _ActivePanel.none;
      });
    } catch (e) {
      _showSnack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingOccupied = false);
    }
  }

  // ─────────────────────── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F14),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            _buildHeader(),

            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  _buildArduinoStatusBar(),
                  const SizedBox(height: 12),
                  _buildLcdPreview(),
                  const SizedBox(height: 20),
                  _buildSectionLabel('TIMER & DISPLAY CONTROLS'),
                  const SizedBox(height: 10),
                  _buildDisplayTimerTile(),
                  const SizedBox(height: 10),
                  _buildCustomMessageTile(),
                  const SizedBox(height: 10),
                  _buildNextPlayerTile(),
                  const SizedBox(height: 20),
                  _buildSectionLabel('FORCE ACTIONS'),
                  const SizedBox(height: 10),
                  _buildForceAvailableTile(),
                  const SizedBox(height: 10),
                  _buildForceOccupiedTile(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isOccupied = _status.isOccupied;
    final statusColor =
        isOccupied ? AppTheme.statusInUse : AppTheme.statusAvailable;
    final statusLabel = isOccupied ? 'IN USE' : 'AVAILABLE';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.display_settings_rounded,
                color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LCD Control — ${widget.court.name}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_status.nextPlayerName != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· Next: ${_status.nextPlayerName}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Restart / Refresh LCD',
            child: IconButton(
              icon: const Icon(Icons.restart_alt_rounded, color: AppTheme.primary),
              onPressed: _restartLcd,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildArduinoStatusBar() {
    return StreamBuilder(
      stream: LcdService.streamArduinoStatus(courtId: widget.court.id),
      builder: (context, snapshot) {
        bool isConnected = false;
        String port = 'COM3';
        if (snapshot.hasData && snapshot.data != null) {
          final event = snapshot.data as dynamic;
          if (event.snapshot.value != null) {
            try {
              final rootMap = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
              Map<dynamic, dynamic>? courtMap;
              if (rootMap.containsKey(widget.court.id)) {
                courtMap = Map<dynamic, dynamic>.from(rootMap[widget.court.id] as Map);
              } else if (rootMap.containsKey('court_1')) {
                courtMap = Map<dynamic, dynamic>.from(rootMap['court_1'] as Map);
              } else if (rootMap.containsKey('global')) {
                courtMap = Map<dynamic, dynamic>.from(rootMap['global'] as Map);
              } else if (rootMap.isNotEmpty) {
                courtMap = Map<dynamic, dynamic>.from(rootMap.values.first as Map);
              }

              if (courtMap != null) {
                final lastSeen = courtMap['lastSeen'] as int? ?? 0;
                final diffMs = (DateTime.now().millisecondsSinceEpoch - lastSeen).abs();
                // 30 seconds freshness window
                isConnected = (courtMap['connected'] == true) && diffMs < 30000;
                port = (courtMap['port'] as String?) ?? 'COM3';
              }
            } catch (_) {}
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isConnected
                ? const Color(0xFF0D2818)
                : const Color(0xFF251315),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isConnected
                  ? const Color(0xFF1B6B38)
                  : const Color(0xFF5A1C22),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isConnected ? Icons.usb_rounded : Icons.usb_off_rounded,
                size: 18,
                color: isConnected ? const Color(0xFF4EFA8A) : const Color(0xFFFF5252),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected
                          ? 'Arduino Uno Connected ($port)'
                          : 'Arduino Bridge Offline',
                      style: TextStyle(
                        color: isConnected
                            ? const Color(0xFF4EFA8A)
                            : const Color(0xFFFF8A80),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isConnected
                          ? 'Connected to system. Changes auto-restart and display on LCD.'
                          : 'Double-click run_arduino_bridge.bat on your PC to connect.',
                      style: TextStyle(
                        color: isConnected
                            ? Colors.white70
                            : const Color(0xFFFFA4A4),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (isConnected)
                TextButton.icon(
                  onPressed: _restartLcd,
                  icon: const Icon(Icons.restart_alt_rounded, size: 14, color: AppTheme.primary),
                  label: const Text('Restart', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Simulates a 16×2 character LCD display.
  Widget _buildLcdPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1E0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A3D1A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF41).withOpacity(0.06),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_rounded,
                  color: Color(0xFF00C853), size: 14),
              const SizedBox(width: 6),
              const Text(
                'LCD PREVIEW  (16×2)',
                style: TextStyle(
                  color: Color(0xFF00C853),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00C853),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // LCD rows
          _lcdLine(_previewRow0),
          const SizedBox(height: 4),
          _lcdLine(_previewRow1),
          const SizedBox(height: 12),
          // Action button row for Timer display
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.timer_rounded, size: 16),
                  label: Text(
                    _status.isOccupied ? 'Display Timer (Live)' : 'Display Timer',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: const Color(0xFF041804),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _savingOccupied
                      ? null
                      : () {
                          if (_status.isOccupied) {
                            _displayTimerOnLcd();
                          } else {
                            setState(() => _open = _ActivePanel.displayTimer);
                          }
                        },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt_rounded, size: 15, color: Color(0xFF00E676)),
                label: const Text('Refresh LCD',
                    style: TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1B5E20)),
                  backgroundColor: const Color(0xFF061A08),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _restartLcd,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms);
  }

  Widget _lcdLine(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF061406),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          color: Color(0xFF39FF14),
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: 2.5,
        ),
        maxLines: 1,
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }

  // ── Display Timer Tile ───────────────────────────────────────────────────────

  Widget _buildDisplayTimerTile() {
    final isOpen = _open == _ActivePanel.displayTimer;
    final isOccupied = _status.isOccupied;
    final remSec = _status.secondsRemaining;
    final remMin = (remSec / 60).ceil();

    return _ActionTile(
      icon: Icons.timer_rounded,
      iconColor: const Color(0xFF00E676),
      title: 'Display Timer on LCD',
      subtitle: isOccupied
          ? 'Live timer running: $remMin mins remaining'
          : 'Set countdown duration & display live timer on LCD',
      isExpanded: isOpen,
      onHeaderTap: () => setState(
          () => _open = isOpen ? _ActivePanel.none : _ActivePanel.displayTimer),
      expandedContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isOccupied) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm_on_rounded, color: Color(0xFF00E676), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Running: ${_status.reservedByName ?? "Player"} · $remMin min left',
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _savingOccupied ? null : () => _displayTimerOnLcd(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Show on LCD',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E676))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Add More Time to Timer:',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _buildTimeChip('+15 min', 15, isAdd: true)),
                const SizedBox(width: 6),
                Expanded(child: _buildTimeChip('+30 min', 30, isAdd: true)),
                const SizedBox(width: 6),
                Expanded(child: _buildTimeChip('+60 min', 60, isAdd: true)),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: AppTheme.cardBorder, height: 1),
            const SizedBox(height: 14),
          ],
          const Text(
            'Quick Duration Presets:',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [15, 30, 45, 60, 90, 120].map((mins) {
              final isSelected = _minutesCtrl.text == mins.toString();
              return InkWell(
                onTap: () => setState(() => _minutesCtrl.text = mins.toString()),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00E676).withOpacity(0.2)
                        : AppTheme.cardBorder.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00E676)
                          : AppTheme.cardBorder,
                    ),
                  ),
                  child: Text(
                    '$mins mins',
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF00E676)
                          : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _lcdTextField(
            controller: _playerCtrl,
            label: 'Player / Team Name',
            hint: 'e.g. Gabriel',
            maxLength: 12,
          ),
          const SizedBox(height: 10),
          _lcdTextField(
            controller: _minutesCtrl,
            label: 'Timer Duration (minutes)',
            hint: 'e.g. 60',
            maxLength: 4,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            icon: _savingOccupied
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF051B07)),
                  )
                : const Icon(Icons.timer_rounded, size: 18),
            label: Text(
              isOccupied
                  ? 'Update & Display Timer on LCD'
                  : 'Display Timer on LCD',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: const Color(0xFF051B07),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _savingOccupied ? null : () => _displayTimerOnLcd(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, int mins, {bool isAdd = false}) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF00E676)),
        backgroundColor: const Color(0xFF00E676).withOpacity(0.08),
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: _savingOccupied
          ? null
          : () => isAdd
              ? _addTimerMinutes(mins)
              : _displayTimerOnLcd(durationMinutes: mins),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF00E676),
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }

  // ── Custom Message Tile ──────────────────────────────────────────────────────

  Widget _buildCustomMessageTile() {
    final isOpen = _open == _ActivePanel.custom;
    return _ActionTile(
      icon: Icons.text_fields_rounded,
      iconColor: AppTheme.accent,
      title: 'Set Custom Message',
      subtitle: 'Show any text on both LCD rows',
      isExpanded: isOpen,
      onHeaderTap: () =>
          setState(() => _open = isOpen ? _ActivePanel.none : _ActivePanel.custom),
      expandedContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _lcdTextField(
            controller: _line1Ctrl,
            label: 'Row 1 (max 16 chars)',
            hint: 'e.g. COURT CLOSED',
            maxLength: 16,
          ),
          const SizedBox(height: 10),
          _lcdTextField(
            controller: _line2Ctrl,
            label: 'Row 2 (max 16 chars)',
            hint: 'e.g. Back at 5 PM',
            maxLength: 16,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.cardBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: _savingCustom ? null : _clearCustomMessage,
                  child: const Text(
                    'Clear Override',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.background,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: _savingCustom ? null : _saveCustomMessage,
                  child: _savingCustom
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Send to LCD',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Next Player Tile ─────────────────────────────────────────────────────────

  Widget _buildNextPlayerTile() {
    final isOpen = _open == _ActivePanel.nextPlayer;
    return _ActionTile(
      icon: Icons.skip_next_rounded,
      iconColor: AppTheme.primary,
      title: 'Set Next Player',
      subtitle: 'Shown on LCD when current session ends',
      isExpanded: isOpen,
      onHeaderTap: () =>
          setState(() => _open = isOpen ? _ActivePanel.none : _ActivePanel.nextPlayer),
      expandedContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _lcdTextField(
            controller: _nextCtrl,
            label: 'Next Player Name (max 12 chars)',
            hint: 'e.g. Maria',
            maxLength: 12,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.background,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: _savingNext ? null : _saveNextPlayer,
            child: _savingNext
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Next Player',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Force Available Tile ─────────────────────────────────────────────────────

  Widget _buildForceAvailableTile() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppTheme.statusAvailable.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppTheme.statusAvailable.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: AppTheme.statusAvailable, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Force Available',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Clears current session & shows AVAILABLE on LCD',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _savingAvailable
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.statusAvailable))
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.statusAvailable,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _forceAvailable,
                  child: const Text('Force',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12)),
                ),
        ],
      ),
    );
  }

  // ── Force Occupied Tile ──────────────────────────────────────────────────────

  Widget _buildForceOccupiedTile() {
    final isOpen = _open == _ActivePanel.forceOccupied;
    return _ActionTile(
      icon: Icons.person_pin_circle_rounded,
      iconColor: AppTheme.statusReserved,
      title: 'Force Occupied',
      subtitle: 'Manually trigger a timed session',
      isExpanded: isOpen,
      onHeaderTap: () =>
          setState(() => _open = isOpen ? _ActivePanel.none : _ActivePanel.forceOccupied),
      expandedContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _lcdTextField(
            controller: _playerCtrl,
            label: 'Player Name',
            hint: 'e.g. Juan',
            maxLength: 12,
          ),
          const SizedBox(height: 10),
          _lcdTextField(
            controller: _minutesCtrl,
            label: 'Duration (minutes)',
            hint: 'e.g. 60',
            maxLength: 4,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusReserved,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: _savingOccupied ? null : _forceOccupied,
            child: _savingOccupied
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Start Session',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _lcdTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int maxLength,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontFamily: 'monospace',
        color: AppTheme.textPrimary,
        letterSpacing: 1.2,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─── Supporting types ────────────────────────────────────────────────────────

enum _ActivePanel { none, displayTimer, custom, nextPlayer, forceOccupied }

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isExpanded;
  final VoidCallback onHeaderTap;
  final Widget expandedContent;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.onHeaderTap,
    required this.expandedContent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? iconColor.withOpacity(0.4)
              : AppTheme.cardBorder,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onHeaderTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: isExpanded ? 0.5 : 0,
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: isExpanded ? iconColor : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: expandedContent,
            ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.05, end: 0, duration: 200.ms),
        ],
      ),
    );
  }
}

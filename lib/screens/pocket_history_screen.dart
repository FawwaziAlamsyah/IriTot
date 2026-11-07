import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/savings_record.dart';
import '../services/storage_service.dart';
import '../services/locale_service.dart';
import '../theme/app_theme.dart';

class PocketHistoryScreen extends StatefulWidget {
  final StorageService storageService;
  final LocaleService? localeService;

  const PocketHistoryScreen({
    super.key,
    required this.storageService,
    this.localeService,
  });

  @override
  State<PocketHistoryScreen> createState() => _PocketHistoryScreenState();
}

class _PocketHistoryScreenState extends State<PocketHistoryScreen> {
  String _historyFilter = 'all'; // 'all', 'in', 'out', 'transfer'
  DateTime? _historyMonth; // null = all months

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String t(String key) => widget.localeService?.t(key) ?? key;

  void _showRecordDetailModal(SavingsRecord r) {
    final isIndo = widget.localeService?.isIndonesian == true;
    final isTransfer = r.isPocketTransfer;
    final isIn = r.isIn;
    final Color accentColor = isTransfer
        ? AppTheme.cyanAccent
        : (isIn ? AppTheme.emeraldGreen : AppTheme.coralRose);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SingleChildScrollView(
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: AppTheme.borderDark, width: 1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isIndo ? 'Detail Mutasi Tabungan' : 'Pocket Transaction Details',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isTransfer
                            ? (isIndo ? 'Antar Pos' : 'Pocket Transfer')
                            : (isIn ? (isIndo ? 'Setoran Dompet' : 'Wallet Deposit') : (isIndo ? 'Tarik Dompet' : 'Wallet Withdraw')),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accentColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Nominal Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLighter,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIndo ? 'Nominal Transaksi' : 'Transaction Amount',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isIn ? '+${_currencyFormat.format(r.amount)}' : '-${_currencyFormat.format(r.amount)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  isIndo ? 'Pos Kantong Tabungan' : 'Savings Pocket',
                  r.pocketName,
                  Icons.savings_outlined,
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  isTransfer
                      ? (isIndo ? 'Pos Lawan (Tujuan/Asal)' : 'Counter Pocket')
                      : (isIn ? (isIndo ? 'Dari Dompet Kas' : 'From Wallet') : (isIndo ? 'Pindah ke Dompet' : 'To Wallet')),
                  r.walletName,
                  isTransfer ? Icons.swap_horiz_rounded : Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  isIndo ? 'Waktu Transaksi' : 'Date & Time',
                  DateFormat('EEEE, dd MMMM yyyy - HH:mm', isIndo ? 'id_ID' : 'en_US').format(r.date),
                  Icons.calendar_today_outlined,
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  isIndo ? 'Catatan' : 'Notes',
                  r.note.isEmpty ? '-' : r.note,
                  Icons.notes_outlined,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceLighter,
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: AppTheme.borderDark),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(t('close'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthChip(DateTime? month, String label) {
    final isSelected = _historyMonth == month;
    return GestureDetector(
      onTap: () => setState(() => _historyMonth = month),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.cyanAccent.withValues(alpha: 0.2) : AppTheme.surfaceLighter,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.cyanAccent : AppTheme.borderDark),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.cyanAccent : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String val, String label) {
    final isSelected = _historyFilter == val;
    return GestureDetector(
      onTap: () => setState(() => _historyFilter = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.emeraldGreen.withValues(alpha: 0.2) : AppTheme.surfaceLighter,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.emeraldGreen : AppTheme.borderDark),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.emeraldGreen : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIndo = widget.localeService?.isIndonesian == true;
    final records = widget.storageService.getSavingsRecords();

    // Pocket history: newest first, optionally limited to one month
    final sortedRecords = List<SavingsRecord>.from(records)..sort((a, b) => b.date.compareTo(a.date));
    final availableMonths = <DateTime>[];
    for (final r in sortedRecords) {
      final m = DateTime(r.date.year, r.date.month);
      if (!availableMonths.contains(m)) availableMonths.add(m);
    }
    if (_historyMonth != null && !availableMonths.contains(_historyMonth)) {
      _historyMonth = null;
    }

    final filteredRecords = sortedRecords.where((r) {
      if (_historyMonth != null &&
          (r.date.year != _historyMonth!.year || r.date.month != _historyMonth!.month)) {
        return false;
      }
      if (_historyFilter == 'in') return r.isIn;
      if (_historyFilter == 'out') return r.isOut;
      if (_historyFilter == 'transfer') return r.isPocketTransfer;
      return true;
    }).toList();

    // Summary calculations for filtered/current view
    final totalIn = filteredRecords.where((r) => r.isIn && !r.isPocketTransfer).fold(0.0, (s, r) => s + r.amount);
    final totalOut = filteredRecords.where((r) => r.isOut && !r.isPocketTransfer).fold(0.0, (s, r) => s + r.amount);
    final netGrowth = totalIn - totalOut;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(t('pocketHistoryTitle')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Top Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF142426), Color(0xFF0D1B1E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.3), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, color: AppTheme.cyanAccent, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            t('totalMutations').toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.cyanAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${filteredRecords.length} ${isIndo ? 'Transaksi' : 'Items'}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.cyanAccent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isIndo ? 'Total Masuk' : 'Total Inflow',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '+${_currencyFormat.format(totalIn)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 26, color: AppTheme.borderDark),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isIndo ? 'Total Keluar' : 'Total Outflow',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '-${_currencyFormat.format(totalOut)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.coralRose),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 26, color: AppTheme.borderDark),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isIndo ? 'Tumbuh Bersih' : 'Net Growth',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              netGrowth >= 0 ? '+${_currencyFormat.format(netGrowth)}' : _currencyFormat.format(netGrowth),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: netGrowth >= 0 ? AppTheme.cyanAccent : AppTheme.amberWarning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', t('allFilter')),
                  const SizedBox(width: 6),
                  _buildFilterChip('in', isIndo ? 'Setor' : 'Deposit'),
                  const SizedBox(width: 6),
                  _buildFilterChip('out', isIndo ? 'Tarik' : 'Withdraw'),
                  const SizedBox(width: 6),
                  _buildFilterChip('transfer', t('pocketTransferFilter')),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Month Filter Chips
            if (availableMonths.isNotEmpty) ...[
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildMonthChip(null, t('allMonths')),
                    for (final m in availableMonths) ...[
                      const SizedBox(width: 6),
                      _buildMonthChip(
                        m,
                        DateFormat('MMM yyyy', isIndo ? 'id_ID' : 'en_US').format(m),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // History Records List
            if (filteredRecords.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.history_toggle_off_rounded, size: 40, color: AppTheme.textMuted),
                    const SizedBox(height: 10),
                    Text(
                      t('noSavingsHistory'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredRecords.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final r = filteredRecords[index];
                  final isIn = r.isIn;
                  final isTransfer = r.isPocketTransfer;
                  final Color accentColor = isTransfer
                      ? AppTheme.cyanAccent
                      : (isIn ? AppTheme.emeraldGreen : AppTheme.coralRose);
                  final IconData iconData = isTransfer
                      ? Icons.swap_horiz_rounded
                      : (isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded);
                  final String badgeText = isTransfer
                      ? (widget.localeService?.t('badgePocketTransfer') ?? 'Antar Pos')
                      : (isIn
                          ? (widget.localeService?.t('badgeWalletDeposit') ?? 'Setoran Dompet')
                          : (widget.localeService?.t('badgeWalletWithdraw') ?? 'Tarik Dompet'));
                  final String subtitleText = isTransfer
                      ? '${r.pocketName} ⇄ ${r.walletName} • ${DateFormat('dd MMM yyyy', isIndo ? 'id_ID' : 'en_US').format(r.date)}'
                      : '${r.pocketName} • ${isIn ? (isIndo ? 'Dari' : 'From') : (isIndo ? 'Ke' : 'To')}: ${r.walletName} • ${DateFormat('dd MMM yyyy', isIndo ? 'id_ID' : 'en_US').format(r.date)}';

                  return InkWell(
                    onTap: () => _showRecordDetailModal(r),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isTransfer
                              ? AppTheme.cyanAccent.withValues(alpha: 0.25)
                              : AppTheme.borderDark,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    iconData,
                                    color: accentColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: accentColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              badgeText,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: accentColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              r.note,
                                              maxLines: 1,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        subtitleText,
                                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isIn ? '+${_currencyFormat.format(r.amount)}' : '-${_currencyFormat.format(r.amount)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isIn ? (isTransfer ? AppTheme.cyanAccent : AppTheme.emeraldGreen) : AppTheme.coralRose,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, size: 14, color: AppTheme.textMuted),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

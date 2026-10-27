import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction_item.dart';
import '../models/category.dart';
import '../models/wallet.dart';
import '../services/storage_service.dart';
import '../services/locale_service.dart';
import '../services/csv_service.dart';
import '../services/file_io_service.dart';
import '../theme/app_theme.dart';

enum PeriodMode {
  monthly,
  thisMonth,
  lastMonth,
  thisYear,
  allTime,
  custom,
}

class ReportsScreen extends StatefulWidget {
  final StorageService storageService;
  final LocaleService? localeService;
  final VoidCallback? onDataChanged;

  const ReportsScreen({
    super.key,
    required this.storageService,
    this.localeService,
    this.onDataChanged,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // Period State
  PeriodMode _periodMode = PeriodMode.thisMonth;
  DateTime _currentPeriodDate = DateTime.now();
  DateTimeRange? _customDateRange;

  // Chart Toggle: Expense (true) vs Income (false)
  bool _showExpenseChart = true;
  int _touchedChartIndex = -1;

  // Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedType = 'all'; // 'all', 'expense', 'income', 'transfer'
  String? _selectedCategoryId; // null = all
  String? _selectedWalletId; // null = all
  String _sortOption = 'newest'; // 'newest', 'oldest', 'amount_high', 'amount_low'

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _customDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _t(String key) => widget.localeService?.t(key) ?? key;
  bool get _isId => widget.localeService?.isIndonesian == true;

  bool get _isMonthlyMode =>
      _periodMode == PeriodMode.monthly ||
      _periodMode == PeriodMode.thisMonth ||
      _periodMode == PeriodMode.lastMonth;

  // --- Date & Period Helpers ---

  void _setPeriodMode(PeriodMode mode) {
    setState(() {
      _periodMode = mode;
      final now = DateTime.now();
      if (mode == PeriodMode.monthly) {
        // Keeps _currentPeriodDate as-is
      } else if (mode == PeriodMode.thisMonth) {
        _currentPeriodDate = DateTime(now.year, now.month, 1);
      } else if (mode == PeriodMode.lastMonth) {
        _currentPeriodDate = DateTime(now.year, now.month - 1, 1);
      } else if (mode == PeriodMode.thisYear) {
        _currentPeriodDate = DateTime(now.year, 1, 1);
      } else if (mode == PeriodMode.custom && _customDateRange == null) {
        _customDateRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      }
      _touchedChartIndex = -1;
    });
  }

  void _navigatePeriod(int delta) {
    setState(() {
      if (_isMonthlyMode) {
        _currentPeriodDate = DateTime(
          _currentPeriodDate.year,
          _currentPeriodDate.month + delta,
          1,
        );
        _periodMode = PeriodMode.monthly;
      } else if (_periodMode == PeriodMode.thisYear) {
        _currentPeriodDate = DateTime(
          _currentPeriodDate.year + delta,
          1,
          1,
        );
      }
      _touchedChartIndex = -1;
    });
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final initialRange = _customDateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppTheme.bgDark,
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.emeraldGreen,
              onPrimary: Colors.black,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textPrimary,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: AppTheme.surfaceDark),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
        );
        _periodMode = PeriodMode.custom;
      });
    }
  }

  // --- Month Filter Modal Sheet ---

  void _showMonthFilterSheet(List<TransactionItem> allTransactions) {
    int pickerYear = _currentPeriodDate.year;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final months = List.generate(12, (index) => DateTime(pickerYear, index + 1, 1));
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.borderDark,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _t('filterPerMonth'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(bottomSheetCtx);
                            setState(() {
                              _periodMode = PeriodMode.thisYear;
                              _currentPeriodDate = DateTime(pickerYear, 1, 1);
                              _touchedChartIndex = -1;
                            });
                          },
                          child: Text(_t('allMonths'), style: const TextStyle(color: AppTheme.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLighter,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, color: AppTheme.textPrimary),
                            onPressed: () => setModalState(() => pickerYear--),
                          ),
                          Text(
                            '$pickerYear',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, color: AppTheme.textPrimary),
                            onPressed: () => setModalState(() => pickerYear++),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.1,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final m = months[index];
                        final isSelected = _isMonthlyMode &&
                            m.year == _currentPeriodDate.year &&
                            m.month == _currentPeriodDate.month;
                        final label = DateFormat('MMMM', _isId ? 'id_ID' : 'en_US').format(m);
                        final txCount = allTransactions.where((t) =>
                          t.date.year == m.year && t.date.month == m.month
                        ).length;

                        return InkWell(
                          onTap: () {
                            Navigator.pop(bottomSheetCtx);
                            setState(() {
                              _currentPeriodDate = m;
                              _periodMode = PeriodMode.monthly;
                              _touchedChartIndex = -1;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.emeraldGreen
                                  : (txCount > 0 ? AppTheme.surfaceLighter : AppTheme.surfaceDark),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.emeraldGreen
                                    : (txCount > 0 ? AppTheme.borderDark : AppTheme.borderDark.withValues(alpha: 0.5)),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? Colors.black : (txCount > 0 ? AppTheme.textPrimary : AppTheme.textMuted),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (txCount > 0)
                                  Text(
                                    '$txCount tx',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSelected ? Colors.black.withValues(alpha: 0.8) : AppTheme.cyanAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Filtering & Calculations ---

  List<TransactionItem> _getPeriodTransactions(List<TransactionItem> all) {
    switch (_periodMode) {
      case PeriodMode.monthly:
      case PeriodMode.thisMonth:
      case PeriodMode.lastMonth:
        return all.where((t) =>
            t.date.year == _currentPeriodDate.year &&
            t.date.month == _currentPeriodDate.month).toList();
      case PeriodMode.thisYear:
        return all.where((t) => t.date.year == _currentPeriodDate.year).toList();
      case PeriodMode.allTime:
        return List.from(all);
      case PeriodMode.custom:
        if (_customDateRange == null) return all;
        final start = _customDateRange!.start;
        final end = _customDateRange!.end;
        return all.where((t) => !t.date.isBefore(start) && !t.date.isAfter(end)).toList();
    }
  }

  List<TransactionItem> _applyFilters(List<TransactionItem> periodTxs, Map<String, CategoryItem> catMap, Map<String, Wallet> walletMap) {
    var result = List<TransactionItem>.from(periodTxs);

    // Type filter
    if (_selectedType != 'all') {
      result = result.where((t) => t.type == _selectedType).toList();
    }

    // Category filter
    if (_selectedCategoryId != null) {
      result = result.where((t) => t.categoryId == _selectedCategoryId).toList();
    }

    // Wallet filter
    if (_selectedWalletId != null) {
      result = result.where((t) =>
          t.walletId == _selectedWalletId ||
          t.destinationWalletId == _selectedWalletId).toList();
    }

    // Search query filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((t) {
        final catName = catMap[t.categoryId]?.name.toLowerCase() ?? '';
        final walletName = walletMap[t.walletId]?.name.toLowerCase() ?? '';
        final note = t.note.toLowerCase();
        final amountStr = t.amount.toStringAsFixed(0);
        return note.contains(q) || catName.contains(q) || walletName.contains(q) || amountStr.contains(q);
      }).toList();
    }

    // Sorting
    switch (_sortOption) {
      case 'oldest':
        result.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'amount_high':
        result.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'amount_low':
        result.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case 'newest':
      default:
        result.sort((a, b) => b.date.compareTo(a.date));
        break;
    }

    return result;
  }

  bool get _hasActiveFilters {
    return _selectedType != 'all' ||
        _selectedCategoryId != null ||
        _selectedWalletId != null ||
        _searchQuery.trim().isNotEmpty ||
        _sortOption != 'newest';
  }

  void _resetAllFilters() {
    setState(() {
      _selectedType = 'all';
      _selectedCategoryId = null;
      _selectedWalletId = null;
      _sortOption = 'newest';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  // --- Export & Summary Actions ---

  Future<void> _exportFilteredCsv(List<TransactionItem> transactions, List<Wallet> wallets, List<CategoryItem> categories) async {
    try {
      final csvData = CsvService.exportTransactionsToCsv(
        transactions: transactions,
        wallets: wallets,
        categories: categories,
      );
      final periodName = _getPeriodLabel().replaceAll(' ', '_').replaceAll('/', '-');
      final fileName = FileIoService.datedName('laporan_$periodName');

      await FileIoService.saveCsv(baseName: fileName, csv: csvData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_t('exportSuccess')} ($fileName.csv)'),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting CSV: $e'),
          backgroundColor: AppTheme.coralRose,
        ),
      );
    }
  }

  void _copySummaryText({
    required double income,
    required double expense,
    required double netCashflow,
    required int txCount,
    required List<MapEntry<String, double>> topExpenses,
    required Map<String, CategoryItem> catMap,
  }) {
    final periodLabel = _getPeriodLabel();
    final buffer = StringBuffer();
    buffer.writeln('📊 ${_t('reportsTitle')} IRITOT');
    buffer.writeln('📅 Periode: $periodLabel');
    buffer.writeln('--------------------------------');
    buffer.writeln('💰 ${_t('netCashflow')}: ${_currencyFormat.format(netCashflow)}');
    buffer.writeln('📈 ${_t('income')}: +${_currencyFormat.format(income)}');
    buffer.writeln('📉 ${_t('expense')}: -${_currencyFormat.format(expense)}');
    buffer.writeln('🔢 Total Transaksi: $txCount');

    if (topExpenses.isNotEmpty) {
      buffer.writeln('\nTop Pengeluaran:');
      for (final entry in topExpenses.take(5)) {
        final cat = catMap[entry.key];
        final pct = expense > 0 ? ((entry.value / expense) * 100).toStringAsFixed(1) : '0';
        buffer.writeln('• ${cat?.name ?? "Umum"}: ${_currencyFormat.format(entry.value)} ($pct%)');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('summaryCopied')),
        backgroundColor: AppTheme.emeraldGreen,
      ),
    );
  }

  String _getPeriodLabel() {
    switch (_periodMode) {
      case PeriodMode.monthly:
      case PeriodMode.thisMonth:
      case PeriodMode.lastMonth:
        return DateFormat('MMMM yyyy', _isId ? 'id_ID' : 'en_US').format(_currentPeriodDate);
      case PeriodMode.thisYear:
        return 'Tahun ${_currentPeriodDate.year}';
      case PeriodMode.allTime:
        return _t('periodAllTime');
      case PeriodMode.custom:
        if (_customDateRange != null) {
          final fmt = DateFormat('dd MMM yyyy', _isId ? 'id_ID' : 'en_US');
          return '${fmt.format(_customDateRange!.start)} - ${fmt.format(_customDateRange!.end)}';
        }
        return _t('periodCustom');
    }
  }

  // --- Deletion & Modals ---

  Future<void> _confirmDeleteTransaction(TransactionItem t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderDark),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppTheme.coralRose, size: 22),
            const SizedBox(width: 8),
            Text(_t('deleteTransactionTitle'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ],
        ),
        content: Text(
          widget.localeService?.t('deleteTransactionConfirm') ?? 'Hapus transaksi ini? Saldo dompet akan disesuaikan kembali.',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(_t('cancel'), style: const TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coralRose,
              foregroundColor: Colors.white,
            ),
            child: Text(_t('delete'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.storageService.deleteTransaction(t.id);
      widget.onDataChanged?.call();
      if (mounted) setState(() {});
    }
  }

  void _showTransactionDetail(TransactionItem t, Map<String, CategoryItem> catMap, Map<String, Wallet> walletMap) {
    final cat = catMap[t.categoryId];
    final wallet = walletMap[t.walletId];
    final destWallet = t.destinationWalletId != null ? walletMap[t.destinationWalletId] : null;
    final isExp = t.type == 'expense';
    final isInc = t.type == 'income';
    final isTransfer = t.type == 'transfer';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderDark,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _t('transactionDetails'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLighter,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isExp
                              ? AppTheme.coralRose.withValues(alpha: 0.15)
                              : (isInc
                                  ? AppTheme.emeraldGreen.withValues(alpha: 0.15)
                                  : AppTheme.cyanAccent.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isExp ? _t('filterExpense') : (isInc ? _t('filterIncome') : _t('filterTransfer')),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isExp ? AppTheme.coralRose : (isInc ? AppTheme.emeraldGreen : AppTheme.cyanAccent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isExp ? '-${_currencyFormat.format(t.amount)}' : (isInc ? '+${_currencyFormat.format(t.amount)}' : _currencyFormat.format(t.amount)),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: isExp ? AppTheme.coralRose : (isInc ? AppTheme.emeraldGreen : AppTheme.cyanAccent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildModalDetailRow(
                  label: _t('category'),
                  value: cat?.name ?? 'Umum',
                  icon: Icons.category_outlined,
                  color: cat != null ? Color(cat.colorValue) : AppTheme.textSecondary,
                ),
                const Divider(color: AppTheme.borderDark, height: 20),
                _buildModalDetailRow(
                  label: isTransfer ? _t('sourceWallet') : _t('wallet'),
                  value: wallet?.name ?? 'Kas',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                if (isTransfer && destWallet != null) ...[
                  const Divider(color: AppTheme.borderDark, height: 20),
                  _buildModalDetailRow(
                    label: _t('destWallet'),
                    value: destWallet.name,
                    icon: Icons.input_rounded,
                  ),
                ],
                const Divider(color: AppTheme.borderDark, height: 20),
                _buildModalDetailRow(
                  label: _t('dateTime'),
                  value: DateFormat('EEEE, dd MMMM yyyy • HH:mm', _isId ? 'id_ID' : 'en_US').format(t.date),
                  icon: Icons.calendar_today_outlined,
                ),
                const Divider(color: AppTheme.borderDark, height: 20),
                _buildModalDetailRow(
                  label: _t('note'),
                  value: t.note.trim().isEmpty ? '—' : t.note,
                  icon: Icons.notes_outlined,
                ),
                const Divider(color: AppTheme.borderDark, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ID', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    Row(
                      children: [
                        Text(
                          t.id.length > 12 ? '${t.id.substring(0, 12)}...' : t.id,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFamily: 'monospace'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 14, color: AppTheme.cyanAccent),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: t.id));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ID copied'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.coralRose,
                      side: const BorderSide(color: AppTheme.coralRose),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(_t('deleteTransactionTitle'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () {
                      Navigator.pop(modalCtx);
                      _confirmDeleteTransaction(t);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalDetailRow({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? AppTheme.textMuted),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? AppTheme.textPrimary),
        ),
      ],
    );
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    final allTransactions = widget.storageService.getTransactions();
    final categories = widget.storageService.getCategories();
    final wallets = widget.storageService.getWallets();

    final catMap = {for (var c in categories) c.id: c};
    final walletMap = {for (var w in wallets) w.id: w};

    // Step 1: Filter by period
    final periodTransactions = _getPeriodTransactions(allTransactions);

    // Calculate Financial Overview Metrics for the Period
    final incomeTransactions = periodTransactions.where((t) => t.type == 'income').toList();
    final expenseTransactions = periodTransactions.where((t) => t.type == 'expense').toList();

    final double income = incomeTransactions.fold(0.0, (sum, t) => sum + t.amount);
    final double expense = expenseTransactions.fold(0.0, (sum, t) => sum + t.amount);
    final double netSavings = income - expense;

    // Grouping for Expense & Income Charts
    final Map<String, double> expenseCategoryTotals = {};
    for (final t in expenseTransactions) {
      expenseCategoryTotals[t.categoryId] = (expenseCategoryTotals[t.categoryId] ?? 0.0) + t.amount;
    }
    final sortedExpenseEntries = expenseCategoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final Map<String, double> incomeCategoryTotals = {};
    for (final t in incomeTransactions) {
      incomeCategoryTotals[t.categoryId] = (incomeCategoryTotals[t.categoryId] ?? 0.0) + t.amount;
    }
    final sortedIncomeEntries = incomeCategoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Active chart entries based on toggle
    final activeChartEntries = _showExpenseChart ? sortedExpenseEntries : sortedIncomeEntries;
    final double activeChartTotal = _showExpenseChart ? expense : income;

    // Step 2: Apply Search and Interactive Filters to Transaction List
    final filteredTransactions = _applyFilters(periodTransactions, catMap, walletMap);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(_t('reportsTitle')),
        actions: [
          // Filter Reset Action Button
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_outlined, color: AppTheme.coralRose),
              tooltip: _t('resetFilters'),
              onPressed: _resetAllFilters,
            ),
          // Export / Share Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
            color: AppTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppTheme.borderDark),
            ),
            onSelected: (val) {
              if (val == 'csv') {
                _exportFilteredCsv(filteredTransactions, wallets, categories);
              } else if (val == 'summary') {
                _copySummaryText(
                  income: income,
                  expense: expense,
                  netCashflow: netSavings,
                  txCount: periodTransactions.length,
                  topExpenses: sortedExpenseEntries,
                  catMap: catMap,
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    const Icon(Icons.file_download_outlined, color: AppTheme.cyanAccent, size: 20),
                    const SizedBox(width: 10),
                    Text(_t('exportCsv'), style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'summary',
                child: Row(
                  children: [
                    const Icon(Icons.copy_all_outlined, color: AppTheme.emeraldGreen, size: 20),
                    const SizedBox(width: 10),
                    Text(_t('copySummary'), style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Period Selector Chips (Per Bulan, Bulan Ini, Bulan Lalu, Tahun Ini, Semua Waktu, Kustom)
              _buildPeriodModeSelector(),
              const SizedBox(height: 12),

              // 2. Interactive Period / Month Selector Bar
              _buildPeriodNavigationBar(allTransactions),
              const SizedBox(height: 16),

              // 3. Comprehensive Net Cashflow Summary Card
              _buildCashflowSummaryCard(
                netSavings: netSavings,
                income: income,
                expense: expense,
                incomeCount: incomeTransactions.length,
                expenseCount: expenseTransactions.length,
                totalTxCount: periodTransactions.length,
              ),
              const SizedBox(height: 22),

              // 4. Interactive Chart Section (Expense vs Income toggle)
              _buildChartSection(
                activeChartEntries: activeChartEntries,
                activeChartTotal: activeChartTotal,
                catMap: catMap,
              ),
              const SizedBox(height: 24),

              // 5. Search & Advanced Filter Controls (Bulan, Tipe, Kategori, Dompet, Urutan)
              _buildFilterControlsBar(categories: categories, wallets: wallets, allTransactions: allTransactions),
              const SizedBox(height: 16),

              // 6. Transaction History Header with Count & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _t('transactionHistory'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '${filteredTransactions.length} ${_t('transactionsFound')}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 7. Filtered Transaction Items List
              _buildTransactionList(
                transactions: filteredTransactions,
                catMap: catMap,
                walletMap: walletMap,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widget Components ---

  Widget _buildPeriodModeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPeriodPill(PeriodMode.monthly, _t('filterPerMonth')),
          const SizedBox(width: 8),
          _buildPeriodPill(PeriodMode.thisMonth, _t('periodThisMonth')),
          const SizedBox(width: 8),
          _buildPeriodPill(PeriodMode.lastMonth, _t('periodLastMonth')),
          const SizedBox(width: 8),
          _buildPeriodPill(PeriodMode.thisYear, _t('periodThisYear')),
          const SizedBox(width: 8),
          _buildPeriodPill(PeriodMode.allTime, _t('periodAllTime')),
          const SizedBox(width: 8),
          _buildPeriodPill(PeriodMode.custom, _t('periodCustom')),
        ],
      ),
    );
  }

  Widget _buildPeriodPill(PeriodMode mode, String label) {
    final isSelected = _periodMode == mode;
    return InkWell(
      onTap: () => _setPeriodMode(mode),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.emeraldGreen.withValues(alpha: 0.16) : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.emeraldGreen : AppTheme.borderDark,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.emeraldGreen : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodNavigationBar(List<TransactionItem> allTransactions) {
    if (_periodMode == PeriodMode.allTime) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Row(
          children: [
            const Icon(Icons.all_inclusive, color: AppTheme.cyanAccent, size: 20),
            const SizedBox(width: 10),
            Text(
              _t('periodAllTime'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const Spacer(),
            Text(
              _isId ? 'Semua Riwayat' : 'Complete History',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    if (_periodMode == PeriodMode.custom) {
      final fmt = DateFormat('dd MMM yyyy', _isId ? 'id_ID' : 'en_US');
      final rangeStr = _customDateRange != null
          ? '${fmt.format(_customDateRange!.start)} - ${fmt.format(_customDateRange!.end)}'
          : _t('periodCustom');

      return InkWell(
        onTap: _pickCustomDateRange,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cyanAccent.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.date_range, color: AppTheme.cyanAccent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rangeStr,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.edit_calendar_outlined, size: 16, color: AppTheme.cyanAccent),
            ],
          ),
        ),
      );
    }

    if (_periodMode == PeriodMode.thisYear) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppTheme.textPrimary, size: 22),
              onPressed: () => _navigatePeriod(-1),
            ),
            Text(
              'Tahun ${_currentPeriodDate.year}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.cyanAccent),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppTheme.textPrimary, size: 22),
              onPressed: () => _navigatePeriod(1),
            ),
          ],
        ),
      );
    }

    // MONTHLY MODE: Interactive Year Header & Horizontal 12-Month Selector Bar
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        children: [
          // Row 1: Month Title with Year Navigation & Picker Sheet
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppTheme.textPrimary, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _navigatePeriod(-1),
              ),
              InkWell(
                onTap: () => _showMonthFilterSheet(allTransactions),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('MMMM yyyy', _isId ? 'id_ID' : 'en_US').format(_currentPeriodDate),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.cyanAccent),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.calendar_month, color: AppTheme.cyanAccent, size: 16),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppTheme.textPrimary, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _navigatePeriod(1),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: 12-Month Horizontal Quick Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(12, (index) {
                final mIndex = index + 1;
                final monthDate = DateTime(_currentPeriodDate.year, mIndex, 1);
                final isSelected = _currentPeriodDate.month == mIndex;
                final monthLabel = DateFormat('MMM', _isId ? 'id_ID' : 'en_US').format(monthDate);
                final hasData = allTransactions.any(
                  (t) => t.date.year == monthDate.year && t.date.month == mIndex,
                );

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _currentPeriodDate = monthDate;
                        _periodMode = PeriodMode.monthly;
                        _touchedChartIndex = -1;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.emeraldGreen
                            : (hasData ? AppTheme.surfaceLighter : Colors.transparent),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.emeraldGreen
                              : (hasData ? AppTheme.borderDark : Colors.transparent),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            monthLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? Colors.black
                                  : (hasData ? AppTheme.textPrimary : AppTheme.textMuted),
                            ),
                          ),
                          if (hasData && !isSelected) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppTheme.cyanAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashflowSummaryCard({
    required double netSavings,
    required double income,
    required double expense,
    required int incomeCount,
    required int expenseCount,
    required int totalTxCount,
  }) {
    final isSurplus = netSavings >= 0;
    final double savingsRate = income > 0 ? ((netSavings / income) * 100).clamp(0, 100) : 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('netCashflow'),
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSurplus
                      ? AppTheme.emeraldGreen.withValues(alpha: 0.16)
                      : AppTheme.coralRose.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSurplus ? _t('surplus') : _t('deficit'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSurplus ? AppTheme.emeraldGreen : AppTheme.coralRose,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _currencyFormat.format(netSavings),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isSurplus ? AppTheme.emeraldGreen : AppTheme.coralRose,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_t('income'), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        const SizedBox(width: 4),
                        Text('($incomeCount tx)', style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+${_currencyFormat.format(income)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: AppTheme.borderDark),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_t('expense'), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        const SizedBox(width: 4),
                        Text('($expenseCount tx)', style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '-${_currencyFormat.format(expense)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.coralRose),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (income > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (expense / income).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: AppTheme.emeraldGreen.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.coralRose),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_t('savingsRate')}: ${savingsRate.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Total: $totalTxCount ${_t('filterTransfer').toLowerCase() != 'transfer' ? 'tx' : 'transaksi'}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChartSection({
    required List<MapEntry<String, double>> activeChartEntries,
    required double activeChartTotal,
    required Map<String, CategoryItem> catMap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _showExpenseChart ? _t('secExpenseByCategory') : _t('secIncomeByCategory'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppTheme.textSecondary,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceLighter,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Row(
                children: [
                  _buildChartToggleBtn(
                    key: const Key('chart_toggle_expense'),
                    label: _t('filterExpense'),
                    isSelected: _showExpenseChart,
                    activeColor: AppTheme.coralRose,
                    onTap: () => setState(() {
                      _showExpenseChart = true;
                      _touchedChartIndex = -1;
                    }),
                  ),
                  _buildChartToggleBtn(
                    key: const Key('chart_toggle_income'),
                    label: _t('filterIncome'),
                    isSelected: !_showExpenseChart,
                    activeColor: AppTheme.emeraldGreen,
                    onTap: () => setState(() {
                      _showExpenseChart = false;
                      _touchedChartIndex = -1;
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (activeChartEntries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    _showExpenseChart ? Icons.receipt_long_outlined : Icons.account_balance_wallet_outlined,
                    color: AppTheme.textMuted,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showExpenseChart ? _t('noExpenseData') : _t('noIncomeData'),
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedChartIndex = -1;
                          return;
                        }
                        _touchedChartIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 3,
                  centerSpaceRadius: 50,
                  sections: activeChartEntries.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final isTouched = idx == _touchedChartIndex;
                    final cat = catMap[item.key];
                    final percent = activeChartTotal > 0 ? (item.value / activeChartTotal) * 100 : 0.0;
                    final color = cat != null ? Color(cat.colorValue) : AppTheme.cyanAccent;

                    return PieChartSectionData(
                      color: color,
                      value: item.value,
                      title: '${percent.toInt()}%',
                      radius: isTouched ? 36.0 : 28.0,
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeChartEntries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = activeChartEntries[index];
              final cat = catMap[item.key];
              final percent = activeChartTotal > 0 ? ((item.value / activeChartTotal) * 100).toInt() : 0;
              final color = cat != null ? Color(cat.colorValue) : AppTheme.cyanAccent;
              final isFilteredByThisCat = _selectedCategoryId == item.key;

              return InkWell(
                onTap: () {
                  setState(() {
                    if (_selectedCategoryId == item.key) {
                      _selectedCategoryId = null;
                    } else {
                      _selectedCategoryId = item.key;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isFilteredByThisCat ? color.withValues(alpha: 0.15) : AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isFilteredByThisCat ? color : AppTheme.borderDark,
                      width: isFilteredByThisCat ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat?.name ?? 'Umum',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: activeChartTotal > 0 ? (item.value / activeChartTotal) : 0,
                                minHeight: 3,
                                backgroundColor: AppTheme.surfaceLighter,
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$percent%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            _currencyFormat.format(item.value),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _showExpenseChart ? AppTheme.coralRose : AppTheme.emeraldGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isFilteredByThisCat ? Icons.check_circle : Icons.filter_list,
                        size: 14,
                        color: isFilteredByThisCat ? color : AppTheme.textMuted,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildChartToggleBtn({
    Key? key,
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? activeColor : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterControlsBar({
    required List<CategoryItem> categories,
    required List<Wallet> wallets,
    required List<TransactionItem> allTransactions,
  }) {
    final monthShort = DateFormat('MMM yyyy', _isId ? 'id_ID' : 'en_US').format(_currentPeriodDate);
    final monthBtnLabel = _isMonthlyMode
        ? '${_t('filterMonth')}: $monthShort'
        : '${_t('filterMonth')}: ${_t('allMonths')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Search Bar
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: _t('searchHintReport'),
              hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textMuted),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 2. Filter Pills Row (Bulan, Type, Category, Wallet, Sort)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Dedicated Month Filter Button
              _buildFilterDropdownButton(
                key: const Key('filter_btn_month'),
                label: monthBtnLabel,
                isActive: _isMonthlyMode,
                icon: Icons.calendar_month_outlined,
                onTap: () => _showMonthFilterSheet(allTransactions),
              ),
              const SizedBox(width: 8),

              // Type Filter Button
              _buildFilterDropdownButton(
                label: _selectedType == 'all'
                    ? _t('filterAll')
                    : (_selectedType == 'expense'
                        ? _t('filterExpense')
                        : (_selectedType == 'income' ? _t('filterIncome') : _t('filterTransfer'))),
                isActive: _selectedType != 'all',
                icon: Icons.layers_outlined,
                onTap: _showTypeFilterSheet,
              ),
              const SizedBox(width: 8),

              // Category Filter Button
              _buildFilterDropdownButton(
                label: _selectedCategoryId != null
                    ? (categories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => categories.first).name)
                    : _t('filterCategory'),
                isActive: _selectedCategoryId != null,
                icon: Icons.category_outlined,
                onTap: () => _showCategoryFilterSheet(categories),
              ),
              const SizedBox(width: 8),

              // Wallet Filter Button
              _buildFilterDropdownButton(
                label: _selectedWalletId != null
                    ? (wallets.firstWhere((w) => w.id == _selectedWalletId, orElse: () => wallets.first).name)
                    : _t('filterWallet'),
                isActive: _selectedWalletId != null,
                icon: Icons.account_balance_wallet_outlined,
                onTap: () => _showWalletFilterSheet(wallets),
              ),
              const SizedBox(width: 8),

              // Sort Option Button
              _buildFilterDropdownButton(
                label: _getSortLabel(),
                isActive: _sortOption != 'newest',
                icon: Icons.sort,
                onTap: _showSortOptionSheet,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdownButton({
    Key? key,
    required String label,
    required bool isActive,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.cyanAccent.withValues(alpha: 0.18) : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppTheme.cyanAccent : AppTheme.borderDark,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? AppTheme.cyanAccent : AppTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppTheme.cyanAccent : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: isActive ? AppTheme.cyanAccent : AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  String _getSortLabel() {
    switch (_sortOption) {
      case 'oldest':
        return _t('sortOldest');
      case 'amount_high':
        return _t('sortAmountHigh');
      case 'amount_low':
        return _t('sortAmountLow');
      case 'newest':
      default:
        return _t('sortNewest');
    }
  }

  // --- Filter Bottom Sheets ---

  void _showTypeFilterSheet() {
    final types = [
      {'val': 'all', 'label': _t('filterAll'), 'icon': Icons.all_inclusive},
      {'val': 'expense', 'label': _t('filterExpense'), 'icon': Icons.arrow_upward},
      {'val': 'income', 'label': _t('filterIncome'), 'icon': Icons.arrow_downward},
      {'val': 'transfer', 'label': _t('filterTransfer'), 'icon': Icons.swap_horiz},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: types.map((t) {
              final isSelected = _selectedType == t['val'];
              return ListTile(
                leading: Icon(t['icon'] as IconData, color: isSelected ? AppTheme.cyanAccent : AppTheme.textMuted),
                title: Text(t['label'] as String, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: AppTheme.textPrimary)),
                trailing: isSelected ? const Icon(Icons.check, color: AppTheme.cyanAccent) : null,
                onTap: () {
                  setState(() => _selectedType = t['val'] as String);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showCategoryFilterSheet(List<CategoryItem> categories) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollCtrl) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_t('allCategories'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.all_inclusive, color: AppTheme.cyanAccent),
                      title: Text(_t('allCategories'), style: TextStyle(fontWeight: _selectedCategoryId == null ? FontWeight.bold : FontWeight.normal, color: AppTheme.textPrimary)),
                      trailing: _selectedCategoryId == null ? const Icon(Icons.check, color: AppTheme.cyanAccent) : null,
                      onTap: () {
                        setState(() => _selectedCategoryId = null);
                        Navigator.pop(ctx);
                      },
                    ),
                    ...categories.map((c) {
                      final isSelected = _selectedCategoryId == c.id;
                      return ListTile(
                        leading: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(color: Color(c.colorValue), shape: BoxShape.circle),
                        ),
                        title: Text(c.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: AppTheme.textPrimary)),
                        trailing: isSelected ? const Icon(Icons.check, color: AppTheme.cyanAccent) : null,
                        onTap: () {
                          setState(() => _selectedCategoryId = c.id);
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWalletFilterSheet(List<Wallet> wallets) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.all_inclusive, color: AppTheme.cyanAccent),
                title: Text(_t('allWallets'), style: TextStyle(fontWeight: _selectedWalletId == null ? FontWeight.bold : FontWeight.normal, color: AppTheme.textPrimary)),
                trailing: _selectedWalletId == null ? const Icon(Icons.check, color: AppTheme.cyanAccent) : null,
                onTap: () {
                  setState(() => _selectedWalletId = null);
                  Navigator.pop(ctx);
                },
              ),
              ...wallets.map((w) {
                final isSelected = _selectedWalletId == w.id;
                return ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.emeraldGreen),
                  title: Text(w.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: AppTheme.textPrimary)),
                  subtitle: Text(_currencyFormat.format(w.balance), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  trailing: isSelected ? const Icon(Icons.check, color: AppTheme.cyanAccent) : null,
                  onTap: () {
                    setState(() => _selectedWalletId = w.id);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortOptionSheet() {
    final sortOptions = [
      {'val': 'newest', 'label': _t('sortNewest'), 'icon': Icons.arrow_downward},
      {'val': 'oldest', 'label': _t('sortOldest'), 'icon': Icons.arrow_upward},
      {'val': 'amount_high', 'label': _t('sortAmountHigh'), 'icon': Icons.trending_up},
      {'val': 'amount_low', 'label': _t('sortAmountLow'), 'icon': Icons.trending_down},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: sortOptions.map((s) {
              final isSelected = _sortOption == s['val'];
              return ListTile(
                leading: Icon(s['icon'] as IconData, color: isSelected ? AppTheme.cyanAccent : AppTheme.textMuted),
                title: Text(s['label'] as String, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: AppTheme.textPrimary)),
                trailing: isSelected ? const Icon(Icons.check, color: AppTheme.cyanAccent) : null,
                onTap: () {
                  setState(() => _sortOption = s['val'] as String);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // --- Filtered Transaction List View ---

  Widget _buildTransactionList({
    required List<TransactionItem> transactions,
    required Map<String, CategoryItem> catMap,
    required Map<String, Wallet> walletMap,
  }) {
    if (transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.search_off_outlined, color: AppTheme.textMuted, size: 36),
              const SizedBox(height: 10),
              Text(
                _t('noTransactionsFound'),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _resetAllFilters,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(_t('resetFilters'), style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.cyanAccent,
                    side: const BorderSide(color: AppTheme.cyanAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final t = transactions[index];
        final cat = catMap[t.categoryId];
        final wallet = walletMap[t.walletId];
        final isExp = t.type == 'expense';
        final isInc = t.type == 'income';
        final isTransfer = t.type == 'transfer';

        final catColor = cat != null ? Color(cat.colorValue) : AppTheme.textSecondary;

        return InkWell(
          onTap: () => _showTransactionDetail(t, catMap, walletMap),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      isInc ? Icons.arrow_downward : (isTransfer ? Icons.swap_horiz : Icons.shopping_bag_outlined),
                      color: catColor,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.note.trim().isEmpty ? (cat?.name ?? (_isId ? 'Transaksi' : 'Transaction')) : t.note,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${cat?.name ?? "Umum"} • ${wallet?.name ?? "Kas"} • ${DateFormat('dd MMM HH:mm', _isId ? 'id_ID' : 'en_US').format(t.date)}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      isExp
                          ? '-${_currencyFormat.format(t.amount)}'
                          : (isInc ? '+${_currencyFormat.format(t.amount)}' : _currencyFormat.format(t.amount)),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isExp ? AppTheme.coralRose : (isInc ? AppTheme.emeraldGreen : AppTheme.cyanAccent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _confirmDeleteTransaction(t),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline, size: 16, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_item.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../services/storage_service.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import 'add_transaction_modal.dart';
import 'budget_screen.dart';
import '../services/locale_service.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;
  final AiService aiService;
  final LocaleService? localeService;
  final VoidCallback onDataChanged;
  final Function(int) onNavigateToTab;
  final VoidCallback onOpenAiAssistant;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.aiService,
    this.localeService,
    required this.onDataChanged,
    required this.onNavigateToTab,
    required this.onOpenAiAssistant,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isBalanceHidden = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  void _openAddModal({String? initialType, bool openWithVoice = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionModal(
        storageService: widget.storageService,
        aiService: widget.aiService,
        initialType: initialType,
        openWithVoice: openWithVoice,
        onTransactionAdded: () {
          setState(() {});
          widget.onDataChanged();
        },
      ),
    );
  }

  void _showScanReceiptDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.borderDark)),
          title: const Row(
            children: [
              Icon(Icons.receipt_long, color: AppTheme.cyanAccent),
              SizedBox(width: 8),
              Text('Scan Foto Struk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fitur OCR Struk membaca struk belanja langsung secara offline di perangkat.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLighter,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Simulasi Deteksi Struk Terakhir:', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    SizedBox(height: 4),
                    Text('Toko: Superindo Minimarket', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    Text('Total: Rp 114.500', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.coralRose)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _openAddModal(initialType: 'expense');
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cyanAccent, foregroundColor: Colors.black),
              child: const Text('Buat Transaksi', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final totalBalance = widget.storageService.getTotalBalance();
    final monthlyIncome = widget.storageService.getMonthlyIncome(now.month, now.year);
    final monthlyExpense = widget.storageService.getMonthlyExpense(now.month, now.year);
    final wallets = widget.storageService.getWallets();
    final transactions = widget.storageService.getTransactions();
    final categories = widget.storageService.getCategories();
    final budgets = widget.storageService.getBudgets(now.month, now.year);
    final totalSavings = widget.storageService.getTotalSavingsBalance();
    final monthlySavingsIn = widget.storageService.getMonthlySavingsIn(now.month, now.year);
    final monthlySavingsOut = widget.storageService.getMonthlySavingsOut(now.month, now.year);
    final savingsPockets = widget.storageService.getSavingsPockets();

    final catMap = {for (var c in categories) c.id: c};
    final walletMap = {for (var w in wallets) w.id: w};

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppTheme.emeraldGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'IRITOT',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLighter,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.borderDark),
                        ),
                        child: Text(
                          widget.localeService?.t('personalBadge') ?? 'PERSONAL',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Tombol Buka Assistant AI
                      GestureDetector(
                        onTap: widget.onOpenAiAssistant,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.violetAI.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.violetAI.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: AppTheme.violetAI, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'AI',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.violetAI),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => setState(() => _isBalanceHidden = !_isBalanceHidden),
                        icon: Icon(
                          _isBalanceHidden ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                        tooltip: 'Balance Privacy',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Hero Balance Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF161F30), Color(0xFF0F1726)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.borderDark, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.localeService?.t('totalCashBalance') ?? 'TOTAL CASH BALANCE',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        Text(
                          DateFormat('MMMM yyyy', widget.localeService?.isIndonesian == true ? 'id_ID' : 'en_US').format(now),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.emeraldGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isBalanceHidden ? 'Rp ••••••••' : _currencyFormat.format(totalBalance),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.only(top: 14),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0xFF1D2A40))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.localeService?.t('income') ?? 'Income', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  _isBalanceHidden ? '+Rp •••' : '+${_currencyFormat.format(monthlyIncome)}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 28, color: const Color(0xFF1D2A40)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.localeService?.t('expense') ?? 'Expense', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  _isBalanceHidden ? '-Rp •••' : '-${_currencyFormat.format(monthlyExpense)}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.coralRose),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Dompet Saya (Wallets Carousel)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.localeService?.t('secWallets') ?? 'MY WALLETS & ACCOUNTS',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateToTab(4),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    child: Text(widget.localeService?.t('manage') ?? 'Manage', style: const TextStyle(fontSize: 12, color: AppTheme.cyanAccent)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: wallets.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final wallet = wallets[index];
                    return Container(
                      width: 140,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            wallet.name,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isBalanceHidden ? '••••••' : _currencyFormat.format(wallet.balance),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Tabungan & Celengan (Savings Summary Card)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.localeService?.t('secSavings') ?? 'SAVINGS & POCKETS',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateToTab(1),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    child: Text(widget.localeService?.t('seeAll') ?? 'See All', style: const TextStyle(fontSize: 12, color: AppTheme.emeraldGreen)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => widget.onNavigateToTab(1),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF132225), Color(0xFF0F1A1C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.emeraldGreen.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.savings_rounded, color: AppTheme.emeraldGreen, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.localeService?.t('totalSaved') ?? 'Total Saved',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const Icon(Icons.chevron_right, size: 18, color: AppTheme.emeraldGreen),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isBalanceHidden ? 'Rp ••••••••' : _currencyFormat.format(totalSavings),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_downward, color: AppTheme.emeraldGreen, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.localeService?.t('inflow') ?? 'In'}: ${_isBalanceHidden ? '•••' : _currencyFormat.format(monthlySavingsIn)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_upward, color: AppTheme.coralRose, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.localeService?.t('outflow') ?? 'Out'}: ${_isBalanceHidden ? '•••' : _currencyFormat.format(monthlySavingsOut)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.coralRose),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (savingsPockets.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: savingsPockets.take(3).map((p) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Color(p.colorValue).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Color(p.colorValue).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '${p.name}: ${p.progressPercent}%',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(p.colorValue)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Aksi Cepat
              Text(
                widget.localeService?.t('quickActions') ?? 'QUICK ACTIONS',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildActionButton(
                    icon: Icons.edit_note,
                    label: widget.localeService?.t('navLog') ?? 'Log',
                    color: AppTheme.emeraldGreen,
                    onTap: () => _openAddModal(),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.mic,
                    label: widget.localeService?.t('actionVoice') ?? 'Voice',
                    color: AppTheme.violetAI,
                    onTap: () => _openAddModal(openWithVoice: true),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.document_scanner,
                    label: widget.localeService?.t('actionScan') ?? 'Receipt',
                    color: AppTheme.cyanAccent,
                    onTap: _showScanReceiptDialog,
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.swap_horiz,
                    label: 'Transfer',
                    color: AppTheme.amberWarning,
                    onTap: () => _openAddModal(initialType: 'transfer'),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Pantauan Anggaran
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.localeService?.t('secBudget') ?? 'MONTHLY BUDGET PROGRESS',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BudgetScreen(
                            storageService: widget.storageService,
                            onDataChanged: widget.onDataChanged,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    child: Text(widget.localeService?.t('seeAll') ?? 'See All', style: const TextStyle(fontSize: 12, color: AppTheme.cyanAccent)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildBudgetCard(budgets, transactions, catMap, now),
              const SizedBox(height: 22),

              // Transaksi Terbaru
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.localeService?.t('secRecentTransactions') ?? 'RECENT TRANSACTIONS',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateToTab(3),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    child: Text(widget.localeService?.t('seeAll') ?? 'See All', style: const TextStyle(fontSize: 12, color: AppTheme.cyanAccent)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (transactions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long, size: 36, color: AppTheme.textMuted),
                      const SizedBox(height: 8),
                      Text(widget.localeService?.t('noTransactions') ?? 'No transactions recorded yet', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      const Text('Press (+) below to log your transaction.', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.take(6).length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    final cat = catMap[t.categoryId];
                    final wallet = walletMap[t.walletId];
                    final isExp = t.type == 'expense';
                    final isInc = t.type == 'income';

                    return Dismissible(
                      key: Key(t.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.coralRose,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) async {
                        await widget.storageService.deleteTransaction(t.id);
                        setState(() {});
                        widget.onDataChanged();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderDark),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: cat != null ? Color(cat.colorValue).withValues(alpha: 0.18) : AppTheme.surfaceLighter,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isInc ? Icons.arrow_downward : (t.type == 'transfer' ? Icons.swap_horiz : Icons.shopping_bag_outlined),
                                      color: cat != null ? Color(cat.colorValue) : AppTheme.textSecondary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.note,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${cat?.name ?? 'Umum'} • ${wallet?.name ?? 'Kas'} • ${DateFormat('dd MMM', 'id_ID').format(t.date)}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              isExp ? '-${_currencyFormat.format(t.amount)}' : (isInc ? '+${_currencyFormat.format(t.amount)}' : _currencyFormat.format(t.amount)),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isExp ? AppTheme.coralRose : (isInc ? AppTheme.emeraldGreen : AppTheme.cyanAccent),
                              ),
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
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetCard(
    List<Budget> budgets,
    List<TransactionItem> transactions,
    Map<String, CategoryItem> catMap,
    DateTime now,
  ) {
    if (budgets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: const Text(
          'Belum ada anggaran bulanan yang disetel. Buka tab Anggaran untuk menyetel batas belanja.',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        children: budgets.take(2).map((b) {
          final cat = catMap[b.categoryId];
          final spent = transactions
              .where((t) =>
                  t.categoryId == b.categoryId &&
                  t.type == 'expense' &&
                  t.date.month == now.month &&
                  t.date.year == now.year)
              .fold(0.0, (sum, t) => sum + t.amount);

          final ratio = (spent / b.monthlyLimit).clamp(0.0, 1.0);
          final percent = ((spent / b.monthlyLimit) * 100).toInt();
          final isWarning = percent >= 80;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cat?.name ?? 'Kategori',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isWarning ? AppTheme.coralRose : AppTheme.emeraldGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: AppTheme.surfaceLighter,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isWarning ? AppTheme.coralRose : AppTheme.emeraldGreen,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

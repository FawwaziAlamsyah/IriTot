import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../services/locale_service.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_input_formatter.dart';

class BudgetScreen extends StatefulWidget {
  final StorageService storageService;
  final LocaleService? localeService;
  final VoidCallback onDataChanged;
  final bool showAppBar;

  const BudgetScreen({
    super.key,
    required this.storageService,
    this.localeService,
    required this.onDataChanged,
    this.showAppBar = true,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String t(String key) => widget.localeService?.t(key) ?? key;

  bool _isSavingsCategory(CategoryItem c) {
    if (c.id == 'cat_savings') return true;
    final name = c.name.toLowerCase();
    return name.contains('tabung') || name.contains('pocket') || name.contains('saving');
  }

  void _showSetBudgetDialog(CategoryItem category, double currentLimit) {
    _showAddOrEditBudgetDialog(preselectedCategory: category, currentLimit: currentLimit);
  }

  void _showAddOrEditBudgetDialog({CategoryItem? preselectedCategory, double? currentLimit}) {
    final now = DateTime.now();
    final expenseCategories = widget.storageService
        .getCategories()
        .where((c) => c.type == 'expense' && !_isSavingsCategory(c))
        .toList();
    if (expenseCategories.isEmpty) return;

    final expenseCatIds = expenseCategories.map((c) => c.id).toSet();
    final existingBudgets = widget.storageService
        .getBudgets(now.month, now.year)
        .where((b) => expenseCatIds.contains(b.categoryId))
        .toList();
    final budgetMap = {for (var b in existingBudgets) b.categoryId: b.monthlyLimit};
    final wallets = widget.storageService.getWallets();
    final totalCash = widget.storageService.getTotalBalance();

    CategoryItem selectedCategory = preselectedCategory ?? expenseCategories.first;
    double limitVal = currentLimit ?? budgetMap[selectedCategory.id] ?? 0.0;

    final controller = TextEditingController(
      text: limitVal > 0 ? ThousandsSeparatorInputFormatter.format(limitVal) : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isEditing = limitVal > 0;
            final otherBudgetsTotal = existingBudgets
                .where((b) => b.categoryId != selectedCategory.id)
                .fold(0.0, (sum, b) => sum + b.monthlyLimit);
            final maxSafeBudget = (totalCash - otherBudgetsTotal).clamp(0.0, double.infinity);
            final enteredAmount = ThousandsSeparatorInputFormatter.parse(controller.text);
            final isOverCash = enteredAmount > maxSafeBudget;

            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.borderDark),
              ),
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline,
                    color: isEditing ? AppTheme.cyanAccent : AppTheme.emeraldGreen,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEditing ? '${t('editBudget')}: ${selectedCategory.name}' : t('addBudget'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Referensi Total Kas dan Dompet
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLighter,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: maxSafeBudget <= 0 ? AppTheme.amberWarning.withValues(alpha: 0.4) : AppTheme.borderDark,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppTheme.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    t('walletCashReference'),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                              Text(
                                _currencyFormat.format(totalCash),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                t('safeAllocationLeft'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                              ),
                              Text(
                                _currencyFormat.format(maxSafeBudget),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: maxSafeBudget > 0 ? AppTheme.cyanAccent : AppTheme.coralRose,
                                ),
                              ),
                            ],
                          ),
                          if (wallets.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1, color: AppTheme.borderDark),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: wallets.map((w) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceDark,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.borderDark.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    '${w.name}: ${_currencyFormat.format(w.balance)}',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (preselectedCategory == null) ...[
                      Text(t('selectCategory'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLighter,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderDark),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategory.id,
                            isExpanded: true,
                            dropdownColor: AppTheme.surfaceDark,
                            items: expenseCategories.map((c) {
                              return DropdownMenuItem(
                                value: c.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Color(c.colorValue),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(c.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final newCat = expenseCategories.firstWhere((c) => c.id == val);
                                final newLimit = budgetMap[val] ?? 0.0;
                                setDialogState(() {
                                  selectedCategory = newCat;
                                  limitVal = newLimit;
                                  controller.text = newLimit > 0 ? ThousandsSeparatorInputFormatter.format(newLimit) : '';
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(t('enterMonthlyLimit'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      onChanged: (_) => setDialogState(() {}),
                      style: TextStyle(
                        color: isOverCash ? AppTheme.coralRose : AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 16, fontWeight: FontWeight.w700),
                        hintText: '0',
                        filled: true,
                        fillColor: AppTheme.surfaceLighter,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderDark)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isOverCash ? AppTheme.coralRose : AppTheme.emeraldGreen, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    if (isOverCash) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.coralRose),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${t('errBudgetExceedsCash')} (${widget.localeService?.isIndonesian == true ? 'Maks' : 'Max'}: ${_currencyFormat.format(maxSafeBudget)})',
                              style: const TextStyle(fontSize: 11, color: AppTheme.coralRose, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (maxSafeBudget > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(
                                  t('useRemainingCash'),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.cyanAccent),
                                ),
                                backgroundColor: AppTheme.cyanAccent.withValues(alpha: 0.12),
                                side: BorderSide(color: AppTheme.cyanAccent.withValues(alpha: 0.4)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                onPressed: () {
                                  setDialogState(() {
                                    controller.text = ThousandsSeparatorInputFormatter.format(maxSafeBudget);
                                  });
                                },
                              ),
                            ),
                          ...[100000, 250000, 500000, 1000000, 2000000, 5000000].map((amt) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(
                                  '+${amt >= 1000000 ? '${amt ~/ 1000000}jt' : '${amt ~/ 1000}rb'}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                                ),
                                backgroundColor: AppTheme.surfaceLighter,
                                side: const BorderSide(color: AppTheme.borderDark),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                onPressed: () {
                                  final cur = ThousandsSeparatorInputFormatter.parse(controller.text);
                                  setDialogState(() {
                                    controller.text = ThousandsSeparatorInputFormatter.format(cur + amt);
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (limitVal > 0)
                  TextButton(
                    onPressed: () async {
                      final navigator = Navigator.of(dialogContext);
                      await widget.storageService.deleteBudget(selectedCategory.id, now.month, now.year);
                      if (mounted) {
                        setState(() {});
                        widget.onDataChanged();
                      }
                      navigator.pop();
                    },
                    child: Text(t('deleteBudget'), style: const TextStyle(color: AppTheme.coralRose, fontWeight: FontWeight.w600)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(t('cancel'), style: const TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final limit = ThousandsSeparatorInputFormatter.parse(controller.text);
                    if (limit > maxSafeBudget && totalCash > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${t('errBudgetExceedsCash')} (${widget.localeService?.isIndonesian == true ? 'Maks' : 'Max'}: ${_currencyFormat.format(maxSafeBudget)})',
                          ),
                          backgroundColor: AppTheme.coralRose,
                        ),
                      );
                      return;
                    }

                    final navigator = Navigator.of(dialogContext);
                    if (limit <= 0) {
                      await widget.storageService.deleteBudget(selectedCategory.id, now.month, now.year);
                    } else {
                      await widget.storageService.setBudget(selectedCategory.id, limit, now.month, now.year);
                    }
                    if (mounted) {
                      setState(() {});
                      widget.onDataChanged();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(t('budgetSavedSuccess')),
                          backgroundColor: AppTheme.emeraldGreen,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                    navigator.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emeraldGreen,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(t('save'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Exclude pocket / savings allocations from Monthly Budget calculations
    final categories = widget.storageService
        .getCategories()
        .where((c) => c.type == 'expense' && !_isSavingsCategory(c))
        .toList();
    final expenseCatIds = categories.map((c) => c.id).toSet();
    final budgets = widget.storageService
        .getBudgets(now.month, now.year)
        .where((b) => expenseCatIds.contains(b.categoryId))
        .toList();
    final transactions = widget.storageService.getTransactions().where(
          (t) => t.type == 'expense' &&
                 expenseCatIds.contains(t.categoryId) &&
                 t.date.month == now.month &&
                 t.date.year == now.year,
        ).toList();

    final budgetMap = {for (var b in budgets) b.categoryId: b.monthlyLimit};
    final totalCash = widget.storageService.getTotalBalance();

    double totalBudget = 0.0;
    double totalSpent = 0.0;

    for (final c in categories) {
      final limit = budgetMap[c.id] ?? 0.0;
      totalBudget += limit;
      final spent = transactions.where((t) => t.categoryId == c.id).fold(0.0, (sum, t) => sum + t.amount);
      totalSpent += spent;
    }

    final overallRatio = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final overallPercent = totalBudget > 0 ? ((totalSpent / totalBudget) * 100).toInt() : 0;

    final body = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B2335), Color(0xFF131B2A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t('totalBudgetThisMonth'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.8),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: overallPercent >= 80 ? AppTheme.coralRose.withValues(alpha: 0.2) : AppTheme.emeraldGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$overallPercent% ${t('used')}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: overallPercent >= 80 ? AppTheme.coralRose : AppTheme.emeraldGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _currencyFormat.format(totalSpent),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/ ${_currencyFormat.format(totalBudget)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: overallRatio,
                    backgroundColor: AppTheme.surfaceLighter,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      overallPercent >= 80 ? AppTheme.coralRose : AppTheme.emeraldGreen,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: totalBudget > totalCash ? AppTheme.coralRose.withValues(alpha: 0.4) : AppTheme.borderDark,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            totalBudget > totalCash ? Icons.warning_amber_rounded : Icons.account_balance_wallet_outlined,
                            size: 14,
                            color: totalBudget > totalCash ? AppTheme.coralRose : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t('walletCashReference'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: totalBudget > totalCash ? AppTheme.coralRose : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _currencyFormat.format(totalCash),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: totalBudget > totalCash ? AppTheme.coralRose : AppTheme.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t('categoryBreakdown'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.textSecondary),
              ),
              InkWell(
                onTap: () => _showAddOrEditBudgetDialog(),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle_outline, size: 15, color: AppTheme.emeraldGreen),
                      const SizedBox(width: 4),
                      Text(
                        t('addBudget'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (categories.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Center(
                child: Text(t('noBudgetSet'), style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final limit = budgetMap[cat.id] ?? 0.0;
                final spent = transactions.where((t) => t.categoryId == cat.id).fold(0.0, (sum, t) => sum + t.amount);
                final ratio = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
                final percent = limit > 0 ? ((spent / limit) * 100).toInt() : 0;
                final isWarning = percent >= 80;

                return GestureDetector(
                  onTap: () => _showSetBudgetDialog(cat, limit),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderDark),
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
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Color(cat.colorValue),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cat.name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  limit > 0 ? '$percent%' : t('notSet'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: limit > 0 ? (isWarning ? AppTheme.coralRose : AppTheme.emeraldGreen) : AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLighter,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.borderDark),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(limit > 0 ? Icons.edit_outlined : Icons.add, size: 11, color: AppTheme.textSecondary),
                                      const SizedBox(width: 3),
                                      Text(
                                        limit > 0 ? t('edit') : t('add'),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${t('spent')}: ${_currencyFormat.format(spent)}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            Text(
                              '${t('limit')}: ${_currencyFormat.format(limit)}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: AppTheme.surfaceLighter,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isWarning ? AppTheme.coralRose : Color(cat.colorValue),
                            ),
                            minHeight: 5,
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
    );

    if (!widget.showAppBar) {
      return body;
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(t('budgetMonitoring')),
      ),
      body: SafeArea(child: body),
    );
  }
}

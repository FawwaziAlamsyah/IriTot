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

  void _showAddBudgetDialog({CategoryItem? preselectedCategory}) {
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
    final totalCash = widget.storageService.getTotalBalance();
    final wallets = widget.storageService.getWallets();

    CategoryItem selectedCategory = preselectedCategory ?? expenseCategories.first;
    String selectedWalletId = existingBudgets
            .where((b) => b.categoryId == selectedCategory.id)
            .firstOrNull
            ?.walletId ??
        (wallets.isNotEmpty ? wallets.first.id : 'w_cash');
    if (!wallets.any((w) => w.id == selectedWalletId) && wallets.isNotEmpty) {
      selectedWalletId = wallets.first.id;
    }
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final totalMonthlyBudget = existingBudgets.fold(0.0, (sum, b) => sum + b.monthlyLimit);
            final maxSafeBudget = (totalCash - totalMonthlyBudget).clamp(0.0, double.infinity);
            final currentLimit = budgetMap[selectedCategory.id] ?? 0.0;
            final addAmount = ThousandsSeparatorInputFormatter.parse(controller.text);
            final isOverCash = addAmount > maxSafeBudget;
            final previewLimit = currentLimit + addAmount;

            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.borderDark),
              ),
              titlePadding: const EdgeInsets.fromLTRB(18, 16, 12, 0),
              contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              title: Row(
                children: [
                  const Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.emeraldGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ADD: ${selectedCategory.name}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                t('currentCategoryLimit'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                              ),
                              Text(
                                _currencyFormat.format(currentLimit),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
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
                                final existingBoundWallet = existingBudgets
                                    .where((b) => b.categoryId == newCat.id)
                                    .firstOrNull
                                    ?.walletId;
                                setDialogState(() {
                                  selectedCategory = newCat;
                                  if (existingBoundWallet != null && wallets.any((w) => w.id == existingBoundWallet)) {
                                    selectedWalletId = existingBoundWallet;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Pilihan Dompet Sumber Dana Anggaran
                    Text(
                      t('sourceWalletFunding'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
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
                          value: selectedWalletId,
                          isExpanded: true,
                          dropdownColor: AppTheme.surfaceDark,
                          items: wallets.map((w) {
                            final isZero = w.balance <= 0;
                            return DropdownMenuItem(
                              value: w.id,
                              child: Row(
                                children: [
                                  Icon(Icons.account_balance_wallet_outlined, size: 14, color: isZero ? AppTheme.textMuted : AppTheme.emeraldGreen),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      w.name,
                                      style: TextStyle(
                                        color: isZero ? AppTheme.textMuted : AppTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    _currencyFormat.format(w.balance),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isZero ? AppTheme.coralRose : AppTheme.emeraldGreen,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedWalletId = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(t('enterAddAmount'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      scrollPadding: const EdgeInsets.all(80),
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
                    if (addAmount > 0 && !isOverCash) ...[
                      const SizedBox(height: 6),
                      Text(
                        t('afterAddInfo').replaceAll('{limit}', _currencyFormat.format(previewLimit)),
                        style: const TextStyle(fontSize: 11, color: AppTheme.emeraldGreen, fontWeight: FontWeight.w600),
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
                          ...[50000, 100000, 250000, 500000, 1000000].map((amt) {
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
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.borderDark),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            t('cancel'),
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          onPressed: () async {
                            final add = ThousandsSeparatorInputFormatter.parse(controller.text);
                            if (add <= 0) return;
                            if (add > maxSafeBudget && totalCash > 0) {
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
                            final updatedLimit = currentLimit + add;
                            await widget.storageService.setBudget(selectedCategory.id, updatedLimit, now.month, now.year, selectedWalletId);
                            if (mounted) {
                              setState(() {});
                              widget.onDataChanged();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    t('addBudgetSuccess').replaceAll('{amount}', _currencyFormat.format(add)),
                                  ),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(t('add'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCairkanBudgetDialog(CategoryItem category, double currentLimit) {
    final now = DateTime.now();
    final expenseCategories = widget.storageService
        .getCategories()
        .where((c) => c.type == 'expense' && !_isSavingsCategory(c))
        .toList();
    final expenseCatIds = expenseCategories.map((c) => c.id).toSet();
    final existingBudgets = widget.storageService
        .getBudgets(now.month, now.year)
        .where((b) => expenseCatIds.contains(b.categoryId))
        .toList();
    final totalCash = widget.storageService.getTotalBalance();
    final totalMonthlyBudget = existingBudgets.fold(0.0, (sum, b) => sum + b.monthlyLimit);
    final maxSafeBudget = (totalCash - totalMonthlyBudget).clamp(0.0, double.infinity);

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final cairkanAmount = ThousandsSeparatorInputFormatter.parse(controller.text);
            final isOverLimit = cairkanAmount > currentLimit;
            final previewLimit = (currentLimit - cairkanAmount).clamp(0.0, double.infinity);

            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.borderDark),
              ),
              titlePadding: const EdgeInsets.fromLTRB(18, 16, 12, 0),
              contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              title: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppTheme.cyanAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${t('cairkanBudgetTitle')}: ${category.name}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLighter,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                t('currentCategoryLimit'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                              ),
                              Text(
                                _currencyFormat.format(currentLimit),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.coralRose),
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
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.cyanAccent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(t('enterCairkanAmount'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      scrollPadding: const EdgeInsets.all(80),
                      onChanged: (_) => setDialogState(() {}),
                      style: TextStyle(
                        color: isOverLimit ? AppTheme.coralRose : AppTheme.textPrimary,
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
                          borderSide: BorderSide(color: isOverLimit ? AppTheme.coralRose : AppTheme.cyanAccent, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    if (isOverLimit) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.coralRose),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${t('errCairkanExceedsLimit')} (${widget.localeService?.isIndonesian == true ? 'Maks' : 'Max'}: ${_currencyFormat.format(currentLimit)})',
                              style: const TextStyle(fontSize: 11, color: AppTheme.coralRose, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (cairkanAmount > 0 && !isOverLimit) ...[
                      const SizedBox(height: 6),
                      Text(
                        t('afterCairkanInfo').replaceAll('{limit}', _currencyFormat.format(previewLimit)),
                        style: const TextStyle(fontSize: 11, color: AppTheme.cyanAccent, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (currentLimit > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(
                                  t('cairkanAll'),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.coralRose),
                                ),
                                backgroundColor: AppTheme.coralRose.withValues(alpha: 0.12),
                                side: BorderSide(color: AppTheme.coralRose.withValues(alpha: 0.4)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                onPressed: () {
                                  setDialogState(() {
                                    controller.text = ThousandsSeparatorInputFormatter.format(currentLimit);
                                  });
                                },
                              ),
                            ),
                          ...[50000, 100000, 250000, 500000].where((amt) => amt <= currentLimit).map((amt) {
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
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.borderDark),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            t('cancel'),
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          onPressed: () async {
                            final cairkan = ThousandsSeparatorInputFormatter.parse(controller.text);
                            if (cairkan <= 0) return;
                            if (cairkan > currentLimit) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${t('errCairkanExceedsLimit')} (${widget.localeService?.isIndonesian == true ? 'Maks' : 'Max'}: ${_currencyFormat.format(currentLimit)})',
                                  ),
                                  backgroundColor: AppTheme.coralRose,
                                ),
                              );
                              return;
                            }

                            final navigator = Navigator.of(dialogContext);
                            final updatedLimit = currentLimit - cairkan;
                            if (updatedLimit <= 0) {
                              await widget.storageService.deleteBudget(category.id, now.month, now.year);
                            } else {
                              await widget.storageService.setBudget(category.id, updatedLimit, now.month, now.year);
                            }
                            if (mounted) {
                              setState(() {});
                              widget.onDataChanged();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    t('cairkanSuccess').replaceAll('{amount}', _currencyFormat.format(cairkan)),
                                  ),
                                  backgroundColor: AppTheme.cyanAccent,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                            navigator.pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cyanAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            widget.localeService?.isIndonesian == true ? 'Cairkan' : 'Withdraw',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
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

    final budgetMap = {for (var b in budgets) b.categoryId: b.monthlyLimit};
    final totalCash = widget.storageService.getTotalBalance();
    final wallets = widget.storageService.getWallets();

    double totalBudget = 0.0;
    for (final c in categories) {
      final limit = budgetMap[c.id] ?? 0.0;
      totalBudget += limit;
    }

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
                Text(
                  t('totalBudgetThisMonth'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Text(
                  _currencyFormat.format(totalBudget),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
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
                onTap: () => _showAddBudgetDialog(),
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
                final catBudget = budgets.where((b) => b.categoryId == cat.id).firstOrNull;
                final fundingWallet = (catBudget?.walletId != null)
                    ? wallets.where((w) => w.id == catBudget!.walletId).firstOrNull
                    : null;

                return Container(
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
                              if (fundingWallet != null && limit > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLighter,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.borderDark),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.account_balance_wallet_outlined, size: 10, color: AppTheme.cyanAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        fundingWallet.name,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.cyanAccent),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            limit > 0 ? _currencyFormat.format(limit) : t('notSet'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: limit > 0 ? AppTheme.textPrimary : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _showAddBudgetDialog(preselectedCategory: cat),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_circle_outline, size: 14, color: AppTheme.emeraldGreen),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'ADD',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (limit > 0) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => _showCairkanBudgetDialog(cat, limit),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cyanAccent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.cyanAccent.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppTheme.cyanAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        t('cairkanBudget'),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.cyanAccent),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
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

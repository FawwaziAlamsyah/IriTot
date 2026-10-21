import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class BudgetScreen extends StatefulWidget {
  final StorageService storageService;
  final VoidCallback onDataChanged;

  const BudgetScreen({
    super.key,
    required this.storageService,
    required this.onDataChanged,
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

  void _showSetBudgetDialog(CategoryItem category, double currentLimit) {
    final controller = TextEditingController(
      text: currentLimit > 0 ? currentLimit.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.borderDark),
          ),
          title: Text(
            'Atur Budget: ${category.name}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Masukkan batas pengeluaran bulanan (Rp):', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.surfaceLighter,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderDark)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                final limit = double.tryParse(controller.text.replaceAll('.', '')) ?? 0.0;
                final now = DateTime.now();
                await widget.storageService.setBudget(category.id, limit, now.month, now.year);
                if (mounted) {
                  setState(() {});
                  widget.onDataChanged();
                }
                navigator.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emeraldGreen,
                foregroundColor: Colors.black,
              ),
              child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final categories = widget.storageService.getCategories().where((c) => c.type == 'expense').toList();
    final budgets = widget.storageService.getBudgets(now.month, now.year);
    final transactions = widget.storageService.getTransactions().where(
          (t) => t.type == 'expense' && t.date.month == now.month && t.date.year == now.year,
        ).toList();

    final budgetMap = {for (var b in budgets) b.categoryId: b.monthlyLimit};

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

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Pantauan Anggaran'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        const Text(
                          'TOTAL ANGGARAN BULAN INI',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.8),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: overallPercent >= 80 ? AppTheme.coralRose.withValues(alpha: 0.2) : AppTheme.emeraldGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$overallPercent% Terpakai',
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
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'RINCIAN PER KATEGORI',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),

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
                                    limit > 0 ? '$percent%' : 'Belum Disetel',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: limit > 0 ? (isWarning ? AppTheme.coralRose : AppTheme.emeraldGreen) : AppTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Terpakai: ${_currencyFormat.format(spent)}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                              Text(
                                'Batas: ${_currencyFormat.format(limit)}',
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
        ),
      ),
    );
  }
}

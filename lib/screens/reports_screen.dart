import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../services/locale_service.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  final StorageService storageService;
  final LocaleService? localeService;

  const ReportsScreen({super.key, required this.storageService, this.localeService});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _touchedIndex = -1;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final transactions = widget.storageService.getTransactions().where(
          (t) => t.date.month == now.month && t.date.year == now.year,
        ).toList();

    final categories = widget.storageService.getCategories();
    final catMap = {for (var c in categories) c.id: c};

    final income = transactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
    final expense = transactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
    final netSavings = income - expense;

    // Grouping pengeluaran per kategori
    final Map<String, double> categoryTotals = {};
    for (final t in transactions.where((t) => t.type == 'expense')) {
      categoryTotals[t.categoryId] = (categoryTotals[t.categoryId] ?? 0.0) + t.amount;
    }

    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(widget.localeService?.t('reportsTitle') ?? 'Financial Reports'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ringkasan Arus Kas
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(widget.localeService?.t('netCashflow') ?? 'Net Cashflow', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                        Text(
                          DateFormat('MMMM yyyy', widget.localeService?.isIndonesian == true ? 'id_ID' : 'en_US').format(now),
                          style: const TextStyle(fontSize: 11, color: AppTheme.cyanAccent, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          _currencyFormat.format(netSavings),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: netSavings >= 0 ? AppTheme.emeraldGreen : AppTheme.coralRose,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.localeService?.t('income') ?? 'Total Income', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              const SizedBox(height: 2),
                              Text('+${_currencyFormat.format(income)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen)),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 26, color: AppTheme.borderDark),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.localeService?.t('expense') ?? 'Total Expense', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              const SizedBox(height: 2),
                              Text('-${_currencyFormat.format(expense)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.coralRose)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Donut Chart Komposisi Pengeluaran
              Text(
                widget.localeService?.t('secExpenseByCategory') ?? 'EXPENSE BY CATEGORY',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),

              if (sortedEntries.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: const Center(
                    child: Text('Belum ada data pengeluaran bulan ini.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
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
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 3,
                        centerSpaceRadius: 50,
                        sections: sortedEntries.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final isTouched = idx == _touchedIndex;
                          final cat = catMap[item.key];
                          final percent = expense > 0 ? (item.value / expense) * 100 : 0.0;
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
                const SizedBox(height: 20),

                // Rincian List Kategori
                const Text(
                  'RINCIAN BELANJA',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 10),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedEntries.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = sortedEntries[index];
                    final cat = catMap[item.key];
                    final percent = expense > 0 ? ((item.value / expense) * 100).toInt() : 0;
                    final color = cat != null ? Color(cat.colorValue) : AppTheme.cyanAccent;

                    return Container(
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
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                cat?.name ?? 'Umum',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '$percent%',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _currencyFormat.format(item.value),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.coralRose),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_item.dart';
import '../models/wallet.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

class AddTransactionModal extends StatefulWidget {
  final StorageService storageService;
  final AiService aiService;
  final VoidCallback onTransactionAdded;
  final String? initialType;
  final bool openWithVoice;

  const AddTransactionModal({
    super.key,
    required this.storageService,
    required this.aiService,
    required this.onTransactionAdded,
    this.initialType,
    this.openWithVoice = false,
  });

  @override
  State<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends State<AddTransactionModal> {
  late String _type; // 'expense', 'income', 'transfer'
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _voiceInputController = TextEditingController();

  late List<Wallet> _wallets;
  late List<CategoryItem> _categories;
  late String _selectedWalletId;
  String? _selectedDestWalletId;
  late String _selectedCategoryId;
  final DateTime _selectedDate = DateTime.now();

  bool _isVoiceRecording = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? 'expense';
    _wallets = widget.storageService.getWallets();
    _categories = widget.storageService.getCategories();

    _selectedWalletId = _wallets.isNotEmpty ? _wallets.first.id : 'w_cash';
    _selectedDestWalletId = _wallets.length > 1 ? _wallets[1].id : null;

    final initialCats = _categories.where((c) => c.type == _type).toList();
    _selectedCategoryId = initialCats.isNotEmpty
        ? initialCats.first.id
        : (_categories.isNotEmpty ? _categories.first.id : 'cat_food');

    if (widget.openWithVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startVoiceInputSimulation();
      });
    }
  }

  void _startVoiceInputSimulation() {
    setState(() {
      _isVoiceRecording = true;
    });
  }

  void _applyParsedVoice(String text) {
    final parsed = widget.aiService.parseOfflineVoiceOrText(text);
    setState(() {
      _type = parsed['type'] as String;
      final amount = parsed['amount'] as double;
      if (amount > 0) {
        _amountController.text = amount.toStringAsFixed(0);
      }
      _selectedCategoryId = parsed['categoryId'] as String;
      _selectedWalletId = parsed['walletId'] as String;
      _noteController.text = parsed['note'] as String;
      _isVoiceRecording = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Terdeteksi: ${_type == "income" ? "Pemasukan" : "Pengeluaran"} Rp ${_amountController.text}'),
        backgroundColor: AppTheme.emeraldGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addQuickAmount(double amount) {
    final current = double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0.0;
    final updated = current + amount;
    _amountController.text = updated.toStringAsFixed(0);
  }

  void _saveTransaction() async {
    final amount = double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nominal transaksi yang valid.'),
          backgroundColor: AppTheme.coralRose,
        ),
      );
      return;
    }

    final item = TransactionItem(
      id: const Uuid().v4(),
      walletId: _selectedWalletId,
      destinationWalletId: _type == 'transfer' ? _selectedDestWalletId : null,
      categoryId: _type == 'transfer' ? 'cat_transfer' : _selectedCategoryId,
      type: _type,
      amount: amount,
      note: _noteController.text.trim().isEmpty
          ? (_type == 'income' ? 'Pemasukan' : 'Pengeluaran')
          : _noteController.text.trim(),
      date: _selectedDate,
    );

    await widget.storageService.addTransaction(item);
    widget.onTransactionAdded();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _categories.where((c) => c.type == _type).toList();
    final isExpense = _type == 'expense';
    final isIncome = _type == 'income';
    final isTransfer = _type == 'transfer';

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppTheme.borderDark, width: 1)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
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

            // Header & Type Switcher
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Catat Transaksi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isVoiceRecording = !_isVoiceRecording;
                    });
                  },
                  icon: Icon(
                    _isVoiceRecording ? Icons.mic_off : Icons.mic,
                    color: _isVoiceRecording ? AppTheme.coralRose : AppTheme.violetAI,
                  ),
                  tooltip: 'Catat Suara',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Voice Simulation Card (If Active)
            if (_isVoiceRecording)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.violetAI.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.violetAI.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.graphic_eq, color: AppTheme.violetAI, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Catat Cepat Pakai Suara / Kalimat',
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _voiceInputController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Contoh: makan siang 25rb pakai bca',
                        hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.8), fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.surfaceLighter,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: _applyParsedVoice,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _isVoiceRecording = false),
                          child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _applyParsedVoice(_voiceInputController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.violetAI,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Terapkan', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    )
                  ],
                ),
              ),

            // Type Segmented Control
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceLighter,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderDark),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildTypeTab('expense', 'Pengeluaran', isExpense ? AppTheme.coralRose : null),
                  _buildTypeTab('income', 'Pemasukan', isIncome ? AppTheme.emeraldGreen : null),
                  _buildTypeTab('transfer', 'Transfer', isTransfer ? AppTheme.cyanAccent : null),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Amount Input Field
            const Text(
              'Nominal (Rp)',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: isExpense
                    ? AppTheme.coralRose
                    : (isIncome ? AppTheme.emeraldGreen : AppTheme.cyanAccent),
                letterSpacing: -0.5,
              ),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                ),
                hintText: '0',
                hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5)),
                filled: true,
                fillColor: AppTheme.surfaceLighter,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.borderDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.borderDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isExpense
                        ? AppTheme.coralRose
                        : (isIncome ? AppTheme.emeraldGreen : AppTheme.cyanAccent),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 10),

            // Quick Amount Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickChip(10000, '+10rb'),
                  _buildQuickChip(20000, '+20rb'),
                  _buildQuickChip(50000, '+50rb'),
                  _buildQuickChip(100000, '+100rb'),
                  _buildQuickChip(500000, '+500rb'),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Wallet Selection
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTransfer ? 'Dari Dompet' : 'Dompet / Rekening',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLighter,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderDark),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedWalletId,
                            isExpanded: true,
                            dropdownColor: AppTheme.surfaceDark,
                            items: _wallets.map((w) {
                              return DropdownMenuItem(
                                value: w.id,
                                child: Text(w.name, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedWalletId = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isTransfer) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ke Dompet',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLighter,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.borderDark),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedDestWalletId,
                              isExpanded: true,
                              dropdownColor: AppTheme.surfaceDark,
                              items: _wallets
                                  .where((w) => w.id != _selectedWalletId)
                                  .map((w) {
                                return DropdownMenuItem(
                                  value: w.id,
                                  child: Text(w.name, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedDestWalletId = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),

            // Category Selection (Only if not transfer)
            if (!isTransfer) ...[
              const Text(
                'Kategori',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredCategories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = filteredCategories[index];
                    final isSelected = cat.id == _selectedCategoryId;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategoryId = cat.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Color(cat.colorValue).withValues(alpha: 0.2) : AppTheme.surfaceLighter,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Color(cat.colorValue) : AppTheme.borderDark,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Color(cat.colorValue) : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Note Input
            const Text(
              'Catatan / Keterangan',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Contoh: Makan siang, bayar wifi, dll.',
                hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.7), fontSize: 13),
                filled: true,
                fillColor: AppTheme.surfaceLighter,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.borderDark),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isExpense
                      ? AppTheme.coralRose
                      : (isIncome ? AppTheme.emeraldGreen : AppTheme.cyanAccent),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  isTransfer ? 'Simpan Transfer' : (isExpense ? 'Simpan Pengeluaran' : 'Simpan Pemasukan'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeTab(String type, String label, Color? activeColor) {
    final isSelected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _type = type;
            final newCats = _categories.where((c) => c.type == type).toList();
            if (newCats.isNotEmpty) {
              _selectedCategoryId = newCats.first.id;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (activeColor ?? AppTheme.surfaceDark) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(double amount, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        backgroundColor: AppTheme.surfaceLighter,
        side: const BorderSide(color: AppTheme.borderDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onPressed: () => _addQuickAmount(amount),
      ),
    );
  }
}

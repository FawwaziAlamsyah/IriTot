import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../models/transaction_item.dart';
import '../models/wallet.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../services/ai_service.dart';
import '../services/locale_service.dart';
import '../services/speech_service.dart';
import '../widgets/voice_wave.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_input_formatter.dart';

class AddTransactionModal extends StatefulWidget {
  final StorageService storageService;
  final AiService aiService;
  final LocaleService? localeService;
  final VoidCallback onTransactionAdded;
  final String? initialType;
  final bool openWithVoice;
  final double? initialAmount;
  final String? initialNote;
  final String? initialCategoryId;
  final String? initialWalletId;

  const AddTransactionModal({
    super.key,
    required this.storageService,
    required this.aiService,
    this.localeService,
    required this.onTransactionAdded,
    this.initialType,
    this.openWithVoice = false,
    this.initialAmount,
    this.initialNote,
    this.initialCategoryId,
    this.initialWalletId,
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
  bool _isScanningReceipt = false;

  String t(String key) => widget.localeService?.t(key) ?? key;

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

    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountController.text = ThousandsSeparatorInputFormatter.format(widget.initialAmount!);
    }
    if (widget.initialNote != null && widget.initialNote!.isNotEmpty) {
      _noteController.text = widget.initialNote!;
    }
    if (widget.initialCategoryId != null && _categories.any((c) => c.id == widget.initialCategoryId)) {
      _selectedCategoryId = widget.initialCategoryId!;
    }
    if (widget.initialWalletId != null && _wallets.any((w) => w.id == widget.initialWalletId)) {
      _selectedWalletId = widget.initialWalletId!;
    }

    if (widget.openWithVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toggleVoiceRecording();
      });
    }
  }

  @override
  void dispose() {
    if (_isVoiceRecording) {
      SpeechService.instance.stopListening();
    }
    _amountController.dispose();
    _noteController.dispose();
    _voiceInputController.dispose();
    super.dispose();
  }

  bool _voiceCancelled = false;

  /// Called once when listening ends (silence, manual stop or engine end):
  /// the full spoken sentence is parsed against the user's categories and wallets.
  void _finishVoice() {
    if (!_isVoiceRecording || !mounted) return;
    setState(() => _isVoiceRecording = false);
    if (_voiceCancelled) return;
    final text = _voiceInputController.text.trim();
    if (text.isEmpty) return;
    _applyParsedVoice(text);
  }

  void _toggleVoiceRecording() async {
    if (_isVoiceRecording) {
      // Tap again = finish now and process what was said
      SpeechService.instance.stopListening();
      _finishVoice();
      return;
    }

    _voiceCancelled = false;
    _voiceInputController.clear();
    setState(() => _isVoiceRecording = true);

    final started = await SpeechService.instance.startListening(
      onResult: (text) {
        if (!mounted) return;
        // Only show live text; parsing waits until the user finishes speaking
        setState(() => _voiceInputController.text = text);
      },
      onEnd: _finishVoice,
      onError: (err) {
        if (mounted) {
          setState(() => _isVoiceRecording = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err),
              backgroundColor: AppTheme.coralRose,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );

    if (!started && mounted) {
      setState(() => _isVoiceRecording = false);
    }
  }
  void _applyParsedVoice(String text) {
    if (text.trim().isEmpty) return;
    final parsed = widget.aiService.parseOfflineVoiceOrText(text, categories: _categories, wallets: _wallets);
    setState(() {
      _type = parsed['type'] as String;
      final amount = parsed['amount'] as double;
      if (amount > 0) {
        _amountController.text = ThousandsSeparatorInputFormatter.format(amount);
      }
      _selectedCategoryId = parsed['categoryId'] as String;
      _selectedWalletId = parsed['walletId'] as String;
      _noteController.text = parsed['note'] as String;
      _isVoiceRecording = false;
    });

    final typeLabel = _type == 'income' ? t('income') : (_type == 'transfer' ? t('transfer') : t('expense'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t('addTxDetected').replaceAll('{type}', typeLabel).replaceAll('{amount}', _amountController.text),
        ),
        backgroundColor: AppTheme.emeraldGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _pickAndScanReceipt() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('scanReceiptTitle'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.cyanAccent),
                  title: Text(t('takePhoto'), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _processReceipt(ImageSource.camera);
                  },
                ),
                const Divider(color: AppTheme.borderDark, height: 1),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppTheme.emeraldGreen),
                  title: Text(t('chooseGallery'), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _processReceipt(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _processReceipt(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source);
      if (file == null) return;

      setState(() => _isScanningReceipt = true);

      final bytes = await file.readAsBytes();
      final result = await widget.aiService.analyzeReceiptImage(
        imageBytes: bytes,
        filePath: file.path,
        wallets: _wallets,
        categories: _categories,
      );

      if (!mounted) return;
      setState(() {
        _isScanningReceipt = false;
        final amount = result['amount'] as double? ?? 0.0;
        if (amount > 0) {
          _amountController.text = ThousandsSeparatorInputFormatter.format(amount);
        }
        final note = result['note'] as String? ?? '';
        if (note.isNotEmpty) {
          _noteController.text = note;
        }
        final catId = result['categoryId'] as String?;
        if (catId != null) {
          _selectedCategoryId = catId;
        }
        final walletId = result['walletId'] as String?;
        if (walletId != null) {
          _selectedWalletId = walletId;
        }
        _type = 'expense';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t('receiptLoggedSuccess')} Rp ${_amountController.text}'),
          backgroundColor: AppTheme.emeraldGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isScanningReceipt = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memindai struk: $e'), backgroundColor: AppTheme.coralRose),
        );
      }
    }
  }

  void _addQuickAmount(double amount) {
    final current = ThousandsSeparatorInputFormatter.parse(_amountController.text);
    final updated = current + amount;
    _amountController.text = ThousandsSeparatorInputFormatter.format(updated);
  }

  void _saveTransaction() async {
    final amount = ThousandsSeparatorInputFormatter.parse(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('addTxErrAmount')),
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
          ? (_type == 'income' ? t('income') : (_type == 'transfer' ? t('transfer') : t('expense')))
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

            // Header & Action Switchers (Voice & Camera)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('addTxTitle'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    // Tombol Scan Foto Struk
                    IconButton(
                      onPressed: _isScanningReceipt ? null : _pickAndScanReceipt,
                      icon: _isScanningReceipt
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyanAccent))
                          : const Icon(Icons.document_scanner_outlined, color: AppTheme.cyanAccent),
                      tooltip: t('addTxScanTooltip'),
                    ),
                    // Tombol Voice
                    IconButton(
                      onPressed: _toggleVoiceRecording,
                      icon: PulsingMic(
                        active: _isVoiceRecording,
                        color: AppTheme.coralRose,
                        child: Icon(
                          _isVoiceRecording ? Icons.mic : Icons.mic_none,
                          color: _isVoiceRecording ? AppTheme.coralRose : AppTheme.violetAI,
                        ),
                      ),
                      tooltip: t('addTxVoiceTooltip'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Voice Bar Active Indicator
            if (_isVoiceRecording)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.violetAI.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.violetAI.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const VoiceWave(color: AppTheme.violetAI, height: 22),
                        const SizedBox(width: 8),
                        Text(
                          t('addTxVoiceHeader'),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary, fontSize: 13),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.coralRose.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t('listeningVoice'),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.coralRose),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _voiceInputController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: t('addTxVoiceHint'),
                        hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.8), fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.surfaceLighter,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: _applyParsedVoice,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t('voiceAutoStopHint'),
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _voiceCancelled = true;
                            SpeechService.instance.stopListening();
                            setState(() => _isVoiceRecording = false);
                          },
                          child: Text(t('cancel'), style: const TextStyle(color: AppTheme.textMuted)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            SpeechService.instance.stopListening();
                            _finishVoice();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.violetAI,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(t('apply'), style: const TextStyle(fontWeight: FontWeight.w700)),
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
                  _buildTypeTab('expense', t('expense'), isExpense ? AppTheme.coralRose : null),
                  _buildTypeTab('income', t('income'), isIncome ? AppTheme.emeraldGreen : null),
                  _buildTypeTab('transfer', t('transfer'), isTransfer ? AppTheme.cyanAccent : null),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Amount Input Field
            Text(
              t('addTxAmount'),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
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
                        isTransfer ? t('addTxFromWallet') : t('addTxWallet'),
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
                        Text(
                          t('addTxToWallet'),
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
              Text(
                t('addTxCategory'),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
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
            Text(
              t('addTxNote'),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
                maxLength: 500,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: t('addTxNoteHint'),
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
                  isTransfer
                      ? t('addTxSaveTransfer')
                      : (isExpense ? t('addTxSaveExpense') : t('addTxSaveIncome')),
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

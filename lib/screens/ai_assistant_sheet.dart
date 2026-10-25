import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../services/ai_service.dart';
import '../services/locale_service.dart';
import '../services/speech_service.dart';
import '../models/transaction_item.dart';
import '../theme/app_theme.dart';
import '../widgets/voice_wave.dart';

class AiAssistantSheet extends StatefulWidget {
  final StorageService storageService;
  final AiService aiService;
  final LocaleService? localeService;
  final VoidCallback? onDataChanged;

  const AiAssistantSheet({
    super.key,
    required this.storageService,
    required this.aiService,
    this.localeService,
    this.onDataChanged,
  });

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _ChatMessage {
  final bool isUser;
  final String text;
  final Map<String, dynamic>? pendingTx;
  bool isLogged;

  _ChatMessage({
    required this.isUser,
    required this.text,
    this.pendingTx,
  }) : isLogged = false;
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isVoiceRecording = false;

  String t(String key) => widget.localeService?.t(key) ?? key;

  @override
  void initState() {
    super.initState();
    final isId = widget.localeService?.isIndonesian ?? true;
    _messages.add(
      _ChatMessage(
        isUser: false,
        text: isId
            ? 'Halo! Saya Assistant AI finansial Anda di IRITOT. Anda bisa bertanya seputar pengeluaran, tips hemat, mencatat transaksi lewat suara, atau scan foto struk belanja.'
            : 'Hello! I am your AI financial assistant at IRITOT. You can ask about your spending, get savings tips, log transactions using voice, or scan a receipt photo.',
      ),
    );
  }

  @override
  void dispose() {
    if (_isVoiceRecording) {
      SpeechService.instance.stopListening();
    }
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _voiceCancelled = false;

  /// Runs once when listening ends; the full sentence is sent to the assistant.
  void _finishVoice() {
    if (!_isVoiceRecording || !mounted) return;
    setState(() => _isVoiceRecording = false);
    if (_voiceCancelled) return;
    final text = _promptController.text.trim();
    if (text.isNotEmpty) _sendMessage(text);
  }

  void _toggleVoice() async {
    if (_isVoiceRecording) {
      // Tap again = finish now and process what was said
      SpeechService.instance.stopListening();
      _finishVoice();
      return;
    }

    _voiceCancelled = false;
    _promptController.clear();
    setState(() => _isVoiceRecording = true);

    final started = await SpeechService.instance.startListening(
      onResult: (text) {
        if (!mounted) return;
        setState(() => _promptController.text = text);
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
  void _sendMessage(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    if (_isVoiceRecording) {
      SpeechService.instance.stopListening();
      _isVoiceRecording = false;
    }

    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: clean));
      _isLoading = true;
    });
    _promptController.clear();
    _scrollToBottom();

    final now = DateTime.now();
    final wallets = widget.storageService.getWallets();
    final categories = widget.storageService.getCategories();

    // Cek apakah query merupakan perintah catat transaksi
    final detectedTx = widget.aiService.detectTransactionFromQuery(
      query: clean,
      wallets: wallets,
      categories: categories,
    );

    if (detectedTx != null) {
      final isId = widget.localeService?.isIndonesian ?? true;
      final f = NumberFormat('#,###', isId ? 'id_ID' : 'en_US');
      final amount = detectedTx['amount'] as double;
      final note = detectedTx['note'] as String;
      final cat = detectedTx['categoryName'] as String;
      final wallet = detectedTx['walletName'] as String;

      final reply = isId
          ? 'Saya mendeteksi transaksi: "$note" sebesar Rp ${f.format(amount)} ($cat) pada dompet $wallet. Klik tombol di bawah untuk mencatatnya langsung ke dompet Anda.'
          : 'I detected a transaction: "$note" of Rp ${f.format(amount)} ($cat) in $wallet. Tap the button below to log it directly into your wallet.';

      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(
              isUser: false,
              text: reply,
              pendingTx: detectedTx,
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
      return;
    }

    // Tanya Financial Advisor Gemini
    final totalBalance = widget.storageService.getTotalBalance();
    final monthlyIncome = widget.storageService.getMonthlyIncome(now.month, now.year);
    final monthlyExpense = widget.storageService.getMonthlyExpense(now.month, now.year);
    final currentMonthTransactions = widget.storageService.getTransactions().where(
          (t) => t.date.month == now.month && t.date.year == now.year,
        ).toList();
    final totalSavings = widget.storageService.getTotalSavingsBalance();
    final monthlySavingsIn = widget.storageService.getMonthlySavingsIn(now.month, now.year);

    final response = await widget.aiService.askFinancialAdvisor(
      userQuestion: clean,
      totalBalance: totalBalance,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      currentMonthTransactions: currentMonthTransactions,
      categories: categories,
      wallets: wallets,
      totalSavings: totalSavings,
      monthlySavingsIn: monthlySavingsIn,
    );

    if (mounted) {
      setState(() {
        _messages.add(_ChatMessage(isUser: false, text: response));
        _isLoading = false;
      });
      _scrollToBottom();
    }
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
                    _processReceiptScan(ImageSource.camera);
                  },
                ),
                const Divider(color: AppTheme.borderDark, height: 1),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppTheme.emeraldGreen),
                  title: Text(t('chooseGallery'), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _processReceiptScan(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _processReceiptScan(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source);
      if (file == null) return;

      setState(() {
        _messages.add(_ChatMessage(
          isUser: true,
          text: widget.localeService?.isIndonesian ?? true ? '📸 [Foto Struk Belanja]' : '📸 [Receipt Photo]',
        ));
        _isLoading = true;
      });
      _scrollToBottom();

      final bytes = await file.readAsBytes();
      final wallets = widget.storageService.getWallets();
      final categories = widget.storageService.getCategories();

      final result = await widget.aiService.analyzeReceiptImage(
        imageBytes: bytes,
        filePath: file.path,
        wallets: wallets,
        categories: categories,
      );

      final isId = widget.localeService?.isIndonesian ?? true;
      final f = NumberFormat('#,###', isId ? 'id_ID' : 'en_US');
      final amount = (result['amount'] as num?)?.toDouble() ?? 0.0;
      final merchant = result['merchant'] as String? ?? 'Struk Belanja';
      final note = result['note'] as String? ?? merchant;
      final catId = result['categoryId'] as String? ?? 'cat_food';
      final walletId = result['walletId'] as String? ?? (wallets.isNotEmpty ? wallets.first.id : 'w_cash');

      final catObj = categories.firstWhere((c) => c.id == catId, orElse: () => categories.first);
      final walletObj = wallets.firstWhere((w) => w.id == walletId, orElse: () => wallets.first);

      final pendingData = {
        'type': 'expense',
        'amount': amount,
        'merchant': merchant,
        'note': note,
        'categoryId': catObj.id,
        'categoryName': catObj.name,
        'walletId': walletObj.id,
        'walletName': walletObj.name,
        'date': result['date'] is DateTime ? result['date'] : DateTime.now(),
      };

      final replyText = isId
          ? 'Struk dari "$merchant" berhasil dianalisis dengan total Rp ${f.format(amount)} ($note). Klik "Catat ke Dompet" untuk menyimpannya.'
          : 'Receipt from "$merchant" analyzed with total Rp ${f.format(amount)} ($note). Tap "Log to Wallet" to save it.';

      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            isUser: false,
            text: replyText,
            pendingTx: pendingData,
          ));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memindai struk: $e'), backgroundColor: AppTheme.coralRose),
        );
      }
    }
  }

  void _savePendingTransaction(_ChatMessage msg) async {
    final txData = msg.pendingTx;
    if (txData == null || msg.isLogged) return;

    final double amount = (txData['amount'] as num?)?.toDouble() ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal transaksi Rp 0. Tidak dapat dicatat.'),
          backgroundColor: AppTheme.coralRose,
        ),
      );
      return;
    }

    final newTx = TransactionItem(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
      type: txData['type'] as String? ?? 'expense',
      categoryId: txData['categoryId'] as String,
      walletId: txData['walletId'] as String,
      date: txData['date'] is DateTime ? txData['date'] as DateTime : DateTime.now(),
      note: txData['note'] as String? ?? '',
    );

    await widget.storageService.addTransaction(newTx);

    if (mounted) {
      setState(() {
        msg.isLogged = true;
      });
      widget.onDataChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('txLoggedSuccess')),
          backgroundColor: AppTheme.emeraldGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppTheme.borderDark, width: 1)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppTheme.violetAI, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.localeService?.isIndonesian ?? true ? 'Assistant AI Finansial' : 'AI Financial Assistant',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.violetAI.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('BYOK Lokal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.violetAI)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: AppTheme.borderDark, height: 1),

          // Quick Chips Prompt
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildPromptChip(widget.localeService?.isIndonesian ?? true ? 'Pengeluaran terbesar bulan ini apa?' : 'What is my top expense this month?'),
                _buildPromptChip(widget.localeService?.isIndonesian ?? true ? 'Catat beli kopi 25rb pakai kas' : 'Log coffee 25k using Cash'),
                _buildPromptChip(widget.localeService?.isIndonesian ?? true ? 'Ada uang bocor nggak?' : 'Any financial leaks?'),
                _buildPromptChip(widget.localeService?.isIndonesian ?? true ? 'Kasih tips hemat belanja' : 'Give me saving tips'),
              ],
            ),
          ),
          const Divider(color: AppTheme.borderDark, height: 1),

          // Chat Messages
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageItem(msg);
              },
            ),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.violetAI)),
                  const SizedBox(width: 10),
                  Text(
                    widget.localeService?.isIndonesian ?? true ? 'Menganalisis dengan AI IRITOT...' : 'Analyzing with IRITOT AI...',
                    style: const TextStyle(fontSize: 12, color: AppTheme.violetAI),
                  ),
                ],
              ),
            ),

          // Input Bar with Mic & Receipt Scanner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceDark,
              border: Border(top: BorderSide(color: AppTheme.borderDark)),
            ),
            child: Row(
              children: [
                // Scan Receipt Icon Button
                IconButton(
                  tooltip: t('scanReceiptTitle'),
                  icon: const Icon(Icons.document_scanner_outlined, color: AppTheme.cyanAccent),
                  onPressed: _pickAndScanReceipt,
                ),

                // Mic Button
                IconButton(
                  tooltip: t('actionVoice'),
                  icon: PulsingMic(
                    active: _isVoiceRecording,
                    color: AppTheme.coralRose,
                    child: Icon(
                      _isVoiceRecording ? Icons.mic : Icons.mic_none,
                      color: _isVoiceRecording ? AppTheme.coralRose : AppTheme.violetAI,
                    ),
                  ),
                  onPressed: _toggleVoice,
                ),

                // Text Input
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      prefixIcon: _isVoiceRecording
                          ? const Padding(
                              padding: EdgeInsets.only(left: 12, right: 4),
                              child: VoiceWave(color: AppTheme.coralRose, height: 18, bars: 4),
                            )
                          : null,
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: _isVoiceRecording
                          ? (widget.localeService?.isIndonesian ?? true ? 'Mendengarkan suara...' : 'Listening...')
                          : (widget.localeService?.isIndonesian ?? true ? 'Tanya atau catat transaksi...' : 'Ask or log transaction...'),
                      hintStyle: TextStyle(
                        color: _isVoiceRecording ? AppTheme.coralRose : AppTheme.textMuted.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: _isVoiceRecording ? FontWeight.w600 : FontWeight.normal,
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceLighter,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 6),

                // Send Button
                IconButton(
                  onPressed: () => _sendMessage(_promptController.text),
                  icon: const Icon(Icons.send_rounded, color: AppTheme.violetAI),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(_ChatMessage msg) {
    final isId = widget.localeService?.isIndonesian ?? true;
    final f = NumberFormat('#,###', isId ? 'id_ID' : 'en_US');

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: msg.isUser ? AppTheme.violetAI : AppTheme.surfaceLighter,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
          ),
          border: msg.isUser ? null : Border.all(color: AppTheme.borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: msg.isUser ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            if (msg.pendingTx != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
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
                            const Icon(Icons.receipt_long, size: 16, color: AppTheme.cyanAccent),
                            const SizedBox(width: 6),
                            Text(
                              t('aiDetectedTx'),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.cyanAccent),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.coralRose.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            msg.pendingTx!['type'] == 'income' ? t('income') : t('expense'),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.coralRose),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rp ${f.format(msg.pendingTx!['amount'] ?? 0)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.coralRose),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${t('addTxCategory')}: ${msg.pendingTx!['categoryName']}  •  ${t('addTxWallet')}: ${msg.pendingTx!['walletName']}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    if ((msg.pendingTx!['note'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${t('addTxNote')}: "${msg.pendingTx!['note']}"',
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textMuted),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: msg.isLogged ? null : () => _savePendingTransaction(msg),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: msg.isLogged ? AppTheme.surfaceLighter : AppTheme.emeraldGreen,
                          foregroundColor: msg.isLogged ? AppTheme.textMuted : Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(
                          msg.isLogged ? Icons.check_circle : Icons.add_task,
                          size: 16,
                          color: msg.isLogged ? AppTheme.emeraldGreen : Colors.black,
                        ),
                        label: Text(
                          msg.isLogged
                              ? (isId ? 'Tercatat di Dompet' : 'Logged to Wallet')
                              : t('logToWalletNow'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: msg.isLogged ? AppTheme.emeraldGreen : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.surfaceLighter,
        side: const BorderSide(color: AppTheme.borderDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onPressed: () => _sendMessage(text),
      ),
    );
  }
}

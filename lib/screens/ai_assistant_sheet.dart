import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

class AiAssistantSheet extends StatefulWidget {
  final StorageService storageService;
  final AiService aiService;

  const AiAssistantSheet({
    super.key,
    required this.storageService,
    required this.aiService,
  });

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _ChatMessage {
  final bool isUser;
  final String text;

  _ChatMessage({required this.isUser, required this.text});
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        isUser: false,
        text: 'Halo! Saya Assistant AI finansial Anda di IRITOT. Saya menganalisis data riil pengeluaran lokal di HP Anda untuk menjawab pertanyaan atau memberi tips hemat. Ada yang ingin ditanyakan?',
      ),
    );
  }

  void _sendMessage(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: clean));
      _isLoading = true;
    });
    _promptController.clear();
    _scrollToBottom();

    final now = DateTime.now();
    final totalBalance = widget.storageService.getTotalBalance();
    final monthlyIncome = widget.storageService.getMonthlyIncome(now.month, now.year);
    final monthlyExpense = widget.storageService.getMonthlyExpense(now.month, now.year);
    final currentMonthTransactions = widget.storageService.getTransactions().where(
          (t) => t.date.month == now.month && t.date.year == now.year,
        ).toList();
    final categories = widget.storageService.getCategories();
    final wallets = widget.storageService.getWallets();
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
      height: MediaQuery.of(context).size.height * 0.85,
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
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppTheme.violetAI, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Assistant AI Finansial',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
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
                _buildPromptChip('Pengeluaran terbesar bulan ini apa?'),
                _buildPromptChip('Ada uang bocor nggak?'),
                _buildPromptChip('Kasih tips hemat belanja'),
                _buildPromptChip('Pola belanja saya bagaimana?'),
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
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
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
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: msg.isUser ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.violetAI)),
                  SizedBox(width: 10),
                  Text('Menganalisis data keuangan lokal...', style: TextStyle(fontSize: 12, color: AppTheme.violetAI)),
                ],
              ),
            ),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceDark,
              border: Border(top: BorderSide(color: AppTheme.borderDark)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Tanya seputar keuangan Anda...',
                      hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.7), fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.surfaceLighter,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/savings_pocket.dart';
import '../services/storage_service.dart';
import '../services/csv_service.dart';
import '../services/file_io_service.dart';
import '../theme/app_theme.dart';

import '../services/locale_service.dart';

class SavingsScreen extends StatefulWidget {
  final StorageService storageService;
  final LocaleService? localeService;
  final VoidCallback onDataChanged;
  final bool showAppBar;
  final bool? isBalanceHidden;

  const SavingsScreen({
    super.key,
    required this.storageService,
    this.localeService,
    required this.onDataChanged,
    this.showAppBar = true,
    this.isBalanceHidden,
  });

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  bool _isBalanceHidden = false;
  bool get _effectiveBalanceHidden => widget.isBalanceHidden ?? _isBalanceHidden;
  String _historyFilter = 'all'; // 'all', 'in', 'out'

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String t(String key) => widget.localeService?.t(key) ?? key;

  void _confirmDeletePocket(SavingsPocket p) {
    showDialog(
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
            Expanded(
              child: Text(
                t('deletePocketTitle').replaceAll('{name}', p.name),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          p.currentAmount > 0
              ? t('deletePocketHasBalance').replaceAll('{amount}', _currencyFormat.format(p.currentAmount))
              : t('deletePocketEmpty'),
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(t('cancel'), style: const TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await widget.storageService.deleteSavingsPocketWithRefund(p.id);
              if (mounted) {
                setState(() {});
                widget.onDataChanged();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coralRose,
              foregroundColor: Colors.white,
            ),
            child: Text(t('deletePocketBtn'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // Modal Setor / Nabung Masuk
  void _showDepositModal({SavingsPocket? preselectedPocket}) {
    final pockets = widget.storageService.getSavingsPockets();
    final wallets = widget.storageService.getWallets();

    if (pockets.isEmpty) {
      _showCreatePocketDialog();
      return;
    }
    if (wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('addWalletFirstAlert')),
          backgroundColor: AppTheme.coralRose,
        ),
      );
      return;
    }

    String selectedPocketId = preselectedPocket?.id ?? pockets.first.id;
    String selectedWalletId = wallets.first.id;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: widget.localeService?.isIndonesian == true ? 'Nabung bulanan' : 'Monthly savings');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final activeWallet = wallets.firstWhere(
              (w) => w.id == selectedWalletId,
              orElse: () => wallets.first,
            );

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
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Row(
                      children: [
                        const Icon(Icons.arrow_downward_rounded, color: AppTheme.emeraldGreen, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          t('depositTitle'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Pilih Kantong Tujuan
                    Text(t('targetPocketLabel'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLighter,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedPocketId,
                          isExpanded: true,
                          dropdownColor: AppTheme.surfaceDark,
                          items: pockets.map((p) {
                            return DropdownMenuItem(
                              value: p.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: Color(p.colorValue), shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(p.name, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedPocketId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Pilih Sumber Dompet
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t('sourceWalletLabel'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        Text(
                          '${t('available')}: ${_currencyFormat.format(activeWallet.balance)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.cyanAccent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLighter,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedWalletId,
                          isExpanded: true,
                          dropdownColor: AppTheme.surfaceDark,
                          items: wallets.map((w) {
                            return DropdownMenuItem(
                              value: w.id,
                              child: Text(w.name, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedWalletId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Nominal Input
                    Text(t('nominal'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.emeraldGreen),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.surfaceLighter,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderDark)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [100000, 250000, 500000, 1000000, 2500000].map((amt) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(
                                '+${(amt / 1000).toInt()}k',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                              ),
                              backgroundColor: AppTheme.surfaceLighter,
                              side: const BorderSide(color: AppTheme.borderDark),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              onPressed: () {
                                final cur = double.tryParse(amountCtrl.text.replaceAll('.', '')) ?? 0.0;
                                amountCtrl.text = (cur + amt).toStringAsFixed(0);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Catatan
                    Text(t('noteOptional'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: widget.localeService?.isIndonesian == true ? 'Contoh: Alokasi gaji awal bulan' : 'e.g. Monthly salary allocation',
                        filled: true,
                        fillColor: AppTheme.surfaceLighter,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderDark)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amount = double.tryParse(amountCtrl.text.replaceAll('.', '')) ?? 0.0;
                          if (amount <= 0) return;

                          if (amount > activeWallet.balance) {
                            ScaffoldMessenger.of(modalCtx).showSnackBar(
                              SnackBar(
                                content: Text(widget.localeService?.isIndonesian == true ? 'Saldo dompet sumber tidak mencukupi.' : 'Insufficient source wallet balance.'),
                                backgroundColor: AppTheme.coralRose,
                              ),
                            );
                            return;
                          }

                          final navigator = Navigator.of(modalCtx);
                          final messenger = ScaffoldMessenger.of(context);

                          await widget.storageService.depositToSavings(
                            pocketId: selectedPocketId,
                            walletId: selectedWalletId,
                            amount: amount,
                            note: noteCtrl.text,
                          );

                          if (mounted) {
                            setState(() {});
                            widget.onDataChanged();
                          }
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(widget.localeService?.isIndonesian == true ? 'Berhasil menabung ${_currencyFormat.format(amount)}!' : 'Successfully deposited ${_currencyFormat.format(amount)}!'),
                              backgroundColor: AppTheme.emeraldGreen,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emeraldGreen,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(t('saveToPocket'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Modal Tarik Dana Tabungan (Keluar)
  void _showWithdrawModal({SavingsPocket? preselectedPocket}) {
    final pockets = widget.storageService.getSavingsPockets();
    final wallets = widget.storageService.getWallets();

    if (pockets.isEmpty) return;
    if (wallets.isEmpty) return;

    String selectedPocketId = preselectedPocket?.id ?? pockets.first.id;
    String selectedWalletId = wallets.first.id;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: 'Tarik dana tabungan');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final activePocket = pockets.firstWhere(
              (p) => p.id == selectedPocketId,
              orElse: () => pockets.first,
            );

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
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Row(
                      children: [
                        const Icon(Icons.arrow_upward_rounded, color: AppTheme.coralRose, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          t('withdrawTitle'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Pilih Kantong Sumber
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t('sourcePocketLabel'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        Text(
                          '${t('available')}: ${_currencyFormat.format(activePocket.currentAmount)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.emeraldGreen, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLighter,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedPocketId,
                          isExpanded: true,
                          dropdownColor: AppTheme.surfaceDark,
                          items: pockets.map((p) {
                            return DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedPocketId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Pilih Dompet Penerima
                    Text(t('destWalletLabel'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLighter,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedWalletId,
                          isExpanded: true,
                          dropdownColor: AppTheme.surfaceDark,
                          items: wallets.map((w) {
                            return DropdownMenuItem(
                              value: w.id,
                              child: Text(w.name, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedWalletId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Nominal Input
                    Text(t('nominal'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.coralRose),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.surfaceLighter,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderDark)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Catatan
                    Text(t('noteOptional'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: widget.localeService?.isIndonesian == true ? 'Contoh: Biaya darurat atau servis' : 'e.g. Emergency expense',
                        filled: true,
                        fillColor: AppTheme.surfaceLighter,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderDark)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amount = double.tryParse(amountCtrl.text.replaceAll('.', '')) ?? 0.0;
                          if (amount <= 0) return;

                          if (amount > activePocket.currentAmount) {
                            ScaffoldMessenger.of(modalCtx).showSnackBar(
                              SnackBar(
                                content: Text(widget.localeService?.isIndonesian == true ? 'Saldo tabungan tidak mencukupi untuk ditarik.' : 'Insufficient savings balance to withdraw.'),
                                backgroundColor: AppTheme.coralRose,
                              ),
                            );
                            return;
                          }

                          final navigator = Navigator.of(modalCtx);
                          final messenger = ScaffoldMessenger.of(context);

                          await widget.storageService.withdrawFromSavings(
                            pocketId: selectedPocketId,
                            walletId: selectedWalletId,
                            amount: amount,
                            note: noteCtrl.text,
                          );

                          if (mounted) {
                            setState(() {});
                            widget.onDataChanged();
                          }
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(widget.localeService?.isIndonesian == true ? 'Berhasil menarik ${_currencyFormat.format(amount)} ke dompet!' : 'Successfully withdrew ${_currencyFormat.format(amount)} to wallet!'),
                              backgroundColor: AppTheme.coralRose,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.coralRose,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(t('withdrawFromPocket'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Dialog Buat Kantong Tabungan Baru
  void _showCreatePocketDialog() {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    int selectedColor = 0xFF10B981;

    final colorOptions = [
      0xFF10B981, // Emerald Green
      0xFF38BDF8, // Sky Cyan
      0xFF8B5CF6, // Violet
      0xFFF59E0B, // Amber
      0xFFEC4899, // Pink Rose
      0xFF14B8A6, // Teal
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.borderDark),
              ),
              title: Text(
                t('createPocketTitle'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('pocketNameLabel'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: t('pocketNameHint'),
                        filled: true,
                        fillColor: AppTheme.surfaceLighter,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderDark)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(t('targetAmountLabel'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: targetCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        hintText: widget.localeService?.isIndonesian == true ? '0 (jika tanpa target tetap)' : '0 (optional)',
                        filled: true,
                        fillColor: AppTheme.surfaceLighter,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderDark)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(t('noteOptional'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: widget.localeService?.isIndonesian == true ? 'Contoh: Target tercapai sebelum akhir tahun' : 'e.g. Target reached before year end',
                        filled: true,
                        fillColor: AppTheme.surfaceLighter,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderDark)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(t('pocketColorLabel'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: colorOptions.map((c) {
                        final isSelected = c == selectedColor;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.black)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(t('cancel'), style: const TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final target = double.tryParse(targetCtrl.text.replaceAll('.', '')) ?? 0.0;

                    final pocket = SavingsPocket(
                      id: const Uuid().v4(),
                      name: nameCtrl.text.trim(),
                      targetAmount: target,
                      currentAmount: 0.0,
                      colorValue: selectedColor,
                      icon: 'savings',
                      notes: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                      createdAt: DateTime.now(),
                    );

                    final navigator = Navigator.of(dialogCtx);
                    await widget.storageService.addSavingsPocket(pocket);
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
    final pockets = widget.storageService.getSavingsPockets();
    final records = widget.storageService.getSavingsRecords();
    final totalSavings = widget.storageService.getTotalSavingsBalance();
    final monthlyIn = widget.storageService.getMonthlySavingsIn(now.month, now.year);
    final monthlyOut = widget.storageService.getMonthlySavingsOut(now.month, now.year);
    final netGrowth = widget.storageService.getNetSavingsGrowth(now.month, now.year);

    final filteredRecords = records.where((r) {
      if (_historyFilter == 'in') return r.isIn;
      if (_historyFilter == 'out') return r.isOut;
      return true;
    }).toList();

    final scrollContent = SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Savings Balance Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF142426), Color(0xFF0D1B1E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.3), width: 1.2),
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
                        Row(
                          children: [
                            const Icon(Icons.savings_rounded, color: AppTheme.emeraldGreen, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              widget.localeService?.t('totalSavings') ?? 'TOTAL SAVINGS',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${pockets.length} Kantong Aktif',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _effectiveBalanceHidden ? 'Rp ••••••••' : _currencyFormat.format(totalSavings),
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
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: AppTheme.emeraldGreen.withValues(alpha: 0.2))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Masuk Bln Ini', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  _isBalanceHidden ? '+Rp •••' : '+${_currencyFormat.format(monthlyIn)}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 26, color: AppTheme.borderDark),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Keluar Bln Ini', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  _isBalanceHidden ? '-Rp •••' : '-${_currencyFormat.format(monthlyOut)}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.coralRose),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 26, color: AppTheme.borderDark),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tumbuh Bersih', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  _isBalanceHidden
                                      ? 'Rp •••'
                                      : (netGrowth >= 0 ? '+${_currencyFormat.format(netGrowth)}' : _currencyFormat.format(netGrowth)),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: netGrowth >= 0 ? AppTheme.cyanAccent : AppTheme.amberWarning,
                                  ),
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
              const SizedBox(height: 18),

              // Aksi Tabungan
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showDepositModal(),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: Text(widget.localeService?.t('deposit') ?? 'Deposit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showWithdrawModal(),
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: Text(widget.localeService?.t('withdraw') ?? 'Withdraw'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceLighter,
                        foregroundColor: AppTheme.coralRose,
                        side: const BorderSide(color: AppTheme.borderDark),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Seksi Kantong Tabungan (Pockets / Goals)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.localeService?.t('secSavingsTargets') ?? 'SAVINGS TARGETS',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.textSecondary),
                  ),
                  TextButton.icon(
                    onPressed: _showCreatePocketDialog,
                    icon: const Icon(Icons.add, size: 16, color: AppTheme.cyanAccent),
                    label: Text(widget.localeService?.t('add') ?? 'Add', style: const TextStyle(fontSize: 12, color: AppTheme.cyanAccent)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (pockets.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.savings_outlined, size: 40, color: AppTheme.textMuted),
                      const SizedBox(height: 8),
                      Text(t('noPocketsYet'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _showCreatePocketDialog,
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cyanAccent, foregroundColor: Colors.black),
                        child: Text(t('newPocket'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pockets.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final p = pockets[index];
                    final color = Color(p.colorValue);
                    final ratio = p.progressRatio;
                    final percent = p.progressPercent;
                    final isDone = p.isAchieved;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDone ? AppTheme.emeraldGreen : AppTheme.borderDark,
                          width: isDone ? 1.5 : 1,
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
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.savings_rounded, color: color, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                      ),
                                      if (p.notes != null)
                                        Text(
                                          p.notes!,
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDone ? AppTheme.emeraldGreen.withValues(alpha: 0.2) : color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isDone ? (widget.localeService?.isIndonesian == true ? 'Tercapai! 🎉' : 'Achieved! 🎉') : '$percent%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isDone ? AppTheme.emeraldGreen : color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Nominal Progress
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _effectiveBalanceHidden ? 'Rp ••••••••' : _currencyFormat.format(p.currentAmount),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                              ),
                              if (p.targetAmount > 0)
                                Text(
                                  '${t('target')}: ${_currencyFormat.format(p.targetAmount)}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Progress Bar
                          if (p.targetAmount > 0) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                backgroundColor: AppTheme.surfaceLighter,
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (!isDone)
                              Text(
                                widget.localeService?.isIndonesian == true
                                    ? 'Kurang ${_currencyFormat.format(p.remainingAmount)} lagi untuk mencapai target.'
                                    : '${_currencyFormat.format(p.remainingAmount)} left to reach target.',
                                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                              ),
                          ],
                          const SizedBox(height: 12),

                          // Tombol Aksi Cepat per Kantong
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.coralRose),
                                tooltip: t('deletePocketBtn'),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _confirmDeletePocket(p),
                              ),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _showWithdrawModal(preselectedPocket: p),
                                    icon: const Icon(Icons.remove, size: 14),
                                    label: Text(t('withdraw'), style: const TextStyle(fontSize: 11)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.coralRose,
                                      side: const BorderSide(color: AppTheme.borderDark),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _showDepositModal(preselectedPocket: p),
                                    icon: const Icon(Icons.add, size: 14),
                                    label: Text(t('deposit'), style: const TextStyle(fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: color,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 28),

              // Seksi Riwayat Mutasi Tabungan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t('secSavingsHistory'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.textSecondary),
                  ),
                  Row(
                    children: [
                      _buildFilterChip('all', t('allFilter')),
                      const SizedBox(width: 4),
                      _buildFilterChip('in', t('inFilter')),
                      const SizedBox(width: 4),
                      _buildFilterChip('out', t('outFilter')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (filteredRecords.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Center(
                    child: Text(t('noSavingsHistory'), style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredRecords.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final r = filteredRecords[index];
                    final isIn = r.isIn;

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
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: isIn ? AppTheme.emeraldGreen.withValues(alpha: 0.15) : AppTheme.coralRose.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                    color: isIn ? AppTheme.emeraldGreen : AppTheme.coralRose,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.note,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${r.pocketName} • ${r.walletName} • ${DateFormat('dd MMM yyyy', widget.localeService?.isIndonesian == true ? 'id_ID' : 'en_US').format(r.date)}',
                                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isIn ? '+${_currencyFormat.format(r.amount)}' : '-${_currencyFormat.format(r.amount)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isIn ? AppTheme.emeraldGreen : AppTheme.coralRose,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 32),
            ],
          ),
        );

    if (widget.showAppBar) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        appBar: AppBar(
          title: Text(widget.localeService?.t('savingsScreenTitle') ?? 'Savings & Pockets'),
          actions: [
            IconButton(
              onPressed: () => setState(() => _isBalanceHidden = !_isBalanceHidden),
              icon: Icon(_effectiveBalanceHidden ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary, size: 20),
              tooltip: 'Balance Privacy',
            ),
            IconButton(
              onPressed: _showImportSavingsCsvDialog,
              icon: const Icon(Icons.file_upload_outlined, color: AppTheme.emeraldGreen, size: 20),
              tooltip: 'Import Pocket CSV',
            ),
          ],
        ),
        body: SafeArea(
          child: scrollContent,
        ),
      );
    }

    return scrollContent;
  }

  void _showImportSavingsCsvDialog() {
    final csvCtrl = TextEditingController();
    bool skipDuplicates = true;
    ParsedSavingsCsv? preview;
    String? validationMsg;

    void updatePreview(String text, StateSetter setModalState) {
      if (text.trim().isEmpty) {
        setModalState(() {
          preview = null;
          validationMsg = null;
        });
        return;
      }

      final parsed = CsvService.parseCsvToSavings(text);
      setModalState(() {
        preview = parsed;
        if (parsed.pockets.isEmpty && parsed.records.isEmpty) {
          validationMsg = t('importNoValid');
        } else {
          final pocketNames = parsed.pockets.map((p) => p.name).join(', ');
          validationMsg = '${t('importPocketDetected').replaceAll('{pockets}', '${parsed.pockets.length}').replaceAll('{count}', '${parsed.records.length}')}\n($pocketNames)';
        }
      });
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isValid = preview != null && (preview!.pockets.isNotEmpty || preview!.records.isNotEmpty);
          return AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppTheme.borderDark),
            ),
            title: Row(
              children: [
                const Icon(Icons.file_upload_outlined, color: AppTheme.emeraldGreen, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.localeService?.isIndonesian == true ? 'Import Data Tabungan' : 'Import Pocket Data',
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
                  Text(
                    widget.localeService?.isIndonesian == true
                        ? 'Pilih file CSV tabungan/pocket untuk memuat pos kantong dan riwayat setor/tarik.'
                        : 'Choose a pocket CSV file to import savings pockets and their records.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          setModalState(() => validationMsg = t('readingFile'));
                          final text = await FileIoService.pickCsvText();
                          if (text == null) {
                            setModalState(() {
                              if (csvCtrl.text.isEmpty) {
                                validationMsg = null;
                              }
                            });
                            return;
                          }
                          if (text.trim().isEmpty) {
                            setModalState(() => validationMsg = t('fileEmpty'));
                            return;
                          }
                          csvCtrl.text = text;
                          updatePreview(text, setModalState);
                        } catch (e) {
                          setModalState(() => validationMsg = '${t('csvReadFailed')} $e');
                        }
                      },
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: Text(t('chooseCsvFile'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(t('orPasteCsv'), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: csvCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'ID,Tanggal,Kantong,Tipe,Nominal,Catatan,Saldo_Akhir\n...',
                      hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5), fontSize: 11),
                      filled: true,
                      fillColor: AppTheme.surfaceLighter,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderDark)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    onChanged: (val) => updatePreview(val, setModalState),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null && data!.text!.trim().isNotEmpty) {
                            csvCtrl.text = data.text!;
                            updatePreview(data.text!, setModalState);
                          }
                        },
                        icon: const Icon(Icons.paste, size: 14, color: AppTheme.cyanAccent),
                        label: Text(
                          widget.localeService?.isIndonesian == true ? 'Tempel dari Clipboard' : 'Paste from Clipboard',
                          style: const TextStyle(fontSize: 11, color: AppTheme.cyanAccent),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.borderDark),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (csvCtrl.text.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            csvCtrl.clear();
                            updatePreview('', setModalState);
                          },
                          child: Text(t('clear'), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ),
                    ],
                  ),
                  if (validationMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isValid
                            ? AppTheme.emeraldGreen.withValues(alpha: 0.12)
                            : AppTheme.coralRose.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isValid
                              ? AppTheme.emeraldGreen.withValues(alpha: 0.3)
                              : AppTheme.coralRose.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isValid ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                            size: 16,
                            color: isValid ? AppTheme.emeraldGreen : AppTheme.coralRose,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              validationMsg!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isValid ? AppTheme.emeraldGreen : AppTheme.coralRose,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: skipDuplicates,
                    activeColor: AppTheme.emeraldGreen,
                    title: Text(
                      widget.localeService?.isIndonesian == true
                          ? 'Lewati duplikat catatan yang sudah ada'
                          : 'Skip existing duplicate records',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    onChanged: (val) => setModalState(() => skipDuplicates = val ?? true),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(t('cancel'), style: const TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton.icon(
                onPressed: isValid
                    ? () async {
                        Navigator.pop(dialogCtx);
                        final count = await widget.storageService.importSavingsData(
                          newPockets: preview!.pockets,
                          newRecords: preview!.records,
                          skipDuplicates: skipDuplicates,
                        );
                        if (mounted) {
                          setState(() {});
                          widget.onDataChanged();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t('importPocketSuccess').replaceAll('{pockets}', '${preview!.pockets.length}').replaceAll('{count}', '$count')),
                              backgroundColor: AppTheme.emeraldGreen,
                            ),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.file_upload, size: 16),
                label: Text(
                  widget.localeService?.isIndonesian == true ? 'Import Sekarang' : 'Import Now',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.surfaceLighter,
                  disabledForegroundColor: AppTheme.textMuted,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String val, String label) {
    final isSelected = _historyFilter == val;
    return GestureDetector(
      onTap: () => setState(() => _historyFilter = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.emeraldGreen.withValues(alpha: 0.2) : AppTheme.surfaceLighter,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.emeraldGreen : AppTheme.borderDark),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.emeraldGreen : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/wallet.dart';
import '../models/category.dart';
import '../models/transaction_item.dart';
import '../services/storage_service.dart';
import '../services/csv_service.dart';
import '../services/file_io_service.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/locale_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storageService;
  final AiService aiService;
  final AuthService authService;
  final LocaleService localeService;
  final VoidCallback onDataChanged;
  final VoidCallback onLogout;

  const SettingsScreen({
    super.key,
    required this.storageService,
    required this.aiService,
    required this.authService,
    required this.localeService,
    required this.onDataChanged,
    required this.onLogout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _endpointController;
  late String _selectedProvider;
  bool _obscureApiKey = true;
  String _categoryFilter = 'all'; // 'all', 'expense', 'income'
  bool _showAllCategories = false;

  String t(String key) => widget.localeService.t(key);

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.aiService.getApiKey());
    _endpointController = TextEditingController(text: widget.aiService.getCustomEndpoint());
    _selectedProvider = widget.aiService.getProvider();
  }

  void _saveAiSettings() async {
    await widget.aiService.setProvider(_selectedProvider);
    await widget.aiService.setApiKey(_apiKeyController.text);
    await widget.aiService.setCustomEndpoint(_endpointController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan Kunci API tersimpan di penyimpanan aman lokal HP.'),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
    }
  }

  void _showAddWalletDialog() {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    String type = 'cash';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.borderDark),
              ),
              title: const Text('Tambah Dompet / Rekening', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nama Dompet / Bank:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: t('walletNameHint'),
                      hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.7), fontSize: 12),
                      filled: true,
                      fillColor: AppTheme.surfaceLighter,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(t('initialBalanceLabel'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: balanceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      filled: true,
                      fillColor: AppTheme.surfaceLighter,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(t('walletTypeLabel'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildTypeRadio('cash', t('typeCash'), type, (val) => setDialogState(() => type = val)),
                      _buildTypeRadio('bank', t('typeBank'), type, (val) => setDialogState(() => type = val)),
                      _buildTypeRadio('ewallet', t('typeEWallet'), type, (val) => setDialogState(() => type = val)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(t('cancel'), style: const TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final navigator = Navigator.of(dialogContext);
                    final bal = double.tryParse(balanceCtrl.text.replaceAll('.', '')) ?? 0.0;
                    final newWallet = Wallet(
                      id: const Uuid().v4(),
                      name: nameCtrl.text.trim(),
                      type: type,
                      balance: bal,
                      icon: type == 'bank' ? 'account_balance' : (type == 'ewallet' ? 'phone_android' : 'payments'),
                      colorValue: type == 'bank' ? 0xFF38BDF8 : (type == 'ewallet' ? 0xFF8B5CF6 : 0xFF10B981),
                    );

                    await widget.storageService.addWallet(newWallet);
                    if (mounted) {
                      setState(() {});
                      widget.onDataChanged();
                    }
                    navigator.pop();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen, foregroundColor: Colors.black),
                  child: Text(t('add'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTypeRadio(String val, String label, String groupVal, Function(String) onSelect) {
    final isSelected = val == groupVal;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(val),
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.emeraldGreen.withValues(alpha: 0.2) : AppTheme.surfaceLighter,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppTheme.emeraldGreen : AppTheme.borderDark),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AppTheme.emeraldGreen : AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }

  void _showDeleteWalletConfirmDialog(Wallet w) {
    final t = widget.localeService.t;
    final wallets = widget.storageService.getWallets();
    if (wallets.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('cannotDeleteLastWallet')),
          backgroundColor: AppTheme.coralRose,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
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
                child: Text('${t('deleteWallet')} "${w.name}"', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ),
            ],
          ),
          content: Text(
            t('deleteWalletConfirm'),
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(t('cancel'), style: const TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await widget.storageService.deleteWallet(w.id);
                if (mounted) {
                  setState(() {});
                  widget.onDataChanged();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralRose,
                foregroundColor: Colors.white,
              ),
              child: Text(t('delete'), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  void _showAddCategoryDialog() {
    final t = widget.localeService.t;
    final nameCtrl = TextEditingController();
    String type = 'expense';
    int colorValue = 0xFFF59E0B;

    final colorOptions = [
      0xFFF59E0B, // Amber
      0xFF38BDF8, // Cyan/Sky
      0xFFF43F5E, // Rose
      0xFF8B5CF6, // Purple
      0xFFEC4899, // Pink
      0xFF10B981, // Emerald
      0xFF14B8A6, // Teal
      0xFF64748B, // Slate
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (builderCtx, setModalState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.borderDark),
              ),
              title: Text(t('addCategoryTitle'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('categoryName'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: t('categoryNameHint'),
                      hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.6), fontSize: 12),
                      filled: true,
                      fillColor: AppTheme.surfaceLighter,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(t('categoryType'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildTypeRadio('expense', t('expense'), type, (v) => setModalState(() => type = v)),
                      _buildTypeRadio('income', t('income'), type, (v) => setModalState(() => type = v)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(t('pocketColorLabel'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: colorOptions.map((c) {
                      final isSelected = colorValue == c;
                      return GestureDetector(
                        onTap: () => setModalState(() => colorValue = c),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(t('cancel'), style: const TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final navigator = Navigator.of(dialogCtx);
                    final newCat = CategoryItem(
                      id: 'cat_${const Uuid().v4().substring(0, 8)}',
                      name: nameCtrl.text.trim(),
                      type: type,
                      icon: type == 'income' ? 'trending_up' : 'label',
                      colorValue: colorValue,
                    );
                    await widget.storageService.addCategory(newCat);
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
                  child: Text(t('add'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteCategoryConfirmDialog(CategoryItem c) {
    final t = widget.localeService.t;
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
              child: Text('${t('deleteCategory')} "${c.name}"', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ),
          ],
        ),
        content: Text(
          t('deleteCategoryConfirm'),
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(t('cancel'), style: const TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await widget.storageService.deleteCategory(c.id);
              if (mounted) {
                setState(() {});
                widget.onDataChanged();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coralRose,
              foregroundColor: Colors.white,
            ),
            child: Text(t('delete'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _exportCsv() {
    final t = widget.localeService.t;
    final transactions = widget.storageService.getTransactions();
    final wallets = widget.storageService.getWallets();
    final categories = widget.storageService.getCategories();
    final pockets = widget.storageService.getSavingsPockets();
    final records = widget.storageService.getSavingsRecords();

    final txCsv = CsvService.exportTransactionsToCsv(
      transactions: transactions,
      wallets: wallets,
      categories: categories,
    );
    final pocketCsv = CsvService.exportSavingsToCsv(pockets: pockets, records: records);

    String target = 'transactions';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (builderCtx, setModalState) {
            final isTx = target == 'transactions';
            final csvString = isTx ? txCsv : pocketCsv;
            final count = isTx ? transactions.length : records.length;
            final summary = isTx
                ? t('exportTxSummary').replaceAll('{count}', '$count')
                : t('exportPocketSummary')
                    .replaceAll('{count}', '$count')
                    .replaceAll('{pockets}', '${pockets.length}');

            Widget segment(String value, String label, IconData icon) {
              final selected = target == value;
              return Expanded(
                child: InkWell(
                  onTap: () => setModalState(() => target = value),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.emeraldGreen.withValues(alpha: 0.15) : AppTheme.surfaceLighter,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? AppTheme.emeraldGreen : AppTheme.borderDark),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 16, color: selected ? AppTheme.emeraldGreen : AppTheme.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? AppTheme.emeraldGreen : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.borderDark)),
              title: Text(t('exportModalTitle'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      segment('transactions', t('exportTargetTx'), Icons.receipt_long_outlined),
                      const SizedBox(width: 8),
                      segment('pockets', t('exportTargetPocket'), Icons.savings_outlined),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(summary, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  Container(
                    height: 110,
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLighter,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        csvString,
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: csvString));
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t('csvCopied')), backgroundColor: AppTheme.emeraldGreen),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 14, color: AppTheme.cyanAccent),
                      label: Text(t('copyCsv'), style: const TextStyle(fontSize: 12, color: AppTheme.cyanAccent)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(t('cancel'), style: const TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton.icon(
                  onPressed: (count == 0 || isSaving)
                      ? null
                      : () async {
                          setModalState(() => isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final name = FileIoService.datedName(isTx ? 'iritot_transactions' : 'iritot_pockets');
                            await FileIoService.saveCsv(baseName: name, csv: csvString);
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(t('csvDownloaded').replaceAll('{file}', '$name.csv')),
                                backgroundColor: AppTheme.emeraldGreen,
                              ),
                            );
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            messenger.showSnackBar(
                              SnackBar(content: Text('${t('csvSaveFailed')} $e'), backgroundColor: AppTheme.coralRose),
                            );
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.download_rounded, size: 16),
                  label: Text(t('downloadCsv'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emeraldGreen,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: AppTheme.surfaceLighter,
                    disabledForegroundColor: AppTheme.textMuted,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showImportCsvDialog() {
    final t = widget.localeService.t;
    final csvCtrl = TextEditingController();
    bool skipDuplicates = true;
    List<TransactionItem> previewItems = [];
    ParsedSavingsCsv? previewSavings;
    bool isSavings = false;
    String? validationMsg;

    void updatePreview(String text, StateSetter setModalState) {
      if (text.trim().isEmpty) {
        setModalState(() {
          previewItems = [];
          previewSavings = null;
          isSavings = false;
          validationMsg = null;
        });
        return;
      }

      if (CsvService.isSavingsCsv(text)) {
        final parsed = CsvService.parseCsvToSavings(text);
        setModalState(() {
          isSavings = true;
          previewSavings = parsed;
          previewItems = [];
          if (parsed.pockets.isEmpty && parsed.records.isEmpty) {
            validationMsg = t('importNoValid');
          } else {
            validationMsg = t('importPocketDetected').replaceAll('{pockets}', '${parsed.pockets.length}').replaceAll('{count}', '${parsed.records.length}');
          }
        });
        return;
      }

      final wallets = widget.storageService.getWallets();
      final categories = widget.storageService.getCategories();
      final parsed = CsvService.parseCsvToTransactions(
        csvString: text,
        wallets: wallets,
        categories: categories,
      );

      setModalState(() {
        isSavings = false;
        previewSavings = null;
        previewItems = parsed;
        if (parsed.isEmpty) {
          validationMsg = t('importNoValid');
        } else {
          final expCount = parsed.where((item) => item.type == 'expense').length;
          final incCount = parsed.where((item) => item.type == 'income').length;
          validationMsg = '${parsed.length} ${t('importValidDetected')} ($expCount ${t('importExpenseWord')}, $incCount ${t('importIncomeWord')})';
        }
      });
    }

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (builderCtx, setModalState) {
            final isValid = previewItems.isNotEmpty || (previewSavings != null && (previewSavings!.pockets.isNotEmpty || previewSavings!.records.isNotEmpty));
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
                      t('importModalTitle'),
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
                      t('importCsvSubtitle'),
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
                    Text(
                      t('orPasteCsv'),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: csvCtrl,
                      maxLines: 4,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        hintText: 'ID,Tanggal,Tipe,Dompet,Kategori,Nominal,Keterangan\n...',
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
                          label: Text(t('pasteFromClipboard'), style: const TextStyle(fontSize: 11, color: AppTheme.cyanAccent)),
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
                        t('importSkipDuplicates'),
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
                          if (isSavings && previewSavings != null) {
                            final count = await widget.storageService.importSavingsData(
                              newPockets: previewSavings!.pockets,
                              newRecords: previewSavings!.records,
                              skipDuplicates: skipDuplicates,
                            );
                            if (mounted) {
                              setState(() {});
                              widget.onDataChanged();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(t('importPocketSuccess').replaceAll('{pockets}', '${previewSavings!.pockets.length}').replaceAll('{count}', '$count')),
                                  backgroundColor: AppTheme.emeraldGreen,
                                ),
                              );
                            }
                          } else {
                            final count = await widget.storageService.importTransactions(
                              previewItems,
                              skipDuplicates: skipDuplicates,
                            );
                            if (mounted) {
                              setState(() {});
                              widget.onDataChanged();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(t('importTxSuccess').replaceAll('{count}', '$count')),
                                  backgroundColor: AppTheme.emeraldGreen,
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  icon: const Icon(Icons.file_upload, size: 16),
                  label: Text(t('importNow'), style: const TextStyle(fontWeight: FontWeight.w700)),
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
        );
      },
    );
  }

  Widget _buildCategoryFilterChip({
    required String label,
    required bool isSelected,
    Color activeColor = AppTheme.cyanAccent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : AppTheme.surfaceLighter,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor.withValues(alpha: 0.5) : AppTheme.borderDark,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeColor : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final t = widget.localeService.t;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final displayNameCtrl = TextEditingController(text: widget.authService.getDisplayName());
    final oldPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();

    bool changePin = false;
    String? dialogError;
    bool obscureOldPin = true;
    bool obscureNewPin = true;
    bool obscureConfirmPin = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (builderCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.borderDark),
              ),
              title: Row(
                children: [
                  const Icon(Icons.manage_accounts_outlined, color: AppTheme.cyanAccent, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t('editProfileTitle'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('editProfileSubtitle'),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 14),

                      if (dialogError != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.coralRose.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.coralRose.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppTheme.coralRose, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dialogError!,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.coralRose, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Nama Tampilan / Panggilan
                      Text(t('displayNameLabel'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: displayNameCtrl,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: t('displayNameHint'),
                          hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: AppTheme.surfaceLighter,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderDark)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Checkbox Ganti PIN
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: changePin,
                        activeColor: AppTheme.cyanAccent,
                        title: Text(
                          t('changePinCheck'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                        onChanged: (val) => setDialogState(() => changePin = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),

                      if (changePin) ...[
                        const SizedBox(height: 8),
                        // PIN Lama
                        Text(t('oldPinLabel'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: oldPinCtrl,
                          obscureText: obscureOldPin,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, letterSpacing: 2),
                          decoration: InputDecoration(
                            hintText: t('oldPinHint'),
                            hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5), letterSpacing: 0),
                            filled: true,
                            fillColor: AppTheme.surfaceLighter,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderDark)),
                            suffixIcon: IconButton(
                              icon: Icon(obscureOldPin ? Icons.visibility : Icons.visibility_off, color: AppTheme.textMuted, size: 18),
                              onPressed: () => setDialogState(() => obscureOldPin = !obscureOldPin),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // PIN Baru
                        Text(t('newPinLabel'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: newPinCtrl,
                          obscureText: obscureNewPin,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, letterSpacing: 2),
                          decoration: InputDecoration(
                            hintText: t('newPinHint'),
                            hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5), letterSpacing: 0),
                            filled: true,
                            fillColor: AppTheme.surfaceLighter,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderDark)),
                            suffixIcon: IconButton(
                              icon: Icon(obscureNewPin ? Icons.visibility : Icons.visibility_off, color: AppTheme.textMuted, size: 18),
                              onPressed: () => setDialogState(() => obscureNewPin = !obscureNewPin),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Konfirmasi PIN Baru
                        Text(t('confirmPinLabel'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: confirmPinCtrl,
                          obscureText: obscureConfirmPin,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, letterSpacing: 2),
                          decoration: InputDecoration(
                            hintText: t('confirmPinHint'),
                            hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5), letterSpacing: 0),
                            filled: true,
                            fillColor: AppTheme.surfaceLighter,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderDark)),
                            suffixIcon: IconButton(
                              icon: Icon(obscureConfirmPin ? Icons.visibility : Icons.visibility_off, color: AppTheme.textMuted, size: 18),
                              onPressed: () => setDialogState(() => obscureConfirmPin = !obscureConfirmPin),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: Text(t('cancel'), style: const TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final newName = displayNameCtrl.text.trim();
                          final oldPin = oldPinCtrl.text.trim();
                          final newPin = newPinCtrl.text.trim();
                          final confirmPin = confirmPinCtrl.text.trim();

                          if (newName.isEmpty) {
                            setDialogState(() => dialogError = 'Nama tampilan tidak boleh kosong.');
                            return;
                          }

                          if (changePin) {
                            if (oldPin.isEmpty) {
                              setDialogState(() => dialogError = t('errOldRequired'));
                              return;
                            }
                            if (newPin.length != 6) {
                              setDialogState(() => dialogError = t('errNewPassShort'));
                              return;
                            }
                            if (!RegExp(r'^\d{6}$').hasMatch(newPin)) {
                              setDialogState(() => dialogError = 'PIN baru harus 6 digit angka.');
                              return;
                            }
                            if (newPin != confirmPin) {
                              setDialogState(() => dialogError = t('errPassMismatch'));
                              return;
                            }
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            dialogError = null;
                          });

                          final result = await widget.authService.updateProfile(
                            newDisplayName: newName,
                            oldPin: changePin ? oldPin : null,
                            newPin: changePin ? newPin : null,
                          );

                          if (result['success'] == true) {
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (!mounted) return;
                            setState(() {});
                            widget.onDataChanged();
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(t('profileUpdatedSuccess')),
                                backgroundColor: AppTheme.emeraldGreen,
                              ),
                            );
                          } else {
                            setDialogState(() {
                              isSubmitting = false;
                              dialogError = result['message'] as String? ?? 'Gagal memperbarui profil.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyanAccent,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(t('saveChanges'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutConfirmDialog() {
    final t = widget.localeService.t;
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.borderDark),
          ),
          title: Row(
            children: [
              const Icon(Icons.logout, color: AppTheme.coralRose, size: 20),
              const SizedBox(width: 8),
              Text(t('logoutDialogTitle'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
          content: Text(
            t('logoutDialogDesc'),
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(t('cancel'), style: const TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                widget.onLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralRose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(t('lockAndExit'), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  void _showResetDataConfirmDialog() {
    final t = widget.localeService.t;
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.borderDark),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.coralRose, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('resetDataDialogTitle'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          content: Text(
            t('resetDataDialogDesc'),
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
                await widget.storageService.clearFinancialData();
                widget.onDataChanged();
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t('resetDataSuccess')),
                      backgroundColor: AppTheme.emeraldGreen,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralRose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(t('resetDataConfirm'), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeService.t;
    final wallets = widget.storageService.getWallets();
    final categories = widget.storageService.getCategories();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(t('navSettings')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Seksi Akun & Keamanan Lokal
              Text(
                t('secAccountSecurity'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Material(
                color: AppTheme.surfaceDark,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppTheme.borderDark),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.4)),
                            ),
                            child: const Icon(Icons.person, color: AppTheme.emeraldGreen, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.authService.getDisplayName(),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.pin_outlined, size: 12, color: AppTheme.cyanAccent),
                                    const SizedBox(width: 4),
                                    Text(
                                      t('securityPinActive'),
                                      style: const TextStyle(fontSize: 12, color: AppTheme.cyanAccent, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle, size: 12, color: AppTheme.emeraldGreen),
                                    const SizedBox(width: 4),
                                    Text(t('offlineBadge'), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.emeraldGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  t('active'),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.cyanAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.cyanAccent.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 10, color: AppTheme.cyanAccent),
                                    const SizedBox(width: 3),
                                    Text(
                                      t('autoLockChip'),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.cyanAccent),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: AppTheme.borderDark, height: 1),
                    ListTile(
                      leading: const Icon(Icons.manage_accounts_outlined, color: AppTheme.cyanAccent, size: 22),
                      title: Text(t('editProfileTitle'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      subtitle: Text(t('editProfileSubtitle'), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                      onTap: _showEditProfileDialog,
                    ),
                    const Divider(color: AppTheme.borderDark, height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout, color: AppTheme.coralRose, size: 22),
                      title: Text(t('logoutTitle'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.coralRose)),
                      subtitle: Text(t('logoutSubtitle'), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                      onTap: _showLogoutConfirmDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Seksi Bahasa / Language Preference
              Text(
                t('secLanguage'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.language, color: AppTheme.cyanAccent, size: 22),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('appLanguage'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            const SizedBox(height: 2),
                            Text(
                              widget.localeService.isEnglish ? 'English' : 'Bahasa Indonesia',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLighter,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: widget.localeService.currentLocale,
                          dropdownColor: AppTheme.surfaceDark,
                          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textMuted),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.emeraldGreen),
                          items: const [
                            DropdownMenuItem(
                              value: 'en',
                              child: Text('English (Default)'),
                            ),
                            DropdownMenuItem(
                              value: 'id',
                              child: Text('Bahasa Indonesia'),
                            ),
                          ],
                          onChanged: (val) async {
                            if (val != null) {
                              await widget.localeService.setLocale(val);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(val == 'en' ? 'Language switched to English' : 'Bahasa diubah ke Bahasa Indonesia'),
                                    backgroundColor: AppTheme.emeraldGreen,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Seksi Dompet
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t('secWallets'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.textSecondary)),
                  TextButton.icon(
                    onPressed: _showAddWalletDialog,
                    icon: const Icon(Icons.add, size: 16, color: AppTheme.emeraldGreen),
                    label: Text(t('add'), style: const TextStyle(fontSize: 12, color: AppTheme.emeraldGreen)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Material(
                color: AppTheme.surfaceDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppTheme.borderDark),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (int i = 0; i < wallets.length; i++) ...[
                      if (i > 0) const Divider(color: AppTheme.borderDark, height: 1),
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(wallets[i].colorValue).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            wallets[i].type == 'bank'
                                ? Icons.account_balance
                                : (wallets[i].type == 'ewallet' ? Icons.phone_android : Icons.payments),
                            color: Color(wallets[i].colorValue),
                            size: 18,
                          ),
                        ),
                        title: Text(wallets[i].name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        subtitle: Text(
                          wallets[i].type == 'bank' ? t('typeBank') : (wallets[i].type == 'ewallet' ? t('typeEWallet') : t('typeCash')),
                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rp ${wallets[i].balance.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.coralRose),
                              onPressed: () => _showDeleteWalletConfirmDialog(wallets[i]),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              tooltip: t('delete'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Seksi Kelola Kategori
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t('manageCategoriesTitle'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.textSecondary)),
                  TextButton.icon(
                    onPressed: _showAddCategoryDialog,
                    icon: const Icon(Icons.add, size: 16, color: AppTheme.emeraldGreen),
                    label: Text(t('add'), style: const TextStyle(fontSize: 12, color: AppTheme.emeraldGreen)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final expenseCats = categories.where((c) => c.type == 'expense').toList();
                  final incomeCats = categories.where((c) => c.type == 'income').toList();

                  List<CategoryItem> displayedList;
                  if (_categoryFilter == 'expense') {
                    displayedList = expenseCats;
                  } else if (_categoryFilter == 'income') {
                    displayedList = incomeCats;
                  } else {
                    displayedList = categories;
                  }

                  final totalFiltered = displayedList.length;
                  final shouldTruncate = !_showAllCategories && totalFiltered > 4;
                  final visibleList = shouldTruncate ? displayedList.take(4).toList() : displayedList;

                  return Material(
                    color: AppTheme.surfaceDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppTheme.borderDark),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Filter Segment Chips
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: Row(
                            children: [
                              _buildCategoryFilterChip(
                                label: '${t('categoryFilterAll')} (${categories.length})',
                                isSelected: _categoryFilter == 'all',
                                onTap: () => setState(() => _categoryFilter = 'all'),
                              ),
                              const SizedBox(width: 8),
                              _buildCategoryFilterChip(
                                label: '${t('categoryFilterExpense')} (${expenseCats.length})',
                                isSelected: _categoryFilter == 'expense',
                                activeColor: AppTheme.coralRose,
                                onTap: () => setState(() => _categoryFilter = 'expense'),
                              ),
                              const SizedBox(width: 8),
                              _buildCategoryFilterChip(
                                label: '${t('categoryFilterIncome')} (${incomeCats.length})',
                                isSelected: _categoryFilter == 'income',
                                activeColor: AppTheme.emeraldGreen,
                                onTap: () => setState(() => _categoryFilter = 'income'),
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: AppTheme.borderDark, height: 1),

                        // List Kategori
                        if (visibleList.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Tidak ada kategori di filter ini.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted.withValues(alpha: 0.7)),
                            ),
                          )
                        else
                          for (int i = 0; i < visibleList.length; i++) ...[
                            if (i > 0) const Divider(color: AppTheme.borderDark, height: 1),
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              leading: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Color(visibleList[i].colorValue).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Color(visibleList[i].colorValue),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    visibleList[i].name,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: visibleList[i].type == 'expense'
                                          ? AppTheme.coralRose.withValues(alpha: 0.12)
                                          : (visibleList[i].type == 'income'
                                              ? AppTheme.emeraldGreen.withValues(alpha: 0.12)
                                              : AppTheme.cyanAccent.withValues(alpha: 0.12)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      visibleList[i].type == 'expense'
                                          ? t('expense')
                                          : (visibleList[i].type == 'income' ? t('income') : 'Transfer'),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: visibleList[i].type == 'expense'
                                            ? AppTheme.coralRose
                                            : (visibleList[i].type == 'income' ? AppTheme.emeraldGreen : AppTheme.cyanAccent),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.coralRose),
                                onPressed: () => _showDeleteCategoryConfirmDialog(visibleList[i]),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                tooltip: t('delete'),
                              ),
                            ),
                          ],

                        // Toggle Expand / Collapse jika kategori banyak
                        if (totalFiltered > 4) ...[
                          const Divider(color: AppTheme.borderDark, height: 1),
                          InkWell(
                            onTap: () => setState(() => _showAllCategories = !_showAllCategories),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _showAllCategories
                                        ? t('showLess')
                                        : '${t('showAll')} ($totalFiltered)',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.cyanAccent),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _showAllCategories ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    size: 16,
                                    color: AppTheme.cyanAccent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Seksi Data & Cadangan
              Text(t('secBackup'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Material(
                color: AppTheme.surfaceDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppTheme.borderDark),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.file_download_outlined, color: AppTheme.cyanAccent),
                      title: Text(t('exportCsvTitle'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      subtitle: Text(t('exportCsvSubtitle'), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                      onTap: _exportCsv,
                    ),
                    const Divider(color: AppTheme.borderDark, height: 1),
                    ListTile(
                      leading: const Icon(Icons.file_upload_outlined, color: AppTheme.emeraldGreen),
                      title: Text(t('importCsvTitle'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      subtitle: Text(t('importCsvSubtitle'), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                      onTap: _showImportCsvDialog,
                    ),
                    const Divider(color: AppTheme.borderDark, height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_sweep_outlined, color: AppTheme.coralRose),
                      title: Text(t('resetDataTitle'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.coralRose)),
                      subtitle: Text(t('resetDataSubtitle'), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                      onTap: _showResetDataConfirmDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Seksi BYOK AI (Bring Your Own Key)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t('secAi'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.textSecondary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.aiService.hasApiKey ? AppTheme.emeraldGreen.withValues(alpha: 0.2) : AppTheme.surfaceLighter,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.aiService.hasApiKey ? t('aiConnected') : t('aiNoKey'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.aiService.hasApiKey ? AppTheme.emeraldGreen : AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('aiDesc'),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 14),

                    // Pilih Provider
                    const Text('Provider AI:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLighter,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedProvider,
                          isExpanded: true,
                          dropdownColor: AppTheme.surfaceDark,
                          items: const [
                            DropdownMenuItem(value: 'gemini', child: Text('Google Gemini (Free AI Studio)', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
                            DropdownMenuItem(value: 'openai', child: Text('OpenAI (GPT-4o mini)', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
                            DropdownMenuItem(value: 'ollama', child: Text('Ollama (Local LLM)', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedProvider = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Input API Key
                    if (_selectedProvider != 'ollama') ...[
                      Text(t('aiApiKey'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _apiKeyController,
                        obscureText: _obscureApiKey,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: _selectedProvider == 'gemini' ? 'AIzaSy...' : 'sk-...',
                          hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: AppTheme.surfaceLighter,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderDark)),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off, color: AppTheme.textMuted, size: 18),
                            onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ] else ...[
                      Text(t('aiEndpoint'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _endpointController,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'http://192.168.1.100:11434',
                          filled: true,
                          fillColor: AppTheme.surfaceLighter,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderDark)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveAiSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.violetAI,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(t('saveAiBtn'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Info Footer
              Center(
                child: Column(
                  children: [
                    const Text('IRITOT v1.0.5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                    const SizedBox(height: 2),
                    Text(t('offlineBadge'), style: TextStyle(fontSize: 10, color: AppTheme.textMuted.withValues(alpha: 0.6))),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

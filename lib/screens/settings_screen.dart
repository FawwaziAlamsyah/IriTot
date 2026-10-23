import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/wallet.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../services/csv_service.dart';
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
                      hintText: 'Contoh: Bank Jago, Dana, dll.',
                      hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.7), fontSize: 12),
                      filled: true,
                      fillColor: AppTheme.surfaceLighter,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Saldo Awal (Rp):', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
                  const Text('Tipe Dompet:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildTypeRadio('cash', 'Tunai', type, (val) => setDialogState(() => type = val)),
                      _buildTypeRadio('bank', 'Bank', type, (val) => setDialogState(() => type = val)),
                      _buildTypeRadio('ewallet', 'E-Wallet', type, (val) => setDialogState(() => type = val)),
                    ],
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
                  child: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.w700)),
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
                  const Text('Pilih Warna:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
    final transactions = widget.storageService.getTransactions();
    final wallets = widget.storageService.getWallets();
    final categories = widget.storageService.getCategories();

    final csvString = CsvService.exportTransactionsToCsv(
      transactions: transactions,
      wallets: wallets,
      categories: categories,
    );

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.borderDark)),
          title: const Text('Ekspor Cadangan CSV', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${transactions.length} transaksi siap diekspor ke format CSV universal.', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              Container(
                height: 120,
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Tutup', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: csvString));
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('File CSV disalin ke Clipboard!'), backgroundColor: AppTheme.emeraldGreen),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Salin CSV'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cyanAccent, foregroundColor: Colors.black),
            ),
          ],
        );
      },
    );
  }

  void _showChangeCredentialsDialog() {
    final t = widget.localeService.t;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final oldUserCtrl = TextEditingController(text: widget.authService.getUsername());
    final oldPassCtrl = TextEditingController();
    final newUserCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    String? dialogError;
    bool obscureOldPass = true;
    bool obscureNewPass = true;
    bool obscureConfirmPass = true;
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
                  const Icon(Icons.shield_outlined, color: AppTheme.cyanAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t('changeCredentialsTitle'),
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
                        t('changeCredentialsDesc'),
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

                      // Username Lama
                      Text(t('oldUsernameLabel'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: oldUserCtrl,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: t('oldUsernameHint'),
                          hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: AppTheme.surfaceLighter,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderDark)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Password Lama
                      Text(t('oldPasswordLabel'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: oldPassCtrl,
                        obscureText: obscureOldPass,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: t('oldPasswordHint'),
                          hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: AppTheme.surfaceLighter,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderDark)),
                          suffixIcon: IconButton(
                            icon: Icon(obscureOldPass ? Icons.visibility : Icons.visibility_off, color: AppTheme.textMuted, size: 18),
                            onPressed: () => setDialogState(() => obscureOldPass = !obscureOldPass),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Divider(color: AppTheme.borderDark, height: 1),
                      const SizedBox(height: 14),

                      // Username Baru
                      Text(t('newUsernameLabel'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: newUserCtrl,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: t('newUsernameHint'),
                          hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: AppTheme.surfaceLighter,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderDark)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Password Baru
                      Text(t('newPasswordLabel'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: newPassCtrl,
                        obscureText: obscureNewPass,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: t('newPasswordHint'),
                          hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: AppTheme.surfaceLighter,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderDark)),
                          suffixIcon: IconButton(
                            icon: Icon(obscureNewPass ? Icons.visibility : Icons.visibility_off, color: AppTheme.textMuted, size: 18),
                            onPressed: () => setDialogState(() => obscureNewPass = !obscureNewPass),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Konfirmasi Password Baru
                      Text(t('confirmPasswordLabel'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: confirmPassCtrl,
                        obscureText: obscureConfirmPass,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: t('confirmPasswordHint'),
                          hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: AppTheme.surfaceLighter,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderDark)),
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirmPass ? Icons.visibility : Icons.visibility_off, color: AppTheme.textMuted, size: 18),
                            onPressed: () => setDialogState(() => obscureConfirmPass = !obscureConfirmPass),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
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
                          final oldUser = oldUserCtrl.text.trim();
                          final oldPass = oldPassCtrl.text;
                          final newUser = newUserCtrl.text.trim();
                          final newPass = newPassCtrl.text;
                          final confirmPass = confirmPassCtrl.text;

                          if (oldUser.isEmpty || oldPass.isEmpty) {
                            setDialogState(() => dialogError = t('errOldRequired'));
                            return;
                          }
                          if (newUser.isEmpty) {
                            setDialogState(() => dialogError = t('errNewUserEmpty'));
                            return;
                          }
                          if (newPass.length < 4) {
                            setDialogState(() => dialogError = t('errNewPassShort'));
                            return;
                          }
                          if (newPass != confirmPass) {
                            setDialogState(() => dialogError = t('errPassMismatch'));
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            dialogError = null;
                          });

                          final result = await widget.authService.changeCredentials(
                            oldUsername: oldUser,
                            oldPassword: oldPass,
                            newUsername: newUser,
                            newPassword: newPass,
                          );

                          if (result['success'] == true) {
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (!mounted) return;
                            setState(() {});
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(t('credentialsUpdatedSuccess')),
                                backgroundColor: AppTheme.emeraldGreen,
                              ),
                            );
                          } else {
                            setDialogState(() {
                              isSubmitting = false;
                              dialogError = result['message'] as String? ?? 'Failed to update credentials.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyanAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text(t('saveChanges'), style: const TextStyle(fontWeight: FontWeight.w700)),
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
                                  '@${widget.authService.getUsername()}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 2),
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
                      leading: const Icon(Icons.lock_reset, color: AppTheme.cyanAccent, size: 22),
                      title: Text(t('changeCredentialsTitle'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      subtitle: Text(t('changeCredentialsSubtitle'), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                      onTap: _showChangeCredentialsDialog,
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
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: wallets.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final w = wallets[index];
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
                            Icon(
                              w.type == 'bank' ? Icons.account_balance : (w.type == 'ewallet' ? Icons.phone_android : Icons.payments),
                              color: Color(w.colorValue),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(w.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              'Rp ${w.balance.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showDeleteWalletConfirmDialog(w),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.delete_outline, size: 18, color: AppTheme.coralRose),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Seksi Kelola Kategori
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t('secCategories'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.textSecondary)),
                  TextButton.icon(
                    onPressed: _showAddCategoryDialog,
                    icon: const Icon(Icons.add, size: 16, color: AppTheme.emeraldGreen),
                    label: Text(t('add'), style: const TextStyle(fontSize: 12, color: AppTheme.emeraldGreen)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categories.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final c = categories[index];
                  final isExp = c.type == 'expense';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                              decoration: BoxDecoration(
                                color: Color(c.colorValue),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              c.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isExp
                                    ? AppTheme.coralRose.withValues(alpha: 0.12)
                                    : (c.type == 'income'
                                        ? AppTheme.emeraldGreen.withValues(alpha: 0.12)
                                        : AppTheme.cyanAccent.withValues(alpha: 0.12)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isExp ? t('expense') : (c.type == 'income' ? t('income') : 'Transfer'),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: isExp ? AppTheme.coralRose : (c.type == 'income' ? AppTheme.emeraldGreen : AppTheme.cyanAccent),
                                ),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _showDeleteCategoryConfirmDialog(c),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.delete_outline, size: 18, color: AppTheme.coralRose),
                          ),
                        ),
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
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    ListTile(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      leading: const Icon(Icons.file_download, color: AppTheme.cyanAccent),
                      title: Text(t('exportCsvTitle'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      subtitle: Text(t('exportCsvSubtitle'), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                      onTap: _exportCsv,
                    ),
                    const Divider(color: AppTheme.borderDark, height: 1),
                    ListTile(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
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
                    const Text('IRITOT v1.0.0', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
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

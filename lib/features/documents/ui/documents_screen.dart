import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_chip.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, this.tenancyId});
  final String? tenancyId;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  bool _isLoading = true;
  String? _resolvedTenancyId;
  List<_DocItem> _documents = [];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      final client = Supabase.instance.client;
      String? tId = widget.tenancyId ?? _resolvedTenancyId;
      if (tId == null) {
        final user = client.auth.currentUser;
        if (user != null) {
          final tenRes = await client
              .from('tenancies')
              .select('id')
              .eq('profile_id', user.id)
              .maybeSingle();
          tId = tenRes?['id'] as String?;
        }
      }
      _resolvedTenancyId = tId;

      if (tId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final res = await client
          .from('documents')
          .select('id, doc_type, storage_path, file_size_bytes, mime_type, is_deleted, created_at')
          .eq('tenancy_id', tId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      final rows = res as List<dynamic>;
      final list = rows.map((r) {
        final date = DateTime.tryParse((r['created_at'] as String?) ?? '') ?? DateTime.now();
        return _DocItem(
          id: r['id'] as String,
          docType: (r['doc_type'] as String?) ?? 'other',
          storagePath: (r['storage_path'] as String?) ?? 'Document',
          uploadedAt: date,
          sizeBytes: (r['file_size_bytes'] as num?)?.toInt(),
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _documents = list;
      });
    } catch (e) {
      debugPrint('Error loading documents: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showAddDocumentSheet() {
    final titleCtrl = TextEditingController();
    final pathCtrl = TextEditingController();
    String selectedType = 'aadhaar';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            top: 24, left: 24, right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Document Record', style: AppTextStyles.h2),
              const SizedBox(height: 16),
              const Text('Document Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'aadhaar', label: Text('Aadhaar')),
                  ButtonSegment(value: 'pan', label: Text('PAN')),
                  ButtonSegment(value: 'agreement', label: Text('Agreement')),
                  ButtonSegment(value: 'other', label: Text('Other')),
                ],
                selected: {selectedType},
                onSelectionChanged: (s) => setSheetState(() => selectedType = s.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Document Name / Title',
                  hintText: 'e.g. Aadhaar Card (Front & Back)',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pathCtrl,
                decoration: const InputDecoration(
                  labelText: 'Document Number / Reference (optional)',
                  hintText: 'e.g. XXXX-XXXX-1234 or File Reference',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Save Document',
                type: AppButtonType.primary,
                onPressed: () async {
                  final name = titleCtrl.text.trim();
                  if (name.isEmpty) return;

                  Navigator.pop(ctx);
                  try {
                    final client = Supabase.instance.client;
                    final userId = client.auth.currentUser?.id;
                    final refPath = pathCtrl.text.trim().isNotEmpty
                        ? '$name (${pathCtrl.text.trim()})'
                        : name;

                    await client.from('documents').insert({
                      'tenancy_id': _resolvedTenancyId ?? widget.tenancyId,
                      'doc_type': selectedType,
                      'storage_path': refPath,
                      if (userId != null) 'uploader_id': userId,
                    });

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Document added successfully.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    setState(() => _isLoading = true);
                    _loadDocuments();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to save document: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteDocument(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to remove "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final client = Supabase.instance.client;
      await client.from('documents').update({
        'is_deleted': true,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document deleted.'), backgroundColor: AppColors.success),
      );
      setState(() => _isLoading = true);
      _loadDocuments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete document: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _navigateBack() {
    if (context.canPop()) {
      context.pop();
    } else if (widget.tenancyId != null) {
      context.go('${Routes.tenantProfile}/${widget.tenancyId}');
    } else {
      context.go(Routes.tenantHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('Documents', style: AppTextStyles.h2),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _navigateBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadDocuments();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.folder_open_rounded, size: 56, color: AppColors.inkMuted),
                        const SizedBox(height: 16),
                        Text('No documents uploaded yet', style: AppTextStyles.h3),
                        const SizedBox(height: 8),
                        Text(
                          'Keep track of tenant agreements, Aadhaar, PAN cards, and identity proofs.',
                          style: AppTextStyles.bodyRegular,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _showAddDocumentSheet,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Document'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _documents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final doc = _documents[i];
                    return _DocTile(
                      doc: doc,
                      onDelete: () => _deleteDocument(doc.id, doc.storagePath),
                    );
                  },
                ),
      floatingActionButton: _documents.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showAddDocumentSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add document'),
            )
          : null,
    );
  }
}

class _DocItem {
  final String id;
  final String docType;
  final String storagePath;
  final DateTime uploadedAt;
  final int? sizeBytes;

  const _DocItem({
    required this.id,
    required this.docType,
    required this.storagePath,
    required this.uploadedAt,
    this.sizeBytes,
  });

  String get typeLabel {
    switch (docType) {
      case 'aadhaar':
        return 'Aadhaar Card';
      case 'pan':
        return 'PAN Card';
      case 'agreement':
        return 'Rent Agreement';
      default:
        return 'Other Document';
    }
  }

  IconData get icon {
    switch (docType) {
      case 'aadhaar':
      case 'pan':
        return Icons.badge_rounded;
      case 'agreement':
        return Icons.handshake_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  Color get color {
    switch (docType) {
      case 'aadhaar':
        return AppColors.action;
      case 'pan':
        return AppColors.navy;
      case 'agreement':
        return AppColors.success;
      default:
        return AppColors.warning;
    }
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.doc, required this.onDelete});
  final _DocItem doc;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final d = doc.uploadedAt;
    final dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: doc.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(doc.icon, color: doc.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusChip(
                      label: doc.typeLabel,
                      type: StatusChipType.neutral,
                    ),
                    const SizedBox(width: 8),
                    Text(dateStr, style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  doc.storagePath,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            tooltip: 'Delete document',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

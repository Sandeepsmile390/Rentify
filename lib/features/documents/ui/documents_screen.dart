import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_chip.dart';

/// Real document management — file picker, local compression, private Supabase Storage, and signed URLs
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
          mimeType: (r['mime_type'] as String?) ?? 'application/octet-stream',
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

  /// Compress image bytes locally to maintain legibility while reducing size
  Uint8List _compressImageLocally(Uint8List rawBytes) {
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return rawBytes;

      img.Image resized = decoded;
      // Cap max dimension to 1600px while maintaining aspect ratio
      if (decoded.width > 1600 || decoded.height > 1600) {
        resized = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1600 : null,
          height: decoded.height > decoded.width ? 1600 : null,
          interpolation: img.Interpolation.linear,
        );
      }

      // Encode to JPEG with 80% quality
      final compressed = img.encodeJpg(resized, quality: 80);
      return Uint8List.fromList(compressed);
    } catch (_) {
      return rawBytes;
    }
  }

  void _showAddDocumentSheet() {
    String selectedType = 'aadhaar';
    PlatformFile? pickedFile;
    Uint8List? fileBytes;
    bool isCompressing = false;
    bool isUploading = false;
    String? uploadError;

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
              Text('Upload Tenant Document', style: AppTextStyles.h2),
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

              if (pickedFile == null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    side: const BorderSide(color: AppColors.action),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.attach_file_rounded, color: AppColors.action),
                  label: const Text('Choose Photo or PDF File', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () async {
                    try {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
                        withData: true,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final file = result.files.first;
                        setSheetState(() {
                          pickedFile = file;
                          fileBytes = file.bytes;
                          uploadError = null;
                        });
                      }
                    } catch (e) {
                      setSheetState(() => uploadError = 'File picker error: $e');
                    }
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        pickedFile!.extension?.toLowerCase() == 'pdf'
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_outlined,
                        color: AppColors.action,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pickedFile!.name,
                              style: AppTextStyles.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${((fileBytes?.length ?? 0) / 1024).toStringAsFixed(1)} KB',
                              style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.error),
                        onPressed: () => setSheetState(() {
                          pickedFile = null;
                          fileBytes = null;
                        }),
                      ),
                    ],
                  ),
                ),

              if (uploadError != null) ...[
                const SizedBox(height: 12),
                Text(uploadError!, style: AppTextStyles.captionBold.copyWith(color: AppColors.error)),
              ],

              const SizedBox(height: 24),
              AppButton(
                label: isUploading
                    ? 'Uploading…'
                    : isCompressing
                        ? 'Compressing…'
                        : 'Upload Document',
                type: AppButtonType.primary,
                onPressed: (pickedFile == null || fileBytes == null || isUploading || isCompressing)
                    ? null
                    : () async {
                        setSheetState(() {
                          isCompressing = true;
                          uploadError = null;
                        });

                        try {
                          final tenancyId = _resolvedTenancyId ?? widget.tenancyId;
                          if (tenancyId == null) {
                            throw Exception('Tenancy not selected.');
                          }

                          final client = Supabase.instance.client;
                          final userId = client.auth.currentUser?.id;
                          final ext = pickedFile!.extension?.toLowerCase() ?? 'jpg';
                          final isPdf = ext == 'pdf';

                          Uint8List uploadBytes = fileBytes!;
                          String mimeType = isPdf ? 'application/pdf' : 'image/jpeg';

                          if (!isPdf) {
                            // Compress locally
                            uploadBytes = _compressImageLocally(uploadBytes);
                          }

                          setSheetState(() {
                            isCompressing = false;
                            isUploading = true;
                          });

                          final filename = '${DateTime.now().millisecondsSinceEpoch}_$selectedType.${isPdf ? 'pdf' : 'jpg'}';
                          final objectPath = '$tenancyId/$filename';

                          // 1. Upload to private Supabase Storage
                          await client.storage.from('documents').uploadBinary(
                            objectPath,
                            uploadBytes,
                            fileOptions: FileOptions(
                              contentType: mimeType,
                              upsert: true,
                            ),
                          );

                          // 2. Insert metadata into documents table
                          await client.from('documents').insert({
                            'tenancy_id': tenancyId,
                            'doc_type': selectedType,
                            'storage_path': objectPath,
                            'file_size_bytes': uploadBytes.length,
                            'mime_type': mimeType,
                            if (userId != null) 'uploader_id': userId,
                          });

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Document uploaded & compressed (${(uploadBytes.length / 1024).toStringAsFixed(1)} KB)!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            setState(() => _isLoading = true);
                            _loadDocuments();
                          }
                        } catch (e) {
                          setSheetState(() {
                            isCompressing = false;
                            isUploading = false;
                            uploadError = 'Upload failed: $e';
                          });
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

  Future<void> _viewDocument(_DocItem doc) async {
    try {
      final client = Supabase.instance.client;
      // Generate short-lived signed URL (300 seconds)
      final signedUrl = await client.storage
          .from('documents')
          .createSignedUrl(doc.storagePath, 300);

      if (!mounted) return;

      if (doc.isImage) {
        showDialog(
          context: context,
          builder: (dCtx) => AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(doc.typeLabel, style: AppTextStyles.h3)),
                IconButton(
                  icon: const Icon(Icons.open_in_browser_rounded),
                  tooltip: 'Open in Browser',
                  onPressed: () => launchUrl(Uri.parse(signedUrl), mode: LaunchMode.externalApplication),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  signedUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('Could not load image preview.'),
                  ),
                ),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        // Open PDF in viewer or browser
        await launchUrl(Uri.parse(signedUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document: $e'), backgroundColor: AppColors.error),
        );
      }
    }
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
              : RefreshIndicator(
                  onRefresh: _loadDocuments,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _documents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final doc = _documents[i];
                      return _DocTile(
                        doc: doc,
                        onTap: () => _viewDocument(doc),
                        onDelete: () => _deleteDocument(doc.id, doc.displayTitle),
                      );
                    },
                  ),
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
  final String mimeType;
  final DateTime uploadedAt;
  final int? sizeBytes;

  const _DocItem({
    required this.id,
    required this.docType,
    required this.storagePath,
    required this.mimeType,
    required this.uploadedAt,
    this.sizeBytes,
  });

  bool get isImage =>
      mimeType.startsWith('image/') ||
      storagePath.endsWith('.jpg') ||
      storagePath.endsWith('.jpeg') ||
      storagePath.endsWith('.png');

  String get displayTitle {
    final parts = storagePath.split('/');
    return parts.isNotEmpty ? parts.last : storagePath;
  }

  String get typeLabel {
    switch (docType) {
      case 'aadhaar':
        return 'Aadhaar Card';
      case 'pan':
        return 'PAN Card';
      case 'agreement':
        return 'Rent Agreement';
      default:
        return 'ID Document';
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
  const _DocTile({
    required this.doc,
    required this.onTap,
    required this.onDelete,
  });
  final _DocItem doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final d = doc.uploadedAt;
    final dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final sizeKb = doc.sizeBytes != null ? '${(doc.sizeBytes! / 1024).toStringAsFixed(1)} KB' : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                      if (sizeKb != null) ...[
                        const SizedBox(width: 6),
                        Text('· $sizeKb', style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    doc.displayTitle,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.visibility_outlined, color: AppColors.action),
              tooltip: 'View Document',
              onPressed: onTap,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              tooltip: 'Delete document',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

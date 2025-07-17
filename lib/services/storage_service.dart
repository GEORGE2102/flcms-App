import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import '../utils/app_config.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Storage error types for categorized error handling
enum StorageErrorType {
  networkError,
  permissionError,
  quotaExceeded,
  fileNotFound,
  invalidFormat,
  fileTooLarge,
  compressionFailed,
  uploadFailed,
  deleteError,
  unknown,
}

/// Detailed storage error with user-friendly messages
class StorageError extends Error {
  final StorageErrorType type;
  final String message;
  final String userMessage;
  final String? technicalDetails;
  final Exception? originalException;

  StorageError({
    required this.type,
    required this.message,
    required this.userMessage,
    this.technicalDetails,
    this.originalException,
  });

  factory StorageError.fromException(Exception exception) {
    final errorString = exception.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('connection')) {
      return StorageError(
        type: StorageErrorType.networkError,
        message: 'Network connection failed',
        userMessage: 'Please check your internet connection and try again.',
        technicalDetails: exception.toString(),
        originalException: exception,
      );
    } else if (errorString.contains('permission') ||
        errorString.contains('unauthorized')) {
      return StorageError(
        type: StorageErrorType.permissionError,
        message: 'Permission denied',
        userMessage: 'You don\'t have permission to access this file.',
        technicalDetails: exception.toString(),
        originalException: exception,
      );
    } else if (errorString.contains('quota') ||
        errorString.contains('storage')) {
      return StorageError(
        type: StorageErrorType.quotaExceeded,
        message: 'Storage quota exceeded',
        userMessage:
            'Storage space is full. Please contact your administrator.',
        technicalDetails: exception.toString(),
        originalException: exception,
      );
    } else if (errorString.contains('not found') ||
        errorString.contains('404')) {
      return StorageError(
        type: StorageErrorType.fileNotFound,
        message: 'File not found',
        userMessage: 'The requested file could not be found.',
        technicalDetails: exception.toString(),
        originalException: exception,
      );
    } else {
      return StorageError(
        type: StorageErrorType.unknown,
        message: 'Unknown error occurred',
        userMessage: 'An unexpected error occurred. Please try again.',
        technicalDetails: exception.toString(),
        originalException: exception,
      );
    }
  }

  @override
  String toString() => 'StorageError: $message (${type.name})';
}

/// Enhanced storage path organization
class StoragePathBuilder {
  static String buildPath({
    required String imageType,
    required String relatedId,
    required String fileName,
    DateTime? timestamp,
  }) {
    final ts = timestamp ?? DateTime.now();
    final year = ts.year.toString();
    final month = ts.month.toString().padLeft(2, '0');

    switch (imageType.toLowerCase()) {
      case 'fellowship':
        return 'fellowship_images/$year/$month/$relatedId/$fileName';
      case 'receipt':
        return 'financial/receipts/$year/$month/$relatedId/$fileName';
      case 'bus':
        return 'transportation/bus_reports/$year/$month/$relatedId/$fileName';
      case 'profile':
        return 'users/profiles/$relatedId/$fileName';
      default:
        return 'general/$year/$month/$relatedId/$fileName';
    }
  }

  static String generateFileName({
    required String imageType,
    required String relatedId,
    required String fileExtension,
    DateTime? timestamp,
  }) {
    final ts = timestamp ?? DateTime.now();
    final uuid = const Uuid().v4().split('-')[0]; // Short UUID
    final timestampStr = ts.millisecondsSinceEpoch.toString();

    return '${imageType}_${relatedId}_${timestampStr}_$uuid.$fileExtension';
  }
}

/// Storage logging service
class StorageLogger {
  static void logUpload({
    required String imageType,
    required String path,
    required int originalSize,
    required int compressedSize,
    int? retryCount,
  }) {
    if (kDebugMode) {
      final compressionRatio =
          ((originalSize - compressedSize) / originalSize * 100).round();
      print('📤 Upload Success - $imageType');
      print('   Path: $path');
      print(
        '   Size: ${_formatBytes(originalSize)} → ${_formatBytes(compressedSize)} ($compressionRatio% saved)',
      );
      if (retryCount != null && retryCount > 0) {
        print('   Retries: $retryCount');
      }
    }
  }

  static void logError({
    required String operation,
    required StorageError error,
    String? context,
  }) {
    if (kDebugMode) {
      print('❌ Storage Error - $operation');
      print('   Type: ${error.type.name}');
      print('   Message: ${error.message}');
      if (context != null) {
        print('   Context: $context');
      }
      if (error.technicalDetails != null) {
        print('   Details: ${error.technicalDetails}');
      }
    }
  }

  static void logCacheOperation({
    required String operation,
    required String imageType,
    String? details,
  }) {
    if (kDebugMode) {
      print('🗂️ Cache $operation - $imageType');
      if (details != null) {
        print('   $details');
      }
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// Upload progress state for tracking upload status
enum UploadState { idle, compressing, uploading, completed, failed, cancelled }

/// Upload progress data with detailed tracking
class UploadProgress {
  final UploadState state;
  final double progress;
  final int bytesTransferred;
  final int totalBytes;
  final String? error;
  final int retryCount;

  UploadProgress({
    required this.state,
    required this.progress,
    required this.bytesTransferred,
    required this.totalBytes,
    this.error,
    this.retryCount = 0,
  });

  UploadProgress copyWith({
    UploadState? state,
    double? progress,
    int? bytesTransferred,
    int? totalBytes,
    String? error,
    int? retryCount,
  }) {
    return UploadProgress(
      state: state ?? this.state,
      progress: progress ?? this.progress,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      error: error ?? this.error,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

/// Cancellable upload handle for managing uploads
class UploadHandle {
  final String id;
  final Stream<UploadProgress> progressStream;
  final Future<String> uploadFuture;
  final Function() cancel;

  UploadHandle({
    required this.id,
    required this.progressStream,
    required this.uploadFuture,
    required this.cancel,
  });
}

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Upload management
  final Map<String, UploadTask?> _activeUploads = {};
  final Map<String, bool> _cancelledUploads = {};

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 2);
  static const double _retryBackoffMultiplier = 2.0;

  // Compression quality settings for different image types
  static const int _fellowshipImageQuality =
      85; // High quality for fellowship photos
  static const int _receiptImageQuality =
      92; // Very high quality for receipt readability
  static const int _busImageQuality = 80; // Good quality for bus photos
  static const int _profileImageQuality =
      90; // High quality for profile pictures

  /// Compress image based on its intended use
  Future<File> _compressImage({
    required File imageFile,
    required String imageType,
    int? customQuality,
  }) async {
    try {
      // Determine compression quality based on image type
      int quality;
      switch (imageType) {
        case 'fellowship':
          quality = customQuality ?? _fellowshipImageQuality;
          break;
        case 'receipt':
          quality = customQuality ?? _receiptImageQuality;
          break;
        case 'bus':
          quality = customQuality ?? _busImageQuality;
          break;
        case 'profile':
          quality = customQuality ?? _profileImageQuality;
          break;
        default:
          quality = 85; // Default quality
      }

      // Generate compressed file path
      final fileExtension = path.extension(imageFile.path);
      final fileName = path.basenameWithoutExtension(imageFile.path);
      final compressedPath =
          '${imageFile.parent.path}/${fileName}_compressed$fileExtension';

      // Compress the image
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        compressedPath,
        quality: quality,
        minWidth: 800, // Reasonable width for mobile viewing
        minHeight: 600, // Reasonable height for mobile viewing
        format: CompressFormat.jpeg, // Convert all to JPEG for consistency
      );

      if (compressedFile == null) {
        throw StorageError(
          type: StorageErrorType.compressionFailed,
          message: 'Image compression returned null',
          userMessage:
              'Failed to process image. Please try with a different image.',
          technicalDetails: 'FlutterImageCompress returned null',
        );
      }

      return File(compressedFile.path);
    } catch (e) {
      if (e is StorageError) {
        rethrow;
      }

      // Log compression failure but continue with original file
      StorageLogger.logError(
        operation: 'imageCompression',
        error: StorageError(
          type: StorageErrorType.compressionFailed,
          message: 'Compression failed, using original',
          userMessage:
              'Image optimization failed, proceeding with original image.',
          technicalDetails: e.toString(),
        ),
        context: 'Image type: $imageType',
      );

      return imageFile;
    }
  }

  /// Calculate retry delay with exponential backoff
  Duration _calculateRetryDelay(int retryCount) {
    final delayMs =
        _baseRetryDelay.inMilliseconds *
        pow(_retryBackoffMultiplier, retryCount);
    return Duration(milliseconds: delayMs.round());
  }

  /// Check if error is retryable (legacy method)
  bool _isRetryableError(Exception error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('socket') ||
        errorString.contains('interrupted');
  }

  /// Check if storage error is retryable based on error type
  bool _isRetryableStorageError(StorageError error) {
    switch (error.type) {
      case StorageErrorType.networkError:
      case StorageErrorType.uploadFailed:
        return true;
      case StorageErrorType.permissionError:
      case StorageErrorType.quotaExceeded:
      case StorageErrorType.fileNotFound:
      case StorageErrorType.invalidFormat:
      case StorageErrorType.fileTooLarge:
      case StorageErrorType.compressionFailed:
      case StorageErrorType.deleteError:
        return false;
      case StorageErrorType.unknown:
        // For unknown errors, fall back to string analysis
        return _isRetryableError(Exception(error.message));
    }
  }

  /// Generic upload method with compression, progress tracking, and retry logic
  UploadHandle uploadImageWithAdvancedTracking({
    required File imageFile,
    required String storagePath,
    required String imageType,
    required String userId,
    required String relatedId,
    int? customQuality,
  }) {
    final uploadId = _uuid.v4();
    late final Stream<UploadProgress> progressStream;
    late final Future<String> uploadFuture;

    // Create progress stream controller
    late final StreamController<UploadProgress> progressController;
    progressController = StreamController<UploadProgress>.broadcast();
    progressStream = progressController.stream;

    // Upload future with retry logic
    uploadFuture = _performUploadWithRetry(
      uploadId: uploadId,
      imageFile: imageFile,
      storagePath: storagePath,
      imageType: imageType,
      userId: userId,
      relatedId: relatedId,
      customQuality: customQuality,
      progressController: progressController,
    );

    // Cleanup when upload completes
    uploadFuture.whenComplete(() {
      _activeUploads.remove(uploadId);
      _cancelledUploads.remove(uploadId);
      progressController.close();
    });

    return UploadHandle(
      id: uploadId,
      progressStream: progressStream,
      uploadFuture: uploadFuture,
      cancel: () => _cancelUpload(uploadId),
    );
  }

  /// Perform upload with retry logic
  Future<String> _performUploadWithRetry({
    required String uploadId,
    required File imageFile,
    required String storagePath,
    required String imageType,
    required String userId,
    required String relatedId,
    int? customQuality,
    required StreamController<UploadProgress> progressController,
    int retryCount = 0,
  }) async {
    try {
      // Check if upload was cancelled
      if (_cancelledUploads.containsKey(uploadId)) {
        progressController.add(
          UploadProgress(
            state: UploadState.cancelled,
            progress: 0.0,
            bytesTransferred: 0,
            totalBytes: 0,
            retryCount: retryCount,
          ),
        );
        throw Exception('Upload cancelled');
      }

      // Validate file
      if (!isValidImageFile(imageFile)) {
        throw Exception('Invalid image file format');
      }

      // Check file size before compression
      final originalSize = await imageFile.length();
      if (originalSize > AppConfig.maxImageSizeBytes) {
        throw Exception(
          'Image size exceeds ${AppConfig.maxImageSizeBytes ~/ 1024 ~/ 1024}MB limit',
        );
      }

      // Update progress: Starting compression
      progressController.add(
        UploadProgress(
          state: UploadState.compressing,
          progress: 0.0,
          bytesTransferred: 0,
          totalBytes: originalSize,
          retryCount: retryCount,
        ),
      );

      // Compress the image
      final compressedFile = await _compressImage(
        imageFile: imageFile,
        imageType: imageType,
        customQuality: customQuality,
      );

      // Update progress: Starting upload
      final compressedSize = await compressedFile.length();
      progressController.add(
        UploadProgress(
          state: UploadState.uploading,
          progress: 0.0,
          bytesTransferred: 0,
          totalBytes: compressedSize,
          retryCount: retryCount,
        ),
      );

      // Upload to Firebase Storage
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(compressedFile);

      // Store upload task for cancellation
      _activeUploads[uploadId] = uploadTask;

      // Monitor progress
      final progressSubscription = uploadTask.snapshotEvents.listen((snapshot) {
        if (!progressController.isClosed) {
          final progress =
              snapshot.totalBytes > 0
                  ? snapshot.bytesTransferred / snapshot.totalBytes
                  : 0.0;

          progressController.add(
            UploadProgress(
              state: UploadState.uploading,
              progress: progress,
              bytesTransferred: snapshot.bytesTransferred,
              totalBytes: snapshot.totalBytes,
              retryCount: retryCount,
            ),
          );
        }
      });

      try {
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        // Upload completed successfully
        progressController.add(
          UploadProgress(
            state: UploadState.completed,
            progress: 1.0,
            bytesTransferred: compressedSize,
            totalBytes: compressedSize,
            retryCount: retryCount,
          ),
        );

        // Log upload with compression info
        await _logUpload(
          path: storagePath,
          downloadUrl: downloadUrl,
          uploadedBy: userId,
          fileType: imageType,
          relatedId: relatedId,
          originalSize: originalSize,
          compressedSize: compressedSize,
          retryCount: retryCount,
        );

        // Enhanced logging
        StorageLogger.logUpload(
          imageType: imageType,
          path: storagePath,
          originalSize: originalSize,
          compressedSize: compressedSize,
          retryCount: retryCount,
        );

        // Clean up compressed file if different from original
        if (compressedFile.path != imageFile.path) {
          try {
            await compressedFile.delete();
          } catch (e) {
            if (kDebugMode) {
              print('Failed to delete temporary compressed file: $e');
            }
          }
        }

        return downloadUrl;
      } finally {
        await progressSubscription.cancel();
      }
    } catch (e) {
      final storageError =
          e is StorageError
              ? e
              : StorageError.fromException(
                e is Exception ? e : Exception(e.toString()),
              );

      // Check if upload was cancelled
      if (_cancelledUploads.containsKey(uploadId)) {
        progressController.add(
          UploadProgress(
            state: UploadState.cancelled,
            progress: 0.0,
            bytesTransferred: 0,
            totalBytes: 0,
            error: 'Upload cancelled',
            retryCount: retryCount,
          ),
        );
        throw StorageError(
          type: StorageErrorType.uploadFailed,
          message: 'Upload cancelled',
          userMessage: 'Upload was cancelled by user.',
        );
      }

      // Check if we should retry based on error type
      final isRetryable = _isRetryableStorageError(storageError);
      if (retryCount < _maxRetries && isRetryable) {
        StorageLogger.logError(
          operation: 'uploadRetry',
          error: storageError,
          context: 'Retry ${retryCount + 1}/$_maxRetries for $imageType',
        );

        // Update progress: Failed, will retry
        progressController.add(
          UploadProgress(
            state: UploadState.failed,
            progress: 0.0,
            bytesTransferred: 0,
            totalBytes: 0,
            error: 'Connection issue, retrying...',
            retryCount: retryCount,
          ),
        );

        // Wait before retry with exponential backoff
        await Future.delayed(_calculateRetryDelay(retryCount));

        // Retry the upload
        return _performUploadWithRetry(
          uploadId: uploadId,
          imageFile: imageFile,
          storagePath: storagePath,
          imageType: imageType,
          userId: userId,
          relatedId: relatedId,
          customQuality: customQuality,
          progressController: progressController,
          retryCount: retryCount + 1,
        );
      } else {
        // Final failure - log and report
        StorageLogger.logError(
          operation: 'uploadFailed',
          error: storageError,
          context: 'Final failure after $retryCount retries for $imageType',
        );

        progressController.add(
          UploadProgress(
            state: UploadState.failed,
            progress: 0.0,
            bytesTransferred: 0,
            totalBytes: 0,
            error: storageError.userMessage,
            retryCount: retryCount,
          ),
        );
        throw storageError;
      }
    }
  }

  /// Cancel an active upload
  void _cancelUpload(String uploadId) {
    _cancelledUploads[uploadId] = true;
    final uploadTask = _activeUploads[uploadId];
    if (uploadTask != null) {
      uploadTask.cancel();
    }
  }

  /// Legacy upload method with progress callback (maintained for backward compatibility)
  Future<String> _uploadImageWithCompression({
    required File imageFile,
    required String storagePath,
    required String imageType,
    required String userId,
    required String relatedId,
    int? customQuality,
    Function(double)? onProgress,
  }) async {
    final uploadHandle = uploadImageWithAdvancedTracking(
      imageFile: imageFile,
      storagePath: storagePath,
      imageType: imageType,
      userId: userId,
      relatedId: relatedId,
      customQuality: customQuality,
    );

    // Listen to progress if callback provided
    if (onProgress != null) {
      uploadHandle.progressStream.listen((progress) {
        onProgress(progress.progress);
      });
    }

    return uploadHandle.uploadFuture;
  }

  /// Upload fellowship report image
  Future<String> uploadFellowshipImage({
    required File imageFile,
    required String fellowshipId,
    required String userId,
    Function(double)? onProgress,
  }) async {
    try {
      // Enhanced validation
      validateImageFile(imageFile);
      await validateFileSize(imageFile, 'fellowship');

      // Generate organized path and filename
      final fileName = StoragePathBuilder.generateFileName(
        imageType: 'fellowship',
        relatedId: fellowshipId,
        fileExtension: 'jpg',
      );
      final storagePath = StoragePathBuilder.buildPath(
        imageType: 'fellowship',
        relatedId: fellowshipId,
        fileName: fileName,
      );

      return await _uploadImageWithCompression(
        imageFile: imageFile,
        storagePath: storagePath,
        imageType: 'fellowship',
        userId: userId,
        relatedId: fellowshipId,
        onProgress: onProgress,
      );
    } catch (e) {
      final error =
          e is StorageError ? e : StorageError.fromException(e as Exception);
      StorageLogger.logError(
        operation: 'uploadFellowshipImage',
        error: error,
        context: 'Fellowship ID: $fellowshipId, User: $userId',
      );
      throw error;
    }
  }

  /// Upload fellowship report image with advanced tracking
  UploadHandle uploadFellowshipImageWithTracking({
    required File imageFile,
    required String fellowshipId,
    required String userId,
  }) {
    final fileName = 'fellowship_${fellowshipId}_${_uuid.v4()}.jpg';
    final path = 'fellowship_images/$fellowshipId/$fileName';

    return uploadImageWithAdvancedTracking(
      imageFile: imageFile,
      storagePath: path,
      imageType: 'fellowship',
      userId: userId,
      relatedId: fellowshipId,
    );
  }

  /// Upload receipt image
  Future<String> uploadReceiptImage({
    required File imageFile,
    required String reportId,
    required String userId,
    Function(double)? onProgress,
  }) async {
    final fileName = 'receipt_${reportId}_${_uuid.v4()}.jpg';
    final path = 'receipt_images/$reportId/$fileName';

    return _uploadImageWithCompression(
      imageFile: imageFile,
      storagePath: path,
      imageType: 'receipt',
      userId: userId,
      relatedId: reportId,
      onProgress: onProgress,
    );
  }

  /// Upload receipt image with advanced tracking
  UploadHandle uploadReceiptImageWithTracking({
    required File imageFile,
    required String reportId,
    required String userId,
  }) {
    final fileName = 'receipt_${reportId}_${_uuid.v4()}.jpg';
    final path = 'receipt_images/$reportId/$fileName';

    return uploadImageWithAdvancedTracking(
      imageFile: imageFile,
      storagePath: path,
      imageType: 'receipt',
      userId: userId,
      relatedId: reportId,
    );
  }

  /// Upload bus report image
  Future<String> uploadBusImage({
    required File imageFile,
    required String busReportId,
    required String userId,
    Function(double)? onProgress,
  }) async {
    final fileName = 'bus_${busReportId}_${_uuid.v4()}.jpg';
    final path = 'bus_images/$busReportId/$fileName';

    return _uploadImageWithCompression(
      imageFile: imageFile,
      storagePath: path,
      imageType: 'bus',
      userId: userId,
      relatedId: busReportId,
      onProgress: onProgress,
    );
  }

  /// Upload bus report image with advanced tracking
  UploadHandle uploadBusImageWithTracking({
    required File imageFile,
    required String busReportId,
    required String userId,
  }) {
    final fileName = 'bus_${busReportId}_${_uuid.v4()}.jpg';
    final path = 'bus_images/$busReportId/$fileName';

    return uploadImageWithAdvancedTracking(
      imageFile: imageFile,
      storagePath: path,
      imageType: 'bus',
      userId: userId,
      relatedId: busReportId,
    );
  }

  /// Upload profile picture
  Future<String> uploadProfilePicture({
    required File imageFile,
    required String userId,
    Function(double)? onProgress,
  }) async {
    final fileName = 'profile_${userId}_${_uuid.v4()}.jpg';
    final path = 'profile_pictures/$userId/$fileName';

    return _uploadImageWithCompression(
      imageFile: imageFile,
      storagePath: path,
      imageType: 'profile',
      userId: userId,
      relatedId: userId,
      onProgress: onProgress,
    );
  }

  /// Upload profile picture with advanced tracking
  UploadHandle uploadProfilePictureWithTracking({
    required File imageFile,
    required String userId,
  }) {
    final fileName = 'profile_${userId}_${_uuid.v4()}.jpg';
    final path = 'profile_pictures/$userId/$fileName';

    return uploadImageWithAdvancedTracking(
      imageFile: imageFile,
      storagePath: path,
      imageType: 'profile',
      userId: userId,
      relatedId: userId,
    );
  }

  /// Delete file from storage
  Future<void> deleteFile(String downloadUrl) async {
    try {
      // Extract path from download URL
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();

      // Remove from upload log
      await _removeUploadLog(downloadUrl);
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  /// Get upload progress stream
  Stream<TaskSnapshot> getUploadProgress(UploadTask uploadTask) {
    return uploadTask.snapshotEvents;
  }

  /// Enhanced file validation with detailed error reporting
  void validateImageFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();

    if (!AppConfig.allowedImageTypes.contains(extension)) {
      throw StorageError(
        type: StorageErrorType.invalidFormat,
        message: 'Invalid file format: .$extension',
        userMessage: 'Please select a valid image file (JPG, PNG, or JPEG).',
        technicalDetails:
            'Allowed formats: ${AppConfig.allowedImageTypes.join(', ')}',
      );
    }
  }

  /// Validate image file (legacy method for backward compatibility)
  bool isValidImageFile(File file) {
    try {
      validateImageFile(file);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Enhanced file size validation
  Future<void> validateFileSize(File file, String imageType) async {
    final fileSize = await file.length();
    final maxSize = AppConfig.maxImageSizeBytes;

    if (fileSize > maxSize) {
      final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      final maxSizeMB = (maxSize / (1024 * 1024)).round();

      throw StorageError(
        type: StorageErrorType.fileTooLarge,
        message: 'File size exceeds limit',
        userMessage:
            'Image size ($fileSizeMB MB) exceeds the ${maxSizeMB}MB limit. Please choose a smaller image.',
        technicalDetails: 'File: ${fileSize} bytes, Max: ${maxSize} bytes',
      );
    }
  }

  /// Get file size in MB
  Future<double> getFileSizeMB(File file) async {
    final bytes = await file.length();
    return bytes / (1024 * 1024);
  }

  /// Get compression info for an image type
  Map<String, dynamic> getCompressionInfo(String imageType) {
    switch (imageType) {
      case 'fellowship':
        return {
          'quality': _fellowshipImageQuality,
          'description': 'High quality for fellowship photos',
          'maxWidth': 800,
          'maxHeight': 600,
        };
      case 'receipt':
        return {
          'quality': _receiptImageQuality,
          'description': 'Very high quality for receipt readability',
          'maxWidth': 800,
          'maxHeight': 600,
        };
      case 'bus':
        return {
          'quality': _busImageQuality,
          'description': 'Good quality for bus photos',
          'maxWidth': 800,
          'maxHeight': 600,
        };
      case 'profile':
        return {
          'quality': _profileImageQuality,
          'description': 'High quality for profile pictures',
          'maxWidth': 800,
          'maxHeight': 600,
        };
      default:
        return {
          'quality': 85,
          'description': 'Default quality',
          'maxWidth': 800,
          'maxHeight': 600,
        };
    }
  }

  /// Get active uploads count
  int get activeUploadsCount => _activeUploads.length;

  /// Cancel all active uploads
  void cancelAllUploads() {
    final uploadIds = _activeUploads.keys.toList();
    for (final uploadId in uploadIds) {
      _cancelUpload(uploadId);
    }
  }

  /// Log upload to Firestore for tracking
  Future<void> _logUpload({
    required String path,
    required String downloadUrl,
    required String uploadedBy,
    required String fileType,
    required String relatedId,
    int? originalSize,
    int? compressedSize,
    int? retryCount,
  }) async {
    final logData = {
      'path': path,
      'downloadUrl': downloadUrl,
      'uploadedBy': uploadedBy,
      'fileType': fileType,
      'relatedId': relatedId,
      'uploadedAt': FieldValue.serverTimestamp(),
    };

    // Add compression info if available
    if (originalSize != null && compressedSize != null) {
      logData.addAll({
        'originalSize': originalSize,
        'compressedSize': compressedSize,
        'compressionRatio':
            ((originalSize - compressedSize) / originalSize * 100).round(),
      });
    }

    // Add retry info if available
    if (retryCount != null && retryCount > 0) {
      logData['retryCount'] = retryCount;
    }

    await _firestore.collection('uploads').add(logData);
  }

  /// Remove upload log
  Future<void> _removeUploadLog(String downloadUrl) async {
    final querySnapshot =
        await _firestore
            .collection('uploads')
            .where('downloadUrl', isEqualTo: downloadUrl)
            .get();

    for (final doc in querySnapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Get user's uploaded files
  Stream<List<Map<String, dynamic>>> getUserUploads(String userId) {
    return _firestore
        .collection('uploads')
        .where('uploadedBy', isEqualTo: userId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              }).toList(),
        );
  }

  /// Enhanced debug method to check user permissions before upload
  Future<Map<String, dynamic>> debugUserPermissions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'error': 'No authenticated user'};
      }

      // Get user data from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return {'error': 'User document not found in Firestore'};
      }

      final userData = userDoc.data()!;
      return {
        'uid': user.uid,
        'email': user.email,
        'role': userData['role'],
        'fellowshipId': userData['fellowshipId'],
        'constituencyId': userData['constituencyId'],
        'status': userData['status'],
        'hasRequiredData':
            userData['role'] == 'leader' && userData['fellowshipId'] != null,
        'rawUserData': userData,
      };
    } catch (e) {
      return {'error': 'Failed to get user data: $e'};
    }
  }

  /// Validate user permissions before attempting upload
  Future<bool> validateUploadPermissions(
    String imageType,
    String relatedId,
  ) async {
    final debugInfo = await debugUserPermissions();

    if (debugInfo.containsKey('error')) {
      print('🔒 Permission Check Failed: ${debugInfo['error']}');
      return false;
    }

    final userRole = debugInfo['role'] as String?;
    final fellowshipId = debugInfo['fellowshipId'] as String?;
    final userStatus = debugInfo['status'] as String?;

    print('🔍 Permission Debug Info:');
    print('   User Role: $userRole');
    print('   Fellowship ID: $fellowshipId');
    print('   User Status: $userStatus');
    print('   Image Type: $imageType');
    print('   Related ID: $relatedId');

    // Check if user is active
    if (userStatus != 'active') {
      print('❌ User is not active: $userStatus');
      return false;
    }

    // Check role requirements
    if (userRole != 'leader') {
      print('❌ User is not a leader: $userRole');
      return false;
    }

    // For fellowship images, check fellowship ID match
    if (imageType == 'fellowship' && fellowshipId != relatedId) {
      print(
        '❌ Fellowship ID mismatch: User($fellowshipId) vs Required($relatedId)',
      );
      return false;
    }

    print('✅ Permission check passed');
    return true;
  }
}

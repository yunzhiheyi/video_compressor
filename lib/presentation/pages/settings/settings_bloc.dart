/// Settings feature BLoC implementation.
///
/// This file contains the event definitions and BLoC for managing
/// application settings including quality presets, resolution defaults,
/// and cache management.
library;

import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/storage_service.dart';
import 'settings_state.dart';

/// Base class for all settings-related events.
abstract class SettingsEvent {}

/// Event to load all settings from persistent storage.
class LoadSettings extends SettingsEvent {}

/// Event to update the default compression quality.
///
/// [quality] - The new quality preset ('Low', 'Medium', 'High').
class SetDefaultQuality extends SettingsEvent {
  final String quality;
  SetDefaultQuality(this.quality);
}

/// Event to update the default output resolution.
///
/// [resolution] - The new resolution ('480P', '720P', '1080P', 'Original').
class SetDefaultResolution extends SettingsEvent {
  final String resolution;
  SetDefaultResolution(this.resolution);
}

/// Event to clear the application cache.
class ClearCache extends SettingsEvent {}

/// BLoC responsible for managing application settings state.
///
/// Handles the following operations:
/// - Loading settings from persistent storage
/// - Updating default quality and resolution preferences
/// - Clearing application cache
/// - Calculating cache size
///
/// Uses [StorageService] for persistent settings storage.
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  /// Service for persistent storage operations.
  final StorageService _storageService;

  /// Creates a new [SettingsBloc] with the required dependencies.
  ///
  /// [storageService] - Service for reading/writing settings data.
  SettingsBloc({required StorageService storageService})
      : _storageService = storageService,
        super(const SettingsState()) {
    on<LoadSettings>(_onLoadSettings);
    on<SetDefaultQuality>(_onSetDefaultQuality);
    on<SetDefaultResolution>(_onSetDefaultResolution);
    on<ClearCache>(_onClearCache);
  }

  /// Handles the [LoadSettings] event.
  ///
  /// Loads all settings from storage including:
  /// - Output directory path
  /// - Current cache size
  /// - Default quality preference
  /// - Default resolution preference
  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    final outputDir = await _storageService.getOutputDirectory();
    final cacheSize = await _getCacheSize();
    final quality = _storageService.getDefaultQuality();
    final resolution = _storageService.getDefaultResolution();
    emit(state.copyWith(
      outputDirectory: outputDir,
      cacheSize: cacheSize,
      defaultQuality: quality,
      defaultResolution: resolution,
    ));
  }

  /// Handles the [SetDefaultQuality] event.
  ///
  /// Saves the new quality preference to storage and updates the state.
  Future<void> _onSetDefaultQuality(
    SetDefaultQuality event,
    Emitter<SettingsState> emit,
  ) async {
    await _storageService.setDefaultQuality(event.quality);
    emit(state.copyWith(defaultQuality: event.quality));
  }

  /// Handles the [SetDefaultResolution] event.
  ///
  /// Saves the new resolution preference to storage and updates the state.
  Future<void> _onSetDefaultResolution(
    SetDefaultResolution event,
    Emitter<SettingsState> emit,
  ) async {
    await _storageService.setDefaultResolution(event.resolution);
    emit(state.copyWith(defaultResolution: event.resolution));
  }

  /// Handles the [ClearCache] event.
  ///
  /// Clears the cache directory and resets the cache size in state.
  Future<void> _onClearCache(
    ClearCache event,
    Emitter<SettingsState> emit,
  ) async {
    await _storageService.clearCache();
    emit(state.copyWith(cacheSize: 0));
  }

  /// Calculates the total size of the cache directory.
  ///
  /// Recursively iterates through all files in the temp directory
  /// and sums their sizes. Returns 0 if the directory doesn't exist
  /// or if any error occurs.
  ///
  /// Returns the cache size in bytes.
  Future<int> _getCacheSize() async {
    int size = 0;
    try {
      final tempDir = await _storageService.getTempDirectory();
      final dir = Directory(tempDir);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            size += await entity.length();
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return size;
  }
}

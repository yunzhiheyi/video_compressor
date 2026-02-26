/// Settings feature state management.
///
/// This file defines the state class for the application settings feature.
/// Contains user preferences for compression quality, resolution, and storage.
library;

import 'package:equatable/equatable.dart';

/// State class for application settings.
///
/// Holds all user-configurable settings that affect default compression
/// behavior and storage management. Extends [Equatable] for efficient
/// state comparison in BLoC.
class SettingsState extends Equatable {
  /// Default compression quality preset.
  ///
  /// Possible values: 'Low', 'Medium', 'High'.
  final String defaultQuality;

  /// Default output resolution for compressed videos.
  ///
  /// Possible values: '480P', '720P', '1080P', 'Original'.
  final String defaultResolution;

  /// Directory path where compressed videos are saved.
  ///
  /// Empty string indicates the default output directory is being used.
  final String outputDirectory;

  /// Current cache size in bytes.
  ///
  /// Used to display cache usage and enable clearing when needed.
  final int cacheSize;

  /// Creates a new [SettingsState] with the specified settings.
  ///
  /// All parameters have sensible defaults for first-time app launch.
  const SettingsState({
    this.defaultQuality = 'Medium',
    this.defaultResolution = '1080P',
    this.outputDirectory = '',
    this.cacheSize = 0,
  });

  /// Creates a copy of this state with optionally updated fields.
  ///
  /// Any field not provided will retain its current value.
  SettingsState copyWith({
    String? defaultQuality,
    String? defaultResolution,
    String? outputDirectory,
    int? cacheSize,
  }) {
    return SettingsState(
      defaultQuality: defaultQuality ?? this.defaultQuality,
      defaultResolution: defaultResolution ?? this.defaultResolution,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      cacheSize: cacheSize ?? this.cacheSize,
    );
  }

  @override
  List<Object?> get props => [
        defaultQuality,
        defaultResolution,
        outputDirectory,
        cacheSize,
      ];
}

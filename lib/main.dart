/// 应用程序入口文件
///
/// 负责初始化应用程序并配置全局状态管理：
/// - 初始化存储服务
/// - 配置 BLoC 状态管理（首页、压缩、历史、设置）
/// - 配置 Repository（FFmpeg服务、存储服务）
/// - 设置应用程序主题
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'presentation/pages/home/home_page.dart';
import 'presentation/pages/home/home_bloc.dart';
import 'presentation/pages/local_compress/local_compress_bloc.dart';
import 'presentation/pages/local_compress/local_compress_event.dart';
import 'presentation/pages/history/history_bloc.dart';
import 'presentation/pages/settings/settings_bloc.dart';
import 'services/ffmpeg_service.dart';
import 'services/storage_service.dart';

/// 应用程序入口函数
///
/// 1. 确保 Flutter 绑定初始化
/// 2. 初始化存储服务
/// 3. 启动应用程序
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = StorageService();
  await storageService.init();
  runApp(VideoCompressorApp(storageService: storageService));
}

/// 视频压缩应用程序主 Widget
///
/// 配置应用程序的依赖注入和状态管理：
/// - RepositoryProvider: FFmpegService, StorageService
/// - BlocProvider: HomeBloc, LocalCompressBloc, HistoryBloc, SettingsBloc
class VideoCompressorApp extends StatelessWidget {
  final StorageService storageService;

  const VideoCompressorApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => FFmpegService()),
        RepositoryProvider.value(value: storageService),
      ],
      child: Builder(
        builder: (context) {
          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => HomeBloc()),
              BlocProvider(
                create: (_) => LocalCompressBloc(
                  ffmpegService: context.read<FFmpegService>(),
                  storageService: context.read<StorageService>(),
                )..add(const LoadDefaultConfig()),
              ),
              BlocProvider(
                create: (_) => HistoryBloc(
                  storageService: context.read<StorageService>(),
                )..add(LoadHistory()),
              ),
              BlocProvider(
                create: (_) => SettingsBloc(
                  storageService: context.read<StorageService>(),
                )..add(LoadSettings()),
              ),
            ],
            child: MaterialApp(
              title: 'Video Compressor',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.dark,
              home: const HomePage(),
            ),
          );
        },
      ),
    );
  }
}

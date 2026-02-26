# 视频压缩 App 技术架构文档

## 一、技术栈

| 层级 | 技术选型 |
|------|----------|
| 框架 | Flutter 3.x |
| 状态管理 | flutter_bloc 8.x |
| 网络请求 | Dio 5.x |
| 本地存储 | SharedPreferences |
| 视频处理 | FFmpeg (自编译) |
| 文件选择 | file_picker 6.x |

---

## 二、项目目录结构

```
lib/
├── main.dart                    # 应用入口
├── app.dart                     # MaterialApp 配置
│
├── core/                        # 核心层
│   ├── constants/               # 常量定义
│   │   ├── app_colors.dart      # 颜色常量
│   │   ├── app_strings.dart     # 字符串常量
│   │   └── app_config.dart      # 配置常量
│   ├── theme/                   # 主题
│   │   ├── app_theme.dart       # 主题定义
│   │   └── text_styles.dart     # 文字样式
│   ├── utils/                   # 工具类
│   │   ├── file_utils.dart      # 文件工具
│   │   ├── permission_utils.dart # 权限工具
│   │   └── video_utils.dart     # 视频工具
│   └── errors/                  # 错误处理
│       ├── failures.dart        # 失败类型
│       └── exceptions.dart      # 异常定义
│
├── data/                        # 数据层
│   ├── models/                  # 数据模型
│   │   ├── video_info.dart      # 视频信息
│   │   ├── compress_task.dart   # 压缩任务
│   │   ├── compress_config.dart # 压缩配置
│   │   └── compress_history.dart # 压缩历史
│   ├── repositories/            # 仓库
│   │   ├── video_repository.dart
│   │   └── compress_repository.dart
│   └── datasources/             # 数据源
│       ├── local/               # 本地数据源
│       │   ├── video_local_ds.dart
│       │   └── history_local_ds.dart
│       └── remote/              # 远程数据源
│           └── video_remote_ds.dart
│
├── domain/                      # 领域层
│   ├── entities/                # 实体
│   │   ├── video.dart
│   │   └── compress_result.dart
│   ├── repositories/            # 仓库接口
│   │   └── i_video_repository.dart
│   └── usecases/                # 用例
│       ├── get_video_info.dart
│       ├── compress_video.dart
│       ├── batch_compress.dart
│       └── download_video.dart
│
├── presentation/                # 表现层
│   ├── pages/                   # 页面
│   │   ├── home/
│   │   │   ├── home_page.dart
│   │   │   └── home_bloc.dart
│   │   ├── local_compress/
│   │   │   ├── local_compress_page.dart
│   │   │   ├── compress_config_page.dart
│   │   │   ├── compress_progress_page.dart
│   │   │   └── local_compress_bloc.dart
│   │   ├── remote_compress/
│   │   │   ├── remote_compress_page.dart
│   │   │   └── remote_compress_bloc.dart
│   │   ├── history/
│   │   │   ├── history_page.dart
│   │   │   └── history_bloc.dart
│   │   └── settings/
│   │       ├── settings_page.dart
│   │       └── settings_bloc.dart
│   ├── widgets/                 # 通用组件
│   │   ├── video_thumbnail.dart
│   │   ├── compress_progress_indicator.dart
│   │   ├── quality_selector.dart
│   │   ├── resolution_selector.dart
│   │   └── task_list_tile.dart
│   └── bloc/                    # 全局 Bloc
│       └── app_bloc.dart
│
├── services/                    # 服务层
│   ├── ffmpeg_service.dart      # FFmpeg 服务
│   ├── download_service.dart    # 下载服务
│   └── storage_service.dart     # 存储服务
│
└── platform/                    # 平台相关
    ├── android/
    │   └── ffmpeg_android.dart
    └── ios/
        └── ffmpeg_ios.dart

android/                         # Android 原生
├── app/
│   └── src/main/
│       └── jniLibs/             # FFmpeg so 库
└── build.gradle

ios/                             # iOS 原生
├── Runner/
│   └── Frameworks/              # FFmpeg framework
└── Podfile
```

---

## 三、架构分层

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │  Pages   │  │ Widgets  │  │   Bloc   │  │  States  │ │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘ │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                     Domain Layer                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐   │
│  │ Entities │  │ UseCases │  │ Repository Interface │   │
│  └──────────┘  └──────────┘  └──────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                      Data Layer                          │
│  ┌──────────────┐  ┌────────────────────────────────┐   │
│  │ Repositories │  │       Data Sources             │   │
│  │              │  │  ┌─────────┐  ┌─────────────┐  │   │
│  │              │  │  │  Local  │  │   Remote    │  │   │
│  └──────────────┘  │  └─────────┘  └─────────────┘  │   │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                    Platform Layer                        │
│  ┌──────────────────┐  ┌──────────────────────────┐     │
│  │ FFmpeg (Android) │  │    FFmpeg (iOS)          │     │
│  └──────────────────┘  └──────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

---

## 四、状态管理设计

### 4.1 Bloc 状态流转

```
Event ──► Bloc ──► State

┌──────────────────────────────────────────────────────┐
│                  LocalCompressBloc                    │
├──────────────────────────────────────────────────────┤
│  Events:                                             │
│  - SelectVideos(List<String> paths)                  │
│  - UpdateConfig(CompressConfig config)               │
│  - StartCompress()                                   │
│  - CancelCompress()                                  │
│  - RemoveTask(String taskId)                         │
│                                                      │
│  States:                                             │
│  - LocalCompressInitial()                            │
│  - LocalCompressVideosSelected(videos)               │
│  - LocalCompressConfiguring(config)                  │
│  - LocalCompressInProgress(tasks, progress)          │
│  - LocalCompressCompleted(results)                   │
│  - LocalCompressError(message)                       │
└──────────────────────────────────────────────────────┘
```

### 4.2 核心状态类

```dart
// 压缩任务状态
abstract class CompressTaskState extends Equatable {
  final String taskId;
  final VideoInfo video;
  
  const CompressTaskState({required this.taskId, required this.video});
}

class CompressTaskPending extends CompressTaskState {
  @override
  List<Object?> get props => [taskId, video];
}

class CompressTaskRunning extends CompressTaskState {
  final double progress;
  final Duration elapsed;
  final Duration? estimatedRemaining;
  
  @override
  List<Object?> get props => [taskId, video, progress, elapsed, estimatedRemaining];
}

class CompressTaskCompleted extends CompressTaskState {
  final String outputPath;
  final int originalSize;
  final int compressedSize;
  
  @override
  List<Object?> get props => [taskId, video, outputPath, originalSize, compressedSize];
}

class CompressTaskFailed extends CompressTaskState {
  final String errorMessage;
  
  @override
  List<Object?> get props => [taskId, video, errorMessage];
}
```

---

## 五、FFmpeg 集成方案

### 5.1 自编译 FFmpeg

**编译目标**：
- 最小化体积（仅包含必要编解码器）
- 支持 H.264/H.265 编码
- 支持 AAC/MP3 音频

**Android 编译脚本**：
```bash
#!/bin/bash
# build_ffmpeg_android.sh

NDK_PATH=/path/to/android-ndk
FFMPEG_VERSION=6.1

./configure \
  --prefix=./android-build \
  --target-os=android \
  --arch=arm64 \
  --cpu=armv8-a \
  --enable-cross-compile \
  --enable-pic \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libfdk-aac \
  --enable-gpl \
  --enable-nonfree \
  --disable-debug \
  --disable-doc \
  --disable-ffmpeg \
  --disable-ffplay \
  --disable-ffprobe \
  --disable-network \
  --disable-everything \
  --enable-protocol=file \
  --enable-demuxer=mov,mp4,mkv,avi \
  --enable-decoder=h264,hevc,aac,mp3 \
  --enable-encoder=libx264,libx265,aac \
  --enable-filter=scale \
  --cc=$NDK_PATH/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android21-clang \
  --nm=$NDK_PATH/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android-nm \
  --ar=$NDK_PATH/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android-ar

make -j8
make install
```

**iOS 编译脚本**：
```bash
#!/bin/bash
# build_ffmpeg_ios.sh

ARCHS="arm64 x86_64"
FFMPEG_VERSION=6.1

for ARCH in $ARCHS; do
  ./configure \
    --prefix=./ios-build/$ARCH \
    --target-os=darwin \
    --arch=$ARCH \
    --enable-cross-compile \
    --enable-pic \
    --enable-libx264 \
    --enable-libx265 \
    --enable-gpl \
    --disable-debug \
    --disable-doc \
    --disable-ffmpeg \
    --disable-ffplay \
    --disable-ffprobe \
    --cc=/usr/bin/clang \
    --extra-cflags="-arch $ARCH -miphoneos-version-min=12.0" \
    --extra-ldflags="-arch $ARCH -miphoneos-version-min=12.0"
    
  make -j8
  make install
  make clean
done

# 合并架构
lipo -create ./ios-build/arm64/lib/libffmpeg.a ./ios-build/x86_64/lib/libffmpeg.a -output ./ios-build/libffmpeg.a
```

### 5.2 Flutter FFmpeg Service

```dart
class FFmpegService {
  static const MethodChannel _channel = MethodChannel('ffmpeg_service');
  
  Future<VideoInfo> getVideoInfo(String path) async {
    final result = await _channel.invokeMethod('getVideoInfo', {'path': path});
    return VideoInfo.fromJson(result);
  }
  
  Stream<double> compressVideo({
    required String inputPath,
    required String outputPath,
    required CompressConfig config,
  }) {
    return _channel
        .receiveBroadcastStream('compressVideo', {
          'inputPath': inputPath,
          'outputPath': outputPath,
          'bitrate': config.bitrate,
          'resolution': config.resolution,
          'quality': config.quality,
        })
        .map((event) => event as double);
  }
  
  Future<void> cancelCompress(String taskId) async {
    await _channel.invokeMethod('cancelCompress', {'taskId': taskId});
  }
}
```

---

## 六、关键流程时序图

### 6.1 本地压缩流程

```
┌──────┐    ┌──────┐    ┌──────┐    ┌──────┐    ┌────────┐
│ Page │    │ Bloc │    │ Usecase│   │ Repo │    │ FFmpeg │
└──┬───┘    └──┬───┘    └──┬───┘    └──┬───┘    └───┬────┘
   │           │           │           │            │
   │ 选择视频   │           │           │            │
   ├──────────►│           │           │            │
   │           │ 获取视频信息│           │            │
   │           ├──────────►│           │            │
   │           │           │ 读取视频   │            │
   │           │           ├──────────►│            │
   │           │           │           │ 执行命令    │
   │           │           │           ├───────────►│
   │           │           │           │◄───────────┤
   │           │           │◄──────────┤            │
   │           │◄──────────┤           │            │
   │◄──────────┤           │           │            │
   │           │           │           │            │
   │ 开始压缩   │           │           │            │
   ├──────────►│           │           │            │
   │           │ 执行压缩   │           │            │
   │           ├──────────►│           │            │
   │           │           │ 压缩视频   │            │
   │           │           ├──────────►│            │
   │           │           │           │ 执行压缩    │
   │           │           │           ├───────────►│
   │           │           │           │  进度回调   │
   │           │           │           │◄───────────┤
   │           │           │◄──────────┤            │
   │           │◄──────────┤ 进度      │            │
   │◄──────────┤ 更新UI    │           │            │
   │           │           │           │            │
```

---

## 七、性能优化策略

### 7.1 内存优化

- 使用 Stream 处理大文件
- 压缩完成后及时释放资源
- 限制并发压缩任务数（最多 2 个）

### 7.2 电量优化

- 压缩时降低屏幕刷新频率
- 提供「省电模式」选项（降低优先级）
- 完成后自动释放唤醒锁

### 7.3 体积优化

- FFmpeg 精简编译
- 图片资源使用 WebP
- 启用代码混淆和压缩

---

## 八、安全考虑

1. **文件权限**：仅访问用户选择的文件
2. **临时文件**：压缩完成后清理临时文件
3. **网络安全**：HTTPS 下载远程视频
4. **数据存储**：不收集用户视频内容

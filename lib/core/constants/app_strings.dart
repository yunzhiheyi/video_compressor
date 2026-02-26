/// 应用程序字符串常量
///
/// 包含应用中使用的所有静态字符串常量。
/// 集中管理字符串便于本地化，并确保一致性。
/// 所有字符串定义为 static const 以实现编译时优化。
class AppStrings {
  /// 私有构造函数，防止实例化
  AppStrings._();

  /// 应用名称，显示在标题栏
  static const String appName = 'Video Compressor';

  /// 导航标签
  static const String home = 'Home';
  static const String history = 'History';
  static const String settings = 'Settings';

  /// 视频选择相关字符串
  static const String selectVideo = 'Select Video';
  static const String selectVideos = 'Select Videos';
  static const String noVideoSelected = 'No video selected';
  static const String videosSelected = 'videos selected';

  /// 压缩质量预设标签
  static const String quality = 'Quality';
  static const String low = 'Low';
  static const String medium = 'Medium';
  static const String high = 'High';
  static const String original = 'Original';
  static const String custom = 'Custom';

  /// 视频参数标签
  static const String resolution = 'Resolution';
  static const String bitrate = 'Bitrate';
  static const String frameRate = 'Frame Rate';

  /// 操作按钮标签
  static const String startCompress = 'Start Compress';
  static const String cancel = 'Cancel';
  static const String pause = 'Pause';
  static const String resume = 'Resume';

  /// 压缩状态消息
  static const String compressing = 'Compressing...';
  static const String compressComplete = 'Compress Complete';
  static const String compressFailed = 'Compress Failed';

  /// 大小对比标签
  static const String originalSize = 'Original';
  static const String compressedSize = 'Compressed';
  static const String savedSpace = 'Saved';

  /// 压缩后操作标签
  static const String preview = 'Preview';
  static const String share = 'Share';
  static const String deleteOriginal = 'Delete Original';
  static const String saveToGallery = 'Save to Gallery';

  /// 下载功能字符串
  static const String enterUrl = 'Enter Video URL';
  static const String download = 'Download';
  static const String downloading = 'Downloading...';
  static const String downloadComplete = 'Download Complete';
  static const String downloadFailed = 'Download Failed';

  /// 历史记录页面字符串
  static const String noHistory = 'No compression history';
  static const String clearHistory = 'Clear History';
  static const String delete = 'Delete';

  /// 设置页面标签
  static const String defaultQuality = 'Default Quality';
  static const String defaultResolution = 'Default Resolution';
  static const String outputDirectory = 'Output Directory';
  static const String clearCache = 'Clear Cache';
  static const String about = 'About';

  /// 错误消息字符串
  static const String errorNoVideo = 'Please select a video first';
  static const String errorNoPermission = 'Storage permission required';
  static const String errorInvalidUrl = 'Invalid video URL';
  static const String errorNetwork = 'Network error, please check connection';
  static const String errorStorageFull = 'Insufficient storage space';

  /// 确认对话框字符串
  static const String confirmDelete = 'Are you sure you want to delete?';
  static const String confirmCancel = 'Are you sure you want to cancel?';
}

/// 存储服务
///
/// 提供应用程序的数据持久化功能：
/// - 压缩历史记录管理
/// - 默认配置存储（画质、分辨率）
/// - 输出目录管理
/// - 缓存管理
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 存储服务类
///
/// 使用 SharedPreferences 存储用户配置和历史记录
class StorageService {
  late SharedPreferences _prefs;

  /// 历史记录存储键
  static const _historyKey = 'compression_history';

  /// 任务列表存储键
  static const _tasksKey = 'compression_tasks';

  /// 默认画质存储键
  static const _qualityKey = 'default_quality';

  /// 默认分辨率存储键
  static const _resolutionKey = 'default_resolution';

  /// 初始化存储服务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 获取输出目录路径
  ///
  /// 默认为应用文档目录下的 compressed_videos 文件夹
  Future<String> getOutputDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/compressed_videos';
  }

  /// 设置自定义输出目录
  Future<void> setOutputDirectory(String path) async {
    await _prefs.setString('output_directory', path);
  }

  /// 获取临时目录路径
  Future<String> getTempDirectory() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  /// 清除缓存
  ///
  /// 删除临时目录下的所有文件
  Future<void> clearCache() async {
    final tempDir = await getTemporaryDirectory();
    await for (final entity in tempDir.list(recursive: true)) {
      if (entity is File) {
        await entity.delete();
      }
    }
  }

  /// 获取缓存大小（字节）
  Future<int> getCacheSize() async {
    int size = 0;
    final tempDir = await getTemporaryDirectory();
    await for (final entity in tempDir.list(recursive: true)) {
      if (entity is File) {
        size += await entity.length();
      }
    }
    return size;
  }

  /// 保存历史记录项
  ///
  /// 新记录会插入到列表开头
  Future<void> saveHistoryItem(Map<String, dynamic> item) async {
    final history = await getHistoryList();
    history.insert(0, item);
    await _prefs.setString(_historyKey, jsonEncode(history));
  }

  /// 获取历史记录列表
  Future<List<Map<String, dynamic>>> getHistoryList() async {
    final String? data = _prefs.getString(_historyKey);
    if (data == null) return [];
    try {
      final List<dynamic> list = jsonDecode(data);
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// 清除所有历史记录
  Future<void> clearHistory() async {
    await _prefs.remove(_historyKey);
  }

  /// 删除指定的历史记录项
  ///
  /// [id] - 记录项的ID
  Future<void> deleteHistoryItem(String id) async {
    final history = await getHistoryList();
    history.removeWhere((item) => item['id'] == id);
    await _prefs.setString(_historyKey, jsonEncode(history));
  }

  /// 设置默认画质
  Future<void> setDefaultQuality(String quality) async {
    await _prefs.setString(_qualityKey, quality);
  }

  /// 获取默认画质
  ///
  /// 默认返回 'Medium'
  String getDefaultQuality() {
    return _prefs.getString(_qualityKey) ?? 'Medium';
  }

  /// 设置默认分辨率
  Future<void> setDefaultResolution(String resolution) async {
    await _prefs.setString(_resolutionKey, resolution);
  }

  /// 获取默认分辨率
  ///
  /// 默认返回 '720P'
  String getDefaultResolution() {
    return _prefs.getString(_resolutionKey) ?? '720P';
  }

  /// 保存任务列表
  Future<void> saveTaskList(List<Map<String, dynamic>> tasks) async {
    await _prefs.setString(_tasksKey, jsonEncode(tasks));
  }

  /// 获取任务列表
  Future<List<Map<String, dynamic>>> getTaskList() async {
    final String? data = _prefs.getString(_tasksKey);
    if (data == null) return [];
    try {
      final List<dynamic> list = jsonDecode(data);
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// 删除指定的任务
  ///
  /// [id] - 任务ID
  Future<void> deleteTaskItem(String id) async {
    final tasks = await getTaskList();
    tasks.removeWhere((item) => item['id'] == id);
    await _prefs.setString(_tasksKey, jsonEncode(tasks));
  }

  /// 清除所有任务
  Future<void> clearTasks() async {
    await _prefs.remove(_tasksKey);
  }
}

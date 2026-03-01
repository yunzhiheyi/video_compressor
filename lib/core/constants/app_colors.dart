/// 应用程序颜色常量定义
///
/// 定义应用程序中使用的所有颜色：
/// - 背景色和表面色
/// - 主题色
/// - 文字颜色
/// - 状态颜色（成功、错误、警告）
library;
import 'package:flutter/material.dart';

/// 应用颜色常量类
class AppColors {
  AppColors._();

  // 背景和表面颜色
  /// 主背景色（深黑色）
  static const Color background = Color(0xFF0D0D0D);

  /// 表面色（卡片、列表项背景）
  static const Color surface = Color(0xFF1A1A1A);

  /// 卡片背景色
  static const Color card = Color(0xFF262626);

  // 主题色
  /// 主色调（蓝色）
  static const Color primary = Color(0xFF2196F3);

  /// 主色调浅色
  static const Color primaryLight = Color(0xFF64B5F6);

  /// 主色调深色
  static const Color primaryDark = Color(0xFF1976D2);

  // 文字颜色
  /// 主要文字颜色（白色）
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// 次要文字颜色（灰色）
  static const Color textSecondary = Color(0xFFB3B3B3);

  /// 提示文字颜色（深灰色）
  static const Color textHint = Color(0xFF666666);

  // 状态颜色
  /// 成功色（绿色）
  static const Color success = Color(0xFF4CAF50);

  /// 错误色（红色）
  static const Color error = Color(0xFFF44336);

  /// 警告色（橙色）
  static const Color warning = Color(0xFFFF9800);

  // 边框和分割线颜色
  /// 分割线颜色
  static const Color divider = Color(0xFF333333);

  /// 边框颜色
  static const Color border = Color(0xFF404040);
}

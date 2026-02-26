/// 首页状态定义
///
/// 存储首页的当前状态数据
import 'package:equatable/equatable.dart';

/// 首页状态类
class HomeState extends Equatable {
  /// 当前选中的标签索引
  /// - 0: 压缩页面
  /// - 1: 历史页面
  /// - 2: 设置页面
  final int currentIndex;

  const HomeState({this.currentIndex = 0});

  /// 复制并修改部分属性
  HomeState copyWith({int? currentIndex}) {
    return HomeState(currentIndex: currentIndex ?? this.currentIndex);
  }

  @override
  List<Object?> get props => [currentIndex];
}

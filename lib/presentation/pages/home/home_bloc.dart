/// 首页BLoC - 管理首页标签切换状态
///
/// 功能：
/// - 管理当前选中的标签索引（压缩、历史、设置）
/// - 处理标签切换事件
import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_event.dart';
import 'home_state.dart';

/// 首页BLoC类
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(const HomeState()) {
    on<HomeTabChanged>(_onTabChanged);
  }

  /// 处理标签切换事件
  void _onTabChanged(HomeTabChanged event, Emitter<HomeState> emit) {
    emit(state.copyWith(currentIndex: event.index));
  }
}

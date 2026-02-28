import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_compressor/presentation/pages/settings/settings_bloc.dart';
import 'package:video_compressor/presentation/pages/settings/settings_state.dart';
import 'package:video_compressor/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  group('SettingsBloc', () {
    late MockStorageService mockStorageService;

    setUp(() {
      mockStorageService = MockStorageService();
    });

    test('初始状态应为 SettingsState 默认值', () {
      final bloc = SettingsBloc(storageService: mockStorageService);
      expect(bloc.state, const SettingsState());
    });

    group('LoadSettings', () {
      blocTest<SettingsBloc, SettingsState>(
        '应加载所有设置并更新状态',
        setUp: () {
          when(() => mockStorageService.getOutputDirectory())
              .thenAnswer((_) async => '/output');
          when(() => mockStorageService.getTempDirectory())
              .thenAnswer((_) async => '/tmp');
          when(() => mockStorageService.getDefaultQuality()).thenReturn('High');
          when(() => mockStorageService.getDefaultResolution())
              .thenReturn('720P');
        },
        build: () => SettingsBloc(storageService: mockStorageService),
        act: (bloc) => bloc.add(LoadSettings()),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<SettingsState>()
              .having((s) => s.outputDirectory, 'outputDirectory', '/output')
              .having((s) => s.defaultQuality, 'defaultQuality', 'High')
              .having((s) => s.defaultResolution, 'defaultResolution', '720P'),
        ],
      );
    });

    group('SetDefaultQuality', () {
      blocTest<SettingsBloc, SettingsState>(
        '应更新默认质量并保存到存储',
        setUp: () {
          when(() => mockStorageService.setDefaultQuality(any()))
              .thenAnswer((_) async {});
        },
        build: () => SettingsBloc(storageService: mockStorageService),
        act: (bloc) => bloc.add(SetDefaultQuality('Low')),
        expect: () => [
          const SettingsState(defaultQuality: 'Low'),
        ],
        verify: (_) {
          verify(() => mockStorageService.setDefaultQuality('Low')).called(1);
        },
      );

      blocTest<SettingsBloc, SettingsState>(
        '应能切换到高画质',
        setUp: () {
          when(() => mockStorageService.setDefaultQuality(any()))
              .thenAnswer((_) async {});
        },
        build: () => SettingsBloc(storageService: mockStorageService),
        act: (bloc) => bloc.add(SetDefaultQuality('High')),
        expect: () => [
          const SettingsState(defaultQuality: 'High'),
        ],
        verify: (_) {
          verify(() => mockStorageService.setDefaultQuality('High')).called(1);
        },
      );
    });

    group('SetDefaultResolution', () {
      blocTest<SettingsBloc, SettingsState>(
        '应更新默认分辨率并保存到存储',
        setUp: () {
          when(() => mockStorageService.setDefaultResolution(any()))
              .thenAnswer((_) async {});
        },
        build: () => SettingsBloc(storageService: mockStorageService),
        act: (bloc) => bloc.add(SetDefaultResolution('1080P')),
        expect: () => [
          const SettingsState(defaultResolution: '1080P'),
        ],
        verify: (_) {
          verify(() => mockStorageService.setDefaultResolution('1080P'))
              .called(1);
        },
      );
    });

    group('ClearCache', () {
      blocTest<SettingsBloc, SettingsState>(
        '应清除缓存并重置缓存大小',
        setUp: () {
          when(() => mockStorageService.clearCache()).thenAnswer((_) async {});
        },
        build: () => SettingsBloc(storageService: mockStorageService),
        act: (bloc) => bloc.add(ClearCache()),
        expect: () => [
          const SettingsState(cacheSize: 0),
        ],
        verify: (_) {
          verify(() => mockStorageService.clearCache()).called(1);
        },
      );
    });
  });

  group('SettingsState', () {
    test('默认值应正确', () {
      const state = SettingsState();
      expect(state.defaultQuality, 'Medium');
      expect(state.defaultResolution, '1080P');
      expect(state.outputDirectory, '');
      expect(state.cacheSize, 0);
    });

    test('copyWith 应正确更新字段', () {
      const state = SettingsState();
      final newState = state.copyWith(
        defaultQuality: 'High',
        cacheSize: 1024,
      );

      expect(newState.defaultQuality, 'High');
      expect(newState.defaultResolution, '1080P');
      expect(newState.cacheSize, 1024);
    });

    test('相同状态应相等', () {
      const state1 = SettingsState(defaultQuality: 'Low');
      const state2 = SettingsState(defaultQuality: 'Low');
      expect(state1, equals(state2));
    });

    test('不同状态应不相等', () {
      const state1 = SettingsState(defaultQuality: 'Low');
      const state2 = SettingsState(defaultQuality: 'High');
      expect(state1, isNot(equals(state2)));
    });
  });
}

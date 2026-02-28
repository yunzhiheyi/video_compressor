import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_compressor/presentation/pages/history/history_bloc.dart';
import 'package:video_compressor/presentation/pages/history/history_state.dart';
import 'package:video_compressor/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  group('HistoryBloc', () {
    late MockStorageService mockStorageService;

    setUp(() {
      mockStorageService = MockStorageService();
    });

    test('初始状态应为空列表', () {
      final bloc = HistoryBloc(storageService: mockStorageService);
      expect(bloc.state, const HistoryState(items: []));
    });

    group('LoadHistory', () {
      blocTest<HistoryBloc, HistoryState>(
        '应加载历史记录列表',
        setUp: () {
          when(() => mockStorageService.getHistoryList())
              .thenAnswer((_) async => [
                    {
                      'id': '1',
                      'name': 'video1.mp4',
                      'originalSize': 10000000,
                      'compressedSize': 5000000,
                      'compressedAt': '2024-01-01T10:00:00.000',
                      'outputPath': '/output/video1.mp4',
                      'originalResolution': '1920x1080',
                      'compressedResolution': '1280x720',
                      'duration': 120.0,
                      'originalBitrate': 5000000,
                      'compressedBitrate': 2500000,
                      'frameRate': 30.0,
                    },
                  ]);
        },
        build: () => HistoryBloc(storageService: mockStorageService),
        act: (bloc) => bloc.add(LoadHistory()),
        expect: () => [
          HistoryState(
            items: [
              HistoryItem(
                id: '1',
                name: 'video1.mp4',
                originalSize: 10000000,
                compressedSize: 5000000,
                compressedAt: DateTime.parse('2024-01-01T10:00:00.000'),
                outputPath: '/output/video1.mp4',
                originalResolution: '1920x1080',
                compressedResolution: '1280x720',
                duration: 120.0,
                originalBitrate: 5000000,
                compressedBitrate: 2500000,
                frameRate: 30.0,
              ),
            ],
          ),
        ],
      );

      blocTest<HistoryBloc, HistoryState>(
        '空历史记录应返回空列表',
        setUp: () {
          when(() => mockStorageService.getHistoryList())
              .thenAnswer((_) async => []);
        },
        build: () => HistoryBloc(storageService: mockStorageService),
        act: (bloc) => bloc.add(LoadHistory()),
        expect: () => [
          const HistoryState(items: []),
        ],
      );
    });

    group('ClearHistory', () {
      blocTest<HistoryBloc, HistoryState>(
        '应清空所有历史记录',
        setUp: () {
          when(() => mockStorageService.clearHistory())
              .thenAnswer((_) async {});
        },
        build: () => HistoryBloc(storageService: mockStorageService),
        act: (bloc) => bloc.add(ClearHistory()),
        expect: () => [
          const HistoryState(items: []),
        ],
        verify: (_) {
          verify(() => mockStorageService.clearHistory()).called(1);
        },
      );
    });

    group('DeleteHistoryItem', () {
      blocTest<HistoryBloc, HistoryState>(
        '应删除指定历史记录',
        setUp: () {
          when(() => mockStorageService.deleteHistoryItem(any()))
              .thenAnswer((_) async {});
        },
        build: () => HistoryBloc(storageService: mockStorageService),
        seed: () {
          // 使用固定的 DateTime 避免微秒差异
          final fixedTime = DateTime(2024, 1, 1, 12, 0, 0);
          return HistoryState(
            items: [
              HistoryItem(
                id: '1',
                name: 'video1.mp4',
                originalSize: 10000000,
                compressedSize: 5000000,
                compressedAt: fixedTime,
                outputPath: '/output/video1.mp4',
              ),
              HistoryItem(
                id: '2',
                name: 'video2.mp4',
                originalSize: 20000000,
                compressedSize: 8000000,
                compressedAt: fixedTime,
                outputPath: '/output/video2.mp4',
              ),
            ],
          );
        },
        act: (bloc) => bloc.add(DeleteHistoryItem('1')),
        expect: () {
          final fixedTime = DateTime(2024, 1, 1, 12, 0, 0);
          return [
            HistoryState(
              items: [
                HistoryItem(
                  id: '2',
                  name: 'video2.mp4',
                  originalSize: 20000000,
                  compressedSize: 8000000,
                  compressedAt: fixedTime,
                  outputPath: '/output/video2.mp4',
                ),
              ],
            ),
          ];
        },
        verify: (_) {
          verify(() => mockStorageService.deleteHistoryItem('1')).called(1);
        },
      );
    });

    group('AddHistoryItem', () {
      blocTest<HistoryBloc, HistoryState>(
        '应添加新历史记录到列表开头',
        setUp: () {
          when(() => mockStorageService.saveHistoryItem(any()))
              .thenAnswer((_) async {});
        },
        build: () => HistoryBloc(storageService: mockStorageService),
        act: (bloc) => bloc.add(AddHistoryItem(
          HistoryItem(
            id: '1',
            name: 'new_video.mp4',
            originalSize: 15000000,
            compressedSize: 6000000,
            compressedAt: DateTime.now(),
            outputPath: '/output/new_video.mp4',
          ),
        )),
        verify: (_) {
          verify(() => mockStorageService.saveHistoryItem(any())).called(1);
        },
      );
    });
  });

  group('HistoryState', () {
    test('默认应为空列表', () {
      const state = HistoryState();
      expect(state.items, isEmpty);
    });

    test('copyWith 应正确更新字段', () {
      const state = HistoryState();
      final newState = state.copyWith(items: [
        HistoryItem(
          id: '1',
          name: 'test.mp4',
          originalSize: 1000,
          compressedSize: 500,
          compressedAt: DateTime.now(),
          outputPath: '/out',
        ),
      ]);

      expect(newState.items.length, 1);
    });

    test('相同状态应相等', () {
      const state1 = HistoryState();
      const state2 = HistoryState();
      expect(state1, equals(state2));
    });
  });

  group('HistoryItem', () {
    test('compressionRatio 应正确计算压缩比', () {
      final item = HistoryItem(
        id: '1',
        name: 'test.mp4',
        originalSize: 10000000,
        compressedSize: 3000000,
        compressedAt: DateTime.now(),
        outputPath: '/out/test.mp4',
      );

      expect(item.compressionRatio, 70.0);
    });

    test('originalSize为0时应返回0压缩比', () {
      final item = HistoryItem(
        id: '1',
        name: 'test.mp4',
        originalSize: 0,
        compressedSize: 0,
        compressedAt: DateTime.now(),
        outputPath: '/out/test.mp4',
      );

      expect(item.compressionRatio, 0);
    });

    test('durationFormatted 应正确格式化', () {
      final item = HistoryItem(
        id: '1',
        name: 'test.mp4',
        originalSize: 1000,
        compressedSize: 500,
        compressedAt: DateTime.now(),
        outputPath: '/out/test.mp4',
        duration: 90, // 1分30秒
      );

      expect(item.durationFormatted, '01:30');
    });

    test('时长超过1小时应包含小时', () {
      final item = HistoryItem(
        id: '1',
        name: 'test.mp4',
        originalSize: 1000,
        compressedSize: 500,
        compressedAt: DateTime.now(),
        outputPath: '/out/test.mp4',
        duration: 3661, // 1小时1分1秒
      );

      expect(item.durationFormatted, '01:01:01');
    });

    test('bitrate格式化应正确', () {
      final item = HistoryItem(
        id: '1',
        name: 'test.mp4',
        originalSize: 1000,
        compressedSize: 500,
        compressedAt: DateTime.now(),
        outputPath: '/out/test.mp4',
        originalBitrate: 5000000,
        compressedBitrate: 2500000,
      );

      expect(item.originalBitrateFormatted, '5.0 Mbps');
      expect(item.compressedBitrateFormatted, '2.5 Mbps');
    });

    test('bitrate为0时应返回N/A', () {
      final item = HistoryItem(
        id: '1',
        name: 'test.mp4',
        originalSize: 1000,
        compressedSize: 500,
        compressedAt: DateTime.now(),
        outputPath: '/out/test.mp4',
        originalBitrate: 0,
        compressedBitrate: 0,
      );

      expect(item.originalBitrateFormatted, 'N/A');
      expect(item.compressedBitrateFormatted, 'N/A');
    });
  });
}

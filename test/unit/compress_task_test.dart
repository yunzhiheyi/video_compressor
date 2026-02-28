import 'package:flutter_test/flutter_test.dart';
import 'package:video_compressor/data/models/compress_config.dart';
import 'package:video_compressor/data/models/compress_task.dart';
import 'package:video_compressor/data/models/video_info.dart';

void main() {
  group('CompressTask', () {
    late VideoInfo testVideo;
    late CompressConfig testConfig;

    setUp(() {
      testVideo = const VideoInfo(
        path: '/test/video.mp4',
        name: 'video.mp4',
        size: 10240000,
        duration: Duration(seconds: 120),
        width: 1920,
        height: 1080,
      );
      testConfig = const CompressConfig(
        quality: CompressQuality.medium,
        targetHeight: 720,
      );
    });

    group('构造函数', () {
      test('应能正确创建压缩任务', () {
        final task = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
          status: CompressTaskStatus.pending,
          progress: 0.0,
        );

        expect(task.id, 'task-1');
        expect(task.video, testVideo);
        expect(task.config, testConfig);
        expect(task.status, CompressTaskStatus.pending);
        expect(task.progress, 0.0);
      });
    });

    group('状态判断属性', () {
      test('isComplete 应在完成时返回 true', () {
        final task = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
          status: CompressTaskStatus.completed,
        );
        expect(task.isComplete, true);
      });

      test('isFailed 应在失败时返回 true', () {
        final task = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
          status: CompressTaskStatus.failed,
        );
        expect(task.isFailed, true);
      });

      test('isRunning 应在进行中返回 true', () {
        final task = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
          status: CompressTaskStatus.running,
        );
        expect(task.isRunning, true);
      });

      test('isPending 应在等待中返回 true', () {
        final task = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
          status: CompressTaskStatus.pending,
        );
        expect(task.isPending, true);
      });

      test('isQueued 应在已排队时返回 true', () {
        final task = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
          status: CompressTaskStatus.queued,
        );
        expect(task.isQueued, true);
      });

      test('isSkipped 应在已跳过时返回 true', () {
        final task = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
          status: CompressTaskStatus.skipped,
        );
        expect(task.isSkipped, true);
      });
    });

    group('compressionRatio 压缩比计算', () {
      test('应正确计算压缩比', () {
        final task = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
          compressedSize: 5000000,
        );

        expect(task.compressionRatio, closeTo(51.2, 0.1));
      });

      test('无压缩后大小应返回0', () {
        final task = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
        );

        expect(task.compressionRatio, 0.0);
      });

      test('原大小为0应返回0', () {
        const zeroSizeVideo = VideoInfo(
          path: '/test.mp4',
          size: 0,
        );
        final task = CompressTask(
          id: 'task-1',
          video: zeroSizeVideo,
          config: testConfig,
          compressedSize: 1000,
        );

        expect(task.compressionRatio, 0.0);
      });
    });

    group('resolution 分辨率', () {
      test('originalResolution 应返回原始分辨率', () {
        final task = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
        );

        expect(task.originalResolution, '1920×1080');
      });

      test('compressedResolution 应返回压缩后分辨率', () {
        final task = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
          compressedWidth: 1280,
          compressedHeight: 720,
        );

        expect(task.compressedResolution, '1280x720');
      });

      test('无压缩后分辨率应返回Unknown', () {
        final task = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
        );

        expect(task.compressedResolution, 'Unknown');
      });
    });

    group('copyWith', () {
      test('应能复制并修改属性', () {
        final original = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
          status: CompressTaskStatus.pending,
          progress: 0.0,
        );

        final modified = original.copyWith(
          status: CompressTaskStatus.running,
          progress: 0.5,
          compressedSize: 5000000,
        );

        expect(modified.id, 'task-1');
        expect(modified.status, CompressTaskStatus.running);
        expect(modified.progress, 0.5);
        expect(modified.compressedSize, 5000000);
      });
    });

    group('JSON 序列化', () {
      test('toJson 应正确序列化', () {
        final task = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
          status: CompressTaskStatus.completed,
          progress: 1.0,
          outputPath: '/output/video.mp4',
          compressedSize: 5000000,
          compressedWidth: 1280,
          compressedHeight: 720,
          compressedBitrate: 2500000,
        );

        final json = task.toJson();

        expect(json['id'], 'task-1');
        expect(json['status'], CompressTaskStatus.completed.index);
        expect(json['progress'], 1.0);
        expect(json['outputPath'], '/output/video.mp4');
        expect(json['compressedSize'], 5000000);
        expect(json['compressedWidth'], 1280);
        expect(json['compressedHeight'], 720);
        expect(json['compressedBitrate'], 2500000);
      });

      test('fromJson 应正确反序列化', () {
        final json = {
          'id': 'task-1',
          'video': {
            'path': '/test.mp4',
            'name': 'test.mp4',
            'size': 10240000,
          },
          'config': {
            'quality': CompressQuality.medium.index,
            'keepOriginalResolution': true,
          },
          'status': CompressTaskStatus.completed.index,
          'progress': 1.0,
          'outputPath': '/output/video.mp4',
          'compressedSize': 5000000,
          'compressedWidth': 1280,
          'compressedHeight': 720,
          'compressedBitrate': 2500000,
        };

        final task = CompressTask.fromJson(json);

        expect(task.id, 'task-1');
        expect(task.status, CompressTaskStatus.completed);
        expect(task.progress, 1.0);
        expect(task.compressedSize, 5000000);
      });
    });

    group('Equatable', () {
      test('相同属性的实例应相等', () {
        final task1 = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
        );
        final task2 = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
        );

        expect(task1, equals(task2));
      });

      test('不同属性的实例应不相等', () {
        final task1 = CompressTask(
          id: 'task-1',
          video: testVideo,
          config: testConfig,
        );
        final task2 = CompressTask(
          id: 'task-2',
          video: testVideo,
          config: testConfig,
        );

        expect(task1, isNot(equals(task2)));
      });
    });
  });

  group('CompressTaskStatus', () {
    test('应有正确的状态枚举值', () {
      expect(CompressTaskStatus.values.length, 7);
      expect(CompressTaskStatus.pending.index, 0);
      expect(CompressTaskStatus.queued.index, 1);
      expect(CompressTaskStatus.running.index, 2);
      expect(CompressTaskStatus.completed.index, 3);
      expect(CompressTaskStatus.failed.index, 4);
      expect(CompressTaskStatus.cancelled.index, 5);
      expect(CompressTaskStatus.skipped.index, 6);
    });
  });
}

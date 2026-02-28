import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_compressor/data/models/video_info.dart';

void main() {
  group('VideoInfo', () {
    group('构造函数', () {
      test('应能正确创建基本视频信息', () {
        const videoInfo = VideoInfo(
          path: '/path/to/video.mp4',
          name: 'video.mp4',
          size: 1024000,
          duration: Duration(seconds: 120),
          width: 1920,
          height: 1080,
          codec: 'h264',
          bitrate: 5000000,
          frameRate: 30.0,
          rotation: 0,
        );

        expect(videoInfo.path, '/path/to/video.mp4');
        expect(videoInfo.name, 'video.mp4');
        expect(videoInfo.size, 1024000);
        expect(videoInfo.duration, const Duration(seconds: 120));
        expect(videoInfo.width, 1920);
        expect(videoInfo.height, 1080);
        expect(videoInfo.codec, 'h264');
        expect(videoInfo.bitrate, 5000000);
        expect(videoInfo.frameRate, 30.0);
        expect(videoInfo.rotation, 0);
      });
    });

    group('resolution 分辨率计算', () {
      test('正常视频应返回正确分辨率', () {
        const videoInfo = VideoInfo(
          path: '/test.mp4',
          width: 1920,
          height: 1080,
        );
        expect(videoInfo.resolution, '1920×1080');
      });

      test('旋转90度应交换宽高用于显示', () {
        const videoInfo = VideoInfo(
          path: '/test.mp4',
          width: 1920,
          height: 1080,
          rotation: 90,
        );
        expect(videoInfo.resolution, '1080×1920');
      });

      test('旋转270度应交换宽高用于显示', () {
        const videoInfo = VideoInfo(
          path: '/test.mp4',
          width: 1920,
          height: 1080,
          rotation: 270,
        );
        expect(videoInfo.resolution, '1080×1920');
      });

      test('旋转0度应保持原始宽高', () {
        const videoInfo = VideoInfo(
          path: '/test.mp4',
          width: 1920,
          height: 1080,
          rotation: 0,
        );
        expect(videoInfo.resolution, '1920×1080');
      });

      test('无宽高信息应返回0×0', () {
        const videoInfo = VideoInfo(path: '/test.mp4');
        expect(videoInfo.resolution, '0×0');
      });
    });

    group('sizeFormatted 文件大小格式化', () {
      test('字节应正确格式化', () {
        const videoInfo = VideoInfo(path: '/test.mp4', size: 500);
        expect(videoInfo.sizeFormatted, '500 B');
      });

      test('KB应正确格式化', () {
        const videoInfo = VideoInfo(path: '/test.mp4', size: 2048);
        expect(videoInfo.sizeFormatted, '2.0 KB');
      });

      test('MB应正确格式化', () {
        const videoInfo = VideoInfo(path: '/test.mp4', size: 5242880);
        expect(videoInfo.sizeFormatted, '5.0 MB');
      });

      test('GB应正确格式化', () {
        const videoInfo = VideoInfo(path: '/test.mp4', size: 2147483648);
        expect(videoInfo.sizeFormatted, '2.00 GB');
      });
    });

    group('durationFormatted 时长格式化', () {
      test('正常时长应格式化', () {
        const videoInfo = VideoInfo(
          path: '/test.mp4',
          duration: Duration(minutes: 5, seconds: 30),
        );
        expect(videoInfo.durationFormatted, '05:30');
      });

      test('有时长应包含小时', () {
        const videoInfo = VideoInfo(
          path: '/test.mp4',
          duration: Duration(hours: 1, minutes: 30, seconds: 45),
        );
        expect(videoInfo.durationFormatted, '01:30:45');
      });

      test('无时长应返回00:00', () {
        const videoInfo = VideoInfo(path: '/test.mp4');
        expect(videoInfo.durationFormatted, '00:00');
      });
    });

    group('JSON 序列化', () {
      test('toJson 应正确序列化', () {
        const videoInfo = VideoInfo(
          path: '/test.mp4',
          name: 'test.mp4',
          size: 1024000,
          duration: Duration(seconds: 120),
          width: 1920,
          height: 1080,
          codec: 'h264',
          bitrate: 5000000,
          frameRate: 30.0,
          rotation: 90,
        );

        final json = videoInfo.toJson();

        expect(json['path'], '/test.mp4');
        expect(json['name'], 'test.mp4');
        expect(json['size'], 1024000);
        expect(json['duration'], 120000);
        expect(json['width'], 1920);
        expect(json['height'], 1080);
        expect(json['codec'], 'h264');
        expect(json['bitrate'], 5000000);
        expect(json['frameRate'], 30.0);
        expect(json['rotation'], 90);
      });

      test('fromJson 应正确反序列化', () {
        final json = {
          'path': '/test.mp4',
          'name': 'test.mp4',
          'size': 1024000,
          'duration': 120000,
          'width': 1920,
          'height': 1080,
          'codec': 'h264',
          'bitrate': 5000000,
          'frameRate': 30.0,
          'rotation': 90,
        };

        final videoInfo = VideoInfo.fromJson(json);

        expect(videoInfo.path, '/test.mp4');
        expect(videoInfo.name, 'test.mp4');
        expect(videoInfo.size, 1024000);
        expect(videoInfo.duration, const Duration(seconds: 120));
        expect(videoInfo.width, 1920);
        expect(videoInfo.height, 1080);
        expect(videoInfo.codec, 'h264');
        expect(videoInfo.bitrate, 5000000);
        expect(videoInfo.frameRate, 30.0);
        expect(videoInfo.rotation, 90);
      });

      test('fromJson 应处理缺失字段', () {
        final json = <String, dynamic>{'path': '/test.mp4'};
        final videoInfo = VideoInfo.fromJson(json);

        expect(videoInfo.path, '/test.mp4');
        expect(videoInfo.name, null);
        expect(videoInfo.size, null);
      });
    });

    group('copyWith', () {
      test('应能复制并修改属性', () {
        const original = VideoInfo(
          path: '/test.mp4',
          name: 'test.mp4',
          size: 1000000,
        );

        final modified = original.copyWith(
          name: 'new_name.mp4',
          size: 2000000,
        );

        expect(modified.path, '/test.mp4');
        expect(modified.name, 'new_name.mp4');
        expect(modified.size, 2000000);
      });
    });

    group('Equatable', () {
      test('相同属性的实例应相等', () {
        const videoInfo1 = VideoInfo(
          path: '/test.mp4',
          name: 'test.mp4',
          size: 1000000,
        );
        const videoInfo2 = VideoInfo(
          path: '/test.mp4',
          name: 'test.mp4',
          size: 1000000,
        );

        expect(videoInfo1, equals(videoInfo2));
      });

      test('不同属性的实例应不相等', () {
        const videoInfo1 = VideoInfo(path: '/test1.mp4');
        const videoInfo2 = VideoInfo(path: '/test2.mp4');

        expect(videoInfo1, isNot(equals(videoInfo2)));
      });
    });
  });
}

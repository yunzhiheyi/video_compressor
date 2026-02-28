import 'package:flutter_test/flutter_test.dart';
import 'package:video_compressor/data/models/compress_config.dart';

void main() {
  group('CompressConfig', () {
    group('构造函数和默认值', () {
      test('默认构造函数应使用中画质', () {
        const config = CompressConfig();
        expect(config.quality, CompressQuality.medium);
      });

      test('应能正确创建自定义配置', () {
        const config = CompressConfig(
          quality: CompressQuality.high,
          customBitrate: 3000000,
          targetWidth: 1920,
          targetHeight: 1080,
          frameRate: 30,
          keepOriginalResolution: false,
        );

        expect(config.quality, CompressQuality.high);
        expect(config.customBitrate, 3000000);
        expect(config.targetWidth, 1920);
        expect(config.targetHeight, 1080);
        expect(config.frameRate, 30);
        expect(config.keepOriginalResolution, false);
      });
    });

    group('bitrate 计算', () {
      test('低画质应返回 1 Mbps', () {
        const config = CompressConfig(quality: CompressQuality.low);
        expect(config.bitrate, 1000000);
      });

      test('中画质应返回 2.5 Mbps', () {
        const config = CompressConfig(quality: CompressQuality.medium);
        expect(config.bitrate, 2500000);
      });

      test('高画质应返回 5 Mbps', () {
        const config = CompressConfig(quality: CompressQuality.high);
        expect(config.bitrate, 5000000);
      });

      test('原始画质应返回 0', () {
        const config = CompressConfig(quality: CompressQuality.original);
        expect(config.bitrate, 0);
      });

      test('自定义画质应使用自定义码率', () {
        const config = CompressQuality.custom;
        const customConfig = CompressConfig(
          quality: CompressQuality.custom,
          customBitrate: 4000000,
        );
        expect(customConfig.bitrate, 4000000);
      });

      test('自定义画质无码率时应返回默认值 2.5 Mbps', () {
        const config = CompressConfig(quality: CompressQuality.custom);
        expect(config.bitrate, 2500000);
      });
    });

    group('qualityLabel 标签', () {
      test('低画质应返回正确标签', () {
        const config = CompressConfig(quality: CompressQuality.low);
        expect(config.qualityLabel, 'Low (1 Mbps)');
      });

      test('中画质应返回正确标签', () {
        const config = CompressConfig(quality: CompressQuality.medium);
        expect(config.qualityLabel, 'Medium (2.5 Mbps)');
      });

      test('高画质应返回正确标签', () {
        const config = CompressConfig(quality: CompressQuality.high);
        expect(config.qualityLabel, 'High (5 Mbps)');
      });

      test('原始画质应返回正确标签', () {
        const config = CompressConfig(quality: CompressQuality.original);
        expect(config.qualityLabel, 'Original');
      });

      test('自定义画质应显示自定义码率', () {
        const config = CompressConfig(
          quality: CompressQuality.custom,
          customBitrate: 3500000,
        );
        expect(config.qualityLabel, 'Custom (3500 Kbps)');
      });
    });

    group('copyWith', () {
      test('应能复制并修改部分属性', () {
        const original = CompressConfig(
          quality: CompressQuality.medium,
          targetWidth: 1920,
        );

        final modified = original.copyWith(
          quality: CompressQuality.high,
          targetHeight: 1080,
        );

        expect(modified.quality, CompressQuality.high);
        expect(modified.targetWidth, 1920);
        expect(modified.targetHeight, 1080);
      });

      test('不修改的属性应保持不变', () {
        const original = CompressConfig(
          quality: CompressQuality.high,
          customBitrate: 3000000,
          frameRate: 30,
        );

        final modified = original.copyWith(quality: CompressQuality.low);

        expect(modified.customBitrate, 3000000);
        expect(modified.frameRate, 30);
      });
    });

    group('JSON 序列化', () {
      test('toJson 应正确序列化配置', () {
        const config = CompressConfig(
          quality: CompressQuality.high,
          customBitrate: 4000000,
          targetWidth: 1280,
          targetHeight: 720,
          frameRate: 30,
          keepOriginalResolution: false,
        );

        final json = config.toJson();

        expect(json['quality'], CompressQuality.high.index);
        expect(json['customBitrate'], 4000000);
        expect(json['targetWidth'], 1280);
        expect(json['targetHeight'], 720);
        expect(json['frameRate'], 30);
        expect(json['keepOriginalResolution'], false);
      });

      test('fromJson 应正确反序列化配置', () {
        final json = {
          'quality': CompressQuality.high.index,
          'customBitrate': 4000000,
          'targetWidth': 1280,
          'targetHeight': 720,
          'frameRate': 30,
          'keepOriginalResolution': false,
        };

        final config = CompressConfig.fromJson(json);

        expect(config.quality, CompressQuality.high);
        expect(config.customBitrate, 4000000);
        expect(config.targetWidth, 1280);
        expect(config.targetHeight, 720);
        expect(config.frameRate, 30);
        expect(config.keepOriginalResolution, false);
      });

      test('fromJson 应处理缺失字段使用默认值', () {
        final json = <String, dynamic>{};
        final config = CompressConfig.fromJson(json);

        expect(config.quality, CompressQuality.medium);
        expect(config.keepOriginalResolution, true);
      });
    });

    group('Equatable', () {
      test('相同属性的实例应相等', () {
        const config1 = CompressConfig(
          quality: CompressQuality.high,
          customBitrate: 3000000,
        );
        const config2 = CompressConfig(
          quality: CompressQuality.high,
          customBitrate: 3000000,
        );

        expect(config1, equals(config2));
      });

      test('不同属性的实例应不相等', () {
        const config1 = CompressConfig(quality: CompressQuality.high);
        const config2 = CompressConfig(quality: CompressQuality.low);

        expect(config1, isNot(equals(config2)));
      });
    });
  });
}

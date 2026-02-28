import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_compressor/core/constants/app_colors.dart';
import 'package:video_compressor/presentation/pages/history/history_state.dart';
import 'package:video_compressor/presentation/widgets/history_item_card.dart';

void main() {
  group('HistoryItemCard', () {
    late HistoryItem testItem;

    setUp(() {
      testItem = HistoryItem(
        id: '1',
        name: 'test_video.mp4',
        originalSize: 10240000, // 10 MB
        compressedSize: 5120000, // 5 MB
        compressedAt: DateTime(2024, 1, 15, 14, 30),
        outputPath: '/output/test_video.mp4',
        originalResolution: '1920x1080',
        compressedResolution: '1280x720',
        duration: 120.0,
        originalBitrate: 5000000,
        compressedBitrate: 2500000,
        frameRate: 30.0,
      );
    });

    testWidgets('应显示视频名称', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryItemCard(item: testItem),
          ),
        ),
      );

      expect(find.text('test_video.mp4'), findsOneWidget);
    });

    testWidgets('应显示压缩前后大小', (WidgetTester tester) async {
      // 使用能整除的大小以便匹配格式化结果
      final testItemFixed = HistoryItem(
        id: '1',
        name: 'test_video.mp4',
        originalSize: 10485760, // 10 MB (1024 * 1024 * 10)
        compressedSize: 5242880, // 5 MB (1024 * 1024 * 5)
        compressedAt: DateTime(2024, 1, 15, 14, 30),
        outputPath: '/output/test_video.mp4',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryItemCard(item: testItemFixed),
          ),
        ),
      );

      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
      // 使用精确匹配格式化后的结果
      expect(find.text('10.0 MB'), findsOneWidget);
      expect(find.text('5.0 MB'), findsOneWidget);
    });

    testWidgets('应显示压缩比', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryItemCard(item: testItem),
          ),
        ),
      );

      // 压缩比应该是 (1 - 5/10) * 100 = 50%
      expect(find.text('-50%'), findsOneWidget);
    });

    testWidgets('应显示日期', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryItemCard(item: testItem),
          ),
        ),
      );

      expect(find.text('2024-01-15 14:30'), findsOneWidget);
    });

    testWidgets('点击应触发 onTap 回调', (WidgetTester tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryItemCard(
              item: testItem,
              onTap: () => wasTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(HistoryItemCard));
      await tester.pump();

      expect(wasTapped, true);
    });

    testWidgets('压缩比为0%时应正确显示', (WidgetTester tester) async {
      final itemNoCompression = HistoryItem(
        id: '2',
        name: 'same_size.mp4',
        originalSize: 5000000,
        compressedSize: 5000000,
        compressedAt: DateTime.now(),
        outputPath: '/output/same.mp4',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryItemCard(item: itemNoCompression),
          ),
        ),
      );

      expect(find.text('-0%'), findsOneWidget);
    });
  });

  group('HistoryItemCard 工具方法', () {
    test('formatSize 应正确格式化字节', () {
      expect(HistoryItemCard.formatSize(500), '500 B');
      expect(HistoryItemCard.formatSize(2048), '2.0 KB');
      expect(HistoryItemCard.formatSize(5242880), '5.0 MB');
      expect(HistoryItemCard.formatSize(2147483648), '2.00 GB');
    });

    test('formatDate 应正确格式化日期', () {
      final date = DateTime(2024, 3, 15, 9, 5);
      expect(HistoryItemCard.formatDate(date), '2024-03-15 09:05');
    });
  });
}

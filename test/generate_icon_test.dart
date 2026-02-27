import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

void main() async {
  const size = 1024.0;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // 背景 - 暗黑渐变
  final bgPaint = ui.Paint()
    ..shader = ui.Gradient.linear(
      const ui.Offset(0, 0),
      const ui.Offset(size, size),
      [const ui.Color(0xFF0D0D0D), const ui.Color(0xFF1A1A2E)],
    );
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, size, size), bgPaint);

  // 圆角矩形背景
  final iconRect = ui.RRect.fromRectAndRadius(
    const ui.Rect.fromLTWH(size * 0.1, size * 0.1, size * 0.8, size * 0.8),
    const ui.Radius.circular(size * 0.18),
  );

  // 图标背景渐变
  final iconPaint = ui.Paint()
    ..shader = ui.Gradient.linear(
      const ui.Offset(size * 0.1, size * 0.1),
      const ui.Offset(size * 0.9, size * 0.9),
      [const ui.Color(0xFF2196F3), const ui.Color(0xFF1976D2)],
    );
  canvas.drawRRect(iconRect, iconPaint);

  // 发光效果
  final glowPaint = ui.Paint()
    ..color = const ui.Color(0x4D2196F3)
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 40);
  canvas.drawRRect(iconRect, glowPaint);

  // 压缩图标线条
  final linePaint = ui.Paint()
    ..color = const ui.Color(0xFFFFFFFF)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = size * 0.04
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;

  // 上层压缩箭头 (左)
  final leftArrow = ui.Path();
  leftArrow.moveTo(size * 0.32, size * 0.36);
  leftArrow.lineTo(size * 0.22, size * 0.50);
  leftArrow.lineTo(size * 0.32, size * 0.64);
  canvas.drawPath(leftArrow, linePaint);

  // 上层视频线条
  canvas.drawLine(
    const ui.Offset(size * 0.24, size * 0.32),
    const ui.Offset(size * 0.52, size * 0.32),
    linePaint,
  );
  canvas.drawLine(
    const ui.Offset(size * 0.24, size * 0.50),
    const ui.Offset(size * 0.52, size * 0.50),
    linePaint,
  );
  canvas.drawLine(
    const ui.Offset(size * 0.24, size * 0.68),
    const ui.Offset(size * 0.52, size * 0.68),
    linePaint,
  );

  // 下层展开箭头 (右)
  final rightArrow = ui.Path();
  rightArrow.moveTo(size * 0.68, size * 0.36);
  rightArrow.lineTo(size * 0.78, size * 0.50);
  rightArrow.lineTo(size * 0.68, size * 0.64);
  canvas.drawPath(rightArrow, linePaint);

  // 下层视频线条（更宽）
  canvas.drawLine(
    const ui.Offset(size * 0.48, size * 0.32),
    const ui.Offset(size * 0.76, size * 0.32),
    linePaint,
  );
  canvas.drawLine(
    const ui.Offset(size * 0.48, size * 0.50),
    const ui.Offset(size * 0.76, size * 0.50),
    linePaint,
  );
  canvas.drawLine(
    const ui.Offset(size * 0.48, size * 0.68),
    const ui.Offset(size * 0.76, size * 0.68),
    linePaint,
  );

  // 完成
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  if (byteData != null) {
    final buffer = byteData.buffer.asUint8List();
    // 使用项目根目录的相对路径
    final file = File('assets/icon/app_icon.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(buffer);

    // 也生成 foreground 图标（无背景）
    print('Icon saved to: ${file.path}');
    print('Size: ${buffer.length} bytes');

    // 复制为 adaptive icon foreground
    final foregroundFile = File('assets/icon/app_icon_foreground.png');
    await file.copy(foregroundFile.path);
    print('Foreground icon saved to: ${foregroundFile.path}');
  }
}

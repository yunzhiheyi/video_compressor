import 'dart:io';
import 'dart:ui' as ui;

void main() async {
  const size = 1024.0;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // 蓝色背景
  final bgPaint = ui.Paint()..color = const ui.Color(0xFF2196F3);
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, size, size), bgPaint);

  // 白色压缩图标
  // 绘制两条压缩箭头
  final linePaint = ui.Paint()
    ..color = const ui.Color(0xFFFFFFFF)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = size * 0.06
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;

  // 左箭头 (收缩)
  final leftArrow = ui.Path();
  leftArrow.moveTo(size * 0.28, size * 0.35);
  leftArrow.lineTo(size * 0.15, size * 0.50);
  leftArrow.lineTo(size * 0.28, size * 0.65);
  canvas.drawPath(leftArrow, linePaint);

  // 左侧线条
  canvas.drawLine(
    const ui.Offset(size * 0.18, size * 0.30),
    const ui.Offset(size * 0.45, size * 0.30),
    linePaint,
  );
  canvas.drawLine(
    const ui.Offset(size * 0.18, size * 0.50),
    const ui.Offset(size * 0.45, size * 0.50),
    linePaint,
  );
  canvas.drawLine(
    const ui.Offset(size * 0.18, size * 0.70),
    const ui.Offset(size * 0.45, size * 0.70),
    linePaint,
  );

  // 右箭头 (展开)
  final rightArrow = ui.Path();
  rightArrow.moveTo(size * 0.72, size * 0.35);
  rightArrow.lineTo(size * 0.85, size * 0.50);
  rightArrow.lineTo(size * 0.72, size * 0.65);
  canvas.drawPath(rightArrow, linePaint);

  // 右侧线条（更宽）
  canvas.drawLine(
    const ui.Offset(size * 0.55, size * 0.30),
    const ui.Offset(size * 0.82, size * 0.30),
    linePaint,
  );
  canvas.drawLine(
    const ui.Offset(size * 0.55, size * 0.50),
    const ui.Offset(size * 0.82, size * 0.50),
    linePaint,
  );
  canvas.drawLine(
    const ui.Offset(size * 0.55, size * 0.70),
    const ui.Offset(size * 0.82, size * 0.70),
    linePaint,
  );

  // 完成
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  if (byteData != null) {
    final buffer = byteData.buffer.asUint8List();
    final file = File('assets/icon/app_icon.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(buffer);

    print('Icon saved to: ${file.path}');
    print('Size: ${buffer.length} bytes');
  }
}

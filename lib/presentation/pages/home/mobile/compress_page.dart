import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../widgets/video_compress_content.dart';

class MobileCompressPage extends StatelessWidget {
  const MobileCompressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Video Compressor'),
        backgroundColor: AppColors.surface,
      ),
      body: const VideoCompressContent(
        style: VideoCompressStyle.mobile,
        includeBottomBar: true,
      ),
    );
  }
}

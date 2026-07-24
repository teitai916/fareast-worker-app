import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';

/// 远东幕墙品牌 Logo 组件
///
/// 使用 CustomPainter 绘制弧形穹顶造型，灵感来自 FAREAST FACADE Logo
/// 蓝色弧形 + 深蓝背景 = 品牌识别核心
class BrandLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const BrandLogo({
    super.key,
    this.size = 88,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.25),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: size * 0.18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.25),
            child: CustomPaint(
              painter: _ArcLogoPainter(arcColor: AppTheme.accentColor),
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 12),
          Text(
            '遠東智工',
            style: TextStyle(
              fontSize: size * 0.38,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'FAREAST WORKER APP',
            style: TextStyle(
              fontSize: size * 0.16,
              color: AppTheme.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// 弧形穹顶 Logo 绘制器
///
/// 绘制一个蓝色弧形穹顶线条，模拟 FAREAST FACADE 品牌 LOGO 效果：
/// - 底部水平基线
/// - 向上弯曲的弧形穹顶
/// - 右侧一个竖直线条作为结构支撑
class _ArcLogoPainter extends CustomPainter {
  final Color arcColor;

  const _ArcLogoPainter({required this.arcColor});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width * 0.35;

    // 画笔配置
    final paint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = arcColor.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    // ─── 绘制弧形穹顶 ───
    // 弧形路径：从底部左侧到右侧顶部，形成穹顶
    final arcPath = Path();
    // 从底部左四分之一处开始
    final startX = centerX - radius * 1.3;
    final endX = centerX + radius * 1.3;
    final baseY = centerY + radius * 0.5;

    // 使用二次贝塞尔曲线绘制弧形穹顶
    arcPath.moveTo(startX, baseY);
    arcPath.quadraticBezierTo(
      centerX, baseY - radius * 1.8, // 控制点（最高处）
      endX, baseY, // 终点（右侧底部）
    );

    // 绘制弧线
    canvas.drawPath(arcPath, paint);

    // ─── 绘制右侧竖线（结构支撑） ───
    final linePaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round;

    final postPath = Path();
    postPath.moveTo(endX, baseY - radius * 0.3);
    postPath.lineTo(endX, baseY + radius * 0.6);
    canvas.drawPath(postPath, linePaint);

    // ─── 填充弧形区域（淡蓝色透明） ───
    final fillPath = Path();
    fillPath.moveTo(startX, baseY);
    fillPath.quadraticBezierTo(
      centerX, baseY - radius * 1.8,
      endX, baseY,
    );
    fillPath.lineTo(endX, baseY + radius * 0.6);
    fillPath.lineTo(startX, baseY + radius * 0.6);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // ─── 穹顶上方小圆点装饰 ───
    final dotPaint = Paint()
      ..color = arcColor.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final dotRadius = size.width * 0.035;
    // 左上角2个小圆点
    canvas.drawCircle(Offset(startX + size.width * 0.12, baseY - radius * 1.2), dotRadius, dotPaint);
    canvas.drawCircle(Offset(centerX - size.width * 0.08, baseY - radius * 1.6), dotRadius * 0.7, dotPaint);

    // 右下角1个小圆点
    canvas.drawCircle(Offset(endX - size.width * 0.1, baseY + radius * 0.3), dotRadius * 0.85, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 简单品牌 Logo（不带弧形细节，用于小尺寸场景）
class SimpleBrandLogo extends StatelessWidget {
  final double size;

  const SimpleBrandLogo({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Icon(
        Icons.architecture,
        color: AppTheme.accentLight,
        size: size * 0.55,
      ),
    );
  }
}

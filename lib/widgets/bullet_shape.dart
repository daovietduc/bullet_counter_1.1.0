import 'package:flutter/material.dart';

class BulletShape extends CustomPainter {
  final Color color = Colors.red;           // Màu đường viền
  final double strokeWidth = 2;             // Độ dày đường viền
  final double bulletHeight = 65;          // Chiều cao viên đạn

  // --- TỶ LỆ CÁC PHẦN (% chiều cao tổng) ---
  // PHẦN ĐẦU ĐẠN
  final double noseHeightRatio = 0.25;        // Chiều cao đầu đạn nhọn / Chiều cao viên đạn
  final double noseWidthRatio = 0.70;         // Độ rộng đầu đạn / Chiều rộng viên đạn

  // PHẦN NỐI ĐẦU ĐẠN VỚI VAI ĐẠN
  final double neckHeightRatio = 0.10;        // Chiều cao neck / Chiều cao viên đạn

  // PHẦN VAI ĐẠN
  final double shoulderHeightRatio = 0.05;    // Chiều cao vai đạn / Chiều cao viên đạn

  // PHẦN ĐÍT ĐẠN
  final double rimTotalHeightRatio = 0.07;    // Tổng chiều cao phần đít / Chiều cao viên đạn
  final double tier1HeightRatio = 0.65;       // Tầng 1 chiếm 65% chiều cao đít / Chiều cao viên đạn
  final double tier2HeightRatio = 0.35;       // Tầng 2 kết thúc ở 25% từ đáy / Chiều cao viên đạn
  final double tier1WidthRatio = 0.80;        // Độ rộng tầng 2 / Chiều rộng viên đạn

  // CHIỀU RỘNG TỔNG
  final double bodyWidthRatio = 0.20;         // Chiều rộng thân đạn / Chiều rộng viên đạn

  BulletShape();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // --- TÍNH TOÁN KÍCH THƯỚC THỰC TẾ ---

    final bHeight = bulletHeight;
    final bWidth = bHeight * bodyWidthRatio;  // Chiều rộng = 30% chiều cao

    final left = centerX - bWidth / 2;
    final right = centerX + bWidth / 2;
    final top = centerY - bHeight / 2;
    final bottom = centerY + bHeight / 2;

    // PHẦN 1: ĐẦU ĐẠN NHỌN (NOSE)
    final noseHeight = bHeight * noseHeightRatio;       // 35% chiều cao
    final noseWidth = bWidth * noseWidthRatio;          // 75% chiều rộng thân
    final noseBottomY = top + noseHeight;
    final noseLeft = centerX - noseWidth / 2;
    final noseRight = centerX + noseWidth / 2;

    // PHẦN 2: NECK (HÌNH CHỮ NHẬT NỐI)
    final neckHeight = bHeight * neckHeightRatio;       // 9% chiều cao
    final neckBottomY = noseBottomY + neckHeight;
    final neckLeft = noseLeft;
    final neckRight = noseRight;

    // PHẦN 3: VAI ĐẠN (SHOULDER)
    final shoulderHeight = bHeight * shoulderHeightRatio;  // 6% chiều cao
    final shoulderBottomY = neckBottomY + shoulderHeight;

    // PHẦN 4: THÂN ĐẠN (CASE BODY)
    // Tự động tính từ shoulderBottomY đến tier1TopY

    // PHẦN 5: ĐÍT ĐẠN (3 TẦNG)
    final rimHeight = bHeight * rimTotalHeightRatio;    // 12% chiều cao

    // Tầng 1: Hình thang
    final tier1TopY = bottom - rimHeight;
    final tier1BottomY = bottom - rimHeight * tier1HeightRatio;  // 65% chiều cao đít
    final tier1Width = bWidth * tier1WidthRatio;        // 85% chiều rộng thân
    final tier1Left = centerX - tier1Width / 2;
    final tier1Right = centerX + tier1Width / 2;

    // Tầng 2: Extractor groove
    final tier2BottomY = bottom - rimHeight * tier2HeightRatio;  // 25% từ đáy

    // Tầng 3: Rim (tự động từ tier2BottomY đến bottom)

    // --- VẼ VIÊN ĐẠN TỪ TRÊN XUỐNG DƯỚI ---

    Path path = Path();

    // 1. ĐẦU ĐẠN NHỌN - Bắt đầu từ đỉnh
    path.moveTo(centerX, top);

    // Vẽ cạnh phải đầu đạn (đường cong)
    path.cubicTo(
        centerX + noseWidth * 0.35, top + noseHeight * 0.15,
        noseRight + noseWidth * 0.08, top + noseHeight * 0.65,
        noseRight, noseBottomY
    );

    // 2. NECK - Hình chữ nhật nối (bên phải)
    path.lineTo(neckRight, neckBottomY);

    // 3. VAI ĐẠN - Chuyển tiếp từ nhỏ sang lớn (bên phải)
    path.lineTo(right, shoulderBottomY);

    // 4. THÂN ĐẠN - Đường thẳng (bên phải)
    path.lineTo(right, tier1TopY);

    // 5. ĐÍT ĐẠN - TẦNG 1: Hình thang (bên phải)
    path.lineTo(tier1Right, tier1BottomY);

    // 6. ĐÍT ĐẠN - TẦNG 2: Extractor groove (bên phải)
    path.lineTo(tier1Right, tier2BottomY);

    // 7. ĐÍT ĐẠN - TẦNG 3: Rim (bên phải)
    path.lineTo(right, tier2BottomY);
    path.lineTo(right, bottom);

    // QUAY LẠI - VẼ TỪ DƯỚI LÊN TRÊN BÊN TRÁI

    // Đáy đạn (ngang)
    path.lineTo(left, bottom);

    // 7. ĐÍT ĐẠN - TẦNG 3: Rim (bên trái)
    path.lineTo(left, tier2BottomY);
    path.lineTo(tier1Left, tier2BottomY);

    // 6. ĐÍT ĐẠN - TẦNG 2: Extractor groove (bên trái)
    path.lineTo(tier1Left, tier1BottomY);

    // 5. ĐÍT ĐẠN - TẦNG 1: Hình thang (bên trái)
    path.lineTo(left, tier1TopY);

    // 4. THÂN ĐẠN - Đường thẳng (bên trái)
    path.lineTo(left, shoulderBottomY);

    // 3. VAI ĐẠN - Chuyển tiếp từ lớn sang nhỏ (bên trái)
    path.lineTo(neckLeft, neckBottomY);

    // 2. NECK - Hình chữ nhật nối (bên trái)
    path.lineTo(neckLeft, noseBottomY);

    // 1. ĐẦU ĐẠN NHỌN - Vẽ cạnh trái (đường cong)
    path.cubicTo(
        noseLeft - noseWidth * 0.08, top + noseHeight * 0.65,
        centerX - noseWidth * 0.35, top + noseHeight * 0.15,
        centerX, top  // Quay về đỉnh
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
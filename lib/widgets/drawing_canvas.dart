import 'package:flutter/material.dart';

class DrawingCanvas extends StatefulWidget {
  final Function(List<Offset>) onDrawingComplete;
  
  const DrawingCanvas({
    Key? key,
    required this.onDrawingComplete,
  }) : super(key: key);

  @override
  _DrawingCanvasState createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  List<List<Offset>> strokes = [];
  List<Offset> currentStroke = [];
  Color selectedColor = Colors.black;
  double strokeWidth = 3.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 도구 모음
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 펜 굵기 조절
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.brush, size: 20, color: Colors.grey[600]),
                  Slider(
                    value: strokeWidth,
                    min: 1.0,
                    max: 10.0,
                    divisions: 9,
                    onChanged: (value) {
                      setState(() {
                        strokeWidth = value;
                      });
                    },
                  ),
                ],
              ),
              
              // 색상 선택
              Row(
                children: [
                  _buildColorButton(Colors.black),
                  SizedBox(width: 8),
                  _buildColorButton(Colors.blue),
                  SizedBox(width: 8),
                  _buildColorButton(Colors.red),
                  SizedBox(width: 8),
                  _buildColorButton(Colors.green),
                ],
              ),
              
              // 지우기 버튼
              IconButton(
                onPressed: () {
                  setState(() {
                    strokes.clear();
                    currentStroke.clear();
                  });
                },
                icon: Icon(Icons.clear, color: Colors.red[600]),
                tooltip: '전체 지우기',
              ),
            ],
          ),
        ),
        
        SizedBox(height: 12),
        
        // 그리기 영역
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    currentStroke = [details.localPosition];
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    currentStroke.add(details.localPosition);
                  });
                },
                onPanEnd: (details) {
                  setState(() {
                    strokes.add(List.from(currentStroke));
                    currentStroke.clear();
                  });
                },
                child: CustomPaint(
                  painter: DrawingPainter(
                    strokes: strokes,
                    currentStroke: currentStroke,
                    strokeColor: selectedColor,
                    strokeWidth: strokeWidth,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = selectedColor == color;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedColor = color;
        });
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.grey[800]! : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? Icon(Icons.check, color: Colors.white, size: 16)
            : null,
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color strokeColor;
  final double strokeWidth;

  DrawingPainter({
    required this.strokes,
    required this.currentStroke,
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 완성된 스트로크들 그리기
    for (List<Offset> stroke in strokes) {
      if (stroke.length > 1) {
        final path = Path();
        path.moveTo(stroke[0].dx, stroke[0].dy);
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    // 현재 그리고 있는 스트로크 그리기
    if (currentStroke.length > 1) {
      final path = Path();
      path.moveTo(currentStroke[0].dx, currentStroke[0].dy);
      for (int i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 
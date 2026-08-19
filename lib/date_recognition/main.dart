import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  // 플러터 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 사용 가능한 카메라 가져오기
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('카메라 초기화 오류: ${e.code}, ${e.description}');
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// 카메라 버튼을 위한 화면 
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('카메라 버튼 테스트')),
      body: Center(
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Color(0xFF2196F3), // 파란색 (첨부 이미지 스타일)
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.camera_alt, color: Colors.white, size: 28),
            onPressed: () {
              // [카메라 버튼 동작] 버튼을 누르면 DateRecognitionCameraScreen(카메라 화면)으로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DateRecognitionCameraScreen(
                    cameras: cameras,
                    onDateRecognized: (date) {
                      print('인식된 날짜: $date');
                    },
                  ),
                ),
              );
            },
            tooltip: '카메라 열기',
          ),
        ),
      ),
    );
  }
}
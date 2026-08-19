import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;
import 'package:permission_handler/permission_handler.dart';
import 'text_detector_helper.dart';

class DateRecognitionCameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Function(String) onDateRecognized;

  const DateRecognitionCameraScreen({
    Key? key, 
    required this.cameras,
    required this.onDateRecognized,
  }) : super(key: key);

  @override
  _DateRecognitionCameraScreenState createState() => _DateRecognitionCameraScreenState();
}

class _DateRecognitionCameraScreenState extends State<DateRecognitionCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isPermissionGranted = false;
  FlashMode _flashMode = FlashMode.off;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    _requestCameraPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱 상태 변경 시 카메라 컨트롤러 관리
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(_selectedCameraIndex);
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _isPermissionGranted = status == PermissionStatus.granted;
    });

    if (_isPermissionGranted) {
      await _initializeCamera(0);
    }
  }

  Future<void> _initializeCamera(int cameraIndex) async {
    if (widget.cameras.isEmpty) {
      print('사용 가능한 카메라가 없습니다.');
      return;
    }

    // 선택한 카메라가 범위를 벗어나면 첫 번째 카메라 사용
    if (cameraIndex >= widget.cameras.length) {
      cameraIndex = 0;
    }

    _selectedCameraIndex = cameraIndex;

    // 기존 컨트롤러가 있으면 해제
    if (_controller != null) {
      await _controller!.dispose();
    }

    // 새 카메라 컨트롤러 초기화
    _controller = CameraController(
      widget.cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print('카메라 초기화 오류: $e');
    }
  }

  void _toggleFlash() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _flashMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
      _controller!.setFlashMode(_flashMode);
    });
  }

  void _switchCamera() {
    if (widget.cameras.length < 2) return;

    setState(() {
      _isCameraInitialized = false;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    });

    _initializeCamera(_selectedCameraIndex);
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      // 사진 촬영
      final XFile photo = await _controller!.takePicture();

      // 임시 파일 경로 생성
      final Directory appDir = await getTemporaryDirectory();
      final String filePath = join(appDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');

      // 촬영한 사진을 임시 파일로 저장
      await File(photo.path).copy(filePath);

      if (!mounted) return;

      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('유통기한 인식 중...'),
                ],
              ),
            ),
          );
        },
      );

      // 텍스트 인식 직접 처리
      final textDetectorHelper = TextDetectorHelper();
      try {
        final recognizedText = await textDetectorHelper.recognizeText(filePath);
        
        // 날짜 추출
        String extractedDate = '';
        if (recognizedText.contains('유통기한:')) {
          List<String> lines = recognizedText.split('\n');
          if (lines.length >= 2) {
            extractedDate = lines[1].trim();
          }
        }

        // 로딩 다이얼로그 닫기
        if (mounted) {
          Navigator.of(context).pop();
        }

        if (extractedDate.isNotEmpty) {
          // 인식 성공 - 콜백 호출하고 화면 닫기
          widget.onDateRecognized(extractedDate);
          Navigator.pop(context, extractedDate);
        } else {
          // 인식 실패 - 에러 메시지 표시
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('유통기한을 인식할 수 없습니다. 다시 촬영해보세요.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        // 로딩 다이얼로그 닫기
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('텍스트 인식 중 오류가 발생했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        textDetectorHelper.dispose();
        // 임시 파일 삭제
        try {
          await File(filePath).delete();
        } catch (e) {
          print('임시 파일 삭제 실패: $e');
        }
      }
    } catch (e) {
      print('사진 촬영 중 오류: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionGranted) {
      return Scaffold(
        appBar: AppBar(
          title: Text('카메라 권한 필요'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('유통기한 인식을 위해 카메라 권한이 필요합니다.'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _requestCameraPermission,
                child: Text('권한 요청'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _controller == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('카메라 초기화 중'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('유통기한 인식'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // 안내 메시지
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: Colors.black.withOpacity(0.7),
            child: Text(
              '유통기한이 잘 보이도록 촬영하세요',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // 카메라 프리뷰
          Expanded(
            child: Container(
              width: double.infinity,
              child: CameraPreview(_controller!),
            ),
          ),
          
          // 컨트롤 버튼들
          Container(
            height: 120,
            width: double.infinity,
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 플래시 버튼
                IconButton(
                  onPressed: _toggleFlash,
                  icon: Icon(
                    _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
                    color: Colors.white,
                    size: 28,
                  ),
                  tooltip: '플래시',
                ),
                
                // 촬영 버튼
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                ),
                
                // 카메라 전환 버튼
                IconButton(
                  onPressed: widget.cameras.length > 1 ? _switchCamera : null,
                  icon: Icon(
                    Icons.flip_camera_ios,
                    color: widget.cameras.length > 1 ? Colors.white : Colors.grey,
                    size: 28,
                  ),
                  tooltip: '카메라 전환',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
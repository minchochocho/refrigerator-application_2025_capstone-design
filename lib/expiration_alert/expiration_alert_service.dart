import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:workmanager/workmanager.dart';  // removed
import 'expiration_alert_model.dart';

// Background scheduler removed due to workmanager incompatibility

/// 유통기한 알림 서비스
class ExpirationAlertService {
  static final ExpirationAlertService _instance = ExpirationAlertService._internal();
  factory ExpirationAlertService() => _instance;
  ExpirationAlertService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isInitialized = false;
  // static const String _dailyRefreshTaskName = 'dailyNotificationRefresh';  // removed

  /// 알림 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 타임존 데이터 초기화
    tz.initializeTimeZones();
    
    // Android 초기화 설정
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS 초기화 설정
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Android 알림 채널 생성
    await _createNotificationChannel();

    // 권한 요청
    await _requestPermissions();
    
    _isInitialized = true;
    print('ExpirationAlertService 초기화 완료');
  }

  /// 알림 권한 요청
  Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      try {
        // 기본 알림 권한 요청
        final bool? notificationPermission = await androidPlugin.requestNotificationsPermission();
        print('알림 권한 요청 결과: $notificationPermission');
        
        // 정확한 알람 권한 확인 및 요청 (Android 12+)
        try {
          final bool? exactAlarmPermission = await androidPlugin.requestExactAlarmsPermission();
          print('정확한 알람 권한 요청 결과: $exactAlarmPermission');
        } catch (e) {
          print('정확한 알람 권한 요청 실패 (Android 버전이 낮거나 권한이 없음): $e');
          // Android 12 미만이거나 권한이 제한된 경우 일반 알림 사용
        }
        
        // 배터리 최적화 제외는 사용자가 수동으로 설정해야 함
        print('배터리 최적화 제외는 설정에서 수동으로 해주세요');
        
      } catch (e) {
        print('Android 알림 권한 요청 오류: $e');
      }
    }
    
    // iOS 권한 요청
    try {
      final bool? result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      
      print('iOS 알림 권한 요청 결과: $result');
    } catch (e) {
      print('iOS 알림 권한 요청 오류: $e');
    }
  }

  /// Android 알림 채널 생성
  Future<void> _createNotificationChannel() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'expiration_alert_channel', // 채널 ID
        '유통기한 알림', // 채널 이름
        description: '식품 유통기한 만료 알림', // 채널 설명
        importance: Importance.high,
        enableVibration: true,
        enableLights: true,
        playSound: true,
        showBadge: true,
      );

      await androidPlugin.createNotificationChannel(channel);
      print('Android 알림 채널 생성 완료: ${channel.id}');
    }
  }

  /// 알림 탭 이벤트 처리
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    print('알림 탭됨: ${notificationResponse.payload}');
    // TODO: 알림 탭 시 해당 식품 화면으로 이동
  }

  /// 식품의 유통기한 알림 스케줄링
  /// expiryDate: 유통기한 (예: 8월 9일)
  /// -> 8월 8일(1일전), 8월 9일(당일)에 알림
  Future<void> scheduleExpirationAlerts({
    required String ingredientId,
    required String ingredientName,
    required DateTime expiryDate,
    required String refrigeratorName,
    required String compartmentName,
    AlertSettings? alertSettings,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // 기본 알림 설정 (오전 9시) + 사용자 설정 반영
    final settings = alertSettings ?? await loadUserAlertSettings();
    
    // 알림이 비활성화된 경우 종료
    if (!settings.enableNotifications) {
      return;
    }

    // 기존 알림 삭제
    await cancelAlertsForIngredient(ingredientId);

    final now = DateTime.now();
    final expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    
    print('🔔 유통기한 알림 스케줄링 시작:');
    print('   식품명: $ingredientName');
    print('   유통기한: ${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}');
    print('   현재시간: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour}:${now.minute}');
    print('   알림시간: ${settings.alertHour}:${settings.alertMinute.toString().padLeft(2, '0')}');
    print('   테스트모드: ${settings.isTestMode}');
    
    if (settings.isTestMode) {
      // 테스트 모드: 설정된 간격으로 알림
      final firstNotificationTime = now.add(Duration(minutes: settings.testIntervalMinutes));
      await _scheduleNotification(
        id: _getDayBeforeNotificationId(ingredientId),
        title: '테스트 알림 1',
        body: '$ingredientName - 첫 번째 알림 (${settings.testIntervalMinutes}분 후)',
        scheduledDate: firstNotificationTime,
        payload: 'test_alert_1:$ingredientId',
      );
      print('첫 번째 알림 스케줄: $ingredientName -> $firstNotificationTime');

      // 두 번째 알림: 간격의 2배 후  
      final secondNotificationTime = now.add(Duration(minutes: settings.testIntervalMinutes * 2));
      await _scheduleNotification(
        id: _getDayOfNotificationId(ingredientId),
        title: '테스트 알림 2',
        body: '$ingredientName - 두 번째 알림 (${settings.testIntervalMinutes * 2}분 후)',
        scheduledDate: secondNotificationTime,
        payload: 'test_alert_2:$ingredientId',
      );
      print('두 번째 알림 스케줄: $ingredientName -> $secondNotificationTime');
    } else {
      // 일반 모드: 유통기한 기반 알림
      // 1일 전 알림
      if (settings.enableDayBeforeAlert) {
        final dayBeforeDate = expiryDateOnly.subtract(Duration(days: 1));
        final scheduledDateTime = dayBeforeDate.add(
          Duration(hours: settings.alertHour, minutes: settings.alertMinute),
        );

        print('📅 1일 전 알림 체크:');
        print('   스케줄 시각: ${scheduledDateTime.year}-${scheduledDateTime.month.toString().padLeft(2, '0')}-${scheduledDateTime.day.toString().padLeft(2, '0')} ${scheduledDateTime.hour}:${scheduledDateTime.minute.toString().padLeft(2, '0')}');

        if (scheduledDateTime.isAfter(now)) {
          await _scheduleNotification(
            id: _getDayBeforeNotificationId(ingredientId),
            title: '유통기한 임박 알림',
            body: '$ingredientName이(가) 내일(${_formatDate(expiryDate)}) 만료됩니다.',
            scheduledDate: scheduledDateTime,
            payload: 'expiry_day_before:$ingredientId',
          );
          print('1일 전 알림 스케줄 완료: $ingredientName -> $scheduledDateTime');
        } else {
          print('❌ 1일 전 알림 스킵 (스케줄 시간이 이미 지남)');
        }
      } else {
        print('❌ 1일 전 알림 비활성화됨');
      }

      // 당일 알림
      if (settings.enableDayOfAlert) {
        final scheduledDateTime = expiryDateOnly.add(
          Duration(hours: settings.alertHour, minutes: settings.alertMinute),
        );

        print('📅 당일 알림 체크:');
        print('   스케줄 시각: ${scheduledDateTime.year}-${scheduledDateTime.month.toString().padLeft(2, '0')}-${scheduledDateTime.day.toString().padLeft(2, '0')} ${scheduledDateTime.hour}:${scheduledDateTime.minute.toString().padLeft(2, '0')}');

        if (scheduledDateTime.isAfter(now)) {
          await _scheduleNotification(
            id: _getDayOfNotificationId(ingredientId),
            title: '유통기한 만료 알림',
            body: '$ingredientName이(가) 오늘(${_formatDate(expiryDate)}) 만료됩니다!',
            scheduledDate: scheduledDateTime,
            payload: 'expiry_day_of:$ingredientId',
          );
          print('당일 알림 스케줄 완료: $ingredientName -> $scheduledDateTime');
        } else {
          print('❌ 당일 알림 스킵 (스케줄 시간이 이미 지남)');
        }
      } else {
        print('❌ 당일 알림 비활성화됨');
      }
    }
  }

  /// 개별 알림 스케줄링
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String payload,
  }) async {
    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'expiration_alert_channel',
            '유통기한 알림',
            channelDescription: '식품 유통기한 만료 알림',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            color: Colors.orange,
            enableVibration: true,
            enableLights: true,
            playSound: true,
            showWhen: true,
            when: null,
            fullScreenIntent: false, // fullScreenIntent를 false로 변경
            category: AndroidNotificationCategory.reminder, // alarm에서 reminder로 변경
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
            badgeNumber: 1,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // 백그라운드에서도 정확한 시간에 알림
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      print('알림 스케줄 성공: $title at $scheduledDate');
    } catch (e) {
      print('알림 스케줄 오류: $e');
      // 정확한 알람이 실패하면 일반 알림으로 대체
      try {
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(scheduledDate, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'expiration_alert_channel',
              '유통기한 알림',
              channelDescription: '식품 유통기한 만료 알림',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              color: Colors.orange,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
                     androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        print('대체 알림 스케줄 성공: $title');
      } catch (e2) {
        print('대체 알림 스케줄도 실패: $e2');
      }
    }
  }

  /// 특정 식품의 모든 알림 취소
  Future<void> cancelAlertsForIngredient(String ingredientId) async {
    await _flutterLocalNotificationsPlugin.cancel(_getDayBeforeNotificationId(ingredientId));
    await _flutterLocalNotificationsPlugin.cancel(_getDayOfNotificationId(ingredientId));
  }

  /// 모든 알림 취소
  Future<void> cancelAllAlerts() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// 테스트 알림 전부 취소
  Future<void> cancelTestNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(999991);
      await _flutterLocalNotificationsPlugin.cancel(999992);
      await _flutterLocalNotificationsPlugin.cancel(888888);
      // 과거에 남아있을 수 있는 페이로드 기반 탐색
      final pending = await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
      for (final p in pending) {
        final payload = p.payload ?? '';
        if (payload.startsWith('test_alert_') || payload.contains('test_ingredient_')) {
          await _flutterLocalNotificationsPlugin.cancel(p.id);
        }
      }
      print('테스트 알림 모두 취소됨');
    } catch (e) {
      print('테스트 알림 취소 오류: $e');
    }
  }

  /// 테스트용 즉시 알림 스케줄링 (3분 간격)
  Future<void> scheduleTestAlerts(String testIngredientName) async {
    if (!_isInitialized) {
      await initialize();
    }

    final now = DateTime.now();
    final testId = 'test_${DateTime.now().millisecondsSinceEpoch}';
    
    print('테스트 알림 스케줄링 시작: $testIngredientName');
    
    // 첫 번째 알림: 3분 후
    final firstNotificationTime = now.add(Duration(minutes: 3));
    await _scheduleNotification(
      id: 999991, // 고정 테스트 ID
      title: '🔔 테스트 알림 1',
      body: '$testIngredientName - 첫 번째 알림 (3분 후) ${firstNotificationTime.hour}:${firstNotificationTime.minute.toString().padLeft(2, '0')}',
      scheduledDate: firstNotificationTime,
      payload: 'test_alert_1:$testId',
    );
    
    // 두 번째 알림: 6분 후
    final secondNotificationTime = now.add(Duration(minutes: 6));
    await _scheduleNotification(
      id: 999992, // 고정 테스트 ID
      title: '🔔 테스트 알림 2',
      body: '$testIngredientName - 두 번째 알림 (6분 후) ${secondNotificationTime.hour}:${secondNotificationTime.minute.toString().padLeft(2, '0')}',
      scheduledDate: secondNotificationTime,
      payload: 'test_alert_2:$testId',
    );
    
    print('테스트 알림 스케줄 완료:');
    print('  - 첫 번째 알림: ${firstNotificationTime.hour}:${firstNotificationTime.minute.toString().padLeft(2, '0')}');
    print('  - 두 번째 알림: ${secondNotificationTime.hour}:${secondNotificationTime.minute.toString().padLeft(2, '0')}');
  }

  /// 즉시 테스트 알림 보내기
  Future<void> showImmediateTestNotification() async {
    if (!_isInitialized) {
      await initialize();
    }

    await _flutterLocalNotificationsPlugin.show(
      888888, // 즉시 알림용 고정 ID
      '🔔 즉시 테스트 알림',
      '푸시 알림이 정상적으로 작동합니다! 현재 시간: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'expiration_alert_channel',
          '유통기한 알림',
          channelDescription: '식품 유통기한 만료 알림',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          color: Colors.green,
          enableVibration: true,
          enableLights: true,
          playSound: true,
          showWhen: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.message,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
          badgeNumber: 1,
        ),
      ),
      payload: 'immediate_test',
    );
    
    print('즉시 테스트 알림 전송 완료');
  }

  /// 모든 필요한 권한 요청 (앱 시작 시 호출)
  Future<void> requestAllPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      print('🔔 알림 권한 요청을 시작합니다...');
      
      // 1. 기본 알림 권한
      try {
        final bool? result = await androidPlugin.requestNotificationsPermission();
        print('📱 기본 알림 권한: ${result == true ? "허용됨" : "거부됨"}');
      } catch (e) {
        print('❌ 기본 알림 권한 요청 실패: $e');
      }
      
      // 2. 정확한 알람 권한
      try {
        final bool? result = await androidPlugin.requestExactAlarmsPermission();
        print('⏰ 정확한 알람 권한: ${result == true ? "허용됨" : "거부됨"}');
      } catch (e) {
        print('❌ 정확한 알람 권한 요청 실패: $e');
      }
      
      // 3. 배터리 최적화 제외 안내
             print('🔋 배터리 최적화 제외는 설정에서 수동으로 설정해주세요');
     }
   }

  /// 현재 스케줄된 알림 목록 확인 (디버깅용)
  Future<void> checkScheduledNotifications() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      final List<PendingNotificationRequest> pendingNotifications = 
          await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
      
      print('현재 스케줄된 알림 개수: ${pendingNotifications.length}');
      
      for (var notification in pendingNotifications) {
        print('📅 알림 ID: ${notification.id}');
        print('   제목: ${notification.title}');
        print('   내용: ${notification.body}');
        print('   페이로드: ${notification.payload}');
        print('   ---');
      }
      
      if (pendingNotifications.isEmpty) {
        print('❌ 스케줄된 알림이 없습니다!');
      }
      
    } catch (e) {
      print('❌ 알림 목록 확인 오류: $e');
    }
  }

  /// 알림 ID 생성 (1일 전)
  int _getDayBeforeNotificationId(String ingredientId) {
    return ingredientId.hashCode % 1000000; // 6자리 숫자로 제한
  }

  /// 알림 ID 생성 (당일)
  int _getDayOfNotificationId(String ingredientId) {
    return (ingredientId.hashCode % 1000000) + 1000000; // 6자리 + 오프셋
  }

  /// 날짜 포맷팅
  String _formatDate(DateTime date) {
    return '${date.month}월 ${date.day}일';
  }

  /// 같은 날인지 확인
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// SharedPreferences에 저장된 사용자 알림 설정을 AlertSettings로 변환
  Future<AlertSettings> loadUserAlertSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final bool pushEnabled = prefs.getBool('push_notifications') ?? true;
      final bool expirationEnabled = prefs.getBool('expiration_alerts') ?? true;
      final String timeString = prefs.getString('notification_time') ?? '09:00';

      int alertHour = 9;
      int alertMinute = 0;
      final parts = timeString.split(':');
      if (parts.length == 2) {
        alertHour = int.tryParse(parts[0]) ?? 9;
        alertMinute = int.tryParse(parts[1]) ?? 0;
      }

      return AlertSettings(
        enableNotifications: pushEnabled && expirationEnabled,
        enableDayBeforeAlert: true,
        enableDayOfAlert: true,
        alertHour: alertHour,
        alertMinute: alertMinute,
        isTestMode: false,
      );
    } catch (e) {
      print('알림 설정 로드 오류, 기본값 사용: $e');
      return AlertSettings(
        enableNotifications: true,
        enableDayBeforeAlert: true,
        enableDayOfAlert: true,
        alertHour: 9,
        alertMinute: 0,
        isTestMode: false,
      );
    }
  }

  /// 사용자가 접근 가능한 모든 냉장고의 만료 예정 식품 알림 업데이트 (개선된 버전)
  Future<void> updateAllExpirationAlerts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ 로그인된 사용자가 없습니다');
      return;
    }

    try {
      print('모든 접근 가능한 식품 알림 갱신 시작...');
      
      int totalIngredientsFound = 0;

      // 1. 사용자가 소유하거나 멤버로 등록된 모든 냉장고 조회
      QuerySnapshot refrigeratorsSnapshot = await _firestore
          .collection('Refrigerators')
          .where('member_ids', arrayContains: user.uid)
          .get();

      print('사용자가 접근 가능한 냉장고: ${refrigeratorsSnapshot.docs.length}개');

      // 2. 각 냉장고의 모든 식품 처리
      for (final refrigeratorDoc in refrigeratorsSnapshot.docs) {
        final refrigeratorData = refrigeratorDoc.data() as Map<String, dynamic>;
        final refrigeratorName = refrigeratorData['name'] ?? '';
        final roomId = refrigeratorData['room_id'];
        
        print('🔧 냉장고 처리 중: $refrigeratorName (방 ID: $roomId)');

        // 냉장고의 칸 이름들 가져오기
        List<String> compartmentNames = List<String>.from(
          refrigeratorData['compartment_names'] ?? []
        );

        // 각 칸에서 재료 가져오기
        for (int compartmentIndex = 0; compartmentIndex < compartmentNames.length; compartmentIndex++) {
          String compartmentName = compartmentNames[compartmentIndex];
          
          final ingredientsSnapshot = await refrigeratorDoc.reference
              .collection('compartments')
              .doc(compartmentIndex.toString())
              .collection('ingredients')
              .get();

          for (final ingredientDoc in ingredientsSnapshot.docs) {
            final ingredientData = ingredientDoc.data() as Map<String, dynamic>;
            final expiryTimestamp = ingredientData['expiryDate'] as Timestamp?;
            
            if (expiryTimestamp != null) {
              totalIngredientsFound++;
              final ingredientName = ingredientData['name'] ?? '';
              final expiryDate = expiryTimestamp.toDate();
              
              print('🥬 식품 발견: $ingredientName (유통기한: ${expiryDate.toString().split(' ')[0]})');
              
              await scheduleExpirationAlerts(
                ingredientId: ingredientDoc.id,
                ingredientName: ingredientName,
                expiryDate: expiryDate,
                refrigeratorName: refrigeratorName,
                compartmentName: compartmentName,
                // 사용자 알림 설정(시간/ON-OFF)을 반영해서 스케줄링
                alertSettings: await loadUserAlertSettings(),
              );
            }
          }
        }
      }

      // 3. 추가로 사용자가 속한 방들의 냉장고도 확인 (혹시 누락된 것이 있을 경우)
      QuerySnapshot roomUserSnapshot = await _firestore
          .collection('RoomUser')
          .where('user_id', isEqualTo: user.uid)
          .get();

      for (DocumentSnapshot roomUserDoc in roomUserSnapshot.docs) {
        String roomId = roomUserDoc['room_id'];
        
        // 방의 냉장고 중 위에서 처리되지 않은 것이 있는지 확인
        QuerySnapshot roomRefrigeratorsSnapshot = await _firestore
            .collection('Refrigerators')
            .where('room_id', isEqualTo: roomId)
            .get();

        for (final refrigeratorDoc in roomRefrigeratorsSnapshot.docs) {
          final refrigeratorData = refrigeratorDoc.data() as Map<String, dynamic>;
          final memberIds = List<String>.from(refrigeratorData['member_ids'] ?? []);
          
          // 사용자가 member_ids에 없지만 방 멤버인 경우 (동기화 누락)
          if (!memberIds.contains(user.uid)) {
            print('동기화 누락 발견: 냉장고 ${refrigeratorData['name']}에 사용자 추가 필요');
            
            // 즉시 동기화 수행
            memberIds.add(user.uid);
            await refrigeratorDoc.reference.update({
              'member_ids': memberIds,
            });
            
            print('냉장고 멤버 동기화 완료');
          }
        }
      }

      print('모든 유통기한 알림 업데이트 완료!');
      print('   처리된 식품 수: $totalIngredientsFound');
      print('   접근 가능한 냉장고: ${refrigeratorsSnapshot.docs.length}개');
    } catch (e) {
      print('❌ 알림 업데이트 오류: $e');
      rethrow;
    }
  }

  // Daily refresh scheduling removed due to workmanager incompatibility
  // Use OS alarms via flutter_local_notifications instead.

  /// 다음 8시 50분까지의 시간 계산
  Duration _calculateInitialDelay() {
    final now = DateTime.now();
    var nextExecution = DateTime(now.year, now.month, now.day, 8, 50);
    if (nextExecution.isBefore(now)) {
      nextExecution = nextExecution.add(Duration(days: 1));
    }
    return nextExecution.difference(now);
  }

  Future<void> cancelDailyNotificationRefresh() async {
    // no-op
    }
 
  /// 즉시 간단한 로컬 알림 표시 (FCM 포그라운드 수신용)
  Future<void> showLocalNotification({required String title, required String body}) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'expiration_alerts_channel',
        'Expiration Alerts',
        channelDescription: '유통기한 및 공지 알림',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
      );
      const NotificationDetails details = NotificationDetails(android: androidDetails);
      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(1000000),
        title,
        body,
        details,
      );
    } catch (e) {
      print('로컬 알림 표시 오류: $e');
    }
  }
 
 }

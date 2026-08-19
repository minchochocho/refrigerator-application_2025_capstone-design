import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/icon_utils.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 현재 사용자 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // 현재 로그인한 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 이메일/비밀번호 로그인
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    try {
      print('이메일 로그인 시도: $email');
      // 로그인 시도
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      print('이메일 로그인 성공: ${credential.user?.email}');
      if (credential.user != null) {
        await _saveFcmToken(credential.user!.uid);
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      print('Firebase 인증 오류: ${e.code} - ${e.message}');
      throw e;
    } catch (e) {
      print('일반 로그인 오류: $e');
      rethrow;
    }
  }

  // 이메일/비밀번호 회원가입
  Future<UserCredential?> signUpWithEmailPassword(String email, String password) async {
    try {
      // 회원가입 시도
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      
      // 사용자 정보 저장 (닉네임은 이메일에서 추출)
      await _createUserProfile(credential.user!, email.split('@')[0]);
      
      if (credential.user != null) {
        await _saveFcmToken(credential.user!.uid);
      }
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _saveFcmToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _firestore.collection('Users').doc(uid).set({
          'fcmToken': token,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('FCM 토큰 저장 완료');
      } else {
        print('FCM 토큰을 가져올 수 없습니다');
      }
    } catch (e) {
      print('FCM 토큰 저장 오류: $e');
    }
  }

  // 구글 로그인
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 이전에 연결된 구글 계정을 해제하여 계정 선택 창을 강제로 띄움
      await _googleSignIn.signOut();
      // 구글 로그인 대화상자 표시
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // 사용자가 구글 로그인을 취소한 경우
        print('Google 로그인 취소됨');
        return null;
      }

      try {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // 구글 계정으로 Firebase 로그인
        UserCredential userCredential = await _auth.signInWithCredential(credential);
        
        // 사용자 정보 확인 및 저장 (첫 로그인인 경우만)
        if (userCredential.additionalUserInfo?.isNewUser ?? false) {
          await _createUserProfile(userCredential.user!, googleUser.displayName ?? googleUser.email.split('@')[0]);
        }
        
        if (userCredential.user != null) {
          await _saveFcmToken(userCredential.user!.uid);
        }
        return userCredential;
      } catch (e) {
        print('Google 인증 오류: $e');
        rethrow;
      }
    } catch (e) {
      print('Google 로그인 오류: $e');
      rethrow;
    }
  }

  // 익명 로그인
  Future<UserCredential?> signInAnonymously() async {
    try {
      // 익명 로그인 시도
      UserCredential credential = await _auth.signInAnonymously();
      
      // 익명 사용자 정보 저장
      await _createUserProfile(credential.user!, "게스트_${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}");
      
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // 비회원 계정 → 소셜(구글)로 연결하여 회원 전환
  Future<UserCredential?> linkAnonymousWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user', message: '로그인된 사용자가 없습니다');
    if (!user.isAnonymous) throw FirebaseAuthException(code: 'not-anonymous', message: '이미 회원 계정입니다');

    try {
      // 익명 사용자 데이터 백업 (기본 프로필만)
      final String oldUid = user.uid;
      Map<String, dynamic>? oldUserData;
      try {
        final snap = await _firestore.collection('Users').doc(oldUid).get();
        if (snap.exists) oldUserData = Map<String, dynamic>.from(snap.data() as Map);
      } catch (_) {}

      // 계정 선택 유도
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // 사용자가 취소
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 현재(익명) 유저에 크리덴셜 연결 시도
      try {
        final UserCredential linked = await user.linkWithCredential(credential);
        await _postLinkUpdate(
          linked.user!,
          email: linked.user!.email,
          defaultNickname: googleUser.displayName ?? googleUser.email.split('@')[0],
        );
        return linked;
      } on FirebaseAuthException catch (e) {
        // 이미 가입된 계정인 경우 전환을 막고 그대로 오류를 전달
        if (e.code == 'credential-already-in-use' || e.code == 'account-exists-with-different-credential' || e.code == 'provider-already-linked') {
          throw e;
        }
        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // 비회원 계정 → 이메일/비밀번호로 연결하여 회원 전환
  Future<UserCredential?> linkAnonymousWithEmailPassword(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user', message: '로그인된 사용자가 없습니다');
    if (!user.isAnonymous) throw FirebaseAuthException(code: 'not-anonymous', message: '이미 회원 계정입니다');

    try {
      final String oldUid = user.uid;
      Map<String, dynamic>? oldUserData;
      try {
        final snap = await _firestore.collection('Users').doc(oldUid).get();
        if (snap.exists) oldUserData = Map<String, dynamic>.from(snap.data() as Map);
      } catch (_) {}

      final AuthCredential credential = EmailAuthProvider.credential(email: email.trim(), password: password.trim());
      try {
        final UserCredential linked = await user.linkWithCredential(credential);
        await _postLinkUpdate(linked.user!, email: email.trim(), defaultNickname: email.split('@')[0]);
        return linked;
      } on FirebaseAuthException catch (e) {
        // 이미 사용 중인 이메일이면 전환 불가
        if (e.code == 'email-already-in-use') {
          throw e;
        }
        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // 링크 성공 후 Firestore/FCM 정리
  Future<void> _postLinkUpdate(User user, {String? email, String? defaultNickname}) async {
    try {
      final userRef = _firestore.collection('Users').doc(user.uid);
      final snap = await userRef.get();

      if (!snap.exists) {
        // 익명 로그인 시점에 생성되지 않았다면 생성
        await _createUserProfile(user, defaultNickname ?? (user.displayName ?? (user.email?.split('@')[0] ?? '사용자')));
      }

      // 익명 플래그 해제 및 이메일 저장
      await userRef.set({
        'email': email ?? user.email,
        'is_anonymous': false,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _saveFcmToken(user.uid);
    } catch (e) {
      // 로깅만 수행
      debugPrint('회원 전환 후 프로필 업데이트 실패: $e');
    }
  }

  // 최소한의 프로필 병합 (닉네임/아바타 등) - 보안 규칙 제약으로 읽어온 데이터를 현재 사용자 문서에 병합
  Future<void> _mergeOldUserDataIntoCurrent({required String oldUid, Map<String, dynamic>? oldUserData}) async {
    try {
      final current = _auth.currentUser;
      if (current == null) return;

      final toWrite = <String, dynamic>{
        'is_anonymous': false,
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (oldUserData != null) {
        if (oldUserData['nickname'] != null) toWrite['nickname'] = oldUserData['nickname'];
        if (oldUserData['avatarColor'] != null) toWrite['avatarColor'] = oldUserData['avatarColor'];
        if (oldUserData['avatarIcon'] != null) toWrite['avatarIcon'] = oldUserData['avatarIcon'];
        if (oldUserData['profile_image'] != null) toWrite['profile_image'] = oldUserData['profile_image'];
      }

      await _firestore.collection('Users').doc(current.uid).set(toWrite, SetOptions(merge: true));
      await _saveFcmToken(current.uid);
    } catch (e) {
      debugPrint('프로필 병합 실패(old:$oldUid -> new:${_auth.currentUser?.uid}): $e');
    }
  }

  // 사용자 정보 저장
  Future<void> _createUserProfile(User user, String defaultNickname) async {
    try {
      // 사용자 문서 생성
      await _firestore.collection('Users').doc(user.uid).set({
        'email': user.email,
        'nickname': defaultNickname,
        'profile_image': null, // 기본값은 null
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'is_anonymous': user.isAnonymous,
      });
    } catch (e) {
      print('사용자 정보 저장 오류: $e');
    }
  }
  
  // 사용자 닉네임 가져오기
  Future<String?> getUserNickname() async {
    if (_auth.currentUser == null) return null;
    
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('Users')
          .doc(_auth.currentUser!.uid)
          .get();
      
      if (userDoc.exists) {
        return (userDoc.data() as Map<String, dynamic>)['nickname'];
      }
      
      return _auth.currentUser!.displayName ?? 
             _auth.currentUser!.email?.split('@')[0] ?? 
             '사용자';
    } catch (e) {
      print('닉네임 조회 오류: $e');
      return null;
    }
  }
  
  // 사용자 프로필 이미지 URL 가져오기
  Future<String?> getUserProfileImageUrl() async {
    if (_auth.currentUser == null) return null;
    
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('Users')
          .doc(_auth.currentUser!.uid)
          .get();
      
      if (userDoc.exists) {
        return (userDoc.data() as Map<String, dynamic>)['profile_image'] as String?;
      }
      
      return null;
    } catch (e) {
      print('프로필 이미지 조회 오류: $e');
      return null;
    }
  }
  
  // 사용자 닉네임 업데이트
  Future<bool> updateUserNickname(String nickname) async {
    if (_auth.currentUser == null) {
      print('닉네임 업데이트 실패: 로그인되지 않음');
      return false;
    }
    
    try {
      final userId = _auth.currentUser!.uid;
      print('닉네임 저장 시작 - userId: $userId, nickname: $nickname');
      
      // 먼저 사용자 문서가 존재하는지 확인
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      
      if (!userDoc.exists) {
        // 문서가 존재하지 않으면 새로 생성
        print('사용자 문서가 없어서 새로 생성');
        await _createUserProfile(_auth.currentUser!, nickname);
        return true;
      }
      
      // 문서가 존재하면 닉네임만 업데이트
      await _firestore.collection('Users').doc(userId).update({
        'nickname': nickname,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      print('✅ 닉네임 Firestore 저장 완료!');
      
      // 저장 확인을 위해 바로 다시 읽기
      final doc = await _firestore.collection('Users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        print('✅ 저장 확인 - nickname: ${data['nickname']}');
      }
      
      return true;
    } catch (e) {
      // 자세한 오류 로깅
      print('❌ 닉네임 업데이트 오류: $e');
      
      // 오류가 발생했을 때 다시 한번 문서 생성 시도
      try {
        await _createUserProfile(_auth.currentUser!, nickname);
        print('문서 생성 방식으로 닉네임 저장 시도');
        return true;
      } catch (retryError) {
        print('❌ 문서 생성 재시도 오류: $retryError');
        return false;
      }
    }
  }

  // 프로필 이미지 업로드 및 URL 업데이트
  Future<bool> updateProfileImage(File imageFile) async {
    if (_auth.currentUser == null) return false;
    
    try {
      // 스토리지에 이미지 업로드
      final storageRef = _storage.ref().child('profile_images/${_auth.currentUser!.uid}');
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask;
      
      // 업로드된 이미지의 URL 가져오기
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Firestore 사용자 문서 업데이트
      await _firestore.collection('Users').doc(_auth.currentUser!.uid).update({
        'profile_image': downloadUrl,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      print('프로필 이미지 업데이트 성공: $downloadUrl');
      return true;
    } catch (e) {
      print('프로필 이미지 업데이트 오류: $e');
      return false;
    }
  }
  
  // 기본 아바타 프로필 이미지 설정
  Future<bool> setDefaultAvatar(String avatarAssetName) async {
    if (_auth.currentUser == null) return false;
    
    try {
      // 기본 아바타 이름으로 URL 설정 (assets 폴더 내 경로)
      final avatarUrl = 'assets/avatars/$avatarAssetName';
      
      // Firestore 사용자 문서 업데이트
      await _firestore.collection('Users').doc(_auth.currentUser!.uid).update({
        'profile_image': avatarUrl,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      print('기본 아바타 설정 성공: $avatarUrl');
      return true;
    } catch (e) {
      print('기본 아바타 설정 오류: $e');
      return false;
    }
  }

  // 컬러 아바타 설정 (새로운 아바타 시스템)
  Future<bool> setColorAvatar(Color avatarColor, IconData avatarIcon) async {
    if (_auth.currentUser == null) {
      print('컬러 아바타 설정 실패: 로그인되지 않음');
      return false;
    }
    
    try {
      final userId = _auth.currentUser!.uid;
      print('컬러 아바타 저장 시작 - userId: $userId, color: ${avatarColor.value}, icon: ${avatarIcon.codePoint}');
      
      // Firestore 사용자 문서 업데이트
      await _firestore.collection('Users').doc(userId).update({
        'avatarColor': avatarColor.value,
        'avatarIcon': avatarIcon.codePoint,
        'profile_image': null, // 컬러 아바타 사용 시 기존 이미지는 null로 설정
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      print('✅ 컬러 아바타 Firestore 저장 완료!');
      
      // 저장 확인을 위해 바로 다시 읽기
      final doc = await _firestore.collection('Users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        print('✅ 저장 확인 - avatarColor: ${data['avatarColor']}, avatarIcon: ${data['avatarIcon']}');
      }
      
      return true;
    } catch (e) {
      print('❌ 컬러 아바타 설정 오류: $e');
      return false;
    }
  }

  // 아바타 색상 가져오기
  Future<Color?> getAvatarColor() async {
    if (_auth.currentUser == null) return null;
    
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('Users')
          .doc(_auth.currentUser!.uid)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final colorValue = data['avatarColor'] as int?;
        print('아바타 색상 조회: $colorValue');
        if (colorValue != null) {
          return Color(colorValue);
        }
      }
      
      print('아바타 색상 데이터 없음 - 기본값 사용');
      return null;
    } catch (e) {
      print('아바타 색상 조회 오류: $e');
      return null;
    }
  }

  // 아바타 아이콘 가져오기
  Future<IconData?> getAvatarIcon() async {
    if (_auth.currentUser == null) return null;
    
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('Users')
          .doc(_auth.currentUser!.uid)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final iconCodePoint = data['avatarIcon'] as int?;
        print('아바타 아이콘 조회: $iconCodePoint');
        if (iconCodePoint != null) {
          return IconUtils.getIconFromCodePoint(iconCodePoint);
        }
      }
      
      print('아바타 아이콘 데이터 없음 - 기본값 사용');
      return null;
    } catch (e) {
      print('아바타 아이콘 조회 오류: $e');
      return null;
    }
  }

  // 특정 사용자 정보 가져오기 (다른 사용자용)
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('Users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return {
          'nickname': data['nickname'] ?? '사용자',
          'profile_image': data['profile_image'],
          'avatarColor': data['avatarColor'],
          'avatarIcon': data['avatarIcon'],
        };
      }
      
      return null;
    } catch (e) {
      print('사용자 정보 조회 오류: $e');
      return null;
    }
  }

  // 에러 메시지 처리
  String? getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return '해당 이메일로 가입된 계정이 없습니다';
      case 'wrong-password':
        return '비밀번호가 일치하지 않습니다';
      case 'invalid-email':
        return '유효하지 않은 이메일 형식입니다';
      case 'user-disabled':
        return '비활성화된 계정입니다';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다';
      case 'weak-password':
        return '보안에 취약한 비밀번호입니다. 다른 비밀번호를 사용해주세요';
      case 'account-exists-with-different-credential':
        return '이미 다른 방식으로 가입된 이메일입니다';
      case 'credential-already-in-use':
        return '이미 가입된 계정입니다';
      case 'provider-already-linked':
        return '이 제공자는 이미 연결되어 있습니다';
      case 'requires-recent-login':
        return '보안을 위해 다시 로그인 후 시도해주세요';
      case 'network-request-failed':
        return '네트워크 오류가 발생했습니다. 연결을 확인해주세요';
      case 'invalid-credential':
        return '인증 정보가 유효하지 않습니다';
      case 'operation-not-allowed':
        return '익명 로그인이 비활성화되어 있습니다';
      default:
        return null;
    }
  }
}
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class LoginOptionsBottomSheet extends StatelessWidget {
  final Function onGoogleLoginPressed;
  final Function onEmailLoginPressed;
  final Function onFindAccountPressed;

  const LoginOptionsBottomSheet({
    Key? key,
    required this.onGoogleLoginPressed,
    required this.onEmailLoginPressed,
    required this.onFindAccountPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // 내부 클릭이 배경 탭으로 전파되지 않도록
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              '로그인 방법 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            
            // 구글 로그인 버튼
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                onGoogleLoginPressed();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 2.0),
                      child: Image.asset(
                        'assets/images/google_logo.png',
                        width: 24,
                        height: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '구글로 로그인',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // 이메일 로그인 버튼
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onEmailLoginPressed();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 2.0),
                      child: Icon(
                        Icons.email_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '이메일로 로그인',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            
            // 계정 찾기 링크
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onFindAccountPressed();
                },
                child: Text(
                  '계정이 가입되지 않나요? 계정 찾기',
                  style: TextStyle(
                    color: Colors.black45,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// 익명 로그인 다이얼로그
class AnonymousLoginDialog extends StatelessWidget {
  final Function onContinuePressed;

  const AnonymousLoginDialog({
    Key? key,
    required this.onContinuePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 28,
          ),
          SizedBox(width: 10),
          Text('비회원 로그인 안내'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '비회원으로 로그인 시 개인 냉장고 서비스만 이용할 수 있습니다.',
            style: TextStyle(fontSize: 15),
          ),
          SizedBox(height: 8),
          Text(
            '다른 서비스를 이용하시려면 회원 가입 후 이용해 주세요.',
            style: TextStyle(fontSize: 15),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            '취소',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onContinuePressed();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text('계속하기'),
        ),
      ],
    );
  }
} 
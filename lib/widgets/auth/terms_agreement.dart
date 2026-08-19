import 'package:flutter/material.dart';

class TermsAgreementBottomSheet extends StatefulWidget {
  final Function(bool termsAccepted, bool privacyAccepted, bool marketingAccepted) onContinuePressed;

  const TermsAgreementBottomSheet({
    Key? key,
    required this.onContinuePressed,
  }) : super(key: key);

  @override
  _TermsAgreementBottomSheetState createState() => _TermsAgreementBottomSheetState();
}

class _TermsAgreementBottomSheetState extends State<TermsAgreementBottomSheet> {
  // 약관 동의 관련 변수
  bool _agreeTermsOfService = false;
  bool _agreePrivacyPolicy = false;
  bool _agreeMarketingInfo = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // 상단 핸들바
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(top: 16, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 제목
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              '약관 동의',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // 약관 내용이 스크롤 가능하도록 Expanded 안에 배치
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 전체 동의 옵션
                  CheckboxListTile(
                    title: Text(
                      '전체 동의',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      '선택 항목에 대한 동의를 포함합니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    value: _agreeTermsOfService && _agreePrivacyPolicy && _agreeMarketingInfo,
                    onChanged: (bool? value) {
                      setState(() {
                        _agreeTermsOfService = value ?? false;
                        _agreePrivacyPolicy = value ?? false;
                        _agreeMarketingInfo = value ?? false;
                      });
                    },
                    activeColor: Colors.black,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  
                  Divider(height: 30),
                  
                  // 필수 약관 제목
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      '필수 약관',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  
                  // 서비스 이용약관 동의
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: _agreeTermsOfService,
                      onChanged: (bool? value) {
                        setState(() {
                          _agreeTermsOfService = value ?? false;
                        });
                      },
                      activeColor: Colors.black,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '서비스 이용약관 동의',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          '[필수]',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _showTermsDialog(context, '서비스 이용약관', '서비스 이용약관 내용...');
                          },
                          child: Text(
                            '보기',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            minimumSize: Size(10, 10),
                            padding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 개인정보 수집 및 이용 동의
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: _agreePrivacyPolicy,
                      onChanged: (bool? value) {
                        setState(() {
                          _agreePrivacyPolicy = value ?? false;
                        });
                      },
                      activeColor: Colors.black,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '개인정보 수집 및 이용 동의',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          '[필수]',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _showTermsDialog(context, '개인정보 수집 및 이용', '개인정보 수집 및 이용 내용...');
                          },
                          child: Text(
                            '보기',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            minimumSize: Size(10, 10),
                            padding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 필수 약관과 선택 약관 사이 구분선 추가
                  SizedBox(height: 16),
                  Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                  SizedBox(height: 16),
                  
                  // 선택 약관 제목
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      '선택 약관',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  
                  // 마케팅 정보 수신 동의
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: _agreeMarketingInfo,
                      onChanged: (bool? value) {
                        setState(() {
                          _agreeMarketingInfo = value ?? false;
                        });
                      },
                      activeColor: Colors.black,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '마케팅 정보 수신 동의',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          '[선택]',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 하단 버튼
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton(
              onPressed: () {
                // 필수 약관에 모두 동의한 경우에만 회원가입 진행
                if (_agreeTermsOfService && _agreePrivacyPolicy) {
                  Navigator.pop(context);
                  widget.onContinuePressed(
                    _agreeTermsOfService,
                    _agreePrivacyPolicy,
                    _agreeMarketingInfo
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('필수 약관에 모두 동의해주세요')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '동의하고 계속하기',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 약관 상세 보기 다이얼로그
  void _showTermsDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('닫기'),
            ),
          ],
        );
      },
    );
  }
} 
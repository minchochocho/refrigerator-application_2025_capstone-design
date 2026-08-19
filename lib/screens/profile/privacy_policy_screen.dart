import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '개인정보처리방침',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIntro(),
            
            const SizedBox(height: 16),
            
            _buildSection(
              title: '1. 개인정보의 수집 및 이용 목적',
              content: '''냉가드(이하 "회사")는 다음의 목적을 위하여 개인정보를 처리합니다:

• 회원 가입 및 관리
  - 회원 식별, 본인 확인, 부정 이용 방지

• 서비스 제공
  - 식품 관리, 유통기한 알림, 통계 제공
  - 그룹 냉장고 공유 및 협업 기능
  - 출석체크 및 리워드 제공

• 서비스 개선 및 개발
  - 신규 서비스 개발
  - 이용 통계 분석 및 서비스 품질 향상''',
            ),
            
            _buildSection(
              title: '2. 수집하는 개인정보 항목',
              content: '''• 필수 수집 항목:
  - 이메일 주소
  - 비밀번호 (암호화 저장)
  - 닉네임

• 선택 수집 항목:
  - 프로필 아바타 정보
  - 식품 사진 (사용자가 업로드한 경우)
  - 영수증 이미지 (영수증 스캔 사용 시)

• 자동 수집 항목:
  - 기기 정보 (기기 고유번호)
  - 접속 로그, 쿠키
  - 서비스 이용 기록''',
            ),
            
            _buildSection(
              title: '3. 개인정보의 보유 및 이용 기간',
              content: '''• 회원 탈퇴 시까지: 서비스 이용 기간 동안 보유

• 관계 법령에 따른 보존:
  - 계약 또는 청약철회 등에 관한 기록: 5년
  - 대금결제 및 재화 등의 공급에 관한 기록: 5년
  - 소비자의 불만 또는 분쟁처리에 관한 기록: 3년
  - 접속에 관한 기록: 3개월

• 회원 탈퇴 후에는 지체없이 파기하며, 관계 법령에 따라 보존이 필요한 경우 별도로 보관합니다.''',
            ),
            
            _buildSection(
              title: '4. 개인정보의 제3자 제공',
              content: '''회사는 원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다. 다만, 다음의 경우에는 예외로 합니다:

• 이용자가 사전에 동의한 경우
• 법령의 규정에 의거하거나, 수사 목적으로 법령에 정해진 절차와 방법에 따라 수사기관의 요구가 있는 경우

현재 회사는 제3자에게 개인정보를 제공하고 있지 않습니다.''',
            ),
            
            _buildSection(
              title: '5. 개인정보 처리의 위탁',
              content: '''회사는 서비스 향상을 위해 개인정보 처리 업무를 외부 전문업체에 위탁할 수 있습니다:

• Firebase (Google Cloud Platform)
  - 위탁 내용: 사용자 인증, 데이터베이스 관리, 푸시 알림
  - 개인정보 보유 및 이용기간: 회원 탈퇴 시 또는 위탁계약 종료 시까지

위탁 업무의 내용이나 수탁자가 변경될 경우에는 지체없이 본 개인정보 처리방침을 통하여 공개하겠습니다.''',
            ),
            
            _buildSection(
              title: '6. 개인정보의 파기',
              content: '''회사는 개인정보 보유기간의 경과, 처리목적 달성 등 개인정보가 불필요하게 되었을 때에는 지체없이 해당 개인정보를 파기합니다.

• 파기 절차:
  - 불필요한 개인정보는 개인정보 보호책임자의 승인 하에 파기

• 파기 방법:
  - 전자적 파일: 복구 및 재생이 불가능한 방법으로 영구 삭제
  - 종이 문서: 분쇄기로 분쇄하거나 소각''',
            ),
            
            _buildSection(
              title: '7. 이용자의 권리와 행사 방법',
              content: '''이용자는 언제든지 다음과 같은 권리를 행사할 수 있습니다:

• 개인정보 열람 요구
• 개인정보 오류 등이 있을 경우 정정 요구
• 개인정보 삭제 요구
• 개인정보 처리 정지 요구

권리 행사는 앱 내 설정 메뉴 또는 이메일(support@naengard.com)을 통해 하실 수 있으며, 회사는 지체 없이 조치하겠습니다.''',
            ),
            
            _buildSection(
              title: '8. 개인정보 보호책임자',
              content: '''회사는 개인정보 처리에 관한 업무를 총괄해서 책임지고, 개인정보 처리와 관련한 정보주체의 불만처리 및 피해구제를 위하여 아래와 같이 개인정보 보호책임자를 지정하고 있습니다.

• 개인정보 보호책임자
  - 이메일: support@naengard.com
  - 문의: 앱 내 문의하기 기능 이용

• 개인정보 침해 신고 및 상담
  - 개인정보 침해신고센터: privacy.kisa.or.kr (국번없이 118)
  - 대검찰청 사이버범죄수사단: www.spo.go.kr (국번없이 1301)
  - 경찰청 사이버안전국: cyberbureau.police.go.kr (국번없이 182)''',
            ),
            
            _buildSection(
              title: '9. 개인정보의 안전성 확보 조치',
              content: '''회사는 개인정보의 안전성 확보를 위해 다음과 같은 조치를 취하고 있습니다:

• 관리적 조치:
  - 내부관리계획 수립 및 시행
  - 정기적인 직원 교육

• 기술적 조치:
  - 개인정보의 암호화 (비밀번호 등)
  - 해킹 등에 대비한 보안 시스템 구축
  - 접속기록의 보관 및 위변조 방지

• 물리적 조치:
  - 서버실 등의 출입 통제''',
            ),
            
            _buildSection(
              title: '10. 개인정보 처리방침의 변경',
              content: '''이 개인정보 처리방침은 시행일로부터 적용되며, 법령 및 방침에 따른 변경내용의 추가, 삭제 및 정정이 있는 경우에는 변경사항의 시행 7일 전부터 공지사항을 통하여 고지할 것입니다.''',
            ),
            
            const SizedBox(height: 20),
            
            Divider(color: Colors.grey[300]),
            
            const SizedBox(height: 20),
            
            Text(
              '공고 일자: 2024년 1월 1일\n시행 일자: 2024년 1월 1일',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6B9FFF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6B9FFF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF6B9FFF),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '개인정보처리방침',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B9FFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '냉가드는 이용자의 개인정보를 중요시하며, "개인정보 보호법" 및 관련 법령을 준수하고 있습니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}


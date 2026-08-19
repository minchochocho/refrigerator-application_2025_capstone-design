import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({Key? key}) : super(key: key);

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
          '이용약관',
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
            _buildSection(
              title: '제1조 (목적)',
              content: '본 약관은 냉가드(이하 "서비스")가 제공하는 모든 서비스의 이용과 관련하여 회사와 이용자의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.',
            ),
            
            _buildSection(
              title: '제2조 (정의)',
              content: '''1. "서비스"란 냉가드가 제공하는 냉장고 식품 관리 및 관련 부가 서비스를 의미합니다.
2. "이용자"란 본 약관에 따라 회사가 제공하는 서비스를 이용하는 회원 및 비회원을 말합니다.
3. "회원"이란 서비스에 접속하여 본 약관에 동의하고 회원등록을 한 자를 말합니다.''',
            ),
            
            _buildSection(
              title: '제3조 (약관의 효력 및 변경)',
              content: '''1. 본 약관은 서비스를 이용하고자 하는 모든 이용자에게 그 효력이 발생합니다.
2. 회사는 필요한 경우 관련 법령을 위배하지 않는 범위 내에서 본 약관을 변경할 수 있습니다.
3. 변경된 약관은 서비스 내 공지사항을 통해 공지되며, 공지 후 7일이 경과한 시점부터 효력이 발생합니다.''',
            ),
            
            _buildSection(
              title: '제4조 (서비스의 제공)',
              content: '''1. 회사는 다음과 같은 서비스를 제공합니다:
   - 냉장고 식품 등록 및 관리
   - 유통기한 알림 서비스
   - 식품 소비/폐기 통계 제공
   - 그룹 냉장고 공유 기능
   - 영수증 스캔 및 바코드 인식 기능
   - 출석체크 및 리워드 시스템

2. 서비스는 연중무휴 1일 24시간 제공함을 원칙으로 합니다.
3. 회사는 시스템 점검, 서버 증설 등의 사유로 서비스 제공을 일시적으로 중단할 수 있습니다.''',
            ),
            
            _buildSection(
              title: '제5조 (회원가입)',
              content: '''1. 회원가입은 이용자가 약관의 내용에 동의하고 회원가입 신청을 한 후 회사가 이를 승낙함으로써 체결됩니다.
2. 회원가입 시 제공하는 정보는 정확하고 최신의 정보여야 합니다.
3. 회사는 다음 각 호에 해당하는 경우 회원가입을 거부할 수 있습니다:
   - 이전에 회원자격을 상실한 적이 있는 경우
   - 실명이 아니거나 타인의 정보를 도용한 경우
   - 허위 정보를 기재한 경우''',
            ),
            
            _buildSection(
              title: '제6조 (개인정보 보호)',
              content: '''1. 회사는 관련 법령이 정하는 바에 따라 이용자의 개인정보를 보호하기 위해 노력합니다.
2. 개인정보의 보호 및 이용에 대해서는 관련 법령 및 회사의 개인정보처리방침이 적용됩니다.
3. 회사는 이용자의 귀책사유로 인해 노출된 정보에 대해서는 책임을 지지 않습니다.''',
            ),
            
            _buildSection(
              title: '제7조 (이용자의 의무)',
              content: '''1. 이용자는 다음 행위를 하여서는 안 됩니다:
   - 타인의 정보 도용
   - 회사가 게시한 정보의 변경
   - 회사와 기타 제3자의 저작권 등 지적재산권 침해
   - 타인의 명예를 손상시키거나 불이익을 주는 행위
   - 음란물이나 불법적인 내용을 게재하는 행위
   - 서비스의 안전한 운영을 방해하는 행위

2. 이용자는 관계 법령, 본 약관, 이용안내 등을 준수하여야 합니다.''',
            ),
            
            _buildSection(
              title: '제8조 (서비스 이용의 제한)',
              content: '''1. 회사는 이용자가 본 약관의 의무를 위반하거나 서비스의 정상적인 운영을 방해한 경우, 경고, 일시정지, 영구이용정지 등으로 서비스 이용을 단계적으로 제한할 수 있습니다.
2. 회사는 관계법령 위반, 명의도용 등의 경우에는 즉시 영구이용정지를 할 수 있습니다.''',
            ),
            
            _buildSection(
              title: '제9조 (책임의 제한)',
              content: '''1. 회사는 천재지변, 전쟁, 기간통신사업자의 서비스 중지 등 불가항력적인 사유로 서비스를 제공할 수 없는 경우에는 책임이 면제됩니다.
2. 회사는 이용자의 귀책사유로 인한 서비스 이용의 장애에 대하여는 책임을 지지 않습니다.
3. 회사는 이용자가 서비스를 이용하여 기대하는 효과나 서비스에 대한 해석 또는 이용으로 얻은 자료에 대한 정확성, 신뢰도에 관하여 책임을 지지 않습니다.''',
            ),
            
            _buildSection(
              title: '제10조 (분쟁 해결)',
              content: '''1. 회사와 이용자는 서비스와 관련하여 발생한 분쟁을 원만하게 해결하기 위하여 필요한 모든 노력을 하여야 합니다.
2. 본 약관에 명시되지 않은 사항은 관계 법령 및 상관례에 따릅니다.
3. 서비스 이용으로 발생한 분쟁에 대해 소송이 제기되는 경우 회사의 본사 소재지를 관할하는 법원을 관할 법원으로 합니다.''',
            ),
            
            const SizedBox(height: 20),
            
            Divider(color: Colors.grey[300]),
            
            const SizedBox(height: 20),
            
            Text(
              '시행일: 2024년 1월 1일',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
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


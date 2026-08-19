import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../utils/icon_utils.dart';

class AvatarSelectionScreen extends StatefulWidget {
  final Function onAvatarSelected;
  final String? roomId; // 방별 칭호 적용을 위한 roomId 추가

  const AvatarSelectionScreen({
    Key? key,
    required this.onAvatarSelected,
    this.roomId,
  }) : super(key: key);

  @override
  _AvatarSelectionScreenState createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  String? _selectedAvatarPath;
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;
  
  // 탭 컨트롤러
  TabController? _tabController;
  int _currentTabIndex = 0;
  
  // 컬러 기반 아바타 목록
  final List<Map<String, dynamic>> _colorAvatars = [
    {'color': Colors.red[400]!, 'name': '레드'},
    {'color': Colors.pink[400]!, 'name': '핑크'},
    {'color': Colors.purple[400]!, 'name': '퍼플'},
    {'color': Colors.deepPurple[400]!, 'name': '딥퍼플'},
    {'color': Colors.indigo[400]!, 'name': '인디고'},
    {'color': Colors.blue[400]!, 'name': '블루'},
    {'color': Colors.lightBlue[400]!, 'name': '라이트블루'},
    {'color': Colors.cyan[400]!, 'name': '시안'},
    {'color': Colors.teal[400]!, 'name': '틸'},
    {'color': Colors.green[400]!, 'name': '그린'},
    {'color': Colors.lightGreen[400]!, 'name': '라이트그린'},
    {'color': Colors.lime[400]!, 'name': '라임'},
    {'color': Colors.yellow[400]!, 'name': '옐로우'},
    {'color': Colors.amber[400]!, 'name': '앰버'},
    {'color': Colors.orange[400]!, 'name': '오렌지'},
    {'color': Colors.deepOrange[400]!, 'name': '딥오렌지'},
    {'color': Colors.brown[400]!, 'name': '브라운'},
    {'color': Colors.blueGrey[400]!, 'name': '블루그레이'},
    {'color': Colors.grey[600]!, 'name': '그레이'},
    {'color': Colors.black87, 'name': '블랙'},
  ];

  // 선택된 아바타 색상과 아이콘
  Color _selectedAvatarColor = Colors.blue[400]!;
  IconData _selectedAvatarIcon = Icons.person;

  // 아바타 아이콘 목록
  // IconUtils에서 아이콘 목록을 가져옴 (Tree shaking 문제 해결)
  List<IconData> get _avatarIcons => IconUtils.avatarIcons;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController?.addListener(() {
      setState(() {
        _currentTabIndex = _tabController?.index ?? 0;
      });
    });
    _loadCurrentData();
  }
  
  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // 현재 설정된 데이터 로드
  Future<void> _loadCurrentData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final nickname = await _authService.getUserNickname();
      if (nickname != null) {
        _nicknameController.text = nickname;
      }
      
      // 현재 프로필 설정 로드
      final avatarColor = await _authService.getAvatarColor();
      final avatarIcon = await _authService.getAvatarIcon();
      
      if (avatarColor != null) {
        _selectedAvatarColor = avatarColor;
      }
      if (avatarIcon != null) {
        _selectedAvatarIcon = avatarIcon;
      }

    } catch (e) {
      print('데이터 로드 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B9FFF)),
                strokeWidth: 3,
              ),
            )
          : Column(
              children: [
                // 커스텀 헤더 (Discord/Slack 스타일)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // 상단 바
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(Icons.arrow_back_ios, color: Color(0xFF6B9FFF)),
                              ),
                              Expanded(
                                child: Text(
                                  '프로필 편집',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1F2937),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              TextButton(
                                onPressed: _saveProfile,
                                child: Text(
                                  '완료',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6B9FFF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // 프로필 미리보기 (Instagram 스타일)
                        Container(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // 아바타
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: _selectedAvatarColor,
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _selectedAvatarColor.withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _selectedAvatarIcon,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                              
                              SizedBox(height: 16),
                              
                              // 닉네임 입력
                              Container(
                                width: 200,
                                child: TextField(
                                  controller: _nicknameController,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '닉네임을 입력하세요',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontWeight: FontWeight.w400,
                                    ),
                                    border: UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: Color(0xFF6B9FFF), width: 2),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {}); // 미리보기 업데이트
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // 탭 바 (Discord 스타일)
                        if (_tabController != null)
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                              ),
                            ),
                            child: TabBar(
                              controller: _tabController!,
                              indicatorColor: Color(0xFF6B9FFF),
                              indicatorWeight: 3,
                              labelColor: Color(0xFF6B9FFF),
                              unselectedLabelColor: Colors.grey[500],
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              unselectedLabelStyle: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              tabs: [
                                Tab(
                                  icon: Icon(Icons.face, size: 20),
                                  text: '아이콘',
                                ),
                                Tab(
                                  icon: Icon(Icons.palette, size: 20),
                                  text: '색상',
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // 탭 뷰 컨텐츠
                if (_tabController != null)
                  Expanded(
                    child: TabBarView(
                      controller: _tabController!,
                      children: [
                        _buildIconTab(),
                        _buildColorTab(),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  // 아이콘 탭 (TikTok/Instagram 스타일)
  Widget _buildIconTab() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '아이콘을 선택하세요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 16),
          
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _avatarIcons.length,
              itemBuilder: (context, index) {
                final icon = _avatarIcons[index];
                final isSelected = _selectedAvatarIcon == icon;
                
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedAvatarIcon = icon;
                      });
                    },
                    borderRadius: BorderRadius.circular(28),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected ? _selectedAvatarColor : Colors.grey[100],
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isSelected ? _selectedAvatarColor.withOpacity(0.3) : Colors.grey[200]!,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected 
                                ? _selectedAvatarColor.withOpacity(0.4)
                                : Colors.black.withOpacity(0.04),
                            blurRadius: isSelected ? 12 : 8,
                            offset: Offset(0, isSelected ? 6 : 2),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: 200),
                        child: Icon(
                          icon,
                          key: ValueKey('${icon.codePoint}_${isSelected}'),
                          color: isSelected ? Colors.white : Colors.grey[600],
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 색상 탭 (Spotify 스타일)
  Widget _buildColorTab() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '색상을 선택하세요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 16),
          
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _colorAvatars.length,
              itemBuilder: (context, index) {
                final colorData = _colorAvatars[index];
                final color = colorData['color'] as Color;
                final isSelected = _selectedAvatarColor == color;
                
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedAvatarColor = color;
                      });
                    },
                    borderRadius: BorderRadius.circular(28),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected 
                                ? color.withOpacity(0.4)
                                : Colors.black.withOpacity(0.04),
                            blurRadius: isSelected ? 12 : 8,
                            offset: Offset(0, isSelected ? 6 : 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.grey[200]!,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: isSelected ? Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            ) : null,
                          ),
                          SizedBox(height: 8),
                          Text(
                            colorData['name'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? color : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  // 프로필 저장
  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // 닉네임 저장
      if (_nicknameController.text.isNotEmpty) {
        await _authService.updateUserNickname(_nicknameController.text);
      }

      // 아바타 색상과 아이콘 저장
      await _authService.setColorAvatar(_selectedAvatarColor, _selectedAvatarIcon);
      
      widget.onAvatarSelected();
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('프로필이 저장되었습니다'),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('프로필 저장 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 
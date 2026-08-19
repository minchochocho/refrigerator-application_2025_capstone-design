import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/refrigerator_service.dart';
import '../../services/statistics_service.dart';
import '../../services/home_service.dart';
import '../../theme/app_theme.dart';
import '../main_screen.dart';
import '../search/search_screen.dart';
import 'ingredients_screen.dart';
import 'refrigerator_compartment_settings_screen.dart';
import '../expiration/expiring_overview_screen.dart';
import '../../services/room_service.dart';
import '../room/room_detail_screen.dart';
import '../../models/room.dart';

class RefrigeratorCompartmentScreen extends StatefulWidget {
  final String roomId;
  final String refrigeratorName;
  final String layout;
  // 검색 등에서 바로 특정 칸/식품으로 이동하기 위한 초기 타겟 정보
  final String? initialCompartmentName;
  final int? initialCompartmentIndex;
  final String? initialTargetIngredientId;

  const RefrigeratorCompartmentScreen({
    Key? key,
    required this.roomId,
    required this.refrigeratorName,
    required this.layout,
    this.initialCompartmentName,
    this.initialCompartmentIndex,
    this.initialTargetIngredientId,
  }) : super(key: key);

  @override
  _RefrigeratorCompartmentScreenState createState() => _RefrigeratorCompartmentScreenState();
}

class _RefrigeratorCompartmentScreenState extends State<RefrigeratorCompartmentScreen> {
  bool _isLoading = true;
  final RefrigeratorService _refrigeratorService = RefrigeratorService();
  List<String> _compartmentNames = [];
  String _compartmentTheme = 'green';
  String _refrigeratorNameState = '';
  bool _isEditing = false;
  final TextEditingController _nameController = TextEditingController();
  final List<TextEditingController> _compartmentControllers = [];
  List<String> _compartmentColors = [];
  String? _refrigeratorId; // 실시간 저장용
  Timer? _nameDebounce;
  List<Timer?> _compartmentDebounces = [];
  bool _hasPushedInitialTarget = false; // 초기 검색 타겟으로 자동 이동 여부
  
  @override
  void initState() {
    super.initState();
    _refrigeratorNameState = widget.refrigeratorName;
    _nameController.text = _refrigeratorNameState;
    
    // 실제 데이터 로드 (최적화된 버전)
    _loadRefrigeratorData();
  }

  // 냉장고 데이터 로드 (최적화 버전)
  Future<void> _loadRefrigeratorData() async {
    try {
      // 만료된 식품 자동 추적 (백그라운드에서 실행 - UI 로딩 차단하지 않음)
      final statisticsService = StatisticsService();
      statisticsService.trackExpiredItems(widget.roomId).catchError((e) {
        print('⚠️ 만료 추적 오류 (백그라운드): $e');
      });
      
      // 냉장고 데이터 로드
      final refrigerator = await _refrigeratorService.getRefrigeratorByRoomAndName(
        widget.roomId,
        _refrigeratorNameState,
      );

      if (refrigerator != null && refrigerator.compartmentNames.isNotEmpty) {
        // 냉장고 방문 기록 저장
        if (refrigerator.id.isNotEmpty) {
          HomeService().recordRefrigeratorVisit(refrigerator.id).catchError((e) {
            print('방문 기록 저장 오류: $e');
          });
        }
        
        if (mounted) {
          setState(() {
            _compartmentNames = refrigerator.compartmentNames;
            _compartmentTheme = refrigerator.compartmentTheme;
            if (refrigerator.compartmentColors.isNotEmpty) {
              _compartmentColors = List<String>.from(refrigerator.compartmentColors);
            } else {
              // 기본색: 냉동실→blue, 냉장실→green
              _compartmentColors = refrigerator.compartmentNames
                  .map((n) => n.contains('냉동') ? 'blue' : 'green')
                  .toList();
            }
            _refrigeratorNameState = refrigerator.name;
            _refrigeratorId = refrigerator.id;
            _nameController.text = _refrigeratorNameState;
            _syncCompartmentControllers();
            _isLoading = false;
          });
          // 데이터 로드 후, 초기 검색 타겟이 있으면 자동으로 해당 칸/식품 화면으로 이동
          _navigateToInitialTargetIfNeeded();
        }
      } else {
        // 기본값 사용 (fallback)
        if (mounted) {
          setState(() {
            _compartmentNames = _getDefaultCompartmentNames();
            _compartmentTheme = 'green';
            _compartmentColors = _compartmentNames
                .map((n) => n.contains('냉동') ? 'blue' : 'green')
                .toList();
            _syncCompartmentControllers();
            _isLoading = false;
          });
          _navigateToInitialTargetIfNeeded();
        }
      }
    } catch (e) {
      print('냉장고 데이터 로드 오류: $e');
      // 오류 시 기본값 사용
      if (mounted) {
        setState(() {
          _compartmentNames = _getDefaultCompartmentNames();
          _compartmentTheme = 'green';
          _compartmentColors = _compartmentNames
              .map((n) => n.contains('냉동') ? 'blue' : 'green')
              .toList();
          _syncCompartmentControllers();
          _isLoading = false;
        });
        _navigateToInitialTargetIfNeeded();
      }
    }
  }

  void _syncCompartmentControllers() {
    _compartmentControllers
      ..forEach((c) => c.dispose())
      ..clear();
    for (final name in _compartmentNames) {
      _compartmentControllers.add(TextEditingController(text: name));
    }
    _compartmentDebounces = List<Timer?>.filled(_compartmentControllers.length, null, growable: false);
  }

  // 초기 검색 타겟이 있는 경우, 해당 칸/식품 화면으로 한 번만 자동 이동
  void _navigateToInitialTargetIfNeeded() {
    if (_hasPushedInitialTarget) return;
    if (widget.initialCompartmentIndex == null ||
        widget.initialCompartmentName == null) return;

    // 유효한 인덱스인지 확인
    final index = widget.initialCompartmentIndex!;
    if (index < 0 || index >= _compartmentNames.length) return;

    _hasPushedInitialTarget = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToIngredients(
        widget.initialCompartmentName!,
        index,
        targetIngredientId: widget.initialTargetIngredientId,
      );
    });
  }

  // 기본 칸 이름들 (레이아웃별) - fallback용
  List<String> _getDefaultCompartmentNames() {
    switch (widget.layout) {
      case 'single':
        return ['냉장실'];
      case 'vertical':
        return ['냉장실', '냉동실'];
      case 'horizontal':
        return ['냉장실 좌', '냉장실 우'];
      case 'tripleTopTwo':
        return ['냉장실 좌', '냉장실 우', '냉동실'];
      case 'tripleBottomTwo':
        return ['냉장실', '냉동실 좌', '냉동실 우'];
      case 'quad':
        return ['냉장실 좌', '냉장실 우', '냉동실 좌', '냉동실 우'];
      default:
        return ['냉장실'];
    }
  }

  // 칸 이름에 따른 색상 설정 (냉장실/냉동실 구분)
  Color _getCompartmentColor(String name, {int? index}) {
    // 개별 색상 우선
    if (index != null && index < _compartmentColors.length && _compartmentColors[index].isNotEmpty) {
      return _colorFromName(_compartmentColors[index]).shade50;
    }
    // 기본 규칙: 냉장=연두, 냉동=하늘
    return name.contains('냉동') ? Color(0xFFE3F2FD) : Color(0xFFE8F5E9);
  }

  // 칸 이름에 따른 테두리 색상
  Color _getCompartmentBorderColor(String name, {int? index}) {
    if (index != null && index < _compartmentColors.length && _compartmentColors[index].isNotEmpty) {
      return _colorFromName(_compartmentColors[index]).shade400;
    }
    return name.contains('냉동') ? Color(0xFF42A5F5) : Color(0xFF66BB6A);
  }

  MaterialColor _colorFromName(String name) {
    switch (name) {
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.yellow;
      case 'lime':
        return Colors.lime;
      case 'teal':
        return Colors.teal;
      case 'purple':
        return Colors.purple;
      case 'orange':
        return Colors.orange;
      case 'indigo':
        return Colors.indigo;
      case 'pink':
        return Colors.pink;
      case 'amber':
        return Colors.amber;
      case 'cyan':
        return Colors.cyan;
      case 'deepOrange':
        return Colors.deepOrange;
      case 'deepPurple':
        return Colors.deepPurple;
      case 'brown':
        return Colors.brown;
      case 'blueGrey':
        return Colors.blueGrey;
      case 'lightBlue':
        return Colors.lightBlue;
      case 'lightGreen':
        return Colors.lightGreen;
      case 'grey':
        return Colors.grey;
      default:
        return Colors.green;
    }
  }


  // 칸 이름에 따른 아이콘
  IconData _getCompartmentIcon(String name) {
    if (name.contains('냉동')) {
      return Icons.ac_unit; // 냉동실은 얼음 아이콘
    } else {
      return Icons.kitchen; // 냉장실은 주방 아이콘
    }
  }

  // 칸 색상 선택 바텀 시트
  void _showCompartmentColorBottomSheet(int compartmentIndex) {
    final options = <String>[
      'green','blue','red','orange','amber','yellow','pink','purple','indigo','teal','lime',
      'cyan','lightBlue','lightGreen','deepPurple','deepOrange','brown','blueGrey','grey'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 헤더
              Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 드래그 핸들
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Icon(Icons.palette, color: Color(0xFF1F2937)),
                        SizedBox(width: 12),
                        Text(
                          '${_compartmentNames[compartmentIndex]} 색상 선택',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 색상 선택 그리드
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final colorName = options[index];
                      final color = _colorFromName(colorName);
                      final isSelected = _compartmentColors[compartmentIndex] == colorName;
                      
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _compartmentColors[compartmentIndex] = colorName;
                            });
                            if (_refrigeratorId != null) {
                              _refrigeratorService.updateCompartmentColorsById(_refrigeratorId!, _compartmentColors);
                            }
                            Navigator.pop(context);
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
                                    color: color.shade300,
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
                                  _getColorDisplayName(colorName),
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
              ),
              
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // 색상 이름을 한글로 변환
  String _getColorDisplayName(String colorName) {
    switch (colorName) {
      case 'green': return '그린';
      case 'blue': return '블루';
      case 'red': return '레드';
      case 'orange': return '오렌지';
      case 'amber': return '앰버';
      case 'yellow': return '옐로우';
      case 'pink': return '핑크';
      case 'purple': return '보라';
      case 'indigo': return '인디고';
      case 'teal': return '틸';
      case 'lime': return '라임';
      case 'cyan': return '시안';
      case 'lightBlue': return '라이트블루';
      case 'lightGreen': return '라이트그린';
      case 'deepPurple': return '딥퍼플';
      case 'deepOrange': return '딥오렌지';
      case 'brown': return '브라운';
      case 'blueGrey': return '블루그레이';
      case 'grey': return '그레이';
      default: return colorName;
    }
  }

  // 냉장고 옵션 메뉴 표시
  void _showRefrigeratorOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들바
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),
            
            Text(
              '냉장고 옵션',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            
            // 검색 옵션
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.search, color: Colors.blue[600]),
              ),
              title: Text('식품 검색'),
              subtitle: Text('이 방의 모든 냉장고에서 검색'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SearchScreen(roomId: widget.roomId),
                  ),
                );
              },
            ),
            
            // 칸 이름 설정
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit, color: Colors.purple[600]),
              ),
              title: Text('칸 이름 설정'),
              subtitle: Text('냉장고 칸 이름을 변경'),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RefrigeratorCompartmentSettingsScreen(
                      roomId: widget.roomId,
                      refrigeratorName: widget.refrigeratorName,
                    ),
                  ),
                );
                
                // 칸 이름이 변경되었으면 화면 새로고침
                if (result == true) {
                  await _loadRefrigeratorData();
                }
              },
            ),
            
            // 냉장고 정보
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.info_outline, color: Colors.green[600]),
              ),
              title: Text('냉장고 정보'),
              subtitle: Text('${widget.refrigeratorName} 상세 정보'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 냉장고 정보 화면 구현
              },
            ),
            
            Divider(color: Colors.grey[300]),
            
            // 냉장고 삭제
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete_outline, color: Colors.red[600]),
              ),
              title: Text(
                '냉장고 삭제',
                style: TextStyle(color: Colors.red[600]),
              ),
              subtitle: Text('냉장고와 모든 데이터가 삭제됩니다'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isEditing) {
          setState(() {
            _isEditing = false;
          });
          return false;
        }

         // 검색 결과에서 자동으로 진입한 칸 선택 화면인 경우,
         // 이전에 쌓여있던 칸 선택 화면들은 모두 건너뛰고
         // 바로 이전의 "비 칸선택" 화면(예: 방 상세, 홈 등)으로 이동
         if (widget.initialTargetIngredientId != null) {
           Navigator.of(context).popUntil(
             (route) => route.settings.name != 'refrigerator_compartment',
           );
           return false; // 여기서 처리했으므로 기본 pop은 막음
         }

        return true;
      },
      child: Scaffold(
      backgroundColor: Color(0xFFF7F8FA),
      appBar: AppBar(
        title: _isEditing
            ? TextField(
                controller: _nameController,
                onChanged: (v) {
                  _refrigeratorNameState = v;
                  _nameDebounce?.cancel();
                  if (_refrigeratorId != null) {
                    _nameDebounce = Timer(Duration(milliseconds: 400), () {
                      _refrigeratorService.updateRefrigeratorNameById(_refrigeratorId!, v.trim());
                    });
                  }
                  setState(() {});
                },
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '냉장고 이름',
                ),
              )
            : Text(
                _refrigeratorNameState,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEditing ? Icons.check_circle : Icons.edit,
              color: _isEditing ? Colors.green[700] : Colors.black,
            ),
            onPressed: () async {
              if (_isEditing) {
                await _saveEdits();
              } else {
                if (_compartmentColors.length != _compartmentNames.length) {
                  setState(() {
                    final needed = _compartmentNames.length;
                    while (_compartmentColors.length < needed) {
                      final name = _compartmentNames[_compartmentColors.length];
                      _compartmentColors.add(name.contains('냉동') ? 'blue' : 'green');
                    }
                    if (_compartmentColors.length > needed) {
                      _compartmentColors = _compartmentColors.sublist(0, needed);
                    }
                  });
                }
                setState(() {
                  _isEditing = true;
                });
              }
            },
            tooltip: _isEditing ? '저장' : '수정',
          ),
          IconButton(
            icon: Icon(Icons.meeting_room_outlined, color: Colors.black),
            onPressed: () {
              _showDeleteConfirmDialog();
            },
            tooltip: '냉장고 삭제',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4E9FFF)),
                strokeWidth: 3,
              ),
            )
          : ScrollConfiguration(
              behavior: NoGlowScrollBehavior(),
              child: SingleChildScrollView(
                physics: ClampingScrollPhysics(),
                child: Column(
                  children: [
                    SizedBox(height: 24),
                    
                    // 냉장고 모양
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: AspectRatio(
                            aspectRatio: _getRefrigeratorAspectRatio(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Color(0xFFFAFBFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[200]!, width: 1),
                              ),
                              child: _buildRealRefrigeratorLayout(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    ),
    );
  }

  // 냉장고 가로세로 비율 설정 (W:H)
  double _getRefrigeratorAspectRatio() {
    // 일반적인 냉장고 느낌: 세로가 약간 더 김 → 3:4 비율(0.75)
    // 레이아웃에 따라 약간씩 조정
    switch (widget.layout) {
      case 'single':
        return 3/4;  // 0.75
      case 'horizontal':
        return 3/4;  // 다른 레이아웃과 동일한 세로 길이 확보 (가로 두칸도 3:4)
      case 'vertical':
        return 3/4;
      case 'tripleTopTwo':
      case 'tripleBottomTwo':
        return 2/3;  // 세로가 더 길어 보이도록
      case 'quad':
        return 3/4;
      default:
        return 3/4;
    }
  }
  
  // 실제 냉장고 레이아웃 구현
  Widget _buildRealRefrigeratorLayout() {
    switch (widget.layout) {
      case 'single':
        return _buildRealSingleLayout();
      case 'vertical':
        return _buildRealVerticalLayout();
      case 'horizontal':
        return _buildRealHorizontalLayout();
      case 'tripleTopTwo':
        return _buildRealTripleTopTwoLayout();
      case 'tripleBottomTwo':
        return _buildRealTripleBottomTwoLayout();
      case 'quad':
        return _buildRealQuadLayout();
      default:
        return _buildRealSingleLayout();
    }
  }

  // 1칸 실제 냉장고 레이아웃
  Widget _buildRealSingleLayout() {
    final name = _compartmentNames[0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildCompartment(
            name: name,
            index: 0,
            color: _getCompartmentColor(name, index: 0),
            borderColor: _getCompartmentBorderColor(name, index: 0),
            icon: _getCompartmentIcon(name),
          ),
        ),
      ],
    );
  }
  
  // 2칸 세로 실제 냉장고 레이아웃
  Widget _buildRealVerticalLayout() {
    final name1 = _compartmentNames[0];
    final name2 = _compartmentNames[1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,  // 3에서 1로 변경하여 위쪽 칸을 작게
          child: _buildCompartment(
            name: name1,
            index: 0,
            color: _getCompartmentColor(name1, index: 0),
            borderColor: _getCompartmentBorderColor(name1, index: 0),
            icon: _getCompartmentIcon(name1),
          ),
        ),
        Container(height: 2, color: Colors.grey[200]),
        Expanded(
          flex: 1,  // 2에서 1로 변경하여 균등하게
          child: _buildCompartment(
            name: name2,
            index: 1,
            color: _getCompartmentColor(name2, index: 1),
            borderColor: _getCompartmentBorderColor(name2, index: 1),
            icon: _getCompartmentIcon(name2),
          ),
        ),
      ],
    );
  }
  
  // 2칸 가로 실제 냉장고 레이아웃
  Widget _buildRealHorizontalLayout() {
    final name1 = _compartmentNames[0];
    final name2 = _compartmentNames[1];
    return Row(
      children: [
        Expanded(
          child: _buildCompartment(
            name: name1,
            index: 0,
            color: _getCompartmentColor(name1, index: 0),
            borderColor: _getCompartmentBorderColor(name1, index: 0),
            icon: _getCompartmentIcon(name1),
          ),
        ),
        Container(width: 2, color: Colors.grey[200]),
        Expanded(
          child: _buildCompartment(
            name: name2,
            index: 1,
            color: _getCompartmentColor(name2, index: 1),
            borderColor: _getCompartmentBorderColor(name2, index: 1),
            icon: _getCompartmentIcon(name2),
          ),
        ),
      ],
    );
  }
  
  // 3칸 위 두칸 실제 냉장고 레이아웃
  Widget _buildRealTripleTopTwoLayout() {
    final name1 = _compartmentNames[0];
    final name2 = _compartmentNames[1];
    final name3 = _compartmentNames[2];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,  // 위 두칸 영역을 더 크게(2)
          child: Row(
            children: [
              Expanded(
                child: _buildCompartment(
                  name: name1,
                  index: 0,
                  color: _getCompartmentColor(name1, index: 0),
                  borderColor: _getCompartmentBorderColor(name1, index: 0),
                  icon: _getCompartmentIcon(name1),
                ),
              ),
              Container(width: 2, color: Colors.grey[200]),
              Expanded(
                child: _buildCompartment(
                  name: name2,
                  index: 1,
                  color: _getCompartmentColor(name2, index: 1),
                  borderColor: _getCompartmentBorderColor(name2, index: 1),
                  icon: _getCompartmentIcon(name2),
                ),
              ),
            ],
          ),
        ),
        Container(height: 2, color: Colors.grey[200]),
        Expanded(
          flex: 1,  // 아래 한칸 영역을 더 작게 유지(1)
          child: _buildCompartment(
            name: name3,
            index: 2,
            color: _getCompartmentColor(name3, index: 2),
            borderColor: _getCompartmentBorderColor(name3, index: 2),
            icon: _getCompartmentIcon(name3),
          ),
        ),
      ],
    );
  }
  
  // 3칸 아래 두칸 실제 냉장고 레이아웃
  Widget _buildRealTripleBottomTwoLayout() {
    final name1 = _compartmentNames[0];
    final name2 = _compartmentNames[1];
    final name3 = _compartmentNames[2];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,  // 아래 단일 칸 영역은 작게 유지(1)
          child: _buildCompartment(
            name: name1,
            index: 0,
            color: _getCompartmentColor(name1, index: 0),
            borderColor: _getCompartmentBorderColor(name1, index: 0),
            icon: _getCompartmentIcon(name1),
          ),
        ),
        Container(height: 2, color: Colors.grey[200]),
        Expanded(
          flex: 1,  // 2에서 1로 변경하여 아래쪽 칸들과 균등하게
          child: Row(
            children: [
              Expanded(
                child: _buildCompartment(
                  name: name2,
                  index: 1,
                  color: _getCompartmentColor(name2, index: 1),
                  borderColor: _getCompartmentBorderColor(name2, index: 1),
                  icon: _getCompartmentIcon(name2),
                ),
              ),
              Container(width: 2, color: Colors.grey[200]),
              Expanded(
                child: _buildCompartment(
                  name: name3,
                  index: 2,
                  color: _getCompartmentColor(name3, index: 2),
                  borderColor: _getCompartmentBorderColor(name3, index: 2),
                  icon: _getCompartmentIcon(name3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 4칸 실제 냉장고 레이아웃
  Widget _buildRealQuadLayout() {
    final name1 = _compartmentNames[0];
    final name2 = _compartmentNames[1];
    final name3 = _compartmentNames[2];
    final name4 = _compartmentNames[3];
    return Column(
      children: [
        Expanded(
          flex: 2,  // 위 두칸 영역을 더 크게(2)
          child: Row(
            children: [
              Expanded(
                child: _buildCompartment(
                  name: name1,
                  index: 0,
                  color: _getCompartmentColor(name1, index: 0),
                  borderColor: _getCompartmentBorderColor(name1, index: 0),
                  icon: _getCompartmentIcon(name1),
                ),
              ),
              Container(width: 2, color: Colors.grey[200]),
              Expanded(
                child: _buildCompartment(
                  name: name2,
                  index: 1,
                  color: _getCompartmentColor(name2, index: 1),
                  borderColor: _getCompartmentBorderColor(name2, index: 1),
                  icon: _getCompartmentIcon(name2),
                ),
              ),
            ],
          ),
        ),
        Container(height: 2, color: Colors.grey[200]),
        Expanded(
          flex: 1,  // 2에서 1로 변경하여 아래쪽 칸들과 균등하게
          child: Row(
            children: [
              Expanded(
                child: _buildCompartment(
                  name: name3,
                  index: 2,
                  color: _getCompartmentColor(name3, index: 2),
                  borderColor: _getCompartmentBorderColor(name3, index: 2),
                  icon: _getCompartmentIcon(name3),
                ),
              ),
              Container(width: 2, color: Colors.grey[200]),
              Expanded(
                child: _buildCompartment(
                  name: name4,
                  index: 3,
                  color: _getCompartmentColor(name4, index: 3),
                  borderColor: _getCompartmentBorderColor(name4, index: 3),
                  icon: _getCompartmentIcon(name4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 개별 칸 위젯 (클릭 가능)
  Widget _buildCompartment({
    required String name,
    required int index,
    required Color color,
    required Color borderColor,
    required IconData icon,
  }) {
    return Container(
      margin: EdgeInsets.all(8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_isEditing) return;
            _navigateToIngredients(name, index);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor.withOpacity(0.3), width: 1.5),
            ),
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Spacer(),
                  
                  // 아이콘
                  Icon(
                    Icons.kitchen_rounded,
                    size: 28.0,
                    color: borderColor,
                  ),
                  
                  SizedBox(height: 8),
                  
                  // 칸 이름 (일반 모드) 또는 이름 편집 (수정 모드)
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: _isEditing
                          ? Center(
                              child: TextField(
                                controller: _compartmentControllers[index],
                                onChanged: (v) {
                                  _compartmentNames[index] = v;
                                  _compartmentDebounces[index]?.cancel();
                                  if (_refrigeratorId != null) {
                                    _compartmentDebounces[index] = Timer(Duration(milliseconds: 400), () {
                                      _refrigeratorService.updateCompartmentNamesById(_refrigeratorId!, _compartmentNames);
                                    });
                                  }
                                  setState(() {});
                                },
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[800],
                                  letterSpacing: -0.3,
                                  height: 1.2,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: UnderlineInputBorder(
                                    borderSide: BorderSide(color: borderColor.withOpacity(0.3), width: 1),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: borderColor.withOpacity(0.3), width: 1),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: borderColor, width: 1.5),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                ),
                              ),
                            )
                          : Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[800],
                                    letterSpacing: -0.3,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            ),
                    ),
                  ),
                  
                  SizedBox(height: 8),
                  
                  // 하단 액션 (색상 버튼만)
                  if (_isEditing)
                    GestureDetector(
                      onTap: () {
                        _showCompartmentColorBottomSheet(index);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.palette, size: 16, color: borderColor),
                            SizedBox(width: 4),
                            Text(
                              '색상',
                              style: TextStyle(
                                fontSize: 13,
                                color: borderColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 냉장고 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[600]),
            SizedBox(width: 8),
            Text('냉장고 삭제'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '정말로 "${widget.refrigeratorName}"을(를) 삭제하시겠습니까?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.red[600], size: 18),
                      SizedBox(width: 6),
                      Text(
                        '주의사항',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• 냉장고 안의 모든 식품 데이터가 삭제됩니다\n• 삭제된 데이터는 복구할 수 없습니다\n• 이 작업은 취소할 수 없습니다',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteRefrigerator();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 냉장고 삭제 실행
  Future<void> _deleteRefrigerator() async {
    if (!mounted) return;
    
    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('냉장고를 삭제하고 있습니다...'),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      print('🗑️ 냉장고 삭제 시작');
      
      // 냉장고 ID 가져오기
      final refrigeratorId = await _refrigeratorService.getRefrigeratorIdByRoomAndName(
        widget.roomId,
        widget.refrigeratorName,
      );

      print('🔍 냉장고 ID: $refrigeratorId');

      if (refrigeratorId != null) {
        // 냉장고 삭제
        print('⏳ 냉장고 삭제 중...');
        bool success = await _refrigeratorService.deleteRefrigerator(refrigeratorId);
        print('✅ 냉장고 삭제 완료: $success');

        // 로딩 다이얼로그 닫기
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: false).pop();
        }

        if (success && mounted) {
          // 방 상세 화면으로 돌아가기 (현재 화면만 pop)
          Navigator.of(context).pop();
          
          // 성공 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('냉장고가 삭제되었습니다'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('냉장고 삭제에 실패했습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // 로딩 다이얼로그 닫기
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: false).pop();
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('냉장고를 찾을 수 없습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ 냉장고 삭제 오류: $e');
      
      // 로딩 다이얼로그가 열려있으면 닫기
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: false).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('냉장고 삭제 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 확인 다이얼로그 없이 바로 삭제 후 그룹 화면으로 복귀
  Future<void> _deleteRefrigeratorQuick() async {
    try {
      final refrigeratorId = await _refrigeratorService.getRefrigeratorIdByRoomAndName(
        widget.roomId,
        _refrigeratorNameState,
      );
      if (refrigeratorId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('냉장고를 찾을 수 없습니다'), backgroundColor: Colors.red),
        );
        return;
      }

      final success = await _refrigeratorService.deleteRefrigerator(refrigeratorId);
      if (success && mounted) {
        // 방 상세 화면으로 돌아가기
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('냉장고가 삭제되었습니다'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제에 실패했습니다'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 중 오류가 발생했습니다'), backgroundColor: Colors.red),
      );
    }
  }

  // 식품 화면으로 이동
  void _navigateToIngredients(
    String compartmentName,
    int index, {
    String? targetIngredientId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IngredientsScreen(
          roomId: widget.roomId,
          refrigeratorName: _refrigeratorNameState,
          compartmentName: compartmentName,
          compartmentIndex: index,
          targetIngredientId: targetIngredientId,
          availableCompartments: _compartmentNames, // 칸 목록 전달
        ),
      ),
    );
  }

  // 만료 예정 아이템 개수 계산 (현재 냉장고만)
  Future<int> _getExpiringItemsCount() async {
    try {
      final now = DateTime.now();
      int count = 0;

      // 현재 냉장고에서만 식품 가져오기
      final refrigeratorSnapshot = await FirebaseFirestore.instance
          .collection('Refrigerators')
          .where('room_id', isEqualTo: widget.roomId)
          .where('name', isEqualTo: _refrigeratorNameState)
          .limit(1)
          .get();

      if (refrigeratorSnapshot.docs.isNotEmpty) {
        final refrigeratorDoc = refrigeratorSnapshot.docs.first;
        final refrigeratorData = refrigeratorDoc.data();
        
        // 냉장고의 칸 이름들 가져오기
        final compartmentNames = List<String>.from(
          refrigeratorData['compartment_names'] ?? []
        );

        // 각 칸에서 재료 가져오기
        for (int compartmentIndex = 0; compartmentIndex < compartmentNames.length; compartmentIndex++) {
          final ingredientsSnapshot = await refrigeratorDoc.reference
              .collection('compartments')
              .doc(compartmentIndex.toString())
              .collection('ingredients')
              .get();

          for (final ingredientDoc in ingredientsSnapshot.docs) {
            final ingredientData = ingredientDoc.data();
            final dynamic expiryField = ingredientData['expiryDate'];
            
            DateTime? expiryDate;
            if (expiryField is Timestamp) {
              // UTC 자정에서 로컬 날짜로 변환
              final utcDate = expiryField.toDate();
              expiryDate = DateTime(utcDate.year, utcDate.month, utcDate.day);
            } else if (expiryField is String) {
              expiryDate = DateTime.tryParse(expiryField);
            }

            if (expiryDate == null) continue;

            final daysLeft = DateTime(expiryDate.year, expiryDate.month, expiryDate.day)
                .difference(DateTime(now.year, now.month, now.day))
                .inDays;

            // 3일 이내 항목 카운트
            if (daysLeft <= 3) {
              count++;
            }
          }
        }
      }

      return count;
    } catch (e) {
      debugPrint('🔥 만료 예정 아이템 카운트 오류: $e');
      return 0;
    }
  }

  // 인라인 편집 패널 UI
  Widget _buildInlineEditPanel() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 냉장고 이름
          Text('냉장고 이름', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
          SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: '냉장고 이름 입력',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
          ),
          SizedBox(height: 16),

          // 칸별 색상 선택 (팔레트)
          Text('칸 색상', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
          SizedBox(height: 8),
          Wrap(
            runSpacing: 8,
            spacing: 8,
            children: List.generate(_compartmentControllers.length, (i) {
              return _buildColorPickerForCompartment(i);
            }),
          ),

          SizedBox(height: 16),
          Text('칸 이름', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
          SizedBox(height: 8),
          ...List.generate(_compartmentControllers.length, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _compartmentControllers[i],
                decoration: InputDecoration(
                  prefixText: '${i + 1}. ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
            );
          }),

          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _loadRefrigeratorData();
                    });
                  },
                  child: Text('취소'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveEdits,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  child: Text('저장'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveEdits() async {
    final newName = _nameController.text.trim();
    final newCompartmentNames = _compartmentControllers.map((c) => c.text.trim().isEmpty ? '칸' : c.text.trim()).toList();

    bool ok = true;

    // 1) 이름 변경 (가능하면 ID 기반)
    if (newName.isNotEmpty && newName != _refrigeratorNameState) {
      if (_refrigeratorId != null) {
        ok = ok && await _refrigeratorService.updateRefrigeratorNameById(_refrigeratorId!, newName);
      } else {
        ok = ok && await _refrigeratorService.updateRefrigeratorName(widget.roomId, _refrigeratorNameState, newName);
      }
      if (ok) {
        _refrigeratorNameState = newName;
      }
    }

    // 2) 칸 이름 (가능하면 ID 기반)
    if (!_listEquals(newCompartmentNames, _compartmentNames)) {
      if (_refrigeratorId != null) {
        ok = ok && await _refrigeratorService.updateCompartmentNamesById(_refrigeratorId!, newCompartmentNames);
      } else {
        ok = ok && await _refrigeratorService.updateCompartmentNames(widget.roomId, _refrigeratorNameState, newCompartmentNames);
      }
    }

    // 3) 칸 색상 (항상 최신 이름 또는 ID로 저장)
    if (_refrigeratorId != null) {
      ok = ok && await _refrigeratorService.updateCompartmentColorsById(_refrigeratorId!, _compartmentColors);
    } else {
      ok = ok && await _refrigeratorService.updateCompartmentColors(
        widget.roomId,
        _refrigeratorNameState,
        _compartmentColors,
      );
    }

    if (ok) {
      setState(() {
        _compartmentNames = newCompartmentNames;
        _isEditing = false;
      });
      await _loadRefrigeratorData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장되었습니다.'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일부 항목 저장에 실패했습니다.'), backgroundColor: Colors.red),
      );
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // 칸별 색상 선택 위젯 (팔레트)
  Widget _buildColorPickerForCompartment(int index) {
    // 리스트 길이 보정
    if (_compartmentColors.length != _compartmentControllers.length) {
      final needed = _compartmentControllers.length;
      while (_compartmentColors.length < needed) {
        _compartmentColors.add('green');
      }
      if (_compartmentColors.length > needed) {
        _compartmentColors = _compartmentColors.sublist(0, needed);
      }
    }

    final options = <String>[
      'green','blue','teal','purple','orange','pink','amber',
      'cyan','lightBlue','lightGreen','deepPurple','deepOrange','brown','blueGrey','indigo','yellow'
    ];
    final current = _compartmentColors[index];
    final label = _compartmentControllers[index].text.isEmpty
        ? '칸 ${index + 1}'
        : _compartmentControllers[index].text;

    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _colorFromName(current).shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _colorFromName(current).shade800,
              ),
            ),
          ),
          SizedBox(width: 10),
          Wrap(
            spacing: 8,
            children: options.map((name) {
              final mat = _colorFromName(name);
              final selected = name == current;
              return InkWell(
                onTap: () {
                  setState(() {
                    _compartmentColors[index] = name;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: mat.shade400,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.black : Colors.white,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
} 
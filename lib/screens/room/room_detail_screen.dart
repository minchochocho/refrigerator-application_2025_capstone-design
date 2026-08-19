import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/room.dart';
import '../../models/refrigerator.dart';
import '../../services/room_service.dart';
import '../../services/refrigerator_service.dart';
import '../../services/auth_service.dart';
import '../../services/search_service.dart';
import '../../utils/icon_utils.dart';
import '../refrigerator/widgets/ingredient_image_widget.dart';
import '../refrigerator/refrigerator_selection_screen.dart';
import '../refrigerator/refrigerator_compartment_screen.dart';
import '../refrigerator/ingredients_screen.dart';
import '../main_screen.dart';
import '../profile/role_edit_screen.dart';
import '../search/search_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoomDetailScreen extends StatefulWidget {
  final Room room;

  const RoomDetailScreen({
    Key? key,
    required this.room,
  }) : super(key: key);

  @override
  _RoomDetailScreenState createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final RoomService _roomService = RoomService();
  final RefrigeratorService _refrigeratorService = RefrigeratorService();
  final AuthService _authService = AuthService();
  final SearchService _searchService = SearchService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isEditingRoomName = false;
  late TextEditingController _roomNameController;

  // 검색 상태
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchingData = false;
  bool _hasSearched = false;
  int _roomSearchRequestId = 0; // 방 상세 내 검색 요청 ID
  Timer? _roomSearchDebounce;   // 방 상세 내 검색 디바운스 타이머
  
  @override
  void initState() {
    super.initState();
    _roomNameController = TextEditingController();
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _roomSearchDebounce?.cancel();
    super.dispose();
  }

  // AppBar 안 검색 바
  Widget _buildSearchBar(Room room) {
    return Container(
      key: ValueKey('room_search_bar'),
      height: 44,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: '식품명을 입력하세요',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                _onRoomSearchTextChanged(room.id, value);
              },
              // 엔터를 눌러도 별도 즉시 검색은 하지 않고,
              // 위 onChanged 디바운스 로직만 사용
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.grey[500]),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            onPressed: () {
              setState(() {
                if (_searchController.text.isEmpty) {
                  // 검색 모드 종료
                  _isSearching = false;
                }
                _roomSearchDebounce?.cancel();
                _searchController.clear();
                _searchResults = [];
                _hasSearched = false;
                _isSearchingData = false;
              });
            },
          ),
          SizedBox(width: 4),
        ],
      ),
    );
  }

  // 방 상세 화면 내 검색: 입력마다 바로 실행 (최신 검색만 반영)
  void _onRoomSearchTextChanged(String roomId, String value) {
    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _isSearchingData = false;
      });
      return;
    }

    // 남아있을 수 있는 타이머는 정리하고, 디바운스 후 검색 실행
    _roomSearchDebounce?.cancel();
    _roomSearchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(roomId, query);
    });
  }

  Future<void> _performSearch(String roomId, String query) async {
    final int requestId = ++_roomSearchRequestId;

    setState(() {
      _isSearchingData = true;
      _hasSearched = true;
    });

    try {
      final results = await _searchService.searchIngredientsInRoom(roomId, query);

      if (!mounted || requestId != _roomSearchRequestId) {
        return;
      }

      setState(() {
        _searchResults = results;
        _isSearchingData = false;
      });
    } catch (e) {
      print('방 상세 검색 오류: $e');

      if (!mounted || requestId != _roomSearchRequestId) {
        return;
      }

      setState(() {
        _searchResults = [];
        _isSearchingData = false;
      });
    }
  }

  Widget _buildSearchResults(Room room) {
    if (_isSearchingData) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4E9FFF)),
          strokeWidth: 3,
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 80),
            Icon(Icons.search, size: 72, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              '식품명을 입력하여 검색하세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Text(
              '이 방의 모든 냉장고에서 검색합니다',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 80),
            Icon(Icons.search_off, size: 72, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              '검색 결과가 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Text(
              '다른 검색어로 시도해보세요',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return _buildSearchResultCard(item);
      },
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> item) {
    final expiry = item['expiryDate'];
    DateTime? expiryDate;
    if (expiry is Timestamp) {
      expiryDate = expiry.toDate();
    } else if (expiry is DateTime) {
      expiryDate = expiry;
    }

    int? daysLeft;
    if (expiryDate != null) {
      final today = DateTime.now();
      daysLeft = DateTime(expiryDate.year, expiryDate.month, expiryDate.day)
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
    }

    // 이미지 경로 (URL, 로컬 파일, Base64 모두 포함)
    final String? imagePath = item['imagePath']?.toString();

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: imagePath != null && imagePath.isNotEmpty
                ? Colors.transparent
                : Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: (imagePath != null && imagePath.isNotEmpty)
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: IngredientImageWidget(
                    imagePath: imagePath,
                    width: 44,
                    height: 44,
                    fallbackIcon: Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF6B9FFF),
                    ),
                  ),
                )
              : Icon(Icons.inventory_2_outlined, color: Color(0xFF6B9FFF)),
        ),
        title: Text(
          item['name'] ?? '',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              '${item['refrigeratorName']} · ${item['compartmentName']}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            if (item['quantity'] != null && item['quantity'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  '수량: ${item['quantity']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
          ],
        ),
        trailing: daysLeft == null
            ? null
            : Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: daysLeft < 0
                      ? Colors.red[50]
                      : daysLeft <= 3
                          ? Colors.orange[50]
                          : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  daysLeft < 0
                      ? 'D+${daysLeft.abs()}'
                      : daysLeft == 0
                          ? 'D-Day'
                          : 'D-$daysLeft',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: daysLeft < 0
                        ? Colors.red[700]
                        : daysLeft <= 3
                            ? Colors.orange[700]
                            : Colors.green[700],
                  ),
                ),
              ),
        onTap: () {
          // 검색 결과를 통해 이동하는 경우,
          // 돌아왔을 때는 검색 모드가 아닌 "냉장고 목록" 화면이 바로 보이도록
          // 현재 검색 상태를 먼저 초기화한다.
          setState(() {
            _isSearching = false;
            _searchController.clear();
            _searchResults = [];
            _hasSearched = false;
            _isSearchingData = false;
          });

          Navigator.push(
            context,
            MaterialPageRoute(
              settings: RouteSettings(name: 'refrigerator_compartment'),
              builder: (context) => RefrigeratorCompartmentScreen(
                roomId: item['roomId'] ?? widget.room.id,
                refrigeratorName: item['refrigeratorName'],
                layout: item['layout'] ?? 'single',
                initialCompartmentName: item['compartmentName'],
                initialCompartmentIndex: item['compartmentIndex'],
                initialTargetIngredientId: item['id'],
              ),
            ),
          );
        },
      ),
    );
  }

  // 사용자의 방 내 역할 확인
  void _checkUserRole() {
    setState(() {
      // _isAdmin = widget.room.roomCreator == _roomService.currentUserId; // 이제 파라미터로 전달받음
    });
  }

  // 그룹 코드 복사 기능
  void _copyRoomCode(Room room) {
    Clipboard.setData(ClipboardData(text: room.roomCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('그룹 코드가 클립보드에 복사되었습니다'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 방 나가기
  Future<void> _leaveRoom(Room room) async {
    // 방장인 경우 방 삭제 확인 팝업
    if (room.roomCreator == _roomService.currentUserId) {
      _showAdminLeaveDialog(room);
      return;
    }

    // 일반 멤버의 방 나가기
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _roomService.leaveRoom(room.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('방에서 나갔습니다'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage ?? '오류가 발생했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 방장 나가기(방 삭제) 확인 다이얼로그
  void _showAdminLeaveDialog(Room room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('방 나가기'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '방장이 방을 나가면 방이 삭제됩니다.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '• 모든 멤버가 방에서 제거됩니다.\n• 모든 방 데이터가 영구적으로 삭제됩니다.\n• 이 작업은 되돌릴 수 없습니다. ',
            ),
            SizedBox(height: 12),
            Text(
              '정말 나가시겠습니까?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRoom(room);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('나가기'),
          ),
        ],
      ),
    );
  }

  // 방 삭제 실행
  Future<void> _deleteRoom(Room room) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _roomService.deleteRoom(room.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('방이 삭제되었습니다'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage ?? '방 삭제 중 오류가 발생했습니다'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Rooms').doc(widget.room.id).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
            ),
          );
        }
        
        final room = Room.fromFirestore(snapshot.data!);
        final bool isAdmin = room.roomCreator == _roomService.currentUserId;
        
        // 수정모드가 아닐 때만 컨트롤러 텍스트 업데이트
        if (!_isEditingRoomName) {
          _roomNameController.text = room.roomName;
        }
        
        return Scaffold(
          backgroundColor: Color(0xFFF7F8FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            titleSpacing: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                if (_isSearching) {
                  // 검색 중이면 검색 모드 취소
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _searchResults = [];
                    _hasSearched = false;
                  });
                } else {
                  // 검색 중이 아니면 뒤로가기
                  Navigator.pop(context);
                }
              },
            ),
            title: AnimatedSwitcher(
              duration: Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axis: Axis.horizontal,
                    child: child,
                  ),
                );
              },
              child: _isSearching
                  ? _buildSearchBar(room)
                  : Text(
                      room.roomName,
                      key: ValueKey('room_title'),
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                    ),
            ),
            actions: [
              if (!_isSearching) ...[
                IconButton(
                  icon: Icon(Icons.search, color: Colors.black),
                  tooltip: '식품 검색',
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                    Future.delayed(Duration(milliseconds: 200), () {
                      _searchFocusNode.requestFocus();
                    });
                  },
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.black),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showRoomDetailInfo(room);
                        break;
                      case 'members':
                        _showRoomMembers(room);
                        break;
                      case 'leave':
                        _leaveRoom(room);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('방 상세정보'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'members',
                      child: Row(
                        children: [
                          Icon(Icons.people_outline, size: 20),
                          SizedBox(width: 8),
                          Text('멤버 관리'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'leave',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 20, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('방 나가기', style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4E9FFF)),
                    strokeWidth: 3,
                  ),
                )
              : (_isSearching
                  ? _buildSearchResults(room)
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                      SizedBox(height: 24),
                      
                      // 냉장고 목록 헤더
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '냉장고 목록',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[900],
                                letterSpacing: -0.3,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _navigateToAddRefrigerator,
                              icon: Icon(Icons.add_rounded, size: 18),
                              label: Text('추가'),
                              style: TextButton.styleFrom(
                                foregroundColor: Color(0xFF4E9FFF),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // 냉장고 목록
                      Container(
                        constraints: BoxConstraints(
                          minHeight: 400,
                        ),
                        child: StreamBuilder<List<Refrigerator>>(
                          stream: _refrigeratorService.getRoomRefrigerators(room.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4E9FFF)),
                                    strokeWidth: 3,
                                  ),
                                ),
                              );
                            }
                            
                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.error_outline_rounded,
                                          size: 40,
                                          color: Colors.red[400],
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        '냉장고 목록을 불러올 수 없습니다',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            
                            final refrigerators = snapshot.data ?? [];
                            
                            if (refrigerators.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.kitchen_outlined,
                                          size: 50,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                      SizedBox(height: 24),
                                      Text(
                                        '등록된 냉장고가 없습니다',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey[800],
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        '냉장고를 추가하여 식재료를 관리해보세요',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            
                            // 리스트 → 2열 그리드로 변경
                            return GridView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              physics: NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.9,
                              ),
                              itemCount: refrigerators.length,
                              itemBuilder: (context, index) {
                                final refrigerator = refrigerators[index];
                                return _buildCleanRefrigeratorCard(refrigerator);
                              },
                            );
                          },
                        ),
                      ),
                      
                      SizedBox(height: 32),
                    ],
                  ),
                )),
        );
      },
    );
  }

  // 정보 카드 위젯 (클릭 가능)
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    VoidCallback? onTap,
  }) {
    return Container(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onTap != null) ...[
                  SizedBox(height: 4),
                  Text(
                    '탭하기',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 냉장고 추가 화면으로 이동
  void _navigateToAddRefrigerator() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RefrigeratorSelectionScreen(
          roomId: widget.room.id,
        ),
      ),
    ).then((_) {
      // 냉장고 추가 후 그룹 멤버들과 냉장고 멤버 동기화
      _syncRoomMembersToRefrigerators();
    });
  }

  // 그룹 멤버와 냉장고 멤버 동기화
  Future<void> _syncRoomMembersToRefrigerators() async {
    try {
      await _refrigeratorService.syncRoomMembersToRefrigerators(widget.room.id);
      print('그룹 ${widget.room.roomName}의 냉장고 멤버 동기화 완료');
    } catch (e) {
      print('냉장고 멤버 동기화 오류: $e');
    }
  }

  // 냉장고 상세 화면으로 이동
  void _navigateToRefrigeratorDetail(Refrigerator refrigerator) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: 'refrigerator_compartment'),
        builder: (context) => RefrigeratorCompartmentScreen(
          roomId: widget.room.id,
          refrigeratorName: refrigerator.name,
          layout: refrigerator.layout,
        ),
      ),
    );
  }

  // 냉장고 레이아웃에 따른 아이콘 반환
  IconData _getRefrigeratorIcon(String layout) {
    switch (layout) {
      case 'single':
        return Icons.kitchen;
      case 'vertical':
        return Icons.kitchen_outlined;
      case 'horizontal':
        return Icons.kitchen_outlined;
      case 'tripleTopTwo':
        return Icons.kitchen_outlined;
      case 'tripleBottomTwo':
        return Icons.kitchen_outlined;
      case 'quad':
        return Icons.kitchen_outlined;
      default:
        return Icons.kitchen_outlined;
    }
  }

  // 정보 항목 위젯
  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade600,
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                content,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 날짜 포맷팅 헬퍼 함수
  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일';
  }

  // 냉장고 삭제 확인 다이얼로그
  void _showDeleteRefrigeratorDialog(Refrigerator refrigerator) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('냉장고 삭제'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '주의: 냉장고를 삭제하면 모든 식재료 데이터가 영구적으로 삭제됩니다.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '정말 삭제하시겠습니까?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRefrigerator(refrigerator);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 냉장고 삭제 실행
  Future<void> _deleteRefrigerator(Refrigerator refrigerator) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _refrigeratorService.deleteRefrigerator(refrigerator.id);
      if (mounted) {
        // 성공 메시지만 표시하고 현재 화면에 머무름
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('냉장고가 삭제되었습니다'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage ?? '냉장고 삭제 중 오류가 발생했습니다'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // 그룹 멤버 관리 화면
  void _showRoomMembers(Room room) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 그룹 멤버 ID 목록 가져오기
      List<String> memberIds = room.memberIds;
      String currentUserId = _authService.currentUser?.uid ?? '';
      String roomCreator = room.roomCreator;
      
      // 각 멤버의 정보 가져오기
      List<Map<String, dynamic>> memberInfos = [];
      for (String memberId in memberIds) {
        Map<String, dynamic>? userInfo = await _authService.getUserInfo(memberId);
        if (userInfo != null) {
          memberInfos.add({
            'userId': memberId,
            'nickname': userInfo['nickname'],
            'profile_image': userInfo['profile_image'],
            'avatarColor': userInfo['avatarColor'],
            'avatarIcon': userInfo['avatarIcon'],
            'isCreator': memberId == roomCreator,
            'isMe': memberId == currentUserId,
          });
        }
      }
      
      // 방장을 먼저 표시하도록 정렬
      memberInfos.sort((a, b) {
        if (a['isCreator'] && !b['isCreator']) return -1;
        if (!a['isCreator'] && b['isCreator']) return 1;
        if (a['isMe'] && !b['isMe']) return -1;
        if (!a['isMe'] && b['isMe']) return 1;
        return 0;
      });
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Container(
              padding: EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  // 상단 핸들
                  Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // 제목
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.purple[400]!, Colors.purple[600]!],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.people_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '멤버 관리',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${memberInfos.length}명',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // 멤버 목록
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      itemCount: memberInfos.length,
                      itemBuilder: (context, index) {
                        final member = memberInfos[index];
                        return _buildMemberItem(member);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('멤버 목록 로딩 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // 멤버 아이템 위젯
  Widget _buildMemberItem(Map<String, dynamic> member) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: member['isMe'] ? Colors.blue[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: member['isMe'] ? Border.all(color: Colors.blue[200]!, width: 1.5) : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // 프로필 아바타
            _buildMemberAvatar(member),
            SizedBox(width: 16),
            
            // 닉네임 및 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member['nickname'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: member['isMe'] ? FontWeight.bold : FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      if (member['isMe'])
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '나',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: member['isCreator'] 
                          ? LinearGradient(colors: [Colors.orange[100]!, Colors.orange[200]!])
                          : LinearGradient(colors: [Colors.green[100]!, Colors.green[200]!]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      member['isCreator'] ? '방장' : '멤버',
                      style: TextStyle(
                        fontSize: 12,
                        color: member['isCreator'] ? Colors.orange[800] : Colors.green[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 멤버 아바타 위젯
  Widget _buildMemberAvatar(Map<String, dynamic> member) {
    if (member['avatarColor'] != null && member['avatarIcon'] != null) {
      // 컬러 아바타 사용
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Color(member['avatarColor']),
          shape: BoxShape.circle,
        ),
        child: Icon(
          IconUtils.getIconFromCodePoint(member['avatarIcon']) ?? Icons.person,
          color: Colors.white,
          size: 24,
        ),
      );
    } else if (member['profile_image'] != null && 
               !member['profile_image'].toString().startsWith('assets/')) {
      // 업로드된 이미지
      return CircleAvatar(
        radius: 25,
        backgroundImage: NetworkImage(member['profile_image']),
        backgroundColor: Colors.grey[200],
      );
    } else {
      // 기본 아바타
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: member['isCreator'] 
                ? [Colors.orange[300]!, Colors.orange[500]!]
                : [Colors.blue[300]!, Colors.blue[500]!],
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          member['isCreator'] ? Icons.star : Icons.person,
          color: Colors.white,
          size: 24,
        ),
      );
    }
  }

  // 역할 편집 화면으로 이동
  void _navigateToRoleEdit(String? currentRole) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoleEditScreen(
          roomId: widget.room.id,
          roomName: widget.room.roomName,
          currentRole: currentRole ?? '',
        ),
      ),
    );
  }

  // 레이아웃 이름 가져오기
  String _getLayoutName(String layout) {
    switch (layout) {
      case 'single':
        return '1칸 냉장고';
      case 'vertical':
        return '2칸 세로형';
      case 'horizontal':
        return '2칸 가로형';
      case 'tripleTopTwo':
        return '3칸 상단형';
      case 'tripleBottomTwo':
        return '3칸 하단형';
      case 'quad':
        return '4칸 냉장고';
      default:
        return '일반 냉장고';
    }
  }

  // 방 상세정보 다이얼로그
  void _showRoomDetailInfo(Room room) {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Rooms').doc(room.id).snapshots(),
        builder: (context, snapshot) {
          // 실시간으로 방 정보 업데이트
          final currentRoom = snapshot.hasData && snapshot.data!.exists
              ? Room.fromFirestore(snapshot.data!)
              : room;
          
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[400]!, Colors.blue[600]!],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('방 상세정보'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailInfoRow(
                      icon: Icons.vpn_key_outlined,
                      title: '그룹 코드',
                      content: currentRoom.roomCode,
                      onTap: () => _copyRoomCode(currentRoom),
                      showCopyIcon: true,
                    ),
                    Divider(height: 24),
                    _buildDetailInfoRow(
                      icon: Icons.calendar_today_outlined,
                      title: '생성일',
                      content: _formatDate(currentRoom.createdAt),
                    ),
                    Divider(height: 24),
                    _buildDetailInfoRow(
                      icon: Icons.edit_outlined,
                      title: '그룹 이름',
                      content: currentRoom.roomName,
                      onTap: () {
                        setDialogState(() {
                          _startEditingRoomName(currentRoom);
                        });
                      },
                      showEditIcon: !_isEditingRoomName,
                      isEditable: true,
                    ),
                    Divider(height: 24),
                    StreamBuilder<List<Refrigerator>>(
                      stream: _refrigeratorService.getRoomRefrigerators(currentRoom.id),
                      builder: (context, snapshot) {
                        int refrigeratorCount = snapshot.hasData ? snapshot.data!.length : 0;
                        return _buildDetailInfoRow(
                          icon: Icons.kitchen_outlined,
                          title: '냉장고 개수',
                          content: '${refrigeratorCount}개',
                        );
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      // 다이얼로그 닫을 때 수정모드도 해제
                      if (_isEditingRoomName) {
                        setState(() {
                          _isEditingRoomName = false;
                        });
                      }
                      Navigator.pop(context);
                    },
                    child: Text(
                      '닫기',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // 상세 정보 행 위젯
  Widget _buildDetailInfoRow({
    required IconData icon,
    required String title,
    required String content,
    VoidCallback? onTap,
    bool showCopyIcon = false,
    bool showEditIcon = false,
    bool isEditable = false,
  }) {
    return InkWell(
      onTap: (_isEditingRoomName && isEditable) ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.blue[600],
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  if (isEditable && _isEditingRoomName)
                    TextField(
                      controller: _roomNameController,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      decoration: InputDecoration(
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue[600]!),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                        ),
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        counterText: '', // 글자 수 카운터 숨김
                      ),
                      maxLength: 20,
                      autofocus: true,
                    )
                  else
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                ],
              ),
            ),
            // 수정모드일 때 체크/X 버튼, 아닐 때 기존 아이콘
            if (isEditable && _isEditingRoomName) ...[
              // 취소 버튼 (X)
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Colors.red[400],
                  size: 22,
                ),
                onPressed: _cancelEditingRoomName,
                tooltip: '취소',
                padding: EdgeInsets.all(4),
                constraints: BoxConstraints(),
              ),
              SizedBox(width: 4),
              // 저장 버튼 (체크)
              IconButton(
                icon: Icon(
                  Icons.check,
                  color: Colors.green[600],
                  size: 22,
                ),
                onPressed: () => _saveRoomName(_roomNameController.text),
                tooltip: '저장',
                padding: EdgeInsets.all(4),
                constraints: BoxConstraints(),
              ),
            ] else if (showCopyIcon) ...[
              Icon(
                Icons.copy_rounded,
                color: Colors.grey[400],
                size: 18,
              ),
            ] else if (showEditIcon) ...[
              Icon(
                Icons.edit_outlined,
                color: Colors.grey[400],
                size: 18,
              ),
            ] else if (onTap != null) ...[
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 밝고 깔끔한 2열 그리드 냉장고 카드
  Widget _buildCleanRefrigeratorCard(Refrigerator refrigerator) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToRefrigeratorDetail(refrigerator),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 아이콘
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF4E9FFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.kitchen_rounded,
                    color: Color(0xFF4E9FFF),
                    size: 24,
                  ),
                ),
                
                SizedBox(height: 14),
                
                // 냉장고 이름
                Text(
                  refrigerator.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                SizedBox(height: 4),
                
                // 냉장고 타입
                Text(
                  _getLayoutDisplayName(refrigerator.layout),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                Spacer(),
                
                // 하단 정보
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 식품 개수
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 15,
                            color: Color(0xFF4E9FFF),
                          ),
                          SizedBox(width: 5),
                          Text(
                            '${refrigerator.itemCount}개',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      
                      // 구분선
                      Container(
                        width: 1,
                        height: 12,
                        color: Colors.grey[300],
                      ),
                      
                      // 멤버 수
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 15,
                            color: Color(0xFF4E9FFF),
                          ),
                          SizedBox(width: 5),
                          Text(
                            '${refrigerator.memberIds.length}명',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 마이페이지 스타일 정보 칩 위젯
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required MaterialColor color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Color(0xFF6B9FFF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Color(0xFF6B9FFF),
          ),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B9FFF),
            ),
          ),
        ],
      ),
    );
  }

  // 레이아웃 표시 이름 변환
  String _getLayoutDisplayName(String layout) {
    switch (layout) {
      case 'single':
        return '1칸 냉장고';
      case 'vertical':
        return '2칸 세로';
      case 'horizontal':
        return '2칸 가로';
      case 'tripleTopTwo':
        return '3칸 냉장고';
      case 'tripleBottomTwo':
        return '3칸 냉장고';
      case 'quad':
        return '4칸 냉장고';
      default:
        return '기본형';
    }
  }

  // 그룹 이름 편집 시작
  void _startEditingRoomName(Room room) {
    setState(() {
      _isEditingRoomName = true;
      _roomNameController.text = room.roomName;
    });
  }

  // 그룹 이름 편집 취소
  void _cancelEditingRoomName() {
    setState(() {
      _isEditingRoomName = false;
      // 컨트롤러는 StreamBuilder에서 자동으로 최신 이름으로 복원됨
    });
  }

  // 그룹 이름 저장
  void _saveRoomName(String newName) async {
    if (newName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('그룹 이름을 입력해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Firestore에 저장
      bool success = await _roomService.updateRoomName(widget.room.id, newName.trim());
      
      if (success) {
        setState(() {
          _isEditingRoomName = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('그룹 이름이 변경되었습니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('그룹 이름 변경 권한이 없습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('그룹 이름 변경에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 검색 화면으로 이동
  void _navigateToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(roomId: widget.room.id),
      ),
    );
  }
} 
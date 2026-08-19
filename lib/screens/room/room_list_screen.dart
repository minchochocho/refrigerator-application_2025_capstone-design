import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/room.dart';
import '../../services/room_service.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'room_detail_screen.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({Key? key}) : super(key: key);

  @override
  _RoomListScreenState createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  final RoomService _roomService = RoomService();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // 헤더
          SliverAppBar(
            expandedHeight: 100,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Text(
                              '그룹 목록',
                              style: TextStyle(
                                color: Colors.grey[900],
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '참여 중인 그룹을 관리하세요',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // 그룹 생성/참여 버튼
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _showCreateRoomDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6B9FFF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, size: 18),
                            SizedBox(width: 6),
                            Text(
                              '그룹 생성',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => _showJoinRoomDialog(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF6B9FFF),
                          side: BorderSide(color: Color(0xFF6B9FFF), width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login_rounded, size: 18),
                            SizedBox(width: 6),
                            Text(
                              '그룹 참여',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 그룹 목록
          SliverToBoxAdapter(
            child: Container(
              color: Colors.grey[50],
              child: StreamBuilder<List<Room>>(
                stream: _roomService.getUserRoomsWithRealTimeUpdates(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 400,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B9FFF)),
                        ),
                      ),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return Container(
                      height: 400,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[300],
                            ),
                            SizedBox(height: 16),
                            Text(
                              '오류가 발생했습니다',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '${snapshot.error}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  List<Room> rooms = snapshot.data ?? [];
                  
                  if (rooms.isEmpty) {
                    return Container(
                      height: 400,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.meeting_room_outlined,
                                size: 48,
                                color: Color(0xFF6B9FFF),
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              '참여 중인 그룹이 없습니다',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '새로운 그룹을 만들거나 참여해보세요',
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
                  
                  return Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: rooms.map((room) {
                        bool isCreator = room.roomCreator == _roomService.currentUserId;
                        
                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RoomDetailScreen(room: room),
                                  ),
                                );
                                if (result == true && mounted) {
                                  setState(() {});
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // 그룹 아이콘
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: isCreator 
                                            ? Color(0xFFFCBA50).withOpacity(0.1)
                                            : Color(0xFF6B9FFF).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.group_rounded,
                                        color: isCreator 
                                            ? Color(0xFFFCBA50)
                                            : Color(0xFF6B9FFF),
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    
                                    // 그룹 정보
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  room.roomName,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey[800],
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.people_outline_rounded,
                                                size: 14,
                                                color: Colors.grey[500],
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                '멤버 ${room.memberIds.length}명',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                              if (isCreator) ...[
                                                SizedBox(width: 8),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Color(0xFFFCBA50),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '방장',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // 화살표
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.grey[400],
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 간단한 그룹 생성 팝업
  void _showCreateRoomDialog(BuildContext context) {
    final TextEditingController roomNameController = TextEditingController();
    bool isCreating = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 아이콘
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Color(0xFF6B9FFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: Color(0xFF6B9FFF),
                        size: 28,
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // 제목
                    Text(
                      '새로운 그룹 생성',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    
                    SizedBox(height: 8),
                    
                    // 설명
                    Text(
                      '그룹 이름을 입력하고 그룹을 생성하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // 입력 필드
                    TextField(
                      controller: roomNameController,
                      decoration: InputDecoration(
                        hintText: '그룹 이름을 입력하세요',
                        errorText: errorMessage,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF6B9FFF), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      maxLength: 30,
                      textInputAction: TextInputAction.done,
                    ),
                    
                    SizedBox(height: 20),
                    
                    // 버튼들
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              '취소',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isCreating ? null : () async {
                              String roomName = roomNameController.text.trim();
                              
                              if (roomName.isEmpty) {
                                setState(() {
                                  errorMessage = '그룹 이름을 입력해주세요';
                                });
                                return;
                              }

                              setState(() {
                                isCreating = true;
                                errorMessage = null;
                              });

                              try {
                                Room? createdRoom = await _roomService.createRoom(roomName);
                                
                                if (createdRoom != null) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('그룹이 성공적으로 생성되었습니다!'),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                } else {
                                  setState(() {
                                    isCreating = false;
                                    errorMessage = '그룹 생성에 실패했습니다';
                                  });
                                }
                              } catch (e) {
                                setState(() {
                                  isCreating = false;
                                  errorMessage = '오류가 발생했습니다';
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF6B9FFF),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: isCreating
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    '생성',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 간단한 그룹 참여 팝업
  void _showJoinRoomDialog(BuildContext context) {
    final TextEditingController roomCodeController = TextEditingController();
    bool isJoining = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 아이콘
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Color(0xFF6B9FFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.login_rounded,
                        color: Color(0xFF6B9FFF),
                        size: 28,
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // 제목
                    Text(
                      '그룹 참여',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    
                    SizedBox(height: 8),
                    
                    // 설명
                    Text(
                      '6자리 초대 코드를 입력하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // 코드 입력 필드
                    TextField(
                      controller: roomCodeController,
                      decoration: InputDecoration(
                        hintText: '––––––',
                        hintStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 10,
                          color: Colors.grey[400],
                        ),
                        errorText: errorMessage,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF6B9FFF), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 4,
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                    
                    SizedBox(height: 20),
                    
                    // 버튼들
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              '취소',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isJoining ? null : () async {
                              String roomCode = roomCodeController.text.trim().toUpperCase();
                              
                              if (roomCode.isEmpty) {
                                setState(() {
                                  errorMessage = '코드를 입력해주세요';
                                });
                                return;
                              }

                              if (roomCode.length != 6) {
                                setState(() {
                                  errorMessage = '6자리 코드를 입력해주세요';
                                });
                                return;
                              }

                              setState(() {
                                isJoining = true;
                                errorMessage = null;
                              });

                              try {
                                bool success = await _roomService.joinRoomByCode(roomCode);
                                
                                if (success) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('그룹에 성공적으로 참여했습니다!'),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setState(() {
                                  isJoining = false;
                                  errorMessage = e.toString().replaceAll('Exception: ', '');
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF6B9FFF),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: isJoining
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    '참여',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

} 
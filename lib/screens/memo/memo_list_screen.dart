import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'memo_edit_screen.dart';

class MemoListScreen extends StatefulWidget {
  final String roomId;
  final String compartmentName; // 호환성을 위해 유지하지만 실제로는 사용하지 않음

  const MemoListScreen({
    Key? key,
    required this.roomId,
    required this.compartmentName,
  }) : super(key: key);

  @override
  _MemoListScreenState createState() => _MemoListScreenState();
}

class _MemoListScreenState extends State<MemoListScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  List<Map<String, dynamic>> memos = [];
  bool isLoading = true;
  String sortOption = 'updated'; // 'updated', 'created', 'title'

  // 닉네임 캐시
  final Map<String, String> _nicknameCache = {};

  Future<String> _getNickname(String authorId, [String? fallback]) async {
    if (_nicknameCache.containsKey(authorId)) {
      return _nicknameCache[authorId]!;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(authorId).get();
      final nickname = userDoc.data()?['nickname'] ?? fallback ?? '사용자';
      _nicknameCache[authorId] = nickname;
      return nickname;
    } catch (e) {
      return fallback ?? '사용자';
    }
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _loadMemos();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadMemos() async {
    try {
      // 방 전체 메모 로드 (compartmentName 조건 제거)
      final querySnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('memos')
          .get();

      final memosData = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // 선택된 정렬 옵션에 따라 정렬
      _sortMemos(memosData);

      setState(() {
        memos = memosData;
        isLoading = false;
      });
      
      print('메모 로드 완료: ${memos.length}개');
    } catch (e) {
      print('메모 로드 오류: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _sortMemos(List<Map<String, dynamic>> memosData) {
    switch (sortOption) {
      case 'updated':
        memosData.sort((a, b) {
          final aTime = a['updatedAt'] ?? a['createdAt'];
          final bTime = b['updatedAt'] ?? b['createdAt'];
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return (bTime as Timestamp).compareTo(aTime as Timestamp);
        });
        break;
      case 'created':
        memosData.sort((a, b) {
          final aTime = a['createdAt'];
          final bTime = b['createdAt'];
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return (bTime as Timestamp).compareTo(aTime as Timestamp);
        });
        break;
      case 'title':
        memosData.sort((a, b) {
          final aTitle = (a['title'] ?? '').toString().toLowerCase();
          final bTitle = (b['title'] ?? '').toString().toLowerCase();
          return aTitle.compareTo(bTitle);
        });
        break;
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '정렬 옵션',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildSortOption('updated', '수정날짜 순', Icons.schedule),
            _buildSortOption('created', '만든날짜 순', Icons.add_circle_outline),
            _buildSortOption('title', '제목 순', Icons.sort_by_alpha),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String value, String label, IconData icon) {
    final isSelected = sortOption == value;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue[600] : Colors.grey[600],
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.blue[600] : Colors.black87,
        ),
      ),
      trailing: isSelected 
          ? Icon(Icons.check, color: Colors.blue[600])
          : null,
      onTap: () {
        setState(() {
          sortOption = value;
        });
        Navigator.pop(context);
        _loadMemos(); // 정렬 변경 시 다시 로드
      },
    );
  }

  String _getSortLabel() {
    switch (sortOption) {
      case 'updated':
        return '수정날짜 순';
      case 'created':
        return '만든날짜 순';
      case 'title':
        return '제목 순';
      default:
        return '수정날짜 순';
    }
  }

  void _showSearchDialog() {
    final searchController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.search, color: Colors.blue[600]),
            SizedBox(width: 8),
            Text('메모 검색'),
          ],
        ),
        content: TextField(
          controller: searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '검색할 메모 제목이나 내용을 입력하세요',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) {
            Navigator.pop(context);
            _performSearch(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performSearch(searchController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            child: Text('검색'),
          ),
        ],
      ),
    );
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      _loadMemos();
      return;
    }

    final filteredMemos = memos.where((memo) {
      final title = (memo['title'] ?? '').toString().toLowerCase();
      final content = (memo['content'] ?? '').toString().toLowerCase();
      final searchQuery = query.toLowerCase();
      
      return title.contains(searchQuery) || content.contains(searchQuery);
    }).toList();

    setState(() {
      memos = filteredMemos;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${filteredMemos.length}개의 메모를 찾았습니다'),
        action: SnackBarAction(
          label: '전체보기',
          onPressed: () => _loadMemos(),
        ),
      ),
    );
  }

  Future<void> _createNewMemo() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemoEditScreen(
          roomId: widget.roomId,
          compartmentName: widget.compartmentName,
        ),
      ),
    );

    if (result == true) {
      _loadMemos();
    }
  }

  Future<void> _editMemo(Map<String, dynamic> memo) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemoEditScreen(
          roomId: widget.roomId,
          compartmentName: widget.compartmentName,
          memoId: memo['id'],
          initialTitle: memo['title'],
          initialContent: memo['content'],
        ),
      ),
    );

    if (result == true) {
      _loadMemos();
    }
  }

  Future<void> _deleteMemo(String memoId) async {
    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('memos')
          .doc(memoId)
          .delete();

      _loadMemos();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('메모가 삭제되었습니다'),
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
          content: Text('삭제 중 오류가 발생했습니다'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  void _showDeleteDialog(String memoId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red[600]),
            SizedBox(width: 8),
            Text('메모 삭제'),
          ],
        ),
        content: Text('정말로 "$title" 메모를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMemo(memoId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: Text('삭제'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '메모장',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            Text(
              widget.compartmentName,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.grey[700]),
            onPressed: _showSearchDialog,
            tooltip: '메모 검색',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeController,
        child: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '메모를 불러오는 중...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : memos.isEmpty
                ? _buildEmptyState()
                : _buildMemoGrid(),
      ),
      floatingActionButton: ScaleTransition(
        scale: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _fadeController,
            curve: Interval(0.6, 1.0, curve: Curves.elasticOut),
          ),
        ),
        child: FloatingActionButton(
          onPressed: _createNewMemo,
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          elevation: 6,
          child: Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.note_add,
              size: 64,
              color: Colors.blue[300],
            ),
          ),
          SizedBox(height: 24),
          Text(
            '아직 메모가 없습니다',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            '첫 번째 메모를 작성해보세요',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _createNewMemo,
            icon: Icon(Icons.add),
            label: Text('메모 작성하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoGrid() {
    return Column(
      children: [
        // 헤더 정보
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Icon(Icons.description, color: Colors.grey[600], size: 20),
              SizedBox(width: 8),
              Text(
                '노트 ${memos.length}개',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              Spacer(),
              GestureDetector(
                onTap: _showSortOptions,
                child: Row(
                  children: [
                    Icon(Icons.sort, color: Colors.grey[600], size: 16),
                    SizedBox(width: 4),
                    Text(
                      _getSortLabel(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down, color: Colors.grey[600], size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // 메모 그리드 (삼성 노트 스타일)
        Expanded(
          child: Container(
            color: Color(0xFFF8F9FA),
            child: GridView.builder(
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8, // 삼성 노트와 유사한 비율
              ),
              itemCount: memos.length,
              itemBuilder: (context, index) {
                return _buildSamsungNoteCard(memos[index], index);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSamsungNoteCard(Map<String, dynamic> memo, int index) {
    final title = memo['title'] ?? '';
    final content = memo['content'] ?? '';
    final updatedAt = memo['updatedAt'] as Timestamp?;
    final createdAt = memo['createdAt'] as Timestamp?;
    final dateToShow = updatedAt ?? createdAt;
    final dateString = dateToShow != null 
        ? _formatDate(dateToShow.toDate())
        : '';
    final authorNickname = memo['authorNickname'];
    final authorId = memo['authorId'];

    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        final animationValue = Interval(
          index * 0.1,
          (index * 0.1) + 0.3,
          curve: Curves.easeOutBack,
        ).transform(_fadeController.value);

        return Transform.translate(
          offset: Offset(0, 50 * (1 - animationValue)),
          child: Opacity(
            opacity: animationValue,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _editMemo(memo),
        onLongPress: () => _showDeleteDialog(memo['id'], title.isEmpty ? '제목 없음' : title),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 메모 내용 미리보기 영역 (삼성 노트 스타일)
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 내용 미리보기 (제목이 없으면 내용을 크게 표시)
                      if (title.isNotEmpty) ...[
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (content.isNotEmpty) SizedBox(height: 6),
                      ],
                      
                      if (content.isNotEmpty)
                        Expanded(
                          child: Text(
                            content,
                            style: TextStyle(
                              fontSize: title.isNotEmpty ? 12 : 14,
                              color: Colors.grey[700],
                              height: 1.3,
                            ),
                            maxLines: title.isNotEmpty ? 8 : 12,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      
                      // 빈 메모인 경우
                      if (title.isEmpty && content.isEmpty)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.note_outlined,
                                color: Colors.grey[300],
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '빈 메모',
                                style: TextStyle(
                                  color: Colors.grey[400],
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
              
              // 하단 정보 바 (삼성 노트 스타일)
              Container(
                height: 32,
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    // 작성자 닉네임 표시
                    FutureBuilder<String>(
                      future: authorNickname != null && authorNickname.toString().isNotEmpty
                          ? Future.value(authorNickname)
                          : _getNickname(authorId ?? '', authorId),
                      builder: (context, snapshot) {
                        final name = snapshot.data ?? '작성자';
                        return Text(
                          name,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    SizedBox(width: 8),
                    Text(
                      dateString,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '오늘 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '어제';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${date.month}월 ${date.day}일';
    }
  }
} 
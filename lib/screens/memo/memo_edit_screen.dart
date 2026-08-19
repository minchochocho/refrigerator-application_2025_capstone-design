import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MemoEditScreen extends StatefulWidget {
  final String roomId;
  final String compartmentName; // 호환성을 위해 유지하지만 실제로는 사용하지 않음
  final String? memoId;
  final String? initialTitle;
  final String? initialContent;

  const MemoEditScreen({
    Key? key,
    required this.roomId,
    required this.compartmentName,
    this.memoId,
    this.initialTitle,
    this.initialContent,
  }) : super(key: key);

  @override
  _MemoEditScreenState createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends State<MemoEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
    
    // 변경 사항 감지
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasChanges = 
        _titleController.text != (widget.initialTitle ?? '') ||
        _contentController.text != (widget.initialContent ?? '');
    
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[600]),
            SizedBox(width: 8),
            Text('변경 사항 저장'),
          ],
        ),
        content: Text('저장하지 않은 변경 사항이 있습니다.\n정말로 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('계속 작성'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red[600],
            ),
            child: Text('나가기'),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  Future<void> _saveMemo() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('제목 또는 내용을 입력해주세요'),
          backgroundColor: Colors.orange[600],
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }
      String? nickname;
      try {
        final userDoc = await FirebaseFirestore.instance.collection('Users').doc(currentUser.uid).get();
        nickname = userDoc.data()?['nickname'] ?? currentUser.displayName ?? currentUser.email?.split('@')[0] ?? '사용자';
      } catch (e) {
        nickname = currentUser.displayName ?? currentUser.email?.split('@')[0] ?? '사용자';
      }

      if (widget.memoId == null) {
        // 새 메모 생성: 작성자 정보 저장
        final memoData = {
          'title': title.isEmpty ? '제목 없음' : title,
          'content': content,
          'updatedAt': Timestamp.now(),
          'createdAt': Timestamp.now(),
          'authorId': currentUser.uid,
          'authorEmail': currentUser.email,
          'authorNickname': nickname,
        };
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .collection('memos')
            .add(memoData);
      } else {
        // 기존 메모 수정: 작성자 정보는 건드리지 않음
        final memoRef = FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .collection('memos')
            .doc(widget.memoId);
        // 기존 데이터 불러오기
        final oldDoc = await memoRef.get();
        final oldData = oldDoc.data() ?? {};
        final memoData = {
          'title': title.isEmpty ? '제목 없음' : title,
          'content': content,
          'updatedAt': Timestamp.now(),
          // 작성자 정보는 기존 값 유지
          'authorId': oldData['authorId'],
          'authorEmail': oldData['authorEmail'],
          'authorNickname': oldData['authorNickname'],
        };
        await memoRef.update(memoData);
      }

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            widget.memoId == null ? '새 메모' : '메모 편집',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            // 저장 버튼
            TextButton.icon(
              onPressed: _isSaving ? null : _saveMemo,
              icon: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                      ),
                    )
                  : Icon(
                      Icons.save,
                      color: _hasChanges ? Colors.blue[600] : Colors.grey[400],
                    ),
              label: Text(
                '저장',
                style: TextStyle(
                  color: _hasChanges ? Colors.blue[600] : Colors.grey[400],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // 구분선
            Container(
              height: 1,
              color: Colors.grey[200],
            ),
            
            // 메모 작성 영역
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 제목 입력
                    TextField(
                      controller: _titleController,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                      decoration: InputDecoration(
                        hintText: '제목을 입력하세요',
                        hintStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      maxLength: 100,
                      buildCounter: (context, {required int currentLength, required bool isFocused, int? maxLength}) {
                        return Text(
                          '$currentLength/${maxLength ?? ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        );
                      },
                    ),
                    
                    // 제목과 내용 구분선
                    Container(
                      height: 1,
                      color: Colors.grey[200],
                      margin: EdgeInsets.symmetric(vertical: 8),
                    ),
                    
                    // 내용 입력 (윈도우 메모장 스타일)
                    Expanded(
                      child: TextField(
                        controller: _contentController,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          height: 1.5,
                          fontFamily: 'monospace', // 고정폭 폰트로 메모장 느낌
                        ),
                        decoration: InputDecoration(
                          hintText: '메모 내용을 입력하세요...\n\n윈도우 메모장처럼 자유롭게 작성하세요.',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                            height: 1.5,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(0),
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 하단 정보 표시
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${widget.compartmentName} • ${_contentController.text.length}자',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Spacer(),
                  if (_hasChanges)
                    Text(
                      '편집 중',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
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
} 
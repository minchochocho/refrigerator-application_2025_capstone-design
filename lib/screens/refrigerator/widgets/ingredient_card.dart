import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/refrigerator_service.dart';
import '../../../utils/icon_utils.dart';
import '../../../widgets/ingredients/stamp_with_tooltip.dart';
import '../constants/food_category_icons.dart';
import '../utils/ingredient_utils.dart';
import 'ingredient_image_widget.dart';

/// 재료 카드 위젯
class IngredientCard extends StatelessWidget {
  final Map<String, dynamic> ingredient;
  final int index;
  final String? highlightedIngredientId;
  final RefrigeratorService refrigeratorService;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLock;
  final VoidCallback onUnlock;
  final Function(String type) onTogglePreference;
  final VoidCallback onShowPreferenceDetails;
  final Function(DismissDirection direction) onDismiss;
  final Future<bool> Function(DismissDirection direction) confirmDismiss;
  
  const IngredientCard({
    Key? key,
    required this.ingredient,
    required this.index,
    required this.highlightedIngredientId,
    required this.refrigeratorService,
    required this.onEdit,
    required this.onDelete,
    required this.onLock,
    required this.onUnlock,
    required this.onTogglePreference,
    required this.onShowPreferenceDetails,
    required this.onDismiss,
    required this.confirmDismiss,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final DateTime? expiryDate = ingredient['expiryDate']?.toDate();
    final DateTime? manufactureDate = ingredient['manufactureDate']?.toDate();
    final String memo = ingredient['memo'] ?? '';
    final String foodName = ingredient['name'] ?? '';
    final bool isExpiring = expiryDate != null && 
        IngredientUtils.calculateDaysLeft(expiryDate) <= 3;
    final bool isExpired = expiryDate != null && 
        IngredientUtils.calculateDaysLeft(expiryDate) < 0;

    // 선호도 데이터 처리
    final Map<String, dynamic> preferences = ingredient['preferences'] ?? {};
    final List<String> likes = List<String>.from(preferences['likes'] ?? []);
    final List<String> dislikes = List<String>.from(preferences['dislikes'] ?? []);
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool userLiked = currentUserId != null && likes.contains(currentUserId);
    final bool userDisliked = currentUserId != null && dislikes.contains(currentUserId);

    // 잠금 관련 데이터 처리
    final bool isLocked = ingredient['isLocked'] ?? false;
    final String? lockedBy = ingredient['lockedBy'];
    final String? registeredBy = ingredient['registeredBy'];
    final bool canManage = refrigeratorService.canUserManageIngredient(ingredient);
    final bool canLock = refrigeratorService.canUserLockIngredient(ingredient);
    final bool canUnlock = refrigeratorService.canUserUnlockIngredient(ingredient);

    return Dismissible(
      key: Key('ingredient_${ingredient['id']}_$index'),
      background: _buildSwipeBackground(isLeft: true),
      secondaryBackground: _buildSwipeBackground(isLeft: false),
      onDismissed: onDismiss,
      confirmDismiss: confirmDismiss,
      child: Column(
        children: [
          Container(
        key: ValueKey('${ingredient['id']}_${ingredient['imagePath']}_${ingredient['name']}'),
        margin: EdgeInsets.only(
          bottom: 16,
          left: 8,
          right: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
              spreadRadius: 0,
              ),
          ],
          border: highlightedIngredientId == ingredient['id']
              ? Border.all(color: Color(0xFF6B9FFF), width: 2)
              : isExpired 
                  ? Border.all(color: Colors.red[400]!, width: 2)
                  : isExpiring 
                      ? Border.all(color: Colors.orange[400]!, width: 2)
                      : Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 왼쪽 구역: 이모지 아이콘 (전체 높이 기준 중앙)
                  Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ingredient['imagePath'] != null && ingredient['imagePath'].toString().isNotEmpty
                      ? IngredientImageWidget(
                          imagePath: ingredient['imagePath'].toString(),
                          width: 60,
                          height: 60,
                          fallbackIcon: _buildFoodIconOrEmoji(foodName),
                        )
                      : _buildFoodIconOrEmoji(foodName),
                    ),
                    if (isLocked)
                      _buildLockStamp(ingredient, size: 60),
                  ],
                ),
              ),
              SizedBox(width: 16),
              
              // 중간 구역: 제목 + 유통기한 + 선호도
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 제목
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: foodName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900],
                              height: 1.3,
                            ),
                          ),
                          TextSpan(
                            text: ' (${ingredient['quantity'] ?? 0})',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4A5568),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 4),
                    
                    // 유통기한
                    if (expiryDate != null)
                      Text(
                        '유통기한: ${IngredientUtils.formatDate(expiryDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isExpired
                              ? Colors.red[600]
                              : isExpiring
                                  ? Colors.orange[600]
                                  : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      )
                    else
                      Text(
                        '유통기한 정보 없음',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    
                    SizedBox(height: 10),
                    
                  // 선호도 (중간 구역 안) - 꾹 누르면 상세 정보
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => onTogglePreference('like'),
                          onLongPress: (likes.isNotEmpty || dislikes.isNotEmpty) ? onShowPreferenceDetails : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: userLiked ? Colors.red[50] : Colors.red[25],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: userLiked ? Colors.red[300]! : Colors.red[100]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  userLiked ? Icons.favorite : Icons.favorite_border,
                                  color: userLiked ? Colors.red[600] : Colors.red[300],
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '좋아요',
                                  style: TextStyle(
                                    color: userLiked ? Colors.red[700] : Colors.red[400],
                                    fontSize: 11,
                                    fontWeight: userLiked ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                                if (likes.isNotEmpty)
                                  Text(
                                    ' ${likes.length}',
                                    style: TextStyle(
                                      color: userLiked ? Colors.red[700] : Colors.red[400],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(width: 6),
                      
                      Expanded(
                        child: InkWell(
                          onTap: () => onTogglePreference('dislike'),
                          onLongPress: (likes.isNotEmpty || dislikes.isNotEmpty) ? onShowPreferenceDetails : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: userDisliked ? Colors.blue[50] : Colors.blue[25],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: userDisliked ? Colors.blue[300]! : Colors.blue[100]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  userDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                                  color: userDisliked ? Colors.blue[600] : Colors.blue[300],
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '싫어요',
                                  style: TextStyle(
                                    color: userDisliked ? Colors.blue[700] : Colors.blue[400],
                                    fontSize: 11,
                                    fontWeight: userDisliked ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                                if (dislikes.isNotEmpty)
                                  Text(
                                    ' ${dislikes.length}',
                                    style: TextStyle(
                                      color: userDisliked ? Colors.blue[700] : Colors.blue[400],
                                      fontSize: 11,
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
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // 오른쪽 상단 영역: 잠금/편집/메모 버튼 (가로로 나란히)
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canLock)
                Container(
                  margin: EdgeInsets.only(right: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onLock,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.lock_outline,
                          size: 20,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ),
                )
              else if (canUnlock)
                Container(
                  margin: EdgeInsets.only(right: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onUnlock,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.lock_open_outlined,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                )
              else if (isLocked)
                Container(
                  margin: EdgeInsets.only(right: 4),
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.lock,
                      size: 20,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              if (canManage)
                Container(
                  margin: EdgeInsets.only(right: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onEdit,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
              if (memo.trim().isNotEmpty)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showMemoDialog(context, memo),
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.sticky_note_2_outlined,
                        size: 22,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

      ],
    ),
          ),
        ],
      ),
    );
  }
  
  /// 스와이프 배경
  Widget _buildSwipeBackground({required bool isLeft}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12, left: 8, right: 8),
      decoration: BoxDecoration(
        color: isLeft ? Colors.green[400] : Colors.red[400],
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isLeft) ...[
            Icon(Icons.restaurant, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              '소비',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else ...[
            Text(
              '폐기',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white, size: 24),
          ],
        ],
      ),
    );
  }

  void _showMemoDialog(BuildContext context, String memo) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Transform.rotate(
            angle: -0.02, // 약간 기울어진 느낌
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 포스트잇 본체
                Container(
                  constraints: BoxConstraints(
                    maxWidth: 320,
                    minHeight: 180,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: Offset(4, 8),
                        spreadRadius: -2,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // 테이프 효과
                      Positioned(
                        top: -8,
                        left: 60,
                        right: 60,
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 내용
                      Padding(
                        padding: EdgeInsets.fromLTRB(24, 28, 24, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.push_pin,
                                  color: Color(0xFFF59E0B),
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Memo',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF92400E),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Container(
                              constraints: BoxConstraints(minHeight: 80),
                              child: Text(
                                memo,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.6,
                                  color: Color(0xFFA16207).withOpacity(0.65),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 닫기 버튼
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.brown.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// 메인 행 (이미지 + 정보 + 유통기한 + 버튼들)
  Widget _buildMainRow(
    BuildContext context,
    String foodName,
    DateTime? expiryDate,
    DateTime? manufactureDate,
    bool isExpired,
    bool isExpiring,
    bool isLocked,
    bool canManage,
    bool canLock,
    bool canUnlock,
  ) {
    final int? daysLeft = expiryDate != null ? IngredientUtils.calculateDaysLeft(expiryDate) : null;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 식품 이미지 또는 아이콘 (왼쪽, 세로 중앙)
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isExpired
                    ? Colors.red[50]
                    : isExpiring 
                        ? Colors.orange[50]
                    : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ingredient['imagePath'] != null && ingredient['imagePath'].toString().isNotEmpty
                  ? IngredientImageWidget(
                      imagePath: ingredient['imagePath'].toString(),
                      width: 44,
                      height: 44,
                      fallbackIcon: Icon(
                        FoodCategoryIcons.getFoodIcon(foodName),
                        color: isExpired 
                            ? Colors.red[600]
                            : isExpiring 
                                ? Colors.orange[600]
                                : Colors.grey[600],
                        size: 24,
                      ),
                    )
                  : Center(
                      child: Icon(
                        FoodCategoryIcons.getFoodIcon(foodName),
                        color: isExpired 
                            ? Colors.red[600]
                            : isExpiring 
                                ? Colors.orange[600]
                                : Colors.grey[600],
                        size: 24,
                      ),
                    ),
              ),
              if (isLocked)
                _buildLockStamp(ingredient, size: 44),
            ],
          ),
        ),
        SizedBox(width: 12),
        
        // 오른쪽 정보 영역
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 첫 번째 줄: 이름 + 버튼들
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$foodName (${ingredient['quantity'] ?? 0})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isLocked)
                    Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.lock, size: 16, color: Colors.orange[700]),
                    ),
                  // 수정/삭제 버튼
                  if (canLock)
                    _buildIconButton(
                      icon: Icons.lock_outline,
                      color: Colors.grey[500]!,
                      onPressed: onLock,
                    )
                  else if (canUnlock)
                    _buildIconButton(
                      icon: Icons.lock_open_outlined,
                      color: Colors.grey[500]!,
                      onPressed: onUnlock,
                    ),
                  if (canManage)
                    _buildIconButton(
                      icon: Icons.edit_outlined,
                      color: Colors.grey[500]!,
                      onPressed: onEdit,
                    ),
                  if (canManage)
                    _buildIconButton(
                      icon: Icons.delete_outline,
                      color: Colors.grey[500]!,
                      onPressed: onDelete,
                    ),
                ],
              ),
              
              SizedBox(height: 4),
              
              // 두 번째 줄: 유통기한
              if (expiryDate != null)
                Text(
                  '유통기한: ${IngredientUtils.formatDate(expiryDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpired
                        ? Colors.red[600]
                        : isExpiring
                            ? Colors.orange[600]
                            : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                )
              else
                Text(
                  '유통기한 정보 없음',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
              ),
            ],
          ),
          ),
      ],
    );
  }
  
  /// 아이콘 버튼 (작고 깔끔하게)
  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: color),
      padding: EdgeInsets.all(4),
      constraints: BoxConstraints(minWidth: 32, minHeight: 32),
      splashRadius: 20,
    );
  }
  
  /// 메모 섹션
  Widget _buildMemoSection(String memo) {
    return Padding(
      padding: EdgeInsets.only(left: 56), // 아이콘 너비 + 간격만큼 왼쪽 패딩
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.note_outlined,
              size: 14,
              color: Colors.grey[600],
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                memo,
      style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 선호도 섹션
  Widget _buildPreferenceSection(
    BuildContext context,
    bool userLiked,
    bool userDisliked,
    List<String> likes,
    List<String> dislikes,
  ) {
    return Padding(
      padding: EdgeInsets.only(left: 56), // 아이콘 너비 + 간격만큼 왼쪽 패딩
      child: Row(
      children: [
          // 좋아요
          InkWell(
              onTap: () => onTogglePreference('like'),
            borderRadius: BorderRadius.circular(16),
              child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      userLiked ? Icons.favorite : Icons.favorite_border,
                    color: Colors.grey[600],
                    size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '좋아요',
                      style: TextStyle(
                      color: Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (likes.isNotEmpty)
                      Text(
                      ' ${likes.length}',
                        style: TextStyle(
                        color: Colors.grey[700],
                          fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
            ),
          ),
        ),
        
        SizedBox(width: 8),
        
          // 싫어요
          InkWell(
              onTap: () => onTogglePreference('dislike'),
            borderRadius: BorderRadius.circular(16),
              child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      userDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                    color: Colors.blue[600],
                    size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '싫어요',
                      style: TextStyle(
                      color: Colors.blue[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (dislikes.isNotEmpty)
                      Text(
                      ' ${dislikes.length}',
                        style: TextStyle(
                        color: Colors.blue[700],
                          fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
      ),
    );
  }
  
  /// 잠금 도장 위젯 생성
  Widget _buildLockStamp(Map<String, dynamic> ingredient, {double size = 48}) {
    final stampSize = size * 0.7;
    
    return Positioned(
      top: size * 0.35,      // 더 아래로 내려서 중앙 근처에 위치
      right: -size * 0.35,  // 살짝 안쪽으로 조정
      child: FutureBuilder<Map<String, dynamic>>(
        future: _getUserInfo(ingredient['registeredBy']),
        builder: (context, snapshot) {
          final userInfo = snapshot.data ?? {};
          final nickname = userInfo['nickname'] ?? '사용자';
          final avatarColor = Color(userInfo['avatarColor'] ?? Colors.blue[400]!.value);
          final avatarIcon = IconUtils.getIconFromCodePoint(userInfo['avatarIcon'] as int?);
          
          return StampWithTooltip(
            nickname: nickname,
            avatarColor: avatarColor,
            avatarIcon: avatarIcon,
            stampSize: stampSize,
          );
        },
      ),
    );
  }
  
  /// 사용자 정보 가져오기
  Future<Map<String, dynamic>> _getUserInfo(String? userId) async {
    if (userId == null) return {
      'nickname': '알 수 없음', 
      'avatarColor': Colors.grey[400]!.value,
      'avatarIcon': IconUtils.defaultAvatarIcon.codePoint,
    };
    
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return {
          'nickname': userData['nickname'] ?? userData['displayName'] ?? '사용자',
          'avatarColor': userData['avatarColor'] ?? Colors.blue[400]!.value,
          'avatarIcon': userData['avatarIcon'] ?? IconUtils.defaultAvatarIcon.codePoint,
        };
      }
      
      return {
        'nickname': '사용자', 
        'avatarColor': Colors.blue[400]!.value,
        'avatarIcon': IconUtils.defaultAvatarIcon.codePoint,
      };
    } catch (e) {
      print('사용자 정보 조회 오류: $e');
      return {
        'nickname': '사용자', 
        'avatarColor': Colors.grey[400]!.value,
        'avatarIcon': IconUtils.defaultAvatarIcon.codePoint,
      };
    }
  }
  
  /// 이모지 매칭 함수
  static String _getEmojiForFood(String foodName) {
    final name = foodName.toLowerCase().trim();
    
    // 신선식품 특별 처리
    if (name == '신선식품' || name == '신선제품') return '🍙';
    
    // 유제품 (우선순위 높음 - 복합 단어 매칭)
    if (name.contains('우유') || name.contains('milk') || name.contains('밀크')) return '🥛';
    if (name.contains('치즈') || name.contains('cheese') || name.contains('체다') || name.contains('모짜렐라')) return '🧀';
    if (name.contains('요구르트') || name.contains('yogurt') || name.contains('요거트') || name.contains('야쿠르트')) return '🥛';
    if (name.contains('버터') || name.contains('butter')) return '🧈';
    if (name.contains('아이스크림') || name.contains('ice cream') || name.contains('빙수')) return '🍦';
    if (name.contains('크림') || name.contains('cream')) return '🥛';
    
    // 음료 (우선순위 높음)
    if (name.contains('커피') || name.contains('coffee') || name.contains('아메리카노') || name.contains('라떼')) return '☕';
    if (name.contains('차') || name.contains('tea') || name.contains('티') || name.contains('녹차') || name.contains('홍차')) return '🍵';
    if (name.contains('주스') || name.contains('juice')) return '🧃';
    if (name.contains('에이드') || name.contains('ade') || name.contains('레모네이드')) return '🍹';
    if (name.contains('스무디') || name.contains('smoothie')) return '🥤';
    if (name.contains('쉐이크') || name.contains('shake')) return '🥤';
    if (name.contains('탄산') || name.contains('콜라') || name.contains('사이다') || name.contains('coke') || name.contains('sprite') || name.contains('펩시')) return '🥤';
    if (name.contains('소주') || name.contains('soju') || name.contains('참이슬') || name.contains('처음처럼')) return '🍶';
    if (name.contains('맥주') || name.contains('beer') || name.contains('카스') || name.contains('하이트') || name.contains('테라')) return '🍺';
    if (name.contains('와인') || name.contains('wine') || name.contains('레드와인') || name.contains('화이트와인')) return '🍷';
    if (name.contains('칵테일') || name.contains('cocktail') || name.contains('하이볼') || name.contains('highball') || 
        name.contains('모히또') || name.contains('mojito') || name.contains('마가리타') || name.contains('margarita')) return '🍸';
    if (name.contains('위스키') || name.contains('whisky') || name.contains('whiskey') || name.contains('버번')) return '🥃';
    if (name.contains('보드카') || name.contains('vodka')) return '🍸';
    if (name.contains('진') || name.contains('gin') || name.contains('럼') || name.contains('rum') || name.contains('테킬라') || name.contains('tequila')) return '🍸';
    if (name.contains('샴페인') || name.contains('champagne') || name.contains('스파클링')) return '🍾';
    if (name.contains('막걸리')) return '🍶';
    if (name.contains('청하') || name.contains('정종') || name.contains('사케') || name.contains('sake')) return '🍶';
    if (name.contains('물') || name.contains('water') || name.contains('생수') || name.contains('탄산수') || name.contains('토닉워터')) return '💧';
    if (name.contains('이온음료') || name.contains('게토레이') || name.contains('포카리')) return '🥤';
    if (name.contains('에너지드링크') || name.contains('핫식스') || name.contains('레드불') || name.contains('몬스터')) return '🥤';
    
    // 과일류
    if (name.contains('사과')) return '🍎';
    if (name.contains('바나나')) return '🍌';
    if (name.contains('딸기')) return '🍓';
    if (name.contains('수박')) return '🍉';
    if (name.contains('포도')) return '🍇';
    if (name.contains('오렌지') || name.contains('귤') || name.contains('감귤') || name.contains('천혜향')) return '🍊';
    if (name.contains('레몬') || name.contains('라임')) return '🍋';
    if (name.contains('복숭아')) return '🍑';
    if (name.contains('체리') || name.contains('앵두')) return '🍒';
    if (name.contains('키위')) return '🥝';
    if (name.contains('파인애플')) return '🍍';
    if (name.contains('망고')) return '🥭';
    if (name.contains('배') && !name.contains('배추') && !name.contains('양배추')) return '🍐';
    if (name.contains('멜론') || name.contains('참외')) return '🍈';
    if (name.contains('블루베리')) return '🫐';
    if (name.contains('코코넛')) return '🥥';
    if (name.contains('아보카도')) return '🥑';
    if (name.contains('과일') || name.contains('fruit')) return '🍎';
    
    // 채소류
    if (name.contains('토마토')) return '🍅';
    if (name.contains('당근')) return '🥕';
    if (name.contains('브로콜리')) return '🥦';
    if (name.contains('양파')) return '🧅';
    if (name.contains('마늘')) return '🧄';
    if (name.contains('고추') || name.contains('피망') || name.contains('파프리카') || name.contains('청양고추')) return '🌶️';
    if (name.contains('감자') || name.contains('potato')) return '🥔';
    if (name.contains('옥수수') || name.contains('corn')) return '🌽';
    if (name.contains('가지')) return '🍆';
    if (name.contains('양배추') || name.contains('배추') || name.contains('cabbage')) return '🥬';
    if (name.contains('상추') || name.contains('샐러드') || name.contains('lettuce') || name.contains('salad')) return '🥗';
    if (name.contains('오이') || name.contains('cucumber')) return '🥒';
    if (name.contains('버섯') || name.contains('mushroom') || name.contains('표고') || name.contains('새송이')) return '🍄';
    if (name.contains('호박') || name.contains('애호박') || name.contains('단호박')) return '🎃';
    if (name.contains('무') && !name.contains('무화과')) return '🥬';
    if (name.contains('파') || name.contains('대파') || name.contains('쪽파')) return '🥬';
    if (name.contains('김치') || name.contains('kimchi')) return '🥬';
    if (name.contains('야채') || name.contains('채소') || name.contains('vegetable')) return '🥬';
    
    // 육류
    if (name.contains('소고기') || name.contains('쇠고기') || name.contains('beef') || name.contains('steak')) return '🥩';
    if (name.contains('돼지고기') || name.contains('삼겹살') || name.contains('pork') || name.contains('목살') || name.contains('앞다리')) return '🥓';
    if (name.contains('닭고기') || name.contains('chicken') || name.contains('치킨') || name.contains('닭') || name.contains('계육')) return '🍗';
    if (name.contains('베이컨') || name.contains('bacon')) return '🥓';
    if (name.contains('햄') || name.contains('ham') || name.contains('스팸')) return '🍖';
    if (name.contains('소시지') || name.contains('sausage') || name.contains('핫도그')) return '🌭';
    if (name.contains('갈비') || name.contains('ribs')) return '🍖';
    if (name.contains('고기') || name.contains('meat')) return '🥩';
    
    // 해산물
    if (name.contains('생선') || name.contains('fish') || name.contains('고등어') || name.contains('연어') || 
        name.contains('삼치') || name.contains('갈치') || name.contains('참치') || name.contains('salmon') ||
        name.contains('tuna') || name.contains('mackerel')) return '🐟';
    if (name.contains('새우') || name.contains('shrimp') || name.contains('prawn')) return '🦐';
    if (name.contains('게') || name.contains('crab') || name.contains('킹크랩') || name.contains('대게')) return '🦀';
    if (name.contains('오징어') || name.contains('squid') || name.contains('갑오징어')) return '🦑';
    if (name.contains('조개') || name.contains('clam') || name.contains('바지락') || name.contains('대합') ||
        name.contains('굴') || name.contains('oyster')) return '🦪';
    if (name.contains('문어') || name.contains('octopus') || name.contains('주꾸미')) return '🐙';
    if (name.contains('랍스터') || name.contains('lobster')) return '🦞';
    
    // 계란
    if (name.contains('계란') || name.contains('달걀') || name.contains('egg')) return '🥚';
    
    // 빵류
    if (name.contains('식빵') || name.contains('bread')) return '🍞';
    if (name.contains('크루아상') || name.contains('croissant')) return '🥐';
    if (name.contains('베이글') || name.contains('bagel')) return '🥯';
    if (name.contains('도넛') || name.contains('doughnut')) return '🍩';
    if (name.contains('케이크') || name.contains('cake')) return '🍰';
    if (name.contains('쿠키') || name.contains('cookie') || name.contains('비스킷')) return '🍪';
    if (name.contains('빵') && !name.contains('식빵')) return '🥖';
    
    // 한식/두부
    if (name.contains('된장') || name.contains('고추장') || name.contains('쌈장')) return '🥫';
    if (name.contains('두부') || name.contains('tofu')) return '⬜';
    if (name.contains('콩') || name.contains('bean') || name.contains('soybean')) return '🫘';
    if (name.contains('떡') || name.contains('rice cake') || name.contains('떡볶이')) return '🍡';
    if (name.contains('김') || name.contains('seaweed') || name.contains('미역')) return '🌊';
    
    // 면류
    if (name.contains('라면') || name.contains('ramen') || name.contains('instant noodle')) return '🍜';
    if (name.contains('파스타') || name.contains('pasta') || name.contains('스파게티')) return '🍝';
    if (name.contains('우동') || name.contains('udon')) return '🍜';
    if (name.contains('냉면') || name.contains('국수') || name.contains('noodle')) return '🍜';
    
    // 밥/곡물류
    if (name.contains('밥') || name.contains('rice') || name.contains('쌀')) return '🍚';
    if (name.contains('김밥')) return '🍱';
    if (name.contains('주먹밥')) return '🍙';
    if (name.contains('초밥') || name.contains('sushi')) return '🍣';
    if (name.contains('볶음밥') || name.contains('fried rice')) return '🍛';
    if (name.contains('카레') || name.contains('curry')) return '🍛';
    if (name.contains('시리얼') || name.contains('cereal')) return '🥣';
    
    // 패스트푸드/간편식
    if (name.contains('피자') || name.contains('pizza')) return '🍕';
    if (name.contains('햄버거') || name.contains('burger')) return '🍔';
    if (name.contains('샌드위치') || name.contains('sandwich')) return '🥪';
    if (name.contains('타코') || name.contains('taco') || name.contains('부리또')) return '🌮';
    if (name.contains('핫도그') || name.contains('hot dog')) return '🌭';
    if (name.contains('감자튀김') || name.contains('fries')) return '🍟';
    if (name.contains('도시락') || name.contains('bento')) return '🍱';
    
    // 디저트/간식
    if (name.contains('초콜릿') || name.contains('초코') || name.contains('chocolate')) return '🍫';
    if (name.contains('사탕') || name.contains('candy')) return '🍬';
    if (name.contains('팝콘') || name.contains('popcorn')) return '🍿';
    if (name.contains('과자') || name.contains('snack') || name.contains('칩')) return '🍘';
    if (name.contains('젤리') || name.contains('jelly') || name.contains('gummy')) return '🍬';
    if (name.contains('푸딩') || name.contains('pudding')) return '🍮';
    if (name.contains('마카롱') || name.contains('macaron')) return '🍪';
    if (name.contains('와플') || name.contains('waffle')) return '🧇';
    if (name.contains('팬케이크') || name.contains('pancake')) return '🥞';
    
    // 조미료
    if (name.contains('소금') || name.contains('salt')) return '🧂';
    if (name.contains('설탕') || name.contains('sugar')) return '🧂';
    if (name.contains('꿀') || name.contains('honey')) return '🍯';
    if (name.contains('간장') || name.contains('soy sauce')) return '🥫';
    if (name.contains('식초') || name.contains('vinegar')) return '🥫';
    if (name.contains('기름') || name.contains('oil') || name.contains('오일')) return '🫗';
    if (name.contains('소스') || name.contains('sauce')) return '🥫';
    if (name.contains('마요') || name.contains('mayonnaise')) return '🥫';
    if (name.contains('케첩') || name.contains('ketchup')) return '🥫';
    if (name.contains('통조림') || name.contains('can')) return '🥫';
    
    // 견과류
    if (name.contains('견과') || name.contains('nuts')) return '🥜';
    if (name.contains('땅콩') || name.contains('peanut')) return '🥜';
    if (name.contains('아몬드') || name.contains('almond')) return '🥜';
    if (name.contains('호두') || name.contains('walnut')) return '🥜';
    
    // 기본값 (null 반환하여 아이콘 사용)
    return '🥘';
  }
  
  /// 음식 아이콘 또는 이모지 빌더
  static Widget _buildFoodIconOrEmoji(String foodName) {
    final emoji = _getEmojiForFood(foodName);
    
    // 이모지 표시
    return Center(
      child: Text(
        emoji,
        style: TextStyle(fontSize: 30),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Services
import '../../services/refrigerator_service.dart';
import '../../services/auth_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/statistics_service.dart';
import '../../services/search_service.dart';
import '../../services/vision_config.dart';
import '../../services/groq_client.dart';
import '../../services/groq_local_config.dart';
import '../../services/image_edit_service.dart';

// Widgets & Screens
import '../../widgets/ingredients/stamp_with_tooltip.dart';
import '../../widgets/ingredients/scroll_date_picker_dialog.dart';
import '../main_screen.dart';
import '../memo/memo_list_screen.dart';
import '../search/search_screen.dart';
import 'refrigerator_compartment_screen.dart';
import '../expiration/expiring_overview_screen.dart';
import '../batch_registration_screen.dart';
import '../../date_recognition/camera_screen.dart';
import 'refrigerator_compartment_settings_screen.dart';
import 'dialogs/quick_compartment_name_edit_dialog.dart';

// Barcode System
import '../../barcode_system/barcode_scanner_screen.dart';
import '../../barcode_system/barcode_model.dart';
import '../../barcode_system/barcode_service.dart';
import '../../barcode_system/serp_search_service.dart';

// Models
import '../../models/receipt_item.dart';
import '../../models/selectable_receipt_item.dart';
import '../../models/refrigerator.dart';

// Utils
import '../../utils/receipt_parse_utils.dart';
import '../../utils/icon_utils.dart';
import '../../utils/expiry_utils.dart';

// Local Modules (분리된 파일들)
import 'constants/food_category_icons.dart';
import 'utils/ingredient_utils.dart';
import 'widgets/ingredient_card.dart';
import 'widgets/ingredient_image_widget.dart';
import 'widgets/sort_counter_bar.dart';
import 'widgets/ingredient_list_section.dart';
import 'dialogs/expiring_bottom_sheet.dart';
import 'logic/receipt_scanner_logic.dart';
import 'logic/barcode_scanner_logic.dart';
import 'logic/ingredient_management_logic.dart';
import 'logic/ingredients_controller.dart';
import 'dialogs/add_ingredient_dialog.dart';
import 'dialogs/receipt_dialogs.dart';
import 'dialogs/barcode_dialogs.dart';
import 'logic/receipt_scanner_logic.dart';
import 'dialogs/common_dialogs.dart';
import 'dialogs/preference_details_dialog.dart';

// 분리된 바텀시트/위젯/헬퍼
import 'dialogs/sort_menu_sheet.dart';
import 'dialogs/add_method_sheet.dart';
import 'widgets/date_field.dart';
import '../../utils/image_pick_helper.dart';

part 'ingredients_scanning_mixin.dart';
part 'ingredients_actions_mixin.dart';
part 'ingredients_scroll_mixin.dart';
part 'ingredients_tabs_sort_mixin.dart';

/// 날짜를 UTC 자정으로 변환 (타임존 문제 해결)
DateTime _toUtcMidnight(DateTime localDate) {
  final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);
  return DateTime.utc(dateOnly.year, dateOnly.month, dateOnly.day);
}

/// UTC 자정 날짜를 로컬 날짜로 변환
DateTime _fromUtcMidnight(DateTime utcDate) {
  return DateTime(utcDate.year, utcDate.month, utcDate.day);
}

class IngredientsScreen extends StatefulWidget {
  final String roomId;
  final String refrigeratorName;
  final String compartmentName;
  final int compartmentIndex;
  final String? targetIngredientId; // 특정 식품으로 스크롤하기 위한 ID
  final List<String>? availableCompartments; // 사용 가능한 칸 목록

  const IngredientsScreen({
    Key? key,
    required this.roomId,
    required this.refrigeratorName,
    required this.compartmentName,
    required this.compartmentIndex,
    this.targetIngredientId,
    this.availableCompartments,
  }) : super(key: key);

  @override
  _IngredientsScreenState createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> with TickerProviderStateMixin, IngredientsScanningMixin, IngredientsActionsMixin, IngredientsScrollMixin, IngredientsTabsSortMixin {
  bool _isLoading = false;
  final RefrigeratorService _refrigeratorService = RefrigeratorService();
  final AuthService _authService = AuthService();
  final ImageUploadService _imageUploadService = ImageUploadService();
  final StatisticsService _statisticsService = StatisticsService();
  final GroqClient _groq = GroqClient();
  final SearchService _searchService = SearchService();
  bool _isProcessingBarcode = false;
  
  // 분리된 로직 클래스들
  late ReceiptScannerLogic _receiptScanner;
  late BarcodeScannerLogic _barcodeScanner;
  late IngredientManagementLogic _ingredientManager;
  
  late String _currentCompartmentName;
  
  // 현재 칸의 재료 데이터
  List<Map<String, dynamic>> _ingredients = [];
  List<Map<String, dynamic>> _filteredIngredients = [];
  String _searchQuery = '';

  // 상단 AppBar 검색 상태
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchingData = false;
  bool _hasSearched = false;
  
  // 하이라이트 관련 상태
  String? _highlightedIngredientId;
  bool _hasScrolledToTarget = false;
  
  // 실시간 스트림 구독
  Stream<List<Map<String, dynamic>>>? _ingredientsStream;
  
  // 모든 탭의 스트림을 미리 로드 (프리로딩)
  final Map<int, Stream<List<Map<String, dynamic>>>> _preloadedStreams = {};
  
  // 각 탭의 최신 데이터 캐시 (즉시 표시용)
  final Map<int, List<Map<String, dynamic>>> _cachedTabData = {};
  
  // 스크롤 위치 유지를 위한 컨트롤러
  late ScrollController _scrollController;
  double _savedScrollPosition = 0.0;
  
  // 각 카드에 대한 GlobalKey 저장
  final Map<String, GlobalKey> _itemKeysById = {};
  
  // 탭 관련
  TabController? _tabController;
  List<String> _compartmentNames = [];
  Refrigerator? _refrigerator;
  
  // 탭 이름 편집 상태
  int? _editingTabIndex;
  
  // 탭 변경 중복 방지
  int _lastChangedIndex = -1;
  int _currentTabIndex = 0; // 현재 표시 중인 탭 인덱스
  final TextEditingController _tabNameController = TextEditingController();
  final FocusNode _tabNameFocusNode = FocusNode();
  
  // 정렬 상태
  String _sortBy = 'date'; // 'date', 'expiry', 'name', 'likes'
  final IngredientsController _controller = IngredientsController();
  
  @override
  void initState() {
    super.initState();
    _currentCompartmentName = widget.compartmentName;
    _currentTabIndex = widget.compartmentIndex; // 초기 탭 인덱스 설정
    _scrollController = ScrollController();
    
    // 분리된 로직 클래스 초기화
    _receiptScanner = ReceiptScannerLogic();
    _barcodeScanner = BarcodeScannerLogic();
    _ingredientManager = IngredientManagementLogic(
      refrigeratorService: _refrigeratorService,
      authService: _authService,
      imageUploadService: _imageUploadService,
      statisticsService: _statisticsService,
    );
    
    // 즉시 필수 데이터/스트림 초기화 후, 정렬 설정은 비차단적으로 로드
    _loadRefrigeratorData();
    _initializeStream();
    _initializeWithSavedSort();
  }
  
  // 정렬 설정을 불러온 후 데이터 초기화
  Future<void> _initializeWithSavedSort() async {
    try {
      await _loadSavedSortPreference(); // 정렬 설정 로드 (UI 차단 없이)
      if (!mounted) return;
      setState(() {
        _controller.setSort(_sortBy);
        // 저장된 정렬 기준이 있을 경우, 현재 목록에도 즉시 반영
        _applySorting();
      });
    } catch (e) {
      // 정렬 설정 실패는 치명적이지 않으므로 무시
    }
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _tabController?.dispose();
    _tabNameController.dispose();
    _tabNameFocusNode.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  
  
  
  
  
  
  // 탭 이름 인라인 편집 시작
  void _startEditingTab(int index, String currentName) {
    setState(() {
      _editingTabIndex = index;
      _tabNameController.text = currentName;
    });
    
    // 포커스 요청
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tabNameFocusNode.requestFocus();
    });
  }
  
  // 탭 이름 편집 완료
  Future<void> _finishEditingTab() async {
    if (_editingTabIndex == null) return;
    
    final index = _editingTabIndex!;
    final newName = _tabNameController.text.trim();
    final oldName = _compartmentNames[index];
    
    setState(() {
      _editingTabIndex = null;
    });
    
    if (newName.isNotEmpty && newName != oldName) {
      await _saveCompartmentName(index, newName);
    }
  }
  
  // 탭 이름 편집 취소
  void _cancelEditingTab() {
    setState(() {
      _editingTabIndex = null;
    });
  }

  // 방 전체 냉장고 검색 (그룹 목록 검색과 동일한 로직)
  Future<void> _performGlobalSearch(String query) async {
    if (widget.roomId.isEmpty) return;

    setState(() {
      _isSearchingData = true;
      _hasSearched = true;
    });

    try {
      final results = await _searchService.searchIngredientsInRoom(
        widget.roomId,
        query,
      );
      setState(() {
        _searchResults = results;
        _isSearchingData = false;
      });
    } catch (e) {
      print('냉장고 화면 검색 오류: $e');
      setState(() {
        _searchResults = [];
        _isSearchingData = false;
      });
    }
  }

  Widget _buildGlobalSearchResults() {
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
        return _buildGlobalSearchResultCard(item);
      },
    );
  }

  Widget _buildGlobalSearchResultCard(Map<String, dynamic> item) {
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
          // 현재 식품목록 화면을, 검색 결과에 해당하는 냉장고/칸 선택 화면으로 교체하고
          // 그 화면에서 자동으로 해당 칸의 식품목록으로 진입하도록 구성
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              settings: RouteSettings(name: 'refrigerator_compartment'),
              builder: (context) => RefrigeratorCompartmentScreen(
                roomId: item['roomId'] ?? widget.roomId,
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
  
  // 칸 이름 저장
  Future<void> _saveCompartmentName(int index, String newName) async {
    if (_refrigerator == null) return;
    
    try {
      List<String> updatedNames = List.from(_compartmentNames);
      updatedNames[index] = newName;
      
      await _refrigeratorService.updateCompartmentNamesById(
        _refrigerator!.id,
        updatedNames,
      );
      
      setState(() {
        _compartmentNames = updatedNames;
        if (index == widget.compartmentIndex) {
          _currentCompartmentName = newName;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('칸 이름이 변경되었습니다'),
          backgroundColor: Color(0xFF6366F1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('칸 이름 변경 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('칸 이름 변경에 실패했습니다'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
  
  // 실시간 스트림 초기화
  void _initializeStream() {
    // 프리로드된 스트림이 있으면 사용, 없으면 생성
    if (_preloadedStreams.containsKey(widget.compartmentIndex)) {
      _ingredientsStream = _preloadedStreams[widget.compartmentIndex];
    } else {
      final stream = _refrigeratorService.getIngredientsForCompartmentStream(
        widget.roomId,
        widget.refrigeratorName,
        widget.compartmentIndex,
      ).asBroadcastStream();
      _preloadedStreams[widget.compartmentIndex] = stream;
      _ingredientsStream = stream;
      
      // 스트림 구독하여 데이터 캐시
      stream.listen((data) {
        if (mounted) {
          _cachedTabData[widget.compartmentIndex] = data;
        }
      });
    }
  }
  
  // 재료 데이터 로드
  Future<void> _loadIngredients() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final ingredientsList = await _refrigeratorService.getIngredientsForCompartment(
        widget.roomId,
        widget.refrigeratorName,
        widget.compartmentIndex,
      );
      
      if (mounted) {
        setState(() {
          _ingredients = ingredientsList;
          // 검색 상태 유지
          if (_searchQuery.isEmpty) {
            _filteredIngredients = ingredientsList;
          } else {
            _filterIngredients(_searchQuery);
          }
        });
      }
    } catch (e) {
      print('재료 로드 오류: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // 검색 필터링
  void _filterIngredients(String query) {
    setState(() {
      _searchQuery = query;
      _controller.setSearch(query);
      if (query.isEmpty) {
        _filteredIngredients = _ingredients;
      } else {
        _filteredIngredients = _ingredients.where((ingredient) {
          final name = ingredient['name']?.toString().toLowerCase() ?? '';
          final memo = ingredient['memo']?.toString().toLowerCase() ?? '';
          final searchLower = query.toLowerCase();
          
          return name.contains(searchLower) || memo.contains(searchLower);
        }).toList();
      }
    });
  }
  
  

  

  

  

  

  

  

  // 이미지 표시 헬퍼 함수 (분리된 위젯 사용)
  Widget _buildIngredientImage(String imagePath, double width, double height, {Widget? fallbackIcon}) {
    return IngredientImageWidget(
      imagePath: imagePath,
      width: width,
      height: height,
      fallbackIcon: fallbackIcon,
    );
  }

  // 식품명으로 아이콘 찾기 (분리된 유틸리티 사용)
  IconData _getFoodIcon(String foodName) {
    return FoodCategoryIcons.getFoodIcon(foodName);
  }
  
  
  
  
  

  // (이전 로컬 파이프라인 제거: ReceiptScannerLogic로 이전됨)

  // (Groq 정제 로직은 ReceiptScannerLogic로 이전됨)

  // (로컬 OCR 파서는 ReceiptScannerLogic로 이전)

  // 기존 로컬 파서는 유틸로 이동

  

  void _showAddIngredientDialog() {
    showDialog(
      context: context,
      builder: (context) => AddIngredientDialog(
        compartmentName: _currentCompartmentName, // 현재 탭의 칸 이름 사용
        availableCompartments: _compartmentNames, // 전체 칸 목록 사용
        onAdd: ({
          required String name,
          required int quantity,
          DateTime? expiryDate,
          DateTime? manufactureDate,
          DateTime? registrationDate,
          String? memo,
          String? imagePath,
          String? compartmentName, // 선택된 칸 이름 받기
        }) async {
          await _addIngredient(
            name: name,
            quantity: quantity,
            expiryDate: expiryDate,
            manufactureDate: manufactureDate,
            registrationDate: registrationDate,
            memo: memo,
            imagePath: imagePath,
            compartmentName: compartmentName, // 선택된 칸으로 추가
          );
        },
      ),
    );
  }

  // 폼 필드 위젯
  Widget _buildFormField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildTopSearchBar() {
    return Container(
      key: ValueKey('fridge_search_bar'),
      height: 44,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(22),
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
                final trimmed = value.trim();
                if (trimmed.isEmpty) {
                  setState(() {
                    _searchResults = [];
                    _hasSearched = false;
                  });
                } else {
                  _performGlobalSearch(trimmed);
                }
              },
              onSubmitted: (value) {
                final trimmed = value.trim();
                if (trimmed.isNotEmpty) {
                  _performGlobalSearch(trimmed);
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.grey[500]),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            onPressed: () {
              setState(() {
                if (_searchController.text.isEmpty) {
                  _isSearching = false;
                }
                _searchController.clear();
                _searchResults = [];
                _hasSearched = false;
              });
            },
          ),
          SizedBox(width: 4),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 검색 모드일 때는 화면을 pop 하지 않고 검색만 종료
        if (_isSearching) {
          setState(() {
            _isSearching = false;
            _searchController.clear();
            _searchResults = [];
            _hasSearched = false;
            _isSearchingData = false;
            _filterIngredients('');
          });
          return false; // Navigator.pop() 호출 막기
        }
        // 그 외에는 일반 뒤로가기 허용 (하나의 화면만 pop)
        return true;
      },
      child: Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          // 시스템 뒤로가기와 동일한 로직을 타도록 maybePop 사용
          onPressed: () => Navigator.maybePop(context),
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
              ? _buildTopSearchBar()
              : Text(
                  widget.refrigeratorName,
                  key: ValueKey('fridge_title'),
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
        ),
        actions: [
          if (!_isSearching) ...[
            IconButton(
              icon: Icon(Icons.search_rounded, color: Colors.grey[700]),
              onPressed: () {
                // 검색 진입 시 항상 깨끗한 상태에서 시작
                setState(() {
                  _isSearching = true;
                  _searchController.clear();
                  _searchResults = [];
                  _hasSearched = false;
                  _isSearchingData = false;
                });
                Future.delayed(Duration(milliseconds: 200), () {
                  _searchFocusNode.requestFocus();
                });
              },
              tooltip: '식품 검색',
              splashRadius: 24,
            ),
            // 유통기한 경고 버튼 (배지 포함)
            FutureBuilder<int>(
              future: _getExpiringItemsCountAsync(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.notifications_none_rounded, color: Colors.grey[700]),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExpiringOverviewScreen(
                              roomId: widget.roomId,
                              refrigeratorName: widget.refrigeratorName,
                            ),
                          ),
                        );
                      },
                      tooltip: '유통기한 알림',
                      splashRadius: 24,
                    ),
                    if (count > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            // 메모장 버튼
            IconButton(
              icon: Icon(Icons.insert_drive_file_outlined, color: Colors.grey[700]),
              onPressed: _openMemoList,
              tooltip: '메모장',
              splashRadius: 24,
            ),
            SizedBox(width: 12),
          ],
        ],
      ),
      body: _isSearching
          ? _buildGlobalSearchResults()
          : Column(
        children: [
          // TabBar - 마이페이지 테마
          if (_compartmentNames.isNotEmpty && _tabController != null)
            Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        offset: Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: TabBar(
                      controller: _tabController!,
                      isScrollable: false,
                      indicatorColor: Color(0xFF6366F1),
                      indicatorWeight: 2.5,
                      labelColor: Color(0xFF6366F1),
                      unselectedLabelColor: Colors.grey[500],
                      labelStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.3,
                      ),
                      labelPadding: EdgeInsets.zero,
                      onTap: (index) async {
                        if (index == _currentTabIndex) return;
                        await _onTabChanged(index); // 프리로드된 데이터 즉시 전환
                      },
                      tabs: _compartmentNames.asMap().entries.map((entry) {
                        final index = entry.key;
                        final name = entry.value;
                        final isEditing = _editingTabIndex == index;
                        
                        return Tab(
                          child: GestureDetector(
                            onDoubleTap: () {
                              if (!isEditing) {
                                _startEditingTab(index, name);
                              }
                            },
                            onLongPress: () {
                              if (!isEditing) {
                                _startEditingTab(index, name);
                              }
                            },
                            child: Container(
                              alignment: Alignment.center,
                              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                              child: isEditing
                                  ? TextField(
                                      controller: _tabNameController,
                                      focusNode: _tabNameFocusNode,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF6366F1),
                                        letterSpacing: -0.3,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                        border: UnderlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
                                        ),
                                      ),
                                      onSubmitted: (_) => _finishEditingTab(),
                                      onTapOutside: (_) => _finishEditingTab(),
                                    )
                                  : Text(name),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
          
          // 내용
          Expanded(
            child: Stack(
              children: [
                // StreamBuilder 항상 표시 (프리로딩으로 즉시 로딩)
                StreamBuilder<List<Map<String, dynamic>>>(
                  key: ValueKey('stream_$_currentTabIndex'), // 탭별로 고유 키
                  stream: _ingredientsStream,
                  initialData: _cachedTabData[_currentTabIndex], // 캐시된 데이터로 즉시 표시!
                  builder: (context, snapshot) {
                // 스트림 데이터가 있으면 업데이트
                if (snapshot.hasData) {
                  final newData = snapshot.data!;
                  
                  // 데이터 구조적 변경 확인 (추가/삭제)
                  final structuralChange = _ingredients.length != newData.length ||
                      !_ingredients.every((item) => newData.any((newItem) => newItem['id'] == item['id']));
                  
                  // likes 정렬일 때 좋아요 수 변경 확인
                  bool preferencesChanged = false;
                  if (_sortBy == 'likes' && !structuralChange) {
                    for (var oldItem in _ingredients) {
                      final newItem = newData.firstWhere(
                        (item) => item['id'] == oldItem['id'],
                        orElse: () => {},
                      );
                      if (newItem.isNotEmpty) {
                        final oldLikes = ((oldItem['preferences']?['likes'] as List?) ?? []).length;
                        final newLikes = ((newItem['preferences']?['likes'] as List?) ?? []).length;
                        if (oldLikes != newLikes) {
                          preferencesChanged = true;
                          print('🔄 좋아요 수 변경 감지: $_sortBy 정렬로 재정렬 필요');
                          break;
                        }
                      }
                    }
                  }
                  
                  if (structuralChange || preferencesChanged) {
                    // 식품 추가/삭제 또는 likes 정렬 시 좋아요 수 변경 시 재정렬
                    print('UI 스트림 데이터 받음 (${preferencesChanged ? "좋아요 변경" : "구조 변경"}): ${newData.length}개');
                    _ingredients = newData;
                    // 검색 상태 유지
                    if (_searchQuery.isEmpty) {
                      _filteredIngredients = List.from(_ingredients);
                    } else {
                      _filteredIngredients = _ingredients.where((ingredient) {
                        final name = ingredient['name']?.toString().toLowerCase() ?? '';
                        final memo = ingredient['memo']?.toString().toLowerCase() ?? '';
                        final searchLower = _searchQuery.toLowerCase();
                        return name.contains(searchLower) || memo.contains(searchLower);
                      }).toList();
                    }
                    // 정렬 적용
                    _applySorting();
                    print('📊 정렬 적용됨: $_sortBy');
                  } else {
                    // 데이터 내용만 변경 (좋아요/싫어요 제외) - 정렬 유지하며 데이터만 업데이트
                    print('UI 데이터 내용 업데이트 (정렬 유지: $_sortBy)');
                    _ingredients = newData;
                    // 기존 정렬 순서를 유지하면서 데이터만 업데이트
                    for (int i = 0; i < _filteredIngredients.length; i++) {
                      final id = _filteredIngredients[i]['id'];
                      final updated = newData.firstWhere(
                        (item) => item['id'] == id,
                        orElse: () => _filteredIngredients[i],
                      );
                      _filteredIngredients[i] = updated;
                    }
                    // 정렬 기준이 좋아요일 때는 내용 변경에서도 재정렬 수행 (순위 변동 반영)
                    if (_sortBy == 'likes') {
                      _applySorting();
                      print('🔁 내용 변경에 따른 좋아요 정렬 재적용');
                    }
                    print('📌 정렬 상태 확인: $_sortBy (유지됨)');
                  }
                  
                  // 첫 스냅샷 도착 시 로딩 해제
                  if (_isLoading) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    });
                  }
                  
                  // 타겟 식품으로 스크롤 (데이터 로드 후, 한 번만 실행)
                  if (widget.targetIngredientId != null && !_hasScrolledToTarget) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToIngredient(widget.targetIngredientId!);
                      _hasScrolledToTarget = true; // 스크롤 완료 플래그 설정
                    });
                  }
                }
                
                return Column(
                  children: [
                    // 정렬 드롭다운 버튼 (마이페이지 테마)
          SortCounterBar(
            sortIcon: _getSortIcon(),
            sortLabel: _getSortLabel(),
            onSortTap: () => _showSortMenu(context),
            itemCount: snapshot.hasData ? _ingredients.length : 0,
          ),
                
                    // 식품 목록
                    Expanded(
                      child: (_isLoading || !snapshot.hasData)
                          ? Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                strokeWidth: 2.5,
                              ),
                            )
                          : IngredientListSection(
                              filteredIngredients: _filteredIngredients,
                              allIngredients: _ingredients,
                              scrollController: _scrollController,
                              itemKeysById: _itemKeysById,
                              searchQuery: _searchQuery,
                              onClearSearch: () => _filterIngredients(''),
                              buildCard: (ingredient, originalIndex) => _buildIngredientCard(ingredient, originalIndex),
                            ),
                    ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMethodDialog,
        backgroundColor: Colors.blue[600],
        child: Icon(Icons.add_rounded, color: Colors.white),
      ),
    ),
    );
  }

  // 칸 타입에 따른 아이콘 반환
  IconData _getCompartmentIcon() {
    if (widget.compartmentName.contains('냉동')) {
      return Icons.ac_unit_rounded;
    } else {
      return Icons.kitchen_rounded;
    }
  }

  // 식품 카드 위젯 - 스와이프 액션 포함
  Widget _buildIngredientCard(Map<String, dynamic> ingredient, int index) {
    return IngredientCard(
      ingredient: ingredient,
      index: index,
      highlightedIngredientId: _highlightedIngredientId,
      refrigeratorService: _refrigeratorService,
      onEdit: () => _showEditIngredientDialog(ingredient, index),
      onDelete: () => _deleteIngredient(index),
      onLock: () => _lockIngredient(ingredient),
      onUnlock: () => _unlockIngredient(ingredient),
      onTogglePreference: (type) => _togglePreference(ingredient, type),
      onShowPreferenceDetails: () => _showPreferenceDetails(ingredient),
      onDismiss: (direction) {
        if (direction == DismissDirection.startToEnd) {
          _consumeIngredient(ingredient);
        } else if (direction == DismissDirection.endToStart) {
          _discardIngredient(ingredient);
        }
      },
      confirmDismiss: (direction) async {
        final bool canManage = _refrigeratorService.canUserManageIngredient(ingredient);
        if (!canManage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.lock, color: Colors.white),
                  SizedBox(width: 8),
                  Text('잠금된 식품은 등록자만 관리할 수 있습니다'),
                ],
              ),
              backgroundColor: Colors.orange[600],
              behavior: SnackBarBehavior.floating,
            ),
          );
          return false;
        }

        String actionText = direction == DismissDirection.startToEnd ? '소비' : '폐기';
        String actionIcon = direction == DismissDirection.startToEnd ? '🍽️' : '🗑️';
        
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Text(actionIcon),
                SizedBox(width: 8),
                Text('식품 $actionText'),
              ],
            ),
            content: Text('${ingredient['name']}을(를) ${actionText}하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('취소'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: direction == DismissDirection.startToEnd 
                      ? Colors.green[600] 
                      : Colors.red[600],
                  foregroundColor: Colors.white,
                ),
                child: Text(actionText),
              ),
            ],
          ),
        ) ?? false;
      },
    );
  }

  Widget _buildIngredientCard_OLD(Map<String, dynamic> ingredient, int index) {
    final DateTime? expiryDate = ingredient['expiryDate']?.toDate();
    final DateTime? manufactureDate = ingredient['manufactureDate']?.toDate();
    final String memo = ingredient['memo'] ?? '';
    final String foodName = ingredient['name'] ?? '';
    final bool isExpiring = expiryDate != null && 
        _calculateDaysLeft(expiryDate) <= 3;
    final bool isExpired = expiryDate != null && 
        _calculateDaysLeft(expiryDate) < 0;

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
    final bool canManage = _refrigeratorService.canUserManageIngredient(ingredient);
    final bool canLock = _refrigeratorService.canUserLockIngredient(ingredient);
    final bool canUnlock = _refrigeratorService.canUserUnlockIngredient(ingredient);

    return Dismissible(
      key: Key('ingredient_${ingredient['id']}_$index'),
      background: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.green[600],
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(Icons.restaurant, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Text(
              '소비',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red[600],
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '폐기',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white, size: 28),
          ],
        ),
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          // 오른쪽으로 스와이프 - 소비
          _consumeIngredient(ingredient);
        } else if (direction == DismissDirection.endToStart) {
          // 왼쪽으로 스와이프 - 폐기
          _discardIngredient(ingredient);
        }
      },
      confirmDismiss: (direction) async {
        // 권한 체크
        if (!canManage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.lock, color: Colors.white),
                  SizedBox(width: 8),
                  Text('잠금된 식품은 등록자만 관리할 수 있습니다'),
                ],
              ),
              backgroundColor: Colors.orange[600],
              behavior: SnackBarBehavior.floating,
            ),
          );
          return false;
        }

        String actionText = direction == DismissDirection.startToEnd ? '소비' : '폐기';
        String actionIcon = direction == DismissDirection.startToEnd ? '🍽️' : '🗑️';
        
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Text(actionIcon),
                SizedBox(width: 8),
                Text('식품 $actionText'),
              ],
            ),
            content: Text('${ingredient['name']}을(를) ${actionText}하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('취소'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: direction == DismissDirection.startToEnd 
                      ? Colors.green[600] 
                      : Colors.red[600],
                  foregroundColor: Colors.white,
                ),
                child: Text(actionText),
              ),
            ],
          ),
        );
      },
      child: Container(
        key: ValueKey('${ingredient['id']}_${ingredient['imagePath']}_${ingredient['name']}'), // 실시간 업데이트를 위한 고유 키
        margin: EdgeInsets.only(
          bottom: 16,
          // 유통기한 만료/만료 예정인 경우 좌우 마진 줄여서 더 넓게 보이게
          left: (isExpired || isExpiring) ? 4 : 8,
          right: (isExpired || isExpiring) ? 4 : 8,
        ),
        decoration: BoxDecoration(
          color: _highlightedIngredientId == ingredient['id'] 
              ? Colors.blue[50] 
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
            // 유통기한 만료/만료 예정인 경우 그림자 강화
            if (isExpired || isExpiring)
              BoxShadow(
                color: (isExpired ? Colors.red : Colors.orange).withOpacity(0.1),
                blurRadius: 15,
                offset: Offset(0, 4),
              ),
          ],
          border: _highlightedIngredientId == ingredient['id']
              ? Border.all(color: Colors.blue[300]!, width: 3)
              : isExpired 
                  ? Border.all(color: Colors.red[300]!, width: 3) // 테두리 두께 증가
                  : isExpiring 
                      ? Border.all(color: Colors.orange[300]!, width: 3) // 테두리 두께 증가
                      : null,
        ),
      child: Padding(
        padding: EdgeInsets.all(
          // 유통기한 만료/만료 예정인 경우 패딩 증가
          (isExpired || isExpiring) ? 20 : 16
        ),
        child: Column(
          children: [
            Row(
              children: [
                // 식품 이미지 또는 아이콘
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: ingredient['imagePath'] != null && ingredient['imagePath'].toString().isNotEmpty
                        ? Colors.transparent
                        : (isExpired 
                            ? Colors.red[50]
                            : isExpiring 
                                ? Colors.orange[50]
                                : Colors.green[50]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ingredient['imagePath'] != null && ingredient['imagePath'].toString().isNotEmpty
                          ? _buildIngredientImage(
                              ingredient['imagePath'].toString(),
                              48,
                              48,
                              fallbackIcon: Icon(
                                _getFoodIcon(foodName),
                                color: isExpired 
                                    ? Colors.red[600]
                                    : isExpiring 
                                        ? Colors.orange[600]
                                        : Colors.green[600],
                                size: 24,
                              ),
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getFoodIcon(foodName),
                                color: isExpired 
                                    ? Colors.red[600]
                                    : isExpiring 
                                        ? Colors.orange[600]
                                        : Colors.green[600],
                                size: 24,
                              ),
                            ),
                      ),
                      // 잠금 도장 효과
                      if (isLocked)
                        _buildLockStamp(ingredient, size: 48),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                
                // 식품 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${foodName} (${ingredient['quantity'] ?? 0})',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          if (isLocked) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[300]!, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock, color: Colors.orange[700], size: 12),
                                  SizedBox(width: 2),
                                  Text(
                                    '잠금',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                // 아이콘 재배치: 오른쪽에 순서대로 [수정] [잠금/해제], 삭제 제거
                if (canManage)
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: Colors.blue[400]),
                    onPressed: () => _showEditIngredientDialog(ingredient, index),
                    tooltip: '수정',
                  ),
                if (canLock)
                  IconButton(
                    icon: Icon(Icons.lock_outline, color: Colors.orange[600]),
                    onPressed: () => _lockIngredient(ingredient),
                    tooltip: '잠금',
                  )
                else if (canUnlock)
                  IconButton(
                    icon: Icon(Icons.lock_open_outlined, color: Colors.green[600]),
                    onPressed: () => _unlockIngredient(ingredient),
                    tooltip: '잠금 해제',
                  ),
              ],
            ),
            
            // 유통기한 섹션 (좋아요/싫어요 버튼 바로 위)
            if (expiryDate != null) ...[
              SizedBox(height: 8),
              Text(
                '유통기한: ${_formatDate(expiryDate)}',
                style: TextStyle(
                  color: isExpired 
                      ? Colors.red[600]
                      : isExpiring 
                          ? Colors.orange[600]
                          : Colors.grey[600],
                  fontWeight: isExpired || isExpiring 
                      ? FontWeight.w600
                      : FontWeight.w500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            SizedBox(height: 12),
            
            // 선호도 섹션
            Row(
              children: [
                // 좋아요 버튼
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _togglePreference(ingredient, 'like'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: userLiked ? Colors.red[50] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: userLiked ? Colors.red[300]! : Colors.grey[200]!,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              userLiked ? Icons.favorite : Icons.favorite_border,
                              color: userLiked ? Colors.red[600] : Colors.grey[500],
                              size: 18,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '좋아요',
                              style: TextStyle(
                                color: userLiked ? Colors.red[600] : Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (likes.isNotEmpty) ...[
                              SizedBox(width: 4),
                              Text(
                                '${likes.length}',
                                style: TextStyle(
                                  color: userLiked ? Colors.red[600] : Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(width: 8),
                
                // 싫어요 버튼  
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _togglePreference(ingredient, 'dislike'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: userDisliked ? Colors.blue[50] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: userDisliked ? Colors.blue[300]! : Colors.grey[200]!,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              userDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                              color: userDisliked ? Colors.blue[600] : Colors.grey[500],
                              size: 18,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '싫어요',
                              style: TextStyle(
                                color: userDisliked ? Colors.blue[600] : Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (dislikes.isNotEmpty) ...[
                              SizedBox(width: 4),
                              Text(
                                '${dislikes.length}',
                                style: TextStyle(
                                  color: userDisliked ? Colors.blue[600] : Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(width: 8),
                
                // 선호도 상세보기 버튼
                if (likes.isNotEmpty || dislikes.isNotEmpty)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showPreferenceDetails(ingredient),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.grey[600],
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  // 선호도 토글 기능
  Future<void> _togglePreference(Map<String, dynamic> ingredient, String type) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인이 필요합니다'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      
      final Map<String, dynamic> preferences = ingredient['preferences'] ?? {};
      final List<String> likes = List<String>.from(preferences['likes'] ?? []);
      final List<String> dislikes = List<String>.from(preferences['dislikes'] ?? []);
      
      bool wasLiked = likes.contains(currentUserId);
      bool wasDisliked = dislikes.contains(currentUserId);
      String message = '';
      
      if (type == 'like') {
        if (wasLiked) {
          likes.remove(currentUserId);
          message = '좋아요를 취소했습니다';
        } else {
          likes.add(currentUserId);
          dislikes.remove(currentUserId); // 싫어요에서 제거
          message = '좋아요를 표시했습니다';
        }
      } else {
        if (wasDisliked) {
          dislikes.remove(currentUserId);
          message = '싫어요를 취소했습니다';
        } else {
          dislikes.add(currentUserId);
          likes.remove(currentUserId); // 좋아요에서 제거
          message = '싫어요를 표시했습니다';
        }
      }
      
      // Firestore 업데이트
      final updatedPreferences = {
        'likes': likes,
        'dislikes': dislikes,
      };
      
      // RefrigeratorService를 통해 선호도 업데이트
      bool success = await _refrigeratorService.updateIngredientPreferences(
        widget.roomId,
        widget.refrigeratorName,
        _currentTabIndex, // 현재 탭 인덱스 사용
        ingredient['id'],
        updatedPreferences,
      );
      
      if (success) {
        // 로컬 상태 즉시 업데이트 (스트림이 곧 실제 데이터와 동기화해 줌)
        setState(() {
          ingredient['preferences'] = updatedPreferences;
        });
      } else {
        throw Exception('선호도 업데이트 실패');
      }
    } catch (e) {
      print('선호도 토글 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 선호도 상세정보 다이얼로그
  void _showPreferenceDetails(Map<String, dynamic> ingredient) async {
    await showPreferenceDetailsDialog(
      context,
      ingredient: ingredient,
      authService: _authService,
    );
  }

  // 날짜 포맷팅 (분리된 유틸리티 사용)
  String _formatDate(DateTime date) {
    return IngredientUtils.formatDate(date);
  }

  // 날짜 및 시간 포맷팅 (분리된 유틸리티 사용)
  String _formatDateTime(DateTime dateTime) {
    return IngredientUtils.formatDateTime(dateTime);
  }

  // 재료 추가 (분리된 로직 클래스 사용)
  Future<void> _addIngredient({
    required String name,
    required int quantity,
    DateTime? expiryDate,
    DateTime? manufactureDate,
    DateTime? registrationDate,
    String? memo,
    String? imagePath,
    String? compartmentName, // 선택된 칸 이름
  }) async {
    try {
      // 기본값은 현재 탭 인덱스 (사용자가 보고 있는 칸)
      int targetCompartmentIndex = _currentTabIndex;

      // compartmentName이 제공되면 해당 칸 이름을 현재 냉장고의 칸 목록에서 찾음
      if (compartmentName != null && _compartmentNames.isNotEmpty) {
        final index = _compartmentNames.indexOf(compartmentName);
        if (index != -1) {
          targetCompartmentIndex = index;
        }
      }

      bool success = await _ingredientManager.addIngredient(
        roomId: widget.roomId,
        refrigeratorName: widget.refrigeratorName,
        compartmentIndex: targetCompartmentIndex,
        name: name,
        quantity: quantity,
        expiryDate: expiryDate,
        manufactureDate: manufactureDate,
        registrationDate: registrationDate,
        memo: memo,
        imagePath: imagePath,
      );
      
      if (success) {
        print('✅ 재료 추가 완료 - 실시간 스트림이 자동 업데이트됨');
        // 추가 직후, 사용자가 새로 추가한 식품이 보이도록 목록을 최상단으로 스크롤
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('식품 추가 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('재료 추가 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('식품 추가 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 식품 소비 처리 (분리된 로직 클래스 사용)
  Future<void> _consumeIngredient(Map<String, dynamic> ingredient) async {
    try {
      bool success = await _ingredientManager.consumeIngredient(
        roomId: widget.roomId,
        refrigeratorName: widget.refrigeratorName,
        compartmentIndex: _currentTabIndex, // 현재 탭 인덱스 사용
        ingredient: ingredient,
      );
    } catch (e) {
      print('식품 소비 처리 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('식품 소비 처리 중 오류가 발생했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 식품 폐기 처리 (분리된 로직 클래스 사용)
  Future<void> _discardIngredient(Map<String, dynamic> ingredient) async {
    try {
      bool success = await _ingredientManager.discardIngredient(
        roomId: widget.roomId,
        refrigeratorName: widget.refrigeratorName,
        compartmentIndex: _currentTabIndex, // 현재 탭 인덱스 사용
        ingredient: ingredient,
      );
    } catch (e) {
      print('식품 폐기 처리 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('식품 폐기 처리 중 오류가 발생했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 재료 삭제
  Future<void> _deleteIngredient(int index) async {
    final ingredient = _ingredients[index];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('식품 삭제'),
        content: Text('${ingredient['name']}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                // 스크롤 위치 저장
                _saveScrollPosition();
                
                await _refrigeratorService.deleteIngredient(
                  widget.roomId,
                  widget.refrigeratorName,
                  _currentTabIndex, // 현재 탭 인덱스 사용
                  ingredient['id'],
                );
                
                // 실시간 스트림이 자동으로 업데이트하므로 _loadIngredients() 호출 불필요
                // 스크롤 위치 복원 (약간의 지연 후)
                Future.delayed(Duration(milliseconds: 100), () {
                  _restoreScrollPosition();
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('식품 삭제 중 오류가 발생했습니다'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
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

  // 식품 검색 기능
  void _showSearchDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          roomId: widget.roomId,
        ),
      ),
    );
  }

  // 유통기한 경고 보기 (D-day 표시)
  void _showExpiryWarnings() {
    final expiringItems = _ingredients.where((ingredient) {
      final expiryDate = ingredient['expiryDate']?.toDate();
      if (expiryDate == null) return false;
      final daysLeft = _calculateDaysLeft(expiryDate);
      return daysLeft <= 3;
    }).toList()
      ..sort((a, b) {
        final expiryA = a['expiryDate']?.toDate();
        final expiryB = b['expiryDate']?.toDate();
        if (expiryA == null || expiryB == null) return 0;
        return expiryA.compareTo(expiryB);
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ExpiringBottomSheet(
        expiringItems: expiringItems,
        foodIconForName: (name) => _getFoodIcon(name),
        dayText: (daysLeft) => _getDayDisplayText(daysLeft),
        dayColor: (daysLeft) => _getDayDisplayColor(daysLeft),
      ),
    );
  }

  // D-day 표시 텍스트 (분리된 유틸리티 사용)
  String _getDayDisplayText(int daysLeft) {
    return IngredientUtils.getDayDisplayText(daysLeft);
  }

  // D-day 표시 색상 (분리된 유틸리티 사용)
  Color _getDayDisplayColor(int daysLeft) {
    return IngredientUtils.getDayDisplayColor(daysLeft);
  }

  // 만료 예정 아이템 개수 계산 (냉장고 전체)
  Future<int> _getExpiringItemsCountAsync() async {
    return ExpiryUtils.getExpiringItemsCount(
      roomId: widget.roomId,
      refrigeratorName: widget.refrigeratorName,
    );
  }

  // D-day 계산 메서드 (분리된 유틸리티 사용)
  int _calculateDaysLeft(DateTime expiryDate) {
    return IngredientUtils.calculateDaysLeft(expiryDate);
  }



  // 메모장 목록 화면으로 이동
  void _openMemoList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemoListScreen(
          roomId: widget.roomId,
          compartmentName: widget.compartmentName,
        ),
      ),
    );
  }

  // 일괄등록 주의사항 팝업 표시
  void _showBatchRegistration() {
    _showBatchRegistrationWarning();
  }

  // 일괄등록 주의사항 팝업
  void _showBatchRegistrationWarning() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                    Icons.playlist_add,
                    color: Color(0xFF6B9FFF),
                    size: 28,
                  ),
                ),
                
                SizedBox(height: 20),
                
                // 제목
                Text(
                  '일괄등록',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                
                SizedBox(height: 8),
                
                // 설명
                Text(
                  '바코드 스캔으로 여러 제품을\n한번에 등록합니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                
                SizedBox(height: 20),
                
                // 주의사항 박스
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF6B9FFF).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFF6B9FFF).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF6B9FFF),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '안내',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B9FFF),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      _buildInfoItem('바코드 스캔만 가능합니다'),
                      SizedBox(height: 8),
                      _buildInfoItem('여러 제품을 연속으로 스캔할 수 있습니다'),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),
                
                // 버튼들
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
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
                        onPressed: () {
                          Navigator.of(context).pop();
                          _navigateToBatchRegistration();
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
                        child: Text(
                          '시작하기',
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
  }

  Widget _buildInfoItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(top: 6),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Color(0xFF6B9FFF),
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // 일괄등록 화면으로 이동 (실제 네비게이션)
  void _navigateToBatchRegistration() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => BatchRegistrationScreen(
          roomId: widget.roomId,
          refrigeratorName: widget.refrigeratorName,
          compartmentIndex: _currentTabIndex, // 현재 탭 인덱스 사용
        ),
      ),
    ).then((_) {
      // 화면에서 돌아왔을 때 데이터 새로고침
      _loadIngredients();
    });
  }

  

  

  

  

  // 추가 방법 선택 다이얼로그
  void _showAddMethodDialog() {
    showAddMethodSheet(
      context,
      onReceiptScan: _showReceiptScanDialog,
      onBarcodeScan: _scanBarcode,
      onBatchRegistration: _showBatchRegistration,
      onManualAdd: _showAddIngredientDialog,
    );
  }

  // 추가 방법 타일은 외부 파일로 분리됨

  

  

  

  

  

  

  

  

  // 상세 정보 카드
  Widget _buildDetailInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // 상세 정보 행
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

   // 재료를 냉장고 칸에 추가하는 메서드
   Future<bool> _addIngredientToCompartment(String name, String quantity, String expiryDate) async {
     if (name.trim().isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('재료명을 입력해주세요')),
       );
       return false;
     }

     try {
       // quantity에서 숫자 추출
       int quantityNumber = 1;
       String quantityText = quantity.trim();
       if (quantityText.isNotEmpty) {
         // 숫자 부분만 추출
         RegExp regExp = RegExp(r'\d+');
         Match? match = regExp.firstMatch(quantityText);
         if (match != null) {
           quantityNumber = int.tryParse(match.group(0)!) ?? 1;
         }
       }
       
       final success = await _refrigeratorService.addIngredient(
         widget.roomId,
         widget.refrigeratorName,
         _currentTabIndex, // 현재 탭 인덱스 사용
         {
           'name': name.trim(),
           'quantity': quantityNumber,
           'expiryDate': expiryDate.trim().isEmpty ? null : expiryDate.trim(),
           'created_at': Timestamp.now(),
         },
       );

       if (success) {
         // 재료 목록 새로고침
         _loadIngredients();
         return true;
       } else {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('재료 추가에 실패했습니다'),
             backgroundColor: Colors.red,
           ),
         );
         return false;
       }
     } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('재료 추가 중 오류가 발생했습니다: $e'),
           backgroundColor: Colors.red,
         ),
       );
       return false;
     }
   }
 
   // OCR 카메라 열기
  Future<void> _openDateRecognitionCamera(BuildContext context, Function(String) onDateRecognized) async {
    try {
      // 사용 가능한 카메라 가져오기
      final cameras = await availableCameras();
      
      if (cameras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용 가능한 카메라가 없습니다')),
        );
        return;
      }

      // 카메라 화면으로 이동하고 결과 받기
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DateRecognitionCameraScreen(
            cameras: cameras,
            onDateRecognized: onDateRecognized,
          ),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카메라 초기화 오류: $e')),
      );
    }
  }

  // 바코드 제품 이미지 표시 위젯
  Widget _buildBarcodeProductImage(BarcodeModel barcode) {
    if (barcode.imageUrl.isNotEmpty && barcode.imageUrl != '') {
      if (barcode.isLocalImage) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            barcode.assetPath,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return _buildProductImagePlaceholder();
            },
          ),
        );
      } else {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: barcode.imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => Container(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) => _buildProductImagePlaceholder(),
          ),
        );
      }
    } else {
      return _buildProductImagePlaceholder();
    }
  }

  // 제품 이미지 플레이스홀더
  Widget _buildProductImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            color: Colors.grey[400],
            size: 48,
          ),
          SizedBox(height: 8),
          Text(
            '제품 이미지',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // 이미지 선택 및 크롭 함수
  Future<void> _pickAndCropImage({Function(String?)? onImageSelected}) async {
    final path = await ImagePickerHelper.pickAndCrop(context);
    if (path != null) {
      onImageSelected?.call(path);
    }
  }

  // 재료 수정 다이얼로그 (AddIngredientDialog 재사용)
  void _showEditIngredientDialog(Map<String, dynamic> ingredient, int index) {
    print('🔍 수정 다이얼로그 열기: widget.compartmentName = ${widget.compartmentName}, _currentCompartmentName = $_currentCompartmentName');
    showDialog(
      context: context,
      builder: (context) => AddIngredientDialog(
        compartmentName: _currentCompartmentName, // 현재 탭의 칸 이름 사용
        availableCompartments: _compartmentNames,  // 전체 칸 목록 사용
        isEditMode: true,
        existingIngredient: ingredient,
        onAdd: ({
          required String name,
          required int quantity,
          DateTime? expiryDate,
          DateTime? manufactureDate,
          DateTime? registrationDate,
          String? memo,
          String? imagePath,
          String? compartmentName,
        }) async {
          await _updateIngredient(
            index: index,
            name: name,
            quantity: quantity,
            expiryDate: expiryDate,
            manufactureDate: manufactureDate,
            registrationDate: registrationDate,
            memo: memo,
            imagePath: imagePath,
            compartmentName: compartmentName,
          );
        },
      ),
    );
  }

  // 재료 수정 실행 함수
  Future<void> _updateIngredient({
    required int index,
    required String name,
    required int quantity,
    DateTime? expiryDate,
    DateTime? manufactureDate,
    DateTime? registrationDate,
    String? memo,
    String? imagePath,
    String? compartmentName,
  }) async {
    try {
      final ingredient = _ingredients[index];
      
      // 수정할 데이터 준비
      Map<String, dynamic> updatedData = {
        'name': name,
        'quantity': quantity,
      };
      
      // 메모가 변경된 경우 작성자 정보와 함께 업데이트
      if (memo != null && memo.trim().isNotEmpty && memo != ingredient['memo']) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          
          updatedData['memo'] = memo.trim();
          updatedData['memoAuthorId'] = currentUser.uid;
          updatedData['memoAuthorName'] = userDoc.data()?['nickname'] ?? '익명';
          updatedData['memoAuthorProfileImage'] = userDoc.data()?['profileImageUrl'];
          updatedData['memoUpdatedAt'] = FieldValue.serverTimestamp();
        }
      } else if (memo == null || memo.trim().isEmpty) {
        // 메모가 삭제된 경우
        updatedData['memo'] = '';
        updatedData['memoAuthorId'] = null;
        updatedData['memoAuthorName'] = null;
        updatedData['memoAuthorProfileImage'] = null;
        updatedData['memoUpdatedAt'] = null;
      }
      
      // 날짜 필드 추가 (UTC 자정으로 변환하여 저장)
      if (expiryDate != null) {
        updatedData['expiryDate'] = Timestamp.fromDate(_toUtcMidnight(expiryDate));
      } else {
        updatedData['expiryDate'] = null;
      }
      
      if (manufactureDate != null) {
        updatedData['manufactureDate'] = Timestamp.fromDate(_toUtcMidnight(manufactureDate));
      } else {
        updatedData['manufactureDate'] = null;
      }
      
      if (registrationDate != null) {
        updatedData['registrationDate'] = Timestamp.fromDate(_toUtcMidnight(registrationDate));
      }
      
      // 이미지 처리
      if (imagePath != null && imagePath.isNotEmpty) {
        if (imagePath != ingredient['imagePath']) {
          // 새 이미지 업로드 (Base64 방식)
          final imageUrl = await _imageUploadService.uploadIngredientImage(
            File(imagePath),
            widget.roomId,
            widget.refrigeratorName,
            widget.compartmentIndex,
          );
          
          if (imageUrl != null) {
            updatedData['imagePath'] = imageUrl;
            updatedData['imageUrl'] = imageUrl;
          }
        } else {
          // 기존 이미지 유지
          updatedData['imagePath'] = ingredient['imagePath'];
          updatedData['imageUrl'] = ingredient['imageUrl'] ?? ingredient['imagePath'];
        }
      } else if (ingredient['imagePath'] != null) {
        // 이미지가 명시적으로 삭제되지 않은 경우 기존 이미지 유지
        updatedData['imagePath'] = ingredient['imagePath'];
        updatedData['imageUrl'] = ingredient['imageUrl'] ?? ingredient['imagePath'];
      }
      
      // 칸 이동 처리
      if (compartmentName != null && compartmentName != _currentCompartmentName) {
        // 다른 칸으로 이동 - 삭제 후 추가 방식
        // 기존 데이터 유지를 위해 필요한 필드 추가
        if (!updatedData.containsKey('created_at')) {
          updatedData['created_at'] = ingredient['created_at'] ?? FieldValue.serverTimestamp();
        }
        if (!updatedData.containsKey('addedBy')) {
          updatedData['addedBy'] = ingredient['addedBy'];
        }
        if (!updatedData.containsKey('addedByName')) {
          updatedData['addedByName'] = ingredient['addedByName'];
        }
        
        // 1. 현재 칸과 타겟 칸의 인덱스 찾기
        final currentIndex = _compartmentNames.indexOf(_currentCompartmentName);
        final targetIndex = _compartmentNames.indexOf(compartmentName);
        
        if (currentIndex != -1 && targetIndex != -1) {
          // 2. 현재 칸에서 삭제
          await _refrigeratorService.deleteIngredient(
            widget.roomId,
            widget.refrigeratorName,
            currentIndex,
            ingredient['id'],
          );
          
          // 3. 새 칸에 추가
          await _refrigeratorService.addIngredient(
            widget.roomId,
            widget.refrigeratorName,
            targetIndex,
            updatedData,
          );
          
          if (mounted) {
            // 약간의 지연으로 부드러운 전환
            await Future.delayed(Duration(milliseconds: 100));
            
            // 해당 칸으로 이동
            if (_tabController?.index != targetIndex) {
              // 탭 변경 전 칸 이름 및 인덱스 업데이트
              _currentCompartmentName = compartmentName;
              setState(() {
                _currentTabIndex = targetIndex;
              });
              
              // 프리로드된 스트림 사용 (즉시 로딩!)
              if (_preloadedStreams.containsKey(targetIndex)) {
                _ingredientsStream = _preloadedStreams[targetIndex];
              } else {
                // fallback: 프리로드되지 않은 경우 즉시 생성
                final stream = _refrigeratorService.getIngredientsForCompartmentStream(
                  widget.roomId,
                  widget.refrigeratorName,
                  targetIndex,
                ).asBroadcastStream();
                _preloadedStreams[targetIndex] = stream;
                _ingredientsStream = stream;
                
                // 스트림 구독하여 데이터 캐시
                stream.listen((data) {
                  if (mounted) {
                    _cachedTabData[targetIndex] = data;
                  }
                });
              }
              
              // 탭 이동 (빠른 전환)
              _tabController?.animateTo(
                targetIndex,
                duration: Duration(milliseconds: 200),
                curve: Curves.easeInOut,
              );
            }
          }
        }
      } else {
        // 같은 칸에서 수정
        final currentIndex = _compartmentNames.indexOf(_currentCompartmentName);
        if (currentIndex != -1) {
          await _refrigeratorService.updateIngredient(
            widget.roomId,
            widget.refrigeratorName,
            currentIndex,
            ingredient['id'],
            updatedData,
          );
        } else {
          // 인덱스를 찾을 수 없으면 widget.compartmentIndex 사용 (fallback)
          await _refrigeratorService.updateIngredient(
            widget.roomId,
            widget.refrigeratorName,
            widget.compartmentIndex,
            ingredient['id'],
            updatedData,
          );
        }
      }
    } catch (e) {
      print('❌ 식품 수정 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  // 이전 _showEditIngredientDialog 함수 (삭제 예정)
  void _showEditIngredientDialog_OLD(Map<String, dynamic> ingredient, int index) {
    final nameController = TextEditingController(text: ingredient['name'] ?? '');
    final quantityController = TextEditingController(text: (ingredient['quantity'] ?? 1).toString());
    final memoController = TextEditingController(text: ingredient['memo'] ?? '');
    
    // 기존 날짜 데이터 파싱 (타임존 변환 적용)
    DateTime? expiryDate;
    DateTime? manufactureDate;
    DateTime? registrationDate;
    
    // 타임존 변환 적용
    if (ingredient['expiryDate'] is Timestamp) {
      final utcDate = (ingredient['expiryDate'] as Timestamp).toDate();
      // UTC 자정에서 로컬 날짜로 변환 (타임존 문제 해결)
      expiryDate = DateTime(utcDate.year, utcDate.month, utcDate.day);
    }
    
    if (ingredient['manufactureDate'] is Timestamp) {
      final utcDate = (ingredient['manufactureDate'] as Timestamp).toDate();
      // UTC 자정에서 로컬 날짜로 변환 (타임존 문제 해결)
      manufactureDate = DateTime(utcDate.year, utcDate.month, utcDate.day);
    }
    
    if (ingredient['registrationDate'] is Timestamp) {
      final utcDate = (ingredient['registrationDate'] as Timestamp).toDate();
      // UTC 자정에서 로컬 날짜로 변환 (타임존 문제 해결)
      registrationDate = DateTime(utcDate.year, utcDate.month, utcDate.day);
    } else {
      registrationDate = DateTime.now();
    }
    
    final expiryController = TextEditingController(
      text: expiryDate != null ? '${expiryDate.year}년 ${expiryDate.month}월 ${expiryDate.day}일' : ''
    );
    final manufactureDateController = TextEditingController(
      text: manufactureDate != null ? '${manufactureDate.year}년 ${manufactureDate.month}월 ${manufactureDate.day}일' : ''
    );
    final registrationDateController = TextEditingController(
      text: registrationDate != null 
          ? '${registrationDate.year}년 ${registrationDate.month}월 ${registrationDate.day}일'
          : '${DateTime.now().year}년 ${DateTime.now().month}월 ${DateTime.now().day}일'
    );
    
    DateTime? selectedExpiryDate = expiryDate;
    DateTime? selectedManufactureDate = manufactureDate;
    DateTime? selectedRegistrationDate = registrationDate;
    String? selectedImagePath = ingredient['imagePath']; // 기존 이미지 경로
    
    String _formatKoreanDate(DateTime date) {
      return '${date.year}년 ${date.month}월 ${date.day}일';
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                  maxWidth: 400,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 헤더
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '식품 정보 수정',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // 이미지 섹션
                            Container(
                              color: Colors.white,
                              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
                              child: _buildEditImageSection(selectedImagePath, setState),
                            ),
                            Container(height: 8, color: Color(0xFFF5F5F5)),
                            
                            // 제품명과 수량
                            Container(
                              color: Colors.white,
                              padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                              child: _buildEditNameAndQuantitySection(nameController, quantityController),
                            ),
                            Container(height: 8, color: Color(0xFFF5F5F5)),
                            
                            // 날짜 섹션
                            Container(
                              color: Colors.white,
                              padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildEditDateSection(
                                    registrationDateController,
                                    selectedRegistrationDate,
                                    manufactureDateController,
                                    selectedManufactureDate,
                                    expiryController,
                                    selectedExpiryDate,
                                    setState,
                                    _formatKoreanDate,
                                  ),
                                ],
                              ),
                            ),
                            Container(height: 8, color: Color(0xFFF5F5F5)),
                            
                            // 메모 섹션
                            Container(
                              color: Colors.white,
                              padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
                              child: _buildEditMemoSection(memoController),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // 하단 버튼들
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              '취소',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // 유효성 검사
                              if (nameController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('제품명을 입력해주세요')),
                                );
                                return;
                              }
                              
                              // 숫자 유효성 검사
                              int? quantity = int.tryParse(quantityController.text);
                              if (quantity == null || quantity <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('유효한 개수를 입력해주세요')),
                                );
                                return;
                              }
                              
                              try {
                                // 수정할 데이터 준비
                                Map<String, dynamic> updatedData = {
                                  'name': nameController.text.trim(),
                                  'quantity': quantity,
                                };
                                
                                // 메모가 변경된 경우 작성자 정보와 함께 업데이트
                                final newMemo = memoController.text.trim();
                                final originalMemo = ingredient['memo'] ?? '';
                                
                                if (newMemo.isNotEmpty) {
                                  updatedData['memo'] = newMemo;
                                  
                                  // 메모가 변경된 경우에만 작성자 정보 업데이트
                                  if (newMemo != originalMemo) {
                                    final userNickname = await _authService.getUserNickname();
                                    updatedData['memoAuthor'] = userNickname ?? '알 수 없는 사용자';
                                    updatedData['memoUpdatedAt'] = Timestamp.now();
                                  }
                                } else {
                                  // 메모가 비워진 경우 관련 필드들도 삭제
                                  updatedData['memo'] = '';
                                  updatedData['memoAuthor'] = null;
                                  updatedData['memoCreatedAt'] = null;
                                  updatedData['memoUpdatedAt'] = null;
                                }
                                
                                // 날짜 데이터 추가
                                if (selectedRegistrationDate != null) {
                                  updatedData['registrationDate'] = Timestamp.fromDate(selectedRegistrationDate!);
                                }
                                if (selectedManufactureDate != null) {
                                  updatedData['manufactureDate'] = Timestamp.fromDate(selectedManufactureDate!);
                                }
                                if (selectedExpiryDate != null) {
                                  updatedData['expiryDate'] = Timestamp.fromDate(selectedExpiryDate!);
                                }
                                
                                // 이미지 업로드 처리
                                if (selectedImagePath != null && selectedImagePath!.isNotEmpty) {
                                  // 기존 이미지와 다른 경우에만 업로드
                                  if (selectedImagePath != ingredient['imagePath']) {
                                    print('   📝 이미지가 변경됨, 업로드 시작');
                                    if (selectedImagePath!.startsWith('http')) {
                                      // 외부 URL (바코드 이미지 등)은 그대로 저장
                                      // 기존 이미지 삭제 (Storage에서)
                                      if (ingredient['imagePath'] != null && ingredient['imagePath'].toString().startsWith('http')) {
                                        await _imageUploadService.deleteImageFromUrl(ingredient['imagePath']);
                                      }
                                      updatedData['imagePath'] = selectedImagePath;
                                    } else if (selectedImagePath!.startsWith('asset://')) {
                                      // Asset 경로도 그대로 저장
                                      // 기존 이미지 삭제 (Storage에서)
                                      if (ingredient['imagePath'] != null && ingredient['imagePath'].toString().startsWith('http')) {
                                        await _imageUploadService.deleteImageFromUrl(ingredient['imagePath']);
                                      }
                                      updatedData['imagePath'] = selectedImagePath;
                                    } else {
                                      // 로컬 파일 - 임시로 로컬 경로 저장 (바코드 방식과 동일)
                                      print('   📁 로컬 파일 임시 저장: $selectedImagePath');
                                      final imageFile = File(selectedImagePath!);
                                      
                                      if (_imageUploadService.validateImageFile(imageFile)) {
                                        print('   ✅ 파일 검증 통과, 임시 경로로 저장');
                                        
                                        // Firebase Storage 업로드 (재시도 메커니즘 포함)
                                        try {
                                          print('   🔥 Firebase Storage 업로드 시도 (개선된 버전)...');
                                          final uploadedImageUrl = await _imageUploadService.uploadIngredientImage(
                                            imageFile,
                                            widget.roomId,
                                            widget.refrigeratorName,
                                            _currentTabIndex, // 현재 탭 인덱스 사용
                                          );
                                          
                                          if (uploadedImageUrl != null) {
                                            print('   🚀 Firebase Storage 업로드 성공: $uploadedImageUrl');
                                            // 기존 이미지 삭제
                                            if (ingredient['imagePath'] != null && 
                                                ingredient['imagePath'].toString().startsWith('http')) {
                                              print('   🗑️ 기존 이미지 삭제: ${ingredient['imagePath']}');
                                              await _imageUploadService.deleteImageFromUrl(ingredient['imagePath']);
                                            }
                                            updatedData['imagePath'] = uploadedImageUrl;
                                          } else {
                                            // Firebase Storage 업로드 실패 시 로컬 경로로 임시 저장
                                            print('   ⚠️ Firebase Storage 업로드 실패, 로컬 경로로 저장: $selectedImagePath');
                                            updatedData['imagePath'] = selectedImagePath;
                                          }
                                        } catch (e) {
                                          print('   ❌ Firebase Storage 업로드 중 오류: $e');
                                          // 오류 발생 시에도 로컬 경로로 저장
                                          updatedData['imagePath'] = selectedImagePath;
                                        }
                                      } else {
                                        // 파일 검증 실패 시 에러 메시지
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('이미지 파일이 유효하지 않습니다'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return; // 로컬 경로 저장 금지 (타 기기 미표시 방지)
                                      }
                                    }
                                  }
                                } else {
                                  // 이미지 제거 시 Storage에서도 삭제
                                  print('   🗑️ 이미지 제거 요청');
                                  if (ingredient['imagePath'] != null && ingredient['imagePath'].toString().startsWith('http')) {
                                    print('   🗑️ Storage에서 기존 이미지 삭제: ${ingredient['imagePath']}');
                                    await _imageUploadService.deleteImageFromUrl(ingredient['imagePath']);
                                  }
                                  updatedData['imagePath'] = null;
                                }
                                
                                print('🔧 최종 업데이트 데이터 imagePath: ${updatedData['imagePath']}');
                                
                                // 재료 수정
                                bool success = await _refrigeratorService.updateIngredient(
                                  widget.roomId,
                                  widget.refrigeratorName,
                                  _currentTabIndex, // 현재 탭 인덱스 사용
                                  ingredient['id'],
                                  updatedData,
                                );
                                
                                if (success) {
                                  Navigator.pop(context);
                                  
                                  print('✅ 재료 수정 완료 - 실시간 스트림이 자동 업데이트됨');
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('식품 정보 수정에 실패했습니다'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                                
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('수정 중 오류가 발생했습니다: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              '수정',
                              style: TextStyle(
                                fontSize: 15,
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

  // 식품 수정 - 이미지 섹션
  Widget _buildEditImageSection(String? imagePath, StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이미지',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            await _pickAndCropImage(
              onImageSelected: (path) {
                setState(() {
                  imagePath = path;
                });
              },
            );
          },
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFE9ECEF)),
            ),
            child: imagePath != null && imagePath.isNotEmpty
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildIngredientImage(imagePath, double.infinity, 160),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              imagePath = null;
                            });
                          },
                          icon: Icon(Icons.close, color: Colors.white, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.5),
                            padding: EdgeInsets.all(6),
                            minimumSize: Size(32, 32),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 32, color: Colors.grey[400]),
                      SizedBox(height: 8),
                      Text(
                        '이미지 추가',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // 식품 수정 - 제품명과 수량 섹션
  Widget _buildEditNameAndQuantitySection(
    TextEditingController nameController,
    TextEditingController quantityController,
  ) {
    return Column(
      children: [
        // 제품명
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '제품명',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            Container(
              width: 176,
              height: 36,
              child: TextField(
                controller: nameController,
                style: TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '제품명 입력',
                  filled: true,
                  fillColor: Color(0xFFE9ECEF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        // 수량
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '수량',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    int current = int.tryParse(quantityController.text) ?? 1;
                    if (current > 1) {
                      quantityController.text = (current - 1).toString();
                    }
                  },
                  icon: Icon(Icons.remove_circle, color: Color(0xFFEF4444), size: 24),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
                SizedBox(width: 12),
                Container(
                  width: 64,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color(0xFFE9ECEF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: quantityController,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    int current = int.tryParse(quantityController.text) ?? 1;
                    quantityController.text = (current + 1).toString();
                  },
                  icon: Icon(Icons.add_circle, color: Color(0xFF3B82F6), size: 24),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // 식품 수정 - 날짜 섹션
  Widget _buildEditDateSection(
    TextEditingController registrationDateController,
    DateTime? selectedRegistrationDate,
    TextEditingController manufactureDateController,
    DateTime? selectedManufactureDate,
    TextEditingController expiryController,
    DateTime? selectedExpiryDate,
    StateSetter setState,
    String Function(DateTime) formatKoreanDate,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () {
              setState(() {
                selectedRegistrationDate = DateTime.now();
                registrationDateController.text = formatKoreanDate(DateTime.now());
                selectedManufactureDate = null;
                manufactureDateController.clear();
                selectedExpiryDate = null;
                expiryController.clear();
              });
            },
            child: Text(
              '초기화',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        _buildEditDateField(
          label: '등록일',
          controller: registrationDateController,
          selectedDate: selectedRegistrationDate,
          onDateSelected: (date) {
            setState(() {
              selectedRegistrationDate = date;
            });
          },
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(Duration(days: 365)),
          isReadOnly: true,
        ),
        _buildEditDateField(
          label: '제조일',
          controller: manufactureDateController,
          selectedDate: selectedManufactureDate,
          onDateSelected: (date) {
            setState(() {
              selectedManufactureDate = date;
            });
          },
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime.now().add(Duration(days: 365 * 10)),
        ),
        _buildEditDateField(
          label: '유통기한',
          controller: expiryController,
          selectedDate: selectedExpiryDate,
          onDateSelected: (date) {
            setState(() {
              selectedExpiryDate = date;
            });
          },
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(Duration(days: 365 * 5)),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Spacer(),
            InkWell(
              onTap: () async {
                await _openDateRecognitionCamera(context, (recognizedDate) {
                  setState(() {
                    // OCR 결과에서 날짜 부분만 추출
                    String dateStr = recognizedDate.replaceAll('유통기한:', '').trim();
                    
                    // yyyy.MM.dd 형식을 파싱
                    try {
                      List<String> parts = dateStr.split('.');
                      if (parts.length == 3) {
                        int year = int.parse(parts[0]);
                        int month = int.parse(parts[1]);
                        int day = int.parse(parts[2]);
                        
                        selectedExpiryDate = DateTime(year, month, day);
                        expiryController.text = '${year}년 ${month}월 ${day}일';
                      } else {
                        expiryController.text = recognizedDate;
                      }
                    } catch (e) {
                      print('날짜 파싱 오류: $e');
                      expiryController.text = recognizedDate;
                    }
                  });
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 176,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '카메라로 유통기한 인식',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 식품 수정 - 날짜 필드
  Widget _buildEditDateField({
    required String label,
    required TextEditingController controller,
    required DateTime? selectedDate,
    required Function(DateTime) onDateSelected,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    bool isReadOnly = false,
  }) {
    String _formatKoreanDate(DateTime date) {
      return '${date.year}년 ${date.month}월 ${date.day}일';
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Row(
            children: [
              // 캘린더 아이콘
              InkWell(
                onTap: isReadOnly ? null : () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? initialDate,
                    firstDate: firstDate,
                    lastDate: lastDate,
                  );
                  if (date != null) {
                    onDateSelected(date);
                    controller.text = _formatKoreanDate(date);
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isReadOnly ? Colors.grey[300]! : Color(0xFFD7E3FC)),
                    color: isReadOnly ? Colors.grey[200] : Colors.white,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.calendar_today_outlined, 
                    size: 14, 
                    color: isReadOnly ? Colors.grey[400] : Color(0xFF3B82F6),
                  ),
                ),
              ),
              SizedBox(width: 8),
              // 날짜 표시 캡슐
              InkWell(
                onTap: isReadOnly ? null : () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? initialDate,
                    firstDate: firstDate,
                    lastDate: lastDate,
                  );
                  if (date != null) {
                    onDateSelected(date);
                    controller.text = _formatKoreanDate(date);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 140,
                  height: 36,
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isReadOnly ? Colors.grey[200] : Color(0xFFE9ECEF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (selectedDate != null ? _formatKoreanDate(selectedDate) : ''),
                    style: TextStyle(
                      fontSize: 14, 
                      color: isReadOnly ? Colors.grey[500] : Colors.black87, 
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 식품 수정 - 메모 섹션
  Widget _buildEditMemoSection(TextEditingController memoController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '메모',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: memoController,
          maxLines: 3,
          maxLength: 100,
          style: TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: '메모를 입력하세요',
            filled: true,
            fillColor: Color(0xFFF8F9FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFFE9ECEF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFFE9ECEF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFF3B82F6), width: 1.5),
            ),
            contentPadding: EdgeInsets.all(12),
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ),
      ],
    );
  }

  // 통일된 날짜 선택 위젯
  // 날짜 필드는 외부 위젯(DateField)로 분리됨

  // 스크롤 날짜 선택 다이얼로그
  void _showScrollDatePicker({
    required BuildContext context,
    required DateTime currentDate,
    DateTime? firstDate,
    DateTime? lastDate,
    required Function(DateTime) onDateSelected,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ScrollDatePickerDialog(
          currentDate: currentDate,
          firstDate: firstDate ?? DateTime(2000),
          lastDate: lastDate ?? DateTime(2030),
          onDateSelected: onDateSelected,
        );
      },
    );
  }

  // 날짜 범위 체크 헬퍼 함수
  bool _isDateInRange(DateTime date, DateTime? firstDate, DateTime? lastDate) {
    if (firstDate != null && date.isBefore(firstDate)) return false;
    if (lastDate != null && date.isAfter(lastDate)) return false;
    return true;
  }


  // 빠른 칸 이름 수정 다이얼로그
  void _showQuickCompartmentNameEdit() {
    showQuickCompartmentNameEditDialog(
      context,
      currentName: _currentCompartmentName,
      onOpenSettings: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RefrigeratorCompartmentSettingsScreen(
              roomId: widget.roomId,
              refrigeratorName: widget.refrigeratorName,
            ),
          ),
        );
      },
      onSubmit: (newName) async {
        try {
          final refrigerator = await _refrigeratorService.getRefrigeratorByRoomAndName(
            widget.roomId,
            widget.refrigeratorName,
          );
          if (refrigerator != null) {
            List<String> updatedNames = List.from(refrigerator.compartmentNames);
            int currentIndex = updatedNames.indexOf(widget.compartmentName);
            if (currentIndex != -1) {
              if (updatedNames.contains(newName) && newName != widget.compartmentName) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('이미 사용 중인 칸 이름입니다'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              updatedNames[currentIndex] = newName;
              bool success = await _refrigeratorService.updateCompartmentNames(
                widget.roomId,
                widget.refrigeratorName,
                updatedNames,
              );
              if (success) {
                setState(() {
                  _currentCompartmentName = newName;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text('칸 이름이 변경되었습니다'),
                      ],
                    ),
                    backgroundColor: Colors.green[600],
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('칸 이름 변경에 실패했습니다'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  /// 잠금 도장 위젯 생성 (카카오톡 스타일 툴팁 포함)
  Widget _buildLockStamp(Map<String, dynamic> ingredient, {double size = 48}) {
    // 이미지 크기에 따른 도장 크기 조정
    final stampSize = size * 0.7; // 이미지 크기의 70%로 작게
    
    return Positioned(
      top: -size * 0.3, // 적당히 위로
      right: -size * 0.2, // 적당히 오른쪽으로
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

  /// 등록자 사용자 이름 가져오기
  Future<String> _getRegisteredUserName(String? userId) async {
    if (userId == null) return '알 수 없음';
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['nickname'] ?? '사용자';
      }
      return '사용자';
    } catch (e) {
      print('사용자 이름 가져오기 오류: $e');
      return '사용자';
    }
  }

  /// 식품 잠금
  Future<void> _lockIngredient(Map<String, dynamic> ingredient) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
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
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                
                SizedBox(height: 20),
                
                // 제목
                Text(
                  '식품 잠금',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                
                SizedBox(height: 8),
                
                // 설명
                Text(
                  '${ingredient['name']}을(를)\n잠금하시겠습니까?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                
                SizedBox(height: 16),
                
                // 안내 박스
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                          SizedBox(width: 6),
                          Text(
                            '잠금 후 변경사항',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• 등록자만 소비/폐기 가능\n• 등록자만 수정/삭제 가능\n• 등록자만 잠금 해제 가능',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),
                
                // 버튼들
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
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
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          '잠금',
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
        ),
      );

      if (confirm == true) {
        bool success = await _refrigeratorService.lockIngredient(
          roomId: widget.roomId,
          refrigeratorName: widget.refrigeratorName,
          compartmentIndex: _currentTabIndex, // 현재 탭 인덱스 사용
          ingredientId: ingredient['id'],
        );

        if (success) {
          // 스크롤 위치 저장
          _saveScrollPosition();
          
          // 실시간 스트림이 자동으로 업데이트하므로 _loadIngredients() 호출 불필요
          // 스크롤 위치 복원 (약간의 지연 후)
          Future.delayed(Duration(milliseconds: 100), () {
            _restoreScrollPosition();
          });
          
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('잠금 처리 중 오류가 발생했습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('식품 잠금 처리 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('잠금 처리 중 오류가 발생했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 식품 잠금 해제
  Future<void> _unlockIngredient(Map<String, dynamic> ingredient) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
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
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.lock_open_outlined,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                
                SizedBox(height: 20),
                
                // 제목
                Text(
                  '잠금 해제',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                
                SizedBox(height: 8),
                
                // 설명
                Text(
                  '${ingredient['name']}의 잠금을\n해제하시겠습니까?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                
                SizedBox(height: 16),
                
                // 안내 박스
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.green[700]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '해제 후 모든 사용자가 관리할 수 있습니다',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),
                
                // 버튼들
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
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
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          '해제',
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
        ),
      );

      if (confirm == true) {
        bool success = await _refrigeratorService.unlockIngredient(
          roomId: widget.roomId,
          refrigeratorName: widget.refrigeratorName,
          compartmentIndex: _currentTabIndex, // 현재 탭 인덱스 사용
          ingredientId: ingredient['id'],
        );

        if (success) {
          // 스크롤 위치 저장
          _saveScrollPosition();
          
          // 실시간 스트림이 자동으로 업데이트하므로 _loadIngredients() 호출 불필요
          // 스크롤 위치 복원 (약간의 지연 후)
          Future.delayed(Duration(milliseconds: 100), () {
            _restoreScrollPosition();
          });
          
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('잠금 해제 처리 중 오류가 발생했습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('식품 잠금 해제 처리 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('잠금 해제 처리 중 오류가 발생했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 사용자 정보 가져오기 (닉네임 + 아바타 정보)
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


  /// 사용자 정보 다이얼로그 표시
  void _showUserInfoDialog(String? userId) async {
    if (userId == null) return;

    final userInfo = await _getUserInfo(userId);
    final nickname = userInfo['nickname'] ?? '사용자';
    final avatarColor = Color(userInfo['avatarColor'] ?? Colors.blue[400]!.value);
    final avatarIcon = IconUtils.getIconFromCodePoint(userInfo['avatarIcon'] as int?);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 프로필 이미지
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.red[600]!,
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 37,
                  backgroundColor: avatarColor,
                  child: Icon(
                    avatarIcon,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 16),
              // 잠금 아이콘
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock,
                  color: Colors.red[600],
                  size: 24,
                ),
              ),
              SizedBox(height: 12),
              // 메시지
              Text(
                '이 제품은',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 4),
              // 사용자 닉네임
              Text(
                nickname,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                '님이 잠궈두셨습니다',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '확인',
                style: TextStyle(
                  color: Colors.red[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // 정렬 메뉴 표시
  void _showSortMenu(BuildContext context) {
    showSortMenuSheet(
      context,
      currentSortBy: _sortBy,
      onSelected: (sortType) {
        if (_sortBy != sortType) {
          setState(() {
            _sortBy = sortType;
            _controller.setSort(sortType);
            _saveSortPreference(sortType);
            _applySorting();
          });
        }
      },
    );
  }
  
  // 정렬 메뉴 아이템은 외부 파일로 분리됨
  
  // 현재 정렬 라벨 가져오기
  String _getSortLabel() {
    switch (_sortBy) {
      case 'date':
        return '최신순';
      case 'expiry':
        return '유통기한';
      case 'name':
        return '이름순';
      case 'likes':
        return '좋아요';
      default:
        return '최신순';
    }
  }
  
  // 현재 정렬 아이콘 가져오기
  IconData _getSortIcon() {
    switch (_sortBy) {
      case 'date':
        return Icons.access_time_rounded;
      case 'expiry':
        return Icons.calendar_today_rounded;
      case 'name':
        return Icons.sort_by_alpha_rounded;
      case 'likes':
        return Icons.favorite_rounded;
      default:
        return Icons.access_time_rounded;
    }
  }
  
  
}

/// 카카오톡 스타일 툴팁이 있는 도장 위젯

// 분리된 위젯들은 별도 파일로 이동됨 
part of 'ingredients_screen.dart';

mixin IngredientsTabsSortMixin on State<IngredientsScreen>, TickerProvider {
  // Abstract state dependencies
  RefrigeratorService get _refrigeratorService;
  Refrigerator? get _refrigerator;
  set _refrigerator(Refrigerator? value);
  List<String> get _compartmentNames;
  set _compartmentNames(List<String> value);
  TabController? get _tabController;
  set _tabController(TabController? value);
  bool get _isLoading;
  set _isLoading(bool value);
  List<Map<String, dynamic>> get _filteredIngredients;
  set _filteredIngredients(List<Map<String, dynamic>> value);
  Stream<List<Map<String, dynamic>>>? get _ingredientsStream;
  set _ingredientsStream(Stream<List<Map<String, dynamic>>>? value);
  Map<int, Stream<List<Map<String, dynamic>>>> get _preloadedStreams;
  Map<int, List<Map<String, dynamic>>> get _cachedTabData;
  String get _currentCompartmentName;
  set _currentCompartmentName(String value);
  int get _currentTabIndex;
  set _currentTabIndex(int value);
  int get _lastChangedIndex;
  set _lastChangedIndex(int value);
  int? get _editingTabIndex;
  set _editingTabIndex(int? value);
  TextEditingController get _tabNameController;
  FocusNode get _tabNameFocusNode;
  String get _sortBy;
  set _sortBy(String value);
  IngredientsController get _controller;
  Future<void> _loadRefrigeratorData() async {
    try {
      final refrigerator = await _refrigeratorService.getRefrigeratorByRoomAndName(
        widget.roomId,
        widget.refrigeratorName,
      );
      if (refrigerator != null && mounted) {
        setState(() {
          _refrigerator = refrigerator;
          _compartmentNames = refrigerator.compartmentNames;
          _tabController = TabController(
            length: _compartmentNames.length,
            vsync: this,
            initialIndex: widget.compartmentIndex,
          );
        });
        
        // 모든 탭의 스트림 미리 로드 (프리로딩)
        _preloadAllStreams();
      }
    } catch (e) {
      print('냉장고 데이터 로드 오류: $e');
    }
  }
  
  // 모든 탭의 스트림을 미리 생성하고 구독 (즉시 로딩)
  void _preloadAllStreams() {
    for (int i = 0; i < _compartmentNames.length; i++) {
      if (!_preloadedStreams.containsKey(i)) {
        final stream = _refrigeratorService
            .getIngredientsForCompartmentStream(
              widget.roomId,
              widget.refrigeratorName,
              i,
            )
            .asBroadcastStream();
        
        _preloadedStreams[i] = stream;
        
        // 스트림을 즉시 구독하여 데이터 캐시
        stream.listen((data) {
          if (mounted) {
            _cachedTabData[i] = data;
          }
        });
      }
    }
  }

  Future<void> _onTabChanged(int newIndex) async {
    if (newIndex < 0 || newIndex >= _compartmentNames.length) return;
    final newCompartmentName = _compartmentNames[newIndex];
    
    if (mounted) {
      setState(() {
        _currentCompartmentName = newCompartmentName;
        _currentTabIndex = newIndex;
        
        // 프리로드된 스트림 사용 (즉시 로딩!)
        if (_preloadedStreams.containsKey(newIndex)) {
          _ingredientsStream = _preloadedStreams[newIndex];
        } else {
          // fallback: 프리로드되지 않은 경우 즉시 생성
          _initializeStreamForCompartment(newIndex);
        }
      });
    }
    
    // 로딩 완료 플래그 리셋
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) {
        _lastChangedIndex = -1;
      }
    });
  }

  void _initializeStreamForCompartment(int compartmentIndex) {
    final stream = _refrigeratorService.getIngredientsForCompartmentStream(
      widget.roomId,
      widget.refrigeratorName,
      compartmentIndex,
    ).asBroadcastStream();
    
    // 스트림 저장 (다음 방문을 위해)
    _preloadedStreams[compartmentIndex] = stream;
    _ingredientsStream = stream;
    
    // 스트림 구독하여 데이터 캐시
    stream.listen((data) {
      if (mounted) {
        _cachedTabData[compartmentIndex] = data;
      }
    });
  }

  void _startEditingTab(int index, String currentName) {
    setState(() {
      _editingTabIndex = index;
      _tabNameController.text = currentName;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tabNameFocusNode.requestFocus();
    });
  }

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

  void _cancelEditingTab() {
    setState(() {
      _editingTabIndex = null;
    });
  }

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

  Future<void> _loadSavedSortPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSort = prefs.getString('ingredient_sort_preference');
      if (savedSort != null && ['date', 'expiry', 'name', 'likes'].contains(savedSort)) {
        _sortBy = savedSort;
      }
    } catch (e) {
      print('⚠️ 정렬 설정 불러오기 실패: $e');
    }
  }

  Future<void> _saveSortPreference(String sortBy) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ingredient_sort_preference', sortBy);
    } catch (e) {
      print('⚠️ 정렬 설정 저장 실패: $e');
    }
  }

  void _applySorting() {
    _controller.applySorting(_filteredIngredients);
  }
}



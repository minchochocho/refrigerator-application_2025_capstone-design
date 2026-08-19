part of 'ingredients_screen.dart';

mixin IngredientsScrollMixin on State<IngredientsScreen> {
  // Abstract state dependencies
  ScrollController get _scrollController;
  double get _savedScrollPosition;
  set _savedScrollPosition(double value);
  List<Map<String, dynamic>> get _filteredIngredients;
  set _highlightedIngredientId(String? value);
  Map<String, GlobalKey> get _itemKeysById; // 대상 위젯 위치 측정을 위한 키 맵

  // 스냅 재시도 횟수 (렌더링 타이밍에 따라 컨텍스트를 여러 번 확인)
  int _snapRetryCount = 0;

  // 현재 필터된 식품 리스트에 대해 GlobalKey를 미리 준비
  void _ensureKeysForFilteredIngredients() {
    for (final ingredient in _filteredIngredients) {
      final String id = ingredient['id']?.toString() ?? '';
      if (id.isNotEmpty && !_itemKeysById.containsKey(id)) {
        _itemKeysById[id] = GlobalKey();
      }
    }
  }
  void _saveScrollPosition() {
    if (_scrollController.hasClients) {
      _savedScrollPosition = _scrollController.offset;
    }
  }

  void _restoreScrollPosition() {
    if (_scrollController.hasClients && _savedScrollPosition > 0) {
      int attempts = 0;
      void tryRestore() {
        if (_scrollController.hasClients && attempts < 5) {
          _scrollController.animateTo(
            _savedScrollPosition,
            duration: Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        } else if (attempts < 5) {
          attempts++;
          Future.delayed(Duration(milliseconds: 50), tryRestore);
        }
      }
      tryRestore();
    }
  }

  double _calculateCardHeight(Map<String, dynamic> ingredient) {
    return IngredientUtils.calculateCardHeight(ingredient);
  }

  double _calculateCumulativeOffset(int targetIndex) {
    return IngredientUtils.calculateCumulativeOffset(targetIndex, _filteredIngredients);
  }

  void _scrollToIngredient(String targetId, {int attempt = 0}) {
    // 새 타겟으로 스크롤 시작 시 스냅 재시도 카운트 초기화
    if (attempt == 0) {
      _snapRetryCount = 0;
    }

    // 너무 많이 재시도하는 것은 방지 (예: ID가 실제로 존재하지 않는 경우)
    const int maxAttempts = 10;
    if (attempt > maxAttempts) {
      print('⚠️ 타겟 제품 스크롤 최대 재시도 초과: $targetId');
      return;
    }

    // 스크롤 컨트롤러나 데이터가 아직 준비되지 않으면 조금 뒤에 재시도
    if (!_scrollController.hasClients || _filteredIngredients.isEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollToIngredient(targetId, attempt: attempt + 1);
      });
      return;
    }

    // 스크롤 전에 현재 리스트에 대한 GlobalKey를 미리 생성
    _ensureKeysForFilteredIngredients();

    // 현재 필터링/정렬된 리스트에서 타겟 인덱스 찾기
    final int targetIndex = _filteredIngredients.indexWhere(
      (ingredient) => ingredient['id'] == targetId,
    );

    if (targetIndex == -1) {
      // 아직 스트림 데이터가 완전히 로딩되지 않았을 수 있으므로,
      // 잠시 후 여러 번 다시 시도해본다.
      print('⏳ 타겟 제품을 아직 찾지 못했습니다 (재시도 $attempt): $targetId');
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollToIngredient(targetId, attempt: attempt + 1);
      });
      return;
    }

    // 이미 렌더링된 카드가 있다면 ensureVisible로 정확히 상단 정렬
    final String id = _filteredIngredients[targetIndex]['id']?.toString() ?? '';
    final key = _itemKeysById[id];
    if (key != null && key.currentContext != null) {
      _snapToExactTop(targetId);
      return;
    }

    // 아직 렌더링되지 않은(화면 밖에 있는) 카드라면,
    // 카드 높이 기반으로 정확한 오프셋을 계산해서 직접 스크롤
    Future.delayed(Duration(milliseconds: 120), () {
      _performSimpleScroll(targetIndex, targetId);
    });
  }

  void _performDirectScroll(int targetIndex, String targetId) {
    // 이전 카드 높이 기반 스크롤은 실제 렌더 높이와 미세하게 달라
    // 특히 리스트 끝 근처 카드에서 오차가 누적되는 문제가 있어,
    // 단순히 인덱스 비율 기반으로 스크롤하도록 변경.
    _performSimpleScroll(targetIndex, targetId);
  }

  void _performSimpleScroll(int targetIndex, String targetId) {
    if (targetIndex == 0) {
      _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 650),
        curve: Curves.easeInOut,
      ).then((_) {
        // 최상단으로 이동 후에도 실제 카드 위치 기준으로 한 번 더 정렬
        _snapToExactTop(targetId);
      });
      return;
    }

    // 리스트 길이에 따른 단순 비율 기반 스크롤
    // - 카드 높이 계산 오차 없이 전체 길이의 일정 비율 위치로 이동
    // - 특히 끝에서 2~3번째 카드도 보다 안정적으로 보이도록 함
    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      // 아직 스크롤 범위가 계산되지 않았으면 조금 뒤에 다시 시도
      Future.delayed(const Duration(milliseconds: 120), () {
        _performSimpleScroll(targetIndex, targetId);
      });
      return;
    }

    final int totalItems = _filteredIngredients.length;
    if (totalItems <= 1) {
      // 아이템이 1개 이하인 경우는 단순히 끝까지 스크롤
      _scrollController.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOut,
      ).then((_) => _snapToExactTop(targetId));
      return;
    }

    // 0.0 ~ 1.0 사이의 비율로 대상 인덱스를 매핑
    final double fraction = targetIndex.clamp(0, totalItems - 1) / (totalItems - 1);
    final double maxScroll = position.maxScrollExtent;
    final double targetOffset = maxScroll * fraction;

    print('📍 인덱스 기반 스크롤: index=$targetIndex / total=$totalItems, '
        'fraction=${fraction.toStringAsFixed(3)}, '
        'targetOffset=${targetOffset.toStringAsFixed(1)}, maxScroll=$maxScroll');

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOut,
    ).then((_) {
      // 근사 위치까지 스크롤한 뒤, 실제 렌더된 카드 위치로 한 번 더 스냅
      _snapToExactTop(targetId);
    });
  }

  // 실제 렌더 위치를 기준으로 최상단에 정확히 스냅
  void _snapToExactTop(String targetId) {
    final key = _itemKeysById[targetId];
    final context = key?.currentContext;
    if (context == null) {
      // 아직 위젯이 렌더링되지 않았거나 컨텍스트가 준비되지 않은 경우,
      // 잠시 후 다시 시도하여 "근처까지만" 가는 현상을 줄인다.
      const int maxSnapRetries = 8;
      if (_snapRetryCount >= maxSnapRetries) {
        // 재시도 한계에 도달하면 하이라이트만 적용하고 종료
        _highlightIngredient(targetId);
        return;
      }
      _snapRetryCount++;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) {
          _snapToExactTop(targetId);
        }
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Scrollable.ensureVisible(
          context,
          alignment: 0.0, // 최상단 정렬
          duration: Duration(milliseconds: 550), // 조금 더 느리고 자연스럽게
          curve: Curves.easeInOutCubic,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      } catch (_) {}
      _highlightIngredient(targetId);
    });
  }

  void _highlightIngredient(String targetId) {
    setState(() {
      _highlightedIngredientId = targetId;
    });
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _highlightedIngredientId = null;
        });
      }
    });
  }
}



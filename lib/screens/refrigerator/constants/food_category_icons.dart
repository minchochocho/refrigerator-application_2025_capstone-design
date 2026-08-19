import 'package:flutter/material.dart';

/// 식품 분류별 아이콘 맵 (한국어 + 영어 + 관련 제품명)
class FoodCategoryIcons {
  static final Map<String, IconData> icons = {
    // 유제품 (한국어 + 영어)
    '우유': Icons.local_drink, 'milk': Icons.local_drink, 'dairy': Icons.local_drink,
    '요구르트': Icons.local_drink, 'yogurt': Icons.local_drink, 'yoghurt': Icons.local_drink,
    '치즈': Icons.grain, 'cheese': Icons.grain, 'cheddar': Icons.grain, 'mozzarella': Icons.grain,
    '버터': Icons.restaurant, 'butter': Icons.restaurant, 'margarine': Icons.restaurant,
    '크림': Icons.local_drink, 'cream': Icons.local_drink, 'whipping': Icons.local_drink,
    
    // 채소/과일 (한국어 + 영어)
    '사과': Icons.apple, 'apple': Icons.apple, 'red apple': Icons.apple, 'green apple': Icons.apple,
    '바나나': Icons.emoji_food_beverage, 'banana': Icons.emoji_food_beverage,
    '당근': Icons.local_florist, 'carrot': Icons.local_florist,
    '양파': Icons.local_florist, 'onion': Icons.local_florist, 'red onion': Icons.local_florist,
    '마늘': Icons.local_florist, 'garlic': Icons.local_florist,
    '감자': Icons.local_florist, 'potato': Icons.local_florist, 'sweet potato': Icons.local_florist,
    '토마토': Icons.local_florist, 'tomato': Icons.local_florist, 'cherry tomato': Icons.local_florist,
    '상추': Icons.eco, 'lettuce': Icons.eco, 'salad': Icons.eco,
    '배추': Icons.eco, 'cabbage': Icons.eco, 'napa cabbage': Icons.eco,
    '오이': Icons.eco, 'cucumber': Icons.eco,
    '브로콜리': Icons.eco, 'broccoli': Icons.eco, 'cauliflower': Icons.eco,
    '시금치': Icons.eco, 'spinach': Icons.eco,
    '파': Icons.eco, 'green onion': Icons.eco, 'scallion': Icons.eco,
    '버섯': Icons.local_florist, 'mushroom': Icons.local_florist, 'shiitake': Icons.local_florist,
    '오렌지': Icons.emoji_food_beverage, 'orange': Icons.emoji_food_beverage,
    '포도': Icons.emoji_food_beverage, 'grape': Icons.emoji_food_beverage,
    '딸기': Icons.emoji_food_beverage, 'strawberry': Icons.emoji_food_beverage,
    '배': Icons.emoji_food_beverage, 'pear': Icons.emoji_food_beverage,
    '복숭아': Icons.emoji_food_beverage, 'peach': Icons.emoji_food_beverage,
    
    // 육류 (한국어 + 영어)
    '소고기': Icons.restaurant_menu, 'beef': Icons.restaurant_menu, 'steak': Icons.restaurant_menu,
    '돼지고기': Icons.restaurant_menu, 'pork': Icons.restaurant_menu, 'ham': Icons.restaurant_menu,
    '닭고기': Icons.restaurant_menu, 'chicken': Icons.restaurant_menu, 'poultry': Icons.restaurant_menu,
    '삼겹살': Icons.restaurant_menu, 'pork belly': Icons.restaurant_menu, 'bacon': Icons.restaurant_menu,
    '갈비': Icons.restaurant_menu, 'ribs': Icons.restaurant_menu, 'short ribs': Icons.restaurant_menu,
    '양고기': Icons.restaurant_menu, 'lamb': Icons.restaurant_menu, 'mutton': Icons.restaurant_menu,
    '소시지': Icons.restaurant_menu, 'sausage': Icons.restaurant_menu, 'hot dog': Icons.restaurant_menu,
    
    // 해산물 (한국어 + 영어)
    '생선': Icons.set_meal, 'fish': Icons.set_meal, 'salmon': Icons.set_meal, 'tuna': Icons.set_meal,
    '새우': Icons.set_meal, 'shrimp': Icons.set_meal, 'prawn': Icons.set_meal,
    '조개': Icons.set_meal, 'clam': Icons.set_meal, 'mussel': Icons.set_meal, 'scallop': Icons.set_meal,
    '오징어': Icons.set_meal, 'squid': Icons.set_meal, 'calamari': Icons.set_meal,
    '문어': Icons.set_meal, 'octopus': Icons.set_meal,
    '게': Icons.set_meal, 'crab': Icons.set_meal,
    '랍스터': Icons.set_meal, 'lobster': Icons.set_meal,
    
    // 계란 (한국어 + 영어)
    '계란': Icons.egg, '달걀': Icons.egg, 'egg': Icons.egg, 'eggs': Icons.egg,
    
    // 곡물/면류 (한국어 + 영어)
    '쌀': Icons.rice_bowl, 'rice': Icons.rice_bowl, 'brown rice': Icons.rice_bowl,
    '밀가루': Icons.bakery_dining, 'flour': Icons.bakery_dining, 'wheat': Icons.bakery_dining,
    '라면': Icons.ramen_dining, 'ramen': Icons.ramen_dining, 'instant noodle': Icons.ramen_dining,
    '파스타': Icons.restaurant, 'pasta': Icons.restaurant, 'spaghetti': Icons.restaurant,
    '우동': Icons.ramen_dining, 'udon': Icons.ramen_dining, 'noodle': Icons.ramen_dining,
    '빵': Icons.bakery_dining, 'bread': Icons.bakery_dining, 'baguette': Icons.bakery_dining,
    '시리얼': Icons.rice_bowl, 'cereal': Icons.rice_bowl, 'cornflakes': Icons.rice_bowl,
    
    // 조미료/양념 (한국어 + 영어)
    '소금': Icons.grain, 'salt': Icons.grain, 'sea salt': Icons.grain,
    '설탕': Icons.grain, 'sugar': Icons.grain, 'brown sugar': Icons.grain,
    '간장': Icons.local_bar, 'soy sauce': Icons.local_bar, 'soya sauce': Icons.local_bar,
    '고추장': Icons.local_bar, 'gochujang': Icons.local_bar, 'chili paste': Icons.local_bar,
    '된장': Icons.local_bar, 'miso': Icons.local_bar, 'soybean paste': Icons.local_bar,
    '식용유': Icons.local_bar, 'oil': Icons.local_bar, 'cooking oil': Icons.local_bar,
    '참기름': Icons.local_bar, 'sesame oil': Icons.local_bar,
    '올리브오일': Icons.local_bar, 'olive oil': Icons.local_bar,
    '식초': Icons.local_bar, 'vinegar': Icons.local_bar, 'white vinegar': Icons.local_bar,
    '마요네즈': Icons.local_bar, 'mayonnaise': Icons.local_bar, 'mayo': Icons.local_bar,
    '케첩': Icons.local_bar, 'ketchup': Icons.local_bar, 'tomato sauce': Icons.local_bar,
    
    // 음료 (한국어 + 영어)
    '물': Icons.water_drop, 'water': Icons.water_drop, 'mineral water': Icons.water_drop,
    '주스': Icons.local_drink, 'juice': Icons.local_drink, 'orange juice': Icons.local_drink,
    '커피': Icons.coffee, 'coffee': Icons.coffee, 'espresso': Icons.coffee,
    '차': Icons.emoji_food_beverage, 'tea': Icons.emoji_food_beverage, 'green tea': Icons.emoji_food_beverage,
    '맥주': Icons.sports_bar, 'beer': Icons.sports_bar, 'lager': Icons.sports_bar,
    '와인': Icons.wine_bar, 'wine': Icons.wine_bar, 'red wine': Icons.wine_bar,
    '소다': Icons.local_drink, 'soda': Icons.local_drink, 'cola': Icons.local_drink,
    
    // 냉동식품 (한국어 + 영어)
    '만두': Icons.restaurant, 'dumpling': Icons.restaurant, 'mandu': Icons.restaurant,
    '아이스크림': Icons.icecream, 'ice cream': Icons.icecream, 'gelato': Icons.icecream,
    '냉동피자': Icons.local_pizza, 'frozen pizza': Icons.local_pizza,
    '냉동식품': Icons.ac_unit, 'frozen food': Icons.ac_unit,
    
    // 빵/과자 (한국어 + 영어)
    '케이크': Icons.cake, 'cake': Icons.cake, 'chocolate cake': Icons.cake,
    '과자': Icons.cookie, 'snack': Icons.cookie, 'cookie': Icons.cookie, 'biscuit': Icons.cookie,
    '초콜릿': Icons.cookie, 'chocolate': Icons.cookie, 'candy': Icons.cookie,
    
    // 기타 (한국어 + 영어)
    '김치': Icons.local_dining, 'kimchi': Icons.local_dining,
    '두부': Icons.restaurant, 'tofu': Icons.restaurant, 'bean curd': Icons.restaurant,
    '콩': Icons.grain, 'bean': Icons.grain, 'soybean': Icons.grain,
    '견과류': Icons.grain, 'nuts': Icons.grain, 'almond': Icons.grain, 'walnut': Icons.grain,
    '땅콩': Icons.grain, 'peanut': Icons.grain,
    '피자': Icons.local_pizza, 'pizza': Icons.local_pizza,
    '햄버거': Icons.lunch_dining, 'hamburger': Icons.lunch_dining, 'burger': Icons.lunch_dining,
    '샐러드': Icons.eco, 'salad': Icons.eco,
    '스프': Icons.soup_kitchen, 'soup': Icons.soup_kitchen,
    
    // 브랜드/제품명
    'coca cola': Icons.local_drink, 'pepsi': Icons.local_drink,
    'sprite': Icons.local_drink, 'fanta': Icons.local_drink,
    'heineken': Icons.sports_bar, 'budweiser': Icons.sports_bar,
    'starbucks': Icons.coffee, 'nescafe': Icons.coffee,
  };
  
  /// 식품명으로 아이콘 찾기 (개선된 매칭 로직)
  static IconData getFoodIcon(String foodName) {
    final lowerFoodName = foodName.toLowerCase();
    
    // 정확한 매치 먼저 시도 (대소문자 무시)
    for (String category in icons.keys) {
      if (category.toLowerCase() == lowerFoodName) {
        return icons[category]!;
      }
    }
    
    // 부분 매치 시도 (대소문자 무시)
    for (String category in icons.keys) {
      if (lowerFoodName.contains(category.toLowerCase()) || 
          category.toLowerCase().contains(lowerFoodName)) {
        return icons[category]!;
      }
    }
    
    // 단어별 매치 시도
    final foodWords = lowerFoodName.split(' ');
    for (String word in foodWords) {
      for (String category in icons.keys) {
        if (category.toLowerCase().contains(word) || 
            word.contains(category.toLowerCase())) {
          return icons[category]!;
        }
      }
    }
    
    // 기본 아이콘
    return Icons.fastfood;
  }
}


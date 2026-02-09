class ExpenseRecord {
  final int? id;
  final String title;
  final double amount;
  final String category;
  final String categoryIcon;
  final bool isExpense;
  final DateTime date;
  final String? note;

  ExpenseRecord({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    this.categoryIcon = '📦',
    required this.isExpense,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'categoryIcon': categoryIcon,
      'isExpense': isExpense ? 1 : 0,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory ExpenseRecord.fromMap(Map<String, dynamic> map) {
    return ExpenseRecord(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      category: map['category'],
      categoryIcon: map['categoryIcon'] ?? '📦',
      isExpense: map['isExpense'] == 1,
      date: DateTime.parse(map['date']),
      note: map['note'],
    );
  }
}

class Category {
  final int? id;
  final String name;
  final String icon;
  final bool isExpense;
  final int sortOrder;

  const Category({
    this.id,
    required this.name,
    required this.icon,
    required this.isExpense,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'isExpense': isExpense ? 1 : 0,
      'sortOrder': sortOrder,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      isExpense: map['isExpense'] == 1,
      sortOrder: map['sortOrder'] ?? 0,
    );
  }

  Category copyWith({
    int? id,
    String? name,
    String? icon,
    bool? isExpense,
    int? sortOrder,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      isExpense: isExpense ?? this.isExpense,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

// 預設分類（首次安裝時使用）
const defaultExpenseCategories = [
  Category(name: '餐飲', icon: '🍜', isExpense: true, sortOrder: 0),
  Category(name: '交通', icon: '🚗', isExpense: true, sortOrder: 1),
  Category(name: '購物', icon: '🛒', isExpense: true, sortOrder: 2),
  Category(name: '娛樂', icon: '🎮', isExpense: true, sortOrder: 3),
  Category(name: '醫療', icon: '💊', isExpense: true, sortOrder: 4),
  Category(name: '居家', icon: '🏠', isExpense: true, sortOrder: 5),
  Category(name: '教育', icon: '📚', isExpense: true, sortOrder: 6),
  Category(name: '其他', icon: '📦', isExpense: true, sortOrder: 7),
];

const defaultIncomeCategories = [
  Category(name: '薪資', icon: '💰', isExpense: false, sortOrder: 0),
  Category(name: '獎金', icon: '🎁', isExpense: false, sortOrder: 1),
  Category(name: '投資', icon: '📈', isExpense: false, sortOrder: 2),
  Category(name: '副業', icon: '💼', isExpense: false, sortOrder: 3),
  Category(name: '其他', icon: '💵', isExpense: false, sortOrder: 4),
];

// 可選的 emoji 圖示
const availableIcons = [
  '🍜', '🍔', '🍕', '☕', '🍺', '🥗',
  '🚗', '🚌', '🚇', '✈️', '⛽', '🚕',
  '🛒', '👕', '👟', '💄', '📱', '💻',
  '🎮', '🎬', '🎵', '📺', '🎨', '⚽',
  '💊', '🏥', '🩺', '💉',
  '🏠', '🔧', '💡', '🧹', '🛋️',
  '📚', '🎓', '📝', '💼',
  '💰', '💵', '💳', '🎁', '📈', '🏦',
  '📦', '❓', '⭐', '❤️', '🔥', '✨',
];

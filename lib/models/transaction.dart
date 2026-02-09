class ExpenseRecord {
  final int? id;
  final String title;
  final double amount;
  final String category;
  final bool isExpense;
  final DateTime date;
  final String? note;

  ExpenseRecord({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
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
      isExpense: map['isExpense'] == 1,
      date: DateTime.parse(map['date']),
      note: map['note'],
    );
  }
}

class Category {
  final String name;
  final String icon;
  final bool isExpense;

  const Category({
    required this.name,
    required this.icon,
    required this.isExpense,
  });
}

// 預設分類
const expenseCategories = [
  Category(name: '餐飲', icon: '🍜', isExpense: true),
  Category(name: '交通', icon: '🚗', isExpense: true),
  Category(name: '購物', icon: '🛒', isExpense: true),
  Category(name: '娛樂', icon: '🎮', isExpense: true),
  Category(name: '醫療', icon: '💊', isExpense: true),
  Category(name: '居家', icon: '🏠', isExpense: true),
  Category(name: '教育', icon: '📚', isExpense: true),
  Category(name: '其他', icon: '📦', isExpense: true),
];

const incomeCategories = [
  Category(name: '薪資', icon: '💰', isExpense: false),
  Category(name: '獎金', icon: '🎁', isExpense: false),
  Category(name: '投資', icon: '📈', isExpense: false),
  Category(name: '副業', icon: '💼', isExpense: false),
  Category(name: '其他', icon: '💵', isExpense: false),
];

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expense_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        categoryIcon TEXT DEFAULT '📦',
        isExpense INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        isExpense INTEGER NOT NULL,
        sortOrder INTEGER DEFAULT 0
      )
    ''');

    // 插入預設分類
    await _insertDefaultCategories(db);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 加入 categories 表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          icon TEXT NOT NULL,
          isExpense INTEGER NOT NULL,
          sortOrder INTEGER DEFAULT 0
        )
      ''');

      // 加入 categoryIcon 欄位到 transactions
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN categoryIcon TEXT DEFAULT "📦"');
      } catch (e) {
        // 欄位可能已存在
      }

      // 插入預設分類
      await _insertDefaultCategories(db);
    }
  }

  Future _insertDefaultCategories(Database db) async {
    // 檢查是否已有分類
    final existing = await db.query('categories', limit: 1);
    if (existing.isNotEmpty) return;

    for (var cat in defaultExpenseCategories) {
      await db.insert('categories', cat.toMap());
    }
    for (var cat in defaultIncomeCategories) {
      await db.insert('categories', cat.toMap());
    }
  }

  // ========== 分類相關 ==========

  // 取得所有分類
  Future<List<Category>> getCategories({bool? isExpense}) async {
    final db = await database;
    final result = await db.query(
      'categories',
      where: isExpense != null ? 'isExpense = ?' : null,
      whereArgs: isExpense != null ? [isExpense ? 1 : 0] : null,
      orderBy: 'isExpense DESC, sortOrder ASC',
    );
    return result.map((map) => Category.fromMap(map)).toList();
  }

  // 取得支出分類
  Future<List<Category>> getExpenseCategories() async {
    return getCategories(isExpense: true);
  }

  // 取得收入分類
  Future<List<Category>> getIncomeCategories() async {
    return getCategories(isExpense: false);
  }

  // 新增分類
  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  // 更新分類
  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  // 刪除分類
  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // 取得分類 by name
  Future<Category?> getCategoryByName(String name, bool isExpense) async {
    final db = await database;
    final result = await db.query(
      'categories',
      where: 'name = ? AND isExpense = ?',
      whereArgs: [name, isExpense ? 1 : 0],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Category.fromMap(result.first);
  }

  // ========== 交易相關 ==========

  // 新增交易
  Future<int> insertTransaction(ExpenseRecord record) async {
    final db = await database;
    return await db.insert('transactions', record.toMap());
  }

  // 取得所有交易
  Future<List<ExpenseRecord>> getAllTransactions() async {
    final db = await database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((map) => ExpenseRecord.fromMap(map)).toList();
  }

  // 取得特定日期範圍的交易
  Future<List<ExpenseRecord>> getTransactionsByDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return result.map((map) => ExpenseRecord.fromMap(map)).toList();
  }

  // 取得特定月份的交易
  Future<List<ExpenseRecord>> getTransactionsByMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return getTransactionsByDateRange(start, end);
  }

  // 刪除交易
  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // 更新交易
  Future<int> updateTransaction(ExpenseRecord record) async {
    final db = await database;
    return await db.update(
      'transactions',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  // 取得統計資料
  Future<Map<String, double>> getCategoryStats(
      DateTime start, DateTime end, bool isExpense) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM transactions
      WHERE date BETWEEN ? AND ? AND isExpense = ?
      GROUP BY category
    ''', [start.toIso8601String(), end.toIso8601String(), isExpense ? 1 : 0]);

    return {for (var row in result) row['category'] as String: row['total'] as double};
  }
}

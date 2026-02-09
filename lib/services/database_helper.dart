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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        isExpense INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT
      )
    ''');
  }

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

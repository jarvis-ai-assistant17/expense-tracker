import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/transaction.dart';
import 'services/database_helper.dart';
import 'services/receipt_scanner.dart';

void main() {
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '記帳本',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<ExpenseRecord> _transactions = [];
  List<Category> _expenseCategories = [];
  List<Category> _incomeCategories = [];
  DateTime _selectedMonth = DateTime.now();
  double _totalIncome = 0;
  double _totalExpense = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadCategories();
    await _loadTransactions();
  }

  Future<void> _loadCategories() async {
    final expense = await _db.getExpenseCategories();
    final income = await _db.getIncomeCategories();
    setState(() {
      _expenseCategories = expense;
      _incomeCategories = income;
    });
  }

  Future<void> _loadTransactions() async {
    final transactions = await _db.getTransactionsByMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    
    double income = 0;
    double expense = 0;
    for (var t in transactions) {
      if (t.isExpense) {
        expense += t.amount;
      } else {
        income += t.amount;
      }
    }

    setState(() {
      _transactions = transactions;
      _totalIncome = income;
      _totalExpense = expense;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###', 'zh_TW');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 記帳本'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => _showStats(context),
            tooltip: '統計',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showCategoryManager(context),
            tooltip: '管理分類',
          ),
        ],
      ),
      body: Column(
        children: [
          // 月份選擇器
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  DateFormat('yyyy年 MM月').format(_selectedMonth),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          
          // 收支摘要卡片
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      '收入',
                      '\$${currencyFormat.format(_totalIncome)}',
                      Colors.green,
                    ),
                    _buildSummaryItem(
                      '支出',
                      '\$${currencyFormat.format(_totalExpense)}',
                      Colors.red,
                    ),
                    _buildSummaryItem(
                      '結餘',
                      '\$${currencyFormat.format(_totalIncome - _totalExpense)}',
                      (_totalIncome - _totalExpense) >= 0
                          ? Colors.blue
                          : Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 交易列表
          Expanded(
            child: _transactions.isEmpty
                ? const Center(
                    child: Text('還沒有記錄\n點擊 + 新增第一筆！', textAlign: TextAlign.center),
                  )
                : ListView.builder(
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final t = _transactions[index];
                      return _buildTransactionTile(t, currencyFormat);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'scan',
            onPressed: () => _showScanOptions(context),
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => _showAddDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('記一筆'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(ExpenseRecord t, NumberFormat format) {
    final categories = t.isExpense ? _expenseCategories : _incomeCategories;
    final category = categories.firstWhere(
      (c) => c.name == t.category,
      orElse: () => Category(name: t.category, icon: t.categoryIcon, isExpense: t.isExpense),
    );

    return Dismissible(
      key: Key(t.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        await _db.deleteTransaction(t.id!);
        _loadTransactions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已刪除')),
          );
        }
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: t.isExpense
              ? Colors.red.withOpacity(0.1)
              : Colors.green.withOpacity(0.1),
          child: Text(category.icon, style: const TextStyle(fontSize: 24)),
        ),
        title: Text(t.title),
        subtitle: Text(
          '${category.name} • ${DateFormat('MM/dd').format(t.date)}',
        ),
        trailing: Text(
          '${t.isExpense ? "-" : "+"}\$${format.format(t.amount)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: t.isExpense ? Colors.red : Colors.green,
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddTransactionSheet(
        expenseCategories: _expenseCategories,
        incomeCategories: _incomeCategories,
        onSaved: _loadTransactions,
      ),
    );
  }

  void _showStats(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatsSheet(
        month: _selectedMonth,
        transactions: _transactions,
        expenseCategories: _expenseCategories,
        incomeCategories: _incomeCategories,
      ),
    );
  }

  void _showCategoryManager(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CategoryManagerPage(),
      ),
    );
    _loadData(); // 重新載入分類
  }

  void _showScanOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '📷 掃描發票/收據',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, size: 32),
                title: const Text('拍照'),
                subtitle: const Text('使用相機拍攝發票'),
                onTap: () {
                  Navigator.pop(context);
                  _scanReceipt(context, fromCamera: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, size: 32),
                title: const Text('從相簿選擇'),
                subtitle: const Text('選擇已拍好的照片'),
                onTap: () {
                  Navigator.pop(context);
                  _scanReceipt(context, fromCamera: false);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanReceipt(BuildContext context, {required bool fromCamera}) async {
    final scanner = ReceiptScanner();
    
    try {
      // 顯示載入中
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('處理中...'),
                ],
              ),
            ),
          ),
        ),
      );

      // 取得圖片
      final File? imageFile = fromCamera
          ? await scanner.takePhoto()
          : await scanner.pickFromGallery();

      if (imageFile == null) {
        if (mounted) Navigator.pop(context); // 關閉載入對話框
        return;
      }

      // 掃描發票
      final result = await scanner.scanReceipt(imageFile);
      
      if (mounted) {
        Navigator.pop(context); // 關閉載入對話框
        
        // 顯示掃描結果
        _showScanResult(context, result, imageFile);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 關閉載入對話框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('掃描失敗: $e')),
        );
      }
    } finally {
      scanner.dispose();
    }
  }

  void _showScanResult(BuildContext context, ScanResult result, File imageFile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ScanResultSheet(
        result: result,
        imageFile: imageFile,
        expenseCategories: _expenseCategories,
        onSaved: _loadTransactions,
      ),
    );
  }
}

// 新增交易的底部表單
class AddTransactionSheet extends StatefulWidget {
  final List<Category> expenseCategories;
  final List<Category> incomeCategories;
  final VoidCallback onSaved;

  const AddTransactionSheet({
    super.key,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.onSaved,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  bool _isExpense = true;
  Category? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.expenseCategories.isNotEmpty 
        ? widget.expenseCategories.first 
        : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _isExpense ? widget.expenseCategories : widget.incomeCategories;
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 標題
              Text(
                '新增記錄',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // 收入/支出切換
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('支出'), icon: Icon(Icons.remove)),
                  ButtonSegment(value: false, label: Text('收入'), icon: Icon(Icons.add)),
                ],
                selected: {_isExpense},
                onSelectionChanged: (value) {
                  setState(() {
                    _isExpense = value.first;
                    final cats = _isExpense ? widget.expenseCategories : widget.incomeCategories;
                    _selectedCategory = cats.isNotEmpty ? cats.first : null;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // 金額
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '金額',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '請輸入金額';
                  if (double.tryParse(value) == null) return '請輸入有效數字';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 名稱
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '項目名稱',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '請輸入名稱';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 分類
              Text('分類', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (categories.isEmpty)
                const Text('沒有分類，請先到設定新增')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((cat) {
                    final isSelected = _selectedCategory?.name == cat.name;
                    return ChoiceChip(
                      label: Text('${cat.icon} ${cat.name}'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = cat);
                        }
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              
              // 日期
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat('yyyy/MM/dd').format(_selectedDate)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // 備註
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: '備註（選填）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              
              // 儲存按鈕
              FilledButton.icon(
                onPressed: _selectedCategory != null ? _save : null,
                icon: const Icon(Icons.save),
                label: const Text('儲存'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) return;

    final record = ExpenseRecord(
      title: _titleController.text,
      amount: double.parse(_amountController.text),
      category: _selectedCategory!.name,
      categoryIcon: _selectedCategory!.icon,
      isExpense: _isExpense,
      date: _selectedDate,
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    await DatabaseHelper.instance.insertTransaction(record);
    widget.onSaved();
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已儲存 ✓')),
      );
    }
  }
}

// 統計頁面
class StatsSheet extends StatelessWidget {
  final DateTime month;
  final List<ExpenseRecord> transactions;
  final List<Category> expenseCategories;
  final List<Category> incomeCategories;

  const StatsSheet({
    super.key,
    required this.month,
    required this.transactions,
    required this.expenseCategories,
    required this.incomeCategories,
  });

  @override
  Widget build(BuildContext context) {
    final expenseByCategory = <String, double>{};
    final incomeByCategory = <String, double>{};

    for (var t in transactions) {
      if (t.isExpense) {
        expenseByCategory[t.category] =
            (expenseByCategory[t.category] ?? 0) + t.amount;
      } else {
        incomeByCategory[t.category] =
            (incomeByCategory[t.category] ?? 0) + t.amount;
      }
    }

    final format = NumberFormat('#,###', 'zh_TW');

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '📊 ${DateFormat('yyyy年MM月').format(month)} 統計',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (expenseByCategory.isNotEmpty) ...[
                      Text(
                        '支出分類',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...expenseByCategory.entries.map((e) {
                        final cat = expenseCategories.firstWhere(
                          (c) => c.name == e.key,
                          orElse: () => Category(name: e.key, icon: '📦', isExpense: true),
                        );
                        return ListTile(
                          leading: Text(cat.icon, style: const TextStyle(fontSize: 24)),
                          title: Text(e.key),
                          trailing: Text(
                            '\$${format.format(e.value)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        );
                      }),
                      const Divider(),
                    ],
                    if (incomeByCategory.isNotEmpty) ...[
                      Text(
                        '收入分類',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...incomeByCategory.entries.map((e) {
                        final cat = incomeCategories.firstWhere(
                          (c) => c.name == e.key,
                          orElse: () => Category(name: e.key, icon: '💵', isExpense: false),
                        );
                        return ListTile(
                          leading: Text(cat.icon, style: const TextStyle(fontSize: 24)),
                          title: Text(e.key),
                          trailing: Text(
                            '\$${format.format(e.value)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        );
                      }),
                    ],
                    if (expenseByCategory.isEmpty && incomeByCategory.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('本月還沒有記錄'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ========== 分類管理頁面 ==========
class CategoryManagerPage extends StatefulWidget {
  const CategoryManagerPage({super.key});

  @override
  State<CategoryManagerPage> createState() => _CategoryManagerPageState();
}

class _CategoryManagerPageState extends State<CategoryManagerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Category> _expenseCategories = [];
  List<Category> _incomeCategories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final expense = await _db.getExpenseCategories();
    final income = await _db.getIncomeCategories();
    setState(() {
      _expenseCategories = expense;
      _incomeCategories = income;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ 管理分類'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '支出分類'),
            Tab(text: '收入分類'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList(_expenseCategories, true),
          _buildCategoryList(_incomeCategories, false),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(_tabController.index == 0),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryList(List<Category> categories, bool isExpense) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('沒有${isExpense ? "支出" : "收入"}分類', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            const Text('點擊 + 新增'),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: categories.length,
      onReorder: (oldIndex, newIndex) async {
        if (newIndex > oldIndex) newIndex--;
        setState(() {
          final item = categories.removeAt(oldIndex);
          categories.insert(newIndex, item);
        });
        // 更新排序
        for (int i = 0; i < categories.length; i++) {
          await _db.updateCategory(categories[i].copyWith(sortOrder: i));
        }
      },
      itemBuilder: (context, index) {
        final cat = categories[index];
        return ListTile(
          key: ValueKey(cat.id),
          leading: Text(cat.icon, style: const TextStyle(fontSize: 28)),
          title: Text(cat.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditCategoryDialog(cat),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(cat),
              ),
              const Icon(Icons.drag_handle),
            ],
          ),
        );
      },
    );
  }

  void _showAddCategoryDialog(bool isExpense) {
    showDialog(
      context: context,
      builder: (context) => CategoryEditDialog(
        isExpense: isExpense,
        onSaved: _loadCategories,
      ),
    );
  }

  void _showEditCategoryDialog(Category category) {
    showDialog(
      context: context,
      builder: (context) => CategoryEditDialog(
        category: category,
        isExpense: category.isExpense,
        onSaved: _loadCategories,
      ),
    );
  }

  void _confirmDelete(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除「${category.icon} ${category.name}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await _db.deleteCategory(category.id!);
              _loadCategories();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已刪除')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}

// 分類編輯對話框
class CategoryEditDialog extends StatefulWidget {
  final Category? category;
  final bool isExpense;
  final VoidCallback onSaved;

  const CategoryEditDialog({
    super.key,
    this.category,
    required this.isExpense,
    required this.onSaved,
  });

  @override
  State<CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<CategoryEditDialog> {
  final _nameController = TextEditingController();
  String _selectedIcon = '📦';

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _selectedIcon = widget.category!.icon;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return AlertDialog(
      title: Text(isEditing ? '編輯分類' : '新增${widget.isExpense ? "支出" : "收入"}分類'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 名稱輸入
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '分類名稱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            // 圖示選擇
            const Text('選擇圖示'),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              width: double.maxFinite,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: availableIcons.length,
                itemBuilder: (context, index) {
                  final icon = availableIcons[index];
                  final isSelected = _selectedIcon == icon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Center(
                        child: Text(icon, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('儲存'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入分類名稱')),
      );
      return;
    }

    final db = DatabaseHelper.instance;

    if (widget.category != null) {
      // 編輯現有分類
      await db.updateCategory(widget.category!.copyWith(
        name: name,
        icon: _selectedIcon,
      ));
    } else {
      // 新增分類
      await db.insertCategory(Category(
        name: name,
        icon: _selectedIcon,
        isExpense: widget.isExpense,
      ));
    }

    widget.onSaved();
    if (mounted) {
      Navigator.pop(context);
    }
  }
}

// ========== 掃描結果表單 ==========
class ScanResultSheet extends StatefulWidget {
  final ScanResult result;
  final File imageFile;
  final List<Category> expenseCategories;
  final VoidCallback onSaved;

  const ScanResultSheet({
    super.key,
    required this.result,
    required this.imageFile,
    required this.expenseCategories,
    required this.onSaved,
  });

  @override
  State<ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends State<ScanResultSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  Category? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _showRawText = false;

  @override
  void initState() {
    super.initState();
    
    // 從掃描結果填入
    if (widget.result.amount != null) {
      _amountController.text = widget.result.amount!.toStringAsFixed(
        widget.result.amount! == widget.result.amount!.roundToDouble() ? 0 : 2
      );
    }
    if (widget.result.storeName != null) {
      _titleController.text = widget.result.storeName!;
    }
    if (widget.result.date != null) {
      _selectedDate = widget.result.date!;
    }
    
    _selectedCategory = widget.expenseCategories.isNotEmpty
        ? widget.expenseCategories.first
        : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 標題
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '📷 掃描結果',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _showRawText = !_showRawText),
                    child: Text(_showRawText ? '隱藏原文' : '顯示原文'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // 顯示掃描到的金額選項
              if (widget.result.allAmounts.isNotEmpty) ...[
                const Text('偵測到的金額：', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: widget.result.allAmounts.map((amt) {
                    final isSelected = _amountController.text == amt;
                    return ActionChip(
                      label: Text('\$$amt'),
                      backgroundColor: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                      onPressed: () {
                        setState(() => _amountController.text = amt);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              
              // 原始文字（可展開）
              if (_showRawText) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.result.rawText.isEmpty ? '（無法辨識文字）' : widget.result.rawText,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // 金額
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '金額',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '請輸入金額';
                  if (double.tryParse(value) == null) return '請輸入有效數字';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 名稱
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '項目名稱',
                  hintText: '例：午餐、加油',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '請輸入名稱';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 分類
              Text('分類', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (widget.expenseCategories.isEmpty)
                const Text('沒有分類，請先到設定新增')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.expenseCategories.map((cat) {
                    final isSelected = _selectedCategory?.name == cat.name;
                    return ChoiceChip(
                      label: Text('${cat.icon} ${cat.name}'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = cat);
                        }
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              
              // 日期
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat('yyyy/MM/dd').format(_selectedDate)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // 備註
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: '備註（選填）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              
              // 儲存按鈕
              FilledButton.icon(
                onPressed: _selectedCategory != null ? _save : null,
                icon: const Icon(Icons.save),
                label: const Text('儲存'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) return;

    final record = ExpenseRecord(
      title: _titleController.text,
      amount: double.parse(_amountController.text),
      category: _selectedCategory!.name,
      categoryIcon: _selectedCategory!.icon,
      isExpense: true,
      date: _selectedDate,
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    await DatabaseHelper.instance.insertTransaction(record);
    widget.onSaved();
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已儲存 ✓')),
      );
    }
  }
}

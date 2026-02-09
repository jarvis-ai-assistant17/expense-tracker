import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/transaction.dart';
import 'services/database_helper.dart';

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
  DateTime _selectedMonth = DateTime.now();
  double _totalIncome = 0;
  double _totalExpense = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('記一筆'),
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
    final category = t.isExpense
        ? expenseCategories.firstWhere(
            (c) => c.name == t.category,
            orElse: () => expenseCategories.last,
          )
        : incomeCategories.firstWhere(
            (c) => c.name == t.category,
            orElse: () => incomeCategories.last,
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
      ),
    );
  }
}

// 新增交易的底部表單
class AddTransactionSheet extends StatefulWidget {
  final VoidCallback onSaved;

  const AddTransactionSheet({super.key, required this.onSaved});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  bool _isExpense = true;
  String _selectedCategory = '餐飲';
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _isExpense ? expenseCategories : incomeCategories;
    
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
                    _selectedCategory = _isExpense ? '餐飲' : '薪資';
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat.name;
                  return ChoiceChip(
                    label: Text('${cat.icon} ${cat.name}'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = cat.name);
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
                onPressed: _save,
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

    final record = ExpenseRecord(
      title: _titleController.text,
      amount: double.parse(_amountController.text),
      category: _selectedCategory,
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

  const StatsSheet({
    super.key,
    required this.month,
    required this.transactions,
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
                          orElse: () => expenseCategories.last,
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
                          orElse: () => incomeCategories.last,
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

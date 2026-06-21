import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZFDataNodeApp());
}

class ZFDataNodeApp extends StatelessWidget {
  const ZFDataNodeApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZF Data Node',
      theme: ThemeData.dark(), 
      home: const CoreReceiverNode(),
    );
  }
}

class DatabaseNode {
  static final DatabaseNode instance = DatabaseNode._init();
  static Database? _database;
  DatabaseNode._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('zf_master_data.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE StatusAbah (
        id_sanad TEXT PRIMARY KEY,
        teks_status TEXT NOT NULL,
        t_abs TEXT NOT NULL,
        t_ext TEXT NOT NULL
      )
    ''');
  }

  Future<void> insertStatus(Map<String, dynamic> data) async {
    final db = await instance.database;
    await db.insert('StatusAbah', data, conflictAlgorithm: ConflictAlgorithm.abort);
  }
}

class CoreReceiverNode extends StatefulWidget {
  const CoreReceiverNode({Key? key}) : super(key: key);
  @override
  State<CoreReceiverNode> createState() => _CoreReceiverNodeState();
}

class _CoreReceiverNodeState extends State<CoreReceiverNode> {
  final TextEditingController _teksController = TextEditingController();
  final TextEditingController _sanadController = TextEditingController();
  DateTime _tAbs = DateTime.now();

  @override
  void initState() {
    super.initState();
    ReceiveSharingIntent.getTextStream().listen((String value) {
      setState(() => _teksController.text = value);
    });
    ReceiveSharingIntent.getInitialText().then((String? value) {
      if (value != null) setState(() => _teksController.text = value);
    });
  }

  Future<void> _kalibrasiWaktuAbsolut() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context, initialDate: _tAbs, firstDate: DateTime(2000), lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_tAbs),
      );
      if (pickedTime != null) {
        setState(() {
          _tAbs = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
      }
    }
  }

  void _simpanDataKlinis() async {
    if (_sanadController.text.isEmpty || _teksController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parameter Sanad atau Teks kosong.')));
      return;
    }
    final data = {
      'id_sanad': _sanadController.text, 'teks_status': _teksController.text,
      't_abs': _tAbs.toIso8601String(), 't_ext': DateTime.now().toIso8601String(),
    };
    try {
      await DatabaseNode.instance.insertStatus(data);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data Terkunci. Sanad Diamankan.')));
      _teksController.clear(); _sanadController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Penolakan: Duplikasi Sanad.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ZF Data Node - Kalibrasi')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _teksController, maxLines: 6, decoration: const InputDecoration(labelText: 'Muatan Teks (Otomatis)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _sanadController, decoration: const InputDecoration(labelText: 'URL Sanad (Manual)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("T-Abs: ${DateFormat('yyyy-MM-dd HH:mm').format(_tAbs)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton(onPressed: _kalibrasiWaktuAbsolut, child: const Text("Kalibrasi Waktu")),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueGrey),
              onPressed: _simpanDataKlinis, child: const Text('KUNCI DATA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

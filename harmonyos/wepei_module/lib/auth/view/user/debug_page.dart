import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wepei_module/commons/themes/template/wpy_theme_data.dart';
import 'package:wepei_module/commons/themes/wpy_theme.dart';
import 'package:wepei_module/commons/util/logger.dart';
import 'package:wepei_module/commons/util/log/file_log_output.dart';

class DebugPage extends StatefulWidget {
  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  final _searchController = TextEditingController();
  String _query = '';
  int _reloadToken = 0;
  String _cachedLogs = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String> _loadLogs() async {
    await Logger.init();
    final logs = await FileLogOutput.instance.readAll();
    _cachedLogs = logs.isNotEmpty ? logs : Logger.logs.join('\n');
    return _cachedLogs;
  }

  Future<void> _copyLogs() async {
    await Clipboard.setData(ClipboardData(text: _cachedLogs));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('日志已复制')),
      );
    }
  }

  Future<void> _clearLogs() async {
    await FileLogOutput.instance.clear();
    Logger.logs.clear();
    if (mounted) setState(() => _reloadToken++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志页面'),
        centerTitle: true,
        backgroundColor:
            WpyTheme.of(context).get(WpyColorKey.oldSecondaryActionColor),
        actions: [
          IconButton(
            onPressed: () => setState(() => _reloadToken++),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _copyLogs,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            onPressed: _clearLogs,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: const InputDecoration(
                hintText: '搜索日志',
                prefixIcon: Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<String>(
        key: ValueKey(_reloadToken),
        future: _loadLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final lines = (snapshot.data ?? '')
              .split('\n')
              .where((line) =>
                  _query.isEmpty ||
                  line.toLowerCase().contains(_query.toLowerCase()))
              .toList(growable: false);
          if (lines.isEmpty) {
            return const Center(child: Text('暂无日志'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: lines.length,
            itemBuilder: (context, index) => SelectableText(
              lines[index],
              style: const TextStyle(fontSize: 11, height: 1.35),
            ),
          );
        },
      ),
    );
  }
}

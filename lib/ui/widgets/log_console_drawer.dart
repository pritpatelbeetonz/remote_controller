import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/tv_remote_manager.dart';
import '../themes/app_theme.dart';

class LogConsoleDrawer extends StatefulWidget {
  final TvRemoteManager manager;

  const LogConsoleDrawer({Key? key, required this.manager}) : super(key: key);

  @override
  State<LogConsoleDrawer> createState() => _LogConsoleDrawerState();
}

class _LogConsoleDrawerState extends State<LogConsoleDrawer> {
  final ScrollController _scrollController = ScrollController();
  String _selectedLevel = 'ALL';
  String _searchQuery = '';
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    widget.manager.addListener(_onLogsChanged);
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onLogsChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogsChanged() {
    if (_autoScroll && _scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'ERROR':
        return AppTheme.error;
      case 'WARN':
        return AppTheme.warning;
      case 'INFO':
        return AppTheme.info;
      case 'DEBUG':
        return const Color(0xFF90A4AE);
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = widget.manager.logs.where((log) {
      final matchesLevel = _selectedLevel == 'ALL' || log.level == _selectedLevel;
      final matchesSearch = _searchQuery.isEmpty ||
          log.message.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log.tag.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesLevel && matchesSearch;
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 2),
        ),
      ),
      height: 320,
      child: Column(
        children: [
          // Drawer Header / Drag Handle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceElevated,
              border: Border(
                bottom: BorderSide(color: AppTheme.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'PROTOCOL & CONNECTION CONSOLE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                // AutoScroll Toggle
                IconButton(
                  icon: Icon(
                    Icons.arrow_downward,
                    color: _autoScroll ? AppTheme.primary : Colors.grey,
                    size: 18,
                  ),
                  tooltip: 'Autoscroll to bottom',
                  onPressed: () {
                    setState(() {
                      _autoScroll = !_autoScroll;
                    });
                  },
                ),
                // Copy Logs Button
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
                  tooltip: 'Copy all logs',
                  onPressed: () {
                    final allLogsText = filteredLogs.map((l) => l.toString()).join('\n');
                    Clipboard.setData(ClipboardData(text: allLogsText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Console logs copied to clipboard'),
                        backgroundColor: AppTheme.surfaceElevated,
                      ),
                    );
                  },
                ),
                // Clear Logs Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                  tooltip: 'Clear logs',
                  onPressed: () {
                    setState(() {
                      widget.manager.clearLogs();
                    });
                  },
                ),
              ],
            ),
          ),

          // Filters and Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Filter dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLevel,
                      items: ['ALL', 'DEBUG', 'INFO', 'WARN', 'ERROR']
                          .map((level) => DropdownMenuItem(
                                value: level,
                                child: Text(
                                  level,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _getLevelColor(level),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedLevel = val;
                          });
                        }
                      },
                      dropdownColor: AppTheme.surfaceElevated,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white60),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Search field
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: TextField(
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Filter logs...',
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                        prefixIcon: Icon(Icons.search, size: 16, color: Colors.white30),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Log terminal list
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF030611),
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: filteredLogs.length,
                itemBuilder: (context, index) {
                  final log = filteredLogs[index];
                  final timeStr = "${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}.${log.timestamp.millisecond.toString().padLeft(3, '0')}";

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 11,
                          height: 1.2,
                        ),
                        children: [
                          TextSpan(
                            text: '[$timeStr] ',
                            style: const TextStyle(color: Colors.white24),
                          ),
                          TextSpan(
                            text: '[${log.level}] ',
                            style: TextStyle(
                              color: _getLevelColor(log.level),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: '[${log.tag}] ',
                            style: const TextStyle(color: AppTheme.secondary),
                          ),
                          TextSpan(
                            text: log.message,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

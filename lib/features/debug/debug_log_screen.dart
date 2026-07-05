import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/services/app_logger.dart';

// ── Level metadata ─────────────────────────────────────────────────────────

extension LogLevelX on LogLevel {
  String get label => switch (this) {
        LogLevel.verbose => 'VRB',
        LogLevel.debug => 'DBG',
        LogLevel.info => 'INF',
        LogLevel.warning => 'WRN',
        LogLevel.error => 'ERR',
        LogLevel.network => 'NET',
      };

  String get fullLabel => switch (this) {
        LogLevel.verbose => 'Verbose',
        LogLevel.debug => 'Debug',
        LogLevel.info => 'Info',
        LogLevel.warning => 'Warning',
        LogLevel.error => 'Error',
        LogLevel.network => 'Network',
      };

  Color get color => switch (this) {
        LogLevel.verbose => const Color(0xFF636E7B),
        LogLevel.debug => const Color(0xFF61AFEF),
        LogLevel.info => const Color(0xFF98C379),
        LogLevel.warning => const Color(0xFFE5C07B),
        LogLevel.error => const Color(0xFFE06C75),
        LogLevel.network => const Color(0xFFC678DD),
      };

  IconData get icon => switch (this) {
        LogLevel.verbose => Icons.notes_rounded,
        LogLevel.debug => Icons.bug_report_outlined,
        LogLevel.info => Icons.info_outline_rounded,
        LogLevel.warning => Icons.warning_amber_rounded,
        LogLevel.error => Icons.error_outline_rounded,
        LogLevel.network => Icons.wifi_rounded,
      };
}

// ── Screen ─────────────────────────────────────────────────────────────────

class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  final _scrollController = ScrollController();
  StreamSubscription<List<LogEntry>>? _sub;

  List<LogEntry> _all = [];
  List<LogEntry> _filtered = [];
  LogLevel? _levelFilter;
  String _query = '';
  bool _autoScroll = true;
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _all = List.of(AppLogger.instance.entries);
    _refilter();
    _sub = AppLogger.instance.stream.listen((entries) {
      if (!mounted) return;
      setState(() {
        _all = List.of(entries);
        _refilter();
      });
      if (_autoScroll) _jumpToBottom();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refilter() {
    _filtered = _all.where((e) {
      if (_levelFilter != null && e.level != _levelFilter) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        return e.message.toLowerCase().contains(q) ||
            e.tag.toLowerCase().contains(q) ||
            (e.extra?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyAll() {
    final buffer = StringBuffer();
    for (final e in _filtered) {
      buffer.writeln(
          '[${_formatTime(e.timestamp)}] [${e.level.label}] [${e.tag}] ${e.message}');
      if (e.extra != null) buffer.writeln(e.extra);
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_filtered.length} logs copied'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _darkTheme(),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0D12),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            if (_showSearch) _buildSearchBar(),
            _buildFilterRow(),
            const Divider(height: 1, thickness: 1, color: Color(0xFF161B22)),
            Expanded(child: _buildLogList()),
          ],
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D1117),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LiveDot(),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'Debug Console',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CountBadge(count: _filtered.length, total: _all.length),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.search_rounded,
            size: 20,
            color:
                _showSearch ? const Color(0xFF98C379) : const Color(0xFF636E7B),
          ),
          tooltip: 'Search',
          onPressed: () => setState(() {
            _showSearch = !_showSearch;
            if (!_showSearch) {
              _query = '';
              _searchCtrl.clear();
              _refilter();
            }
          }),
        ),
        IconButton(
          icon: Icon(
            Icons.vertical_align_bottom_rounded,
            size: 20,
            color:
                _autoScroll ? const Color(0xFF98C379) : const Color(0xFF636E7B),
          ),
          tooltip: 'Auto-scroll',
          onPressed: () => setState(() => _autoScroll = !_autoScroll),
        ),
        IconButton(
          icon: const Icon(Icons.copy_all_rounded,
              size: 18, color: Color(0xFF636E7B)),
          tooltip: 'Copy all',
          onPressed: _copyAll,
        ),
        IconButton(
          icon: const Icon(Icons.delete_sweep_rounded,
              size: 20, color: Color(0xFF636E7B)),
          tooltip: 'Clear',
          onPressed: () {
            AppLogger.instance.clear();
            HapticFeedback.lightImpact();
          },
        ),
      ],
    );
  }

  // ── Search bar ──────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: const Color(0xFF0D1117),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: 'Filter logs…',
          hintStyle: const TextStyle(color: Color(0xFF4A5168), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 16, color: Color(0xFF4A5168)),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 16, color: Color(0xFF4A5168)),
                  onPressed: () => setState(() {
                    _query = '';
                    _searchCtrl.clear();
                    _refilter();
                  }),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF161B22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2D3748), width: 1),
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          isDense: true,
        ),
        onChanged: (v) => setState(() {
          _query = v;
          _refilter();
        }),
      ),
    ).animate().fadeIn(duration: 150.ms).slideY(begin: -0.3, end: 0);
  }

  // ── Filter row ──────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    return Container(
      color: const Color(0xFF0D1117),
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _LevelChip(
            label: 'All',
            count: _all.length,
            color: const Color(0xFF8B93A7),
            selected: _levelFilter == null,
            onTap: () => setState(() {
              _levelFilter = null;
              _refilter();
            }),
          ),
          const SizedBox(width: 6),
          ...LogLevel.values.map((level) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _LevelChip(
                  label: level.label,
                  count: _all.where((e) => e.level == level).length,
                  color: level.color,
                  selected: _levelFilter == level,
                  onTap: () => setState(() {
                    _levelFilter = _levelFilter == level ? null : level;
                    _refilter();
                  }),
                ),
              )),
        ],
      ),
    );
  }

  // ── Log list ────────────────────────────────────────────────────────────

  Widget _buildLogList() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal_rounded,
                size: 44, color: const Color(0xFF2A2D35)),
            const SizedBox(height: 12),
            Text(
              _query.isNotEmpty ? 'No matching logs' : 'No logs yet',
              style: const TextStyle(color: Color(0xFF4A5168), fontSize: 13),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final entry = _filtered[i];
        return _LogTile(
          entry: entry,
          key: ValueKey(entry.id),
          highlight: _query,
        );
      },
    );
  }
}

// ── Live dot ───────────────────────────────────────────────────────────────

class _LiveDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Color(0xFF98C379),
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(begin: 0.25, end: 1.0, duration: 900.ms, curve: Curves.easeInOut);
  }
}

// ── Count badge ────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.total});
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2530),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        count == total ? '$count' : '$count/$total',
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF636E7B),
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ── Filter chip ────────────────────────────────────────────────────────────

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.6)
                : const Color(0xFF2A2D35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? color : const Color(0xFF636E7B),
                fontFamily: 'monospace',
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.25)
                      : const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    color: selected ? color : const Color(0xFF4A5168),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Log tile ───────────────────────────────────────────────────────────────

class _LogTile extends StatefulWidget {
  const _LogTile({required this.entry, required this.highlight, super.key});
  final LogEntry entry;
  final String highlight;

  @override
  State<_LogTile> createState() => _LogTileState();
}

class _LogTileState extends State<_LogTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final level = e.level;
    final hasExtra = e.extra != null && e.extra!.isNotEmpty;

    return GestureDetector(
      onTap: hasExtra ? () => setState(() => _expanded = !_expanded) : null,
      onLongPress: () {
        HapticFeedback.selectionClick();
        Clipboard.setData(ClipboardData(
          text:
              '[${_formatTime(e.timestamp)}] [${level.label}] [${e.tag}] ${e.message}'
              '${e.extra != null ? '\n${e.extra}' : ''}',
        ));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied to clipboard'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: level.color, width: 2.5),
          ),
        ),
        child: Container(
          color: _expanded
              ? level.color.withValues(alpha: 0.05)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  _LevelBadge(level: level),
                  const SizedBox(width: 6),
                  _TagBadge(tag: e.tag),
                  const Spacer(),
                  Text(
                    _formatTime(e.timestamp),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF4A5168),
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (hasExtra) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: const Color(0xFF4A5168),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              // Message
              _HighlightText(
                text: e.message,
                highlight: widget.highlight,
                baseStyle: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: level == LogLevel.error
                      ? level.color.withValues(alpha: 0.9)
                      : const Color(0xFFCDD6F4),
                  height: 1.4,
                ),
                highlightColor: const Color(0xFFE5C07B),
              ),
              // Extra (expanded)
              if (_expanded && hasExtra) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: const Color(0xFF1E2530), width: 1),
                  ),
                  child: Text(
                    e.extra!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Color(0xFF8B93A7),
                      height: 1.5,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 150.ms)
                    .slideY(begin: -0.2, end: 0),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Level badge ────────────────────────────────────────────────────────────

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final LogLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, size: 10, color: level.color),
          const SizedBox(width: 3),
          Text(
            level.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: level.color,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tag badge ──────────────────────────────────────────────────────────────

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Text(
      tag,
      style: const TextStyle(
        fontSize: 10,
        color: Color(0xFF636E7B),
        fontFamily: 'monospace',
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

// ── Highlight text ─────────────────────────────────────────────────────────

class _HighlightText extends StatelessWidget {
  const _HighlightText({
    required this.text,
    required this.highlight,
    required this.baseStyle,
    required this.highlightColor,
  });

  final String text;
  final String highlight;
  final TextStyle baseStyle;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    if (highlight.isEmpty) return Text(text, style: baseStyle);

    final lower = text.toLowerCase();
    final lowerQ = highlight.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lower.indexOf(lowerQ, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) spans.add(TextSpan(text: text.substring(start, idx)));
      spans.add(TextSpan(
        text: text.substring(idx, idx + highlight.length),
        style: baseStyle.copyWith(
          color: highlightColor,
          backgroundColor: highlightColor.withValues(alpha: 0.2),
          fontWeight: FontWeight.bold,
        ),
      ));
      start = idx + highlight.length;
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  final s = dt.second.toString().padLeft(2, '0');
  final ms = dt.millisecond.toString().padLeft(3, '0');
  return '$h:$m:$s.$ms';
}

ThemeData _darkTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0D12),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D1117),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF8B93A7)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF1E2530),
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 13),
      ),
    );

import 'dart:async';

import '../../core/api/api_exception.dart';

import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.worker, this.conversationId});
  final Worker worker;
  final int? conversationId;

  /// How often an open chat asks for new messages. There is no push to the
  /// employer app, so without this a karigar's reply only shows on reopening.
  static const pollEvery = Duration(seconds: 10);
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final controller = TextEditingController();
  final scroll = ScrollController();
  final messages = <Map<String, dynamic>>[];
  late bool loading;
  bool sending = false;
  bool loadingOlder = false;
  String? loadError;
  String? jobTitle;
  bool _requested = false;
  int _olderPage = 1;
  int _lastPage = 1;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    loading = widget.conversationId != null;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.conversationId != null && !_requested) {
      _requested = true;
      _load();
      _poll = Timer.periodic(ChatScreen.pollEvery, (_) => _refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Catch up straight away when the employer comes back to the app.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  /// The first page, with a full-screen error and Retry when it fails.
  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      await _fetchLatest();
      _scrollToEnd(jump: true);
    } catch (exception) {
      if (mounted) setState(() => loadError = errorText(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// A quiet check for new messages. A failure keeps what is on screen; the
  /// next tick tries again.
  Future<void> _refresh() async {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final inBackground =
        lifecycle != null && lifecycle != AppLifecycleState.resumed;
    if (!mounted || loading || loadError != null || inBackground) return;
    final atEnd =
        !scroll.hasClients ||
        scroll.position.pixels >= scroll.position.maxScrollExtent - 80;
    try {
      final added = await _fetchLatest();
      // Follow new messages only when the employer was already at the bottom,
      // never pull them away from older messages they are reading.
      if (added && atEnd) _scrollToEnd();
    } catch (_) {}
  }

  /// Page 1 holds the newest 30 messages, oldest first. Opening the thread
  /// also marks it read on the server. Returns whether anything new came.
  Future<bool> _fetchLatest() async {
    final response = await AppScope.of(
      context,
    ).api.conversation(widget.conversationId!);
    if (!mounted) return false;
    final meta = response['meta'];
    final conversation = response['conversation'];
    final job = conversation is Map ? conversation['job'] : null;
    final before = messages.length;
    setState(() {
      if (job is Map) jobTitle = job['title']?.toString();
      _merge(response['messages']);
      if (meta is Map) _lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
    });
    return messages.length > before;
  }

  Future<void> _loadOlder() async {
    if (loadingOlder || _olderPage >= _lastPage) return;
    setState(() => loadingOlder = true);
    try {
      final response = await AppScope.of(
        context,
      ).api.conversation(widget.conversationId!, page: _olderPage + 1);
      if (!mounted) return;
      setState(() {
        _merge(response['messages']);
        _olderPage++;
      });
    } catch (exception) {
      _notice(errorText(exception));
    } finally {
      if (mounted) setState(() => loadingOlder = false);
    }
  }

  /// Adds messages by id (a message never shows twice) and keeps them in the
  /// order they were sent.
  void _merge(dynamic rows) {
    final byId = {for (final message in messages) '${message['id']}': message};
    for (final row in (rows as List? ?? const []).whereType<Map>()) {
      final message = Map<String, dynamic>.from(row);
      byId['${message['id']}'] = message;
    }
    messages
      ..clear()
      ..addAll(byId.values)
      ..sort(
        (a, b) => ((a['id'] as num?) ?? 0).compareTo((b['id'] as num?) ?? 0),
      );
  }

  void _scrollToEnd({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      final end = scroll.position.maxScrollExtent;
      jump
          ? scroll.jumpTo(end)
          : scroll.animateTo(
              end,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
    });
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _send([String? suggested]) async {
    final body = (suggested ?? controller.text).trim();
    if (body.isEmpty || sending) return;
    if (widget.conversationId == null) {
      _notice('Start the conversation from an applicant profile.');
      return;
    }
    setState(() => sending = true);
    try {
      final response = await AppScope.of(
        context,
      ).api.sendMessage(widget.conversationId!, body);
      final message = response['message'];
      if (!mounted) return;
      setState(() {
        if (message is Map) _merge([message]);
        // Only a typed message empties the box; a quick reply never used it.
        if (suggested == null) controller.clear();
      });
      _scrollToEnd();
    } catch (exception) {
      // The typed text stays in the box so it can be sent again.
      _notice('Message not sent. ${errorText(exception)}');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    scroll.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.brand100,
              child: Text(
                widget.worker.initials,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.brandDark,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.worker.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // The job this chat is about. The server has no online
                  // status for karigars, so none is shown.
                  if (jobTitle?.isNotEmpty == true)
                    Text(
                      jobTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(14),
                    itemCount:
                        messages.length + (_olderPage < _lastPage ? 1 : 0),
                    itemBuilder: (_, index) {
                      final hasOlder = _olderPage < _lastPage;
                      if (hasOlder && index == 0) {
                        return Center(
                          child: TextButton(
                            onPressed: loadingOlder ? null : _loadOlder,
                            child: Text(
                              loadingOlder
                                  ? 'Loading…'
                                  : 'Load earlier messages',
                            ),
                          ),
                        );
                      }
                      final message = messages[hasOlder ? index - 1 : index];
                      final me = message['sent_by_me'] == true;
                      return Align(
                        alignment: me
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 9,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                          ),
                          decoration: BoxDecoration(
                            color: me
                                ? colors.primary
                                : colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: me
                                ? null
                                : Border.all(color: colors.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: me
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${message['body'] ?? ''}',
                                style: TextStyle(
                                  color: me
                                      ? colors.onPrimary
                                      : colors.onSurface,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                              if (_sentAt(context, message['created_at'])
                                  case final sentAt?)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    sentAt,
                                    style: TextStyle(
                                      color:
                                          (me
                                                  ? colors.onPrimary
                                                  : colors.onSurfaceVariant)
                                              .withValues(alpha: .75),
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  height: 39,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children:
                        [
                              'Can you join tomorrow?',
                              'Share your location',
                              'Call me',
                            ]
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ActionChip(
                                  label: Text(e),
                                  onPressed: sending ? null : () => _send(e),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    color: colors.surface,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            maxLength: 2000,
                            minLines: 1,
                            maxLines: 4,
                            buildCounter:
                                (
                                  _, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) => null,
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: sending ? null : _send,
                          icon: const Icon(LucideIcons.send),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// "3:05 PM" today, "26 Nov, 3:05 PM" on older days.
String? _sentAt(BuildContext context, Object? value) {
  final at = DateTime.tryParse('${value ?? ''}')?.toLocal();
  if (at == null) return null;
  final l10n = MaterialLocalizations.of(context);
  final time = l10n.formatTimeOfDay(TimeOfDay.fromDateTime(at));
  final now = DateTime.now();
  if (at.year == now.year && at.month == now.month && at.day == now.day) {
    return time;
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${at.day} ${months[at.month - 1]}, $time';
}

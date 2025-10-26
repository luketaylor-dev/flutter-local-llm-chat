import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_interface/src/features/chat/application/chat_controller.dart';
import 'package:llm_interface/src/features/chat/application/sessions_controller.dart';
import 'package:llm_interface/src/features/chat/domain/chat_session.dart';
import 'package:llm_interface/src/features/chat/presentation/chat_page.dart';
import 'package:llm_interface/src/features/settings/presentation/settings_drawer.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionsProvider.notifier).loadSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<ChatSession> sessions = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('LLM Chat'),
        actions: <Widget>[
          Builder(
            builder: (BuildContext ctx) {
              return IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              );
            },
          ),
        ],
      ),
      endDrawer: const SettingsDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ChatSession session = await ref
              .read(sessionsProvider.notifier)
              .createSession();
          if (!mounted) return;
          _openChat(session);
        },
        icon: const Icon(Icons.add_comment),
        label: const Text('New Chat'),
      ),
      body: ListView.builder(
        itemCount: sessions.length,
        itemBuilder: (BuildContext context, int index) {
          final ChatSession s = sessions[index];
          final String subtitle = s.messages.isEmpty
              ? 'Empty conversation'
              : s.messages.last.content;
          return Dismissible(
            key: ValueKey<String>(s.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Theme.of(context).colorScheme.error.withOpacity(0.15),
              child: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            confirmDismiss: (DismissDirection dir) async {
              return await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Delete chat?'),
                        content: const Text(
                          'This will remove the conversation from local storage.',
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(
                              'Delete',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ) ??
                  false;
            },
            onDismissed: (_) =>
                ref.read(sessionsProvider.notifier).removeSession(s.id),
            child: ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(s.title.isEmpty ? 'Chat' : s.title),
              subtitle: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _openChat(s),
              trailing: Wrap(
                spacing: 4,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Rename',
                    onPressed: () async {
                      final TextEditingController controller =
                          TextEditingController(text: s.title);
                      final String? newName = await showDialog<String>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Rename chat'),
                            content: TextField(
                              controller: controller,
                              autofocus: true,
                              decoration: const InputDecoration(
                                hintText: 'Enter a name',
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(null),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(
                                  context,
                                ).pop(controller.text.trim()),
                                child: const Text('Save'),
                              ),
                            ],
                          );
                        },
                      );
                      if (newName != null && newName.isNotEmpty) {
                        await ref
                            .read(sessionsProvider.notifier)
                            .renameSession(sessionId: s.id, title: newName);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Theme.of(context).colorScheme.error,
                    tooltip: 'Delete',
                    onPressed: () async {
                      final bool? ok = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Delete chat?'),
                            content: const Text(
                              'This will remove the conversation from local storage.',
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                      if (ok == true) {
                        await ref
                            .read(sessionsProvider.notifier)
                            .removeSession(s.id);
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openChat(ChatSession session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return ChatPageWithSession(session: session);
        },
      ),
    );
  }
}

class ChatPageWithSession extends ConsumerStatefulWidget {
  const ChatPageWithSession({super.key, required this.session});
  final ChatSession session;

  @override
  ConsumerState<ChatPageWithSession> createState() =>
      _ChatPageWithSessionState();
}

class _ChatPageWithSessionState extends ConsumerState<ChatPageWithSession> {
  @override
  void initState() {
    super.initState();
    // Initialize controller with existing messages so the API has full context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatControllerProvider.notifier)
          .startSession(
            sessionId: widget.session.id,
            messages: widget.session.messages,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChatPage(sessionId: widget.session.id);
  }
}

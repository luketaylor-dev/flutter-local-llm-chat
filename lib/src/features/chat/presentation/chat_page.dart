import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Keyboard services import removed to restore default TextField behavior
import 'package:llm_interface/src/features/chat/application/chat_controller.dart';
import 'package:llm_interface/src/features/chat/application/chat_state.dart';
import 'package:llm_interface/src/features/chat/domain/chat_message.dart';
import 'package:llm_interface/src/features/settings/presentation/settings_drawer.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, this.sessionId});
  final String? sessionId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ChatState state = ref.watch(chatControllerProvider);
    final String? sessionId = widget.sessionId;
    if (sessionId != null) {
      ref.read(chatControllerProvider.notifier).setSessionId(sessionId);
    }
    ref.listen(
      chatControllerProvider,
      (ChatState? _, ChatState next) => _scrollToBottom(),
    );
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
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: state.messages.length,
              itemBuilder: (BuildContext context, int index) {
                final ChatMessage msg = state.messages[index];
                // Hide system messages (summaries) from UI
                // They're still stored and used for context, just not displayed
                if (msg.role == ChatRole.system) {
                  return const SizedBox.shrink();
                }
                final bool isUser = msg.role == ChatRole.user;
                return Dismissible(
                  key: ValueKey<String>(msg.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withOpacity(0.15),
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
                              title: const Text('Delete message?'),
                              content: const Text(
                                'This removes the message from the conversation context.',
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ) ??
                        false;
                  },
                  onDismissed: (_) => ref
                      .read(chatControllerProvider.notifier)
                      .deleteMessage(messageId: msg.id),
                  child: Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                      ),
                      decoration: BoxDecoration(
                        gradient: isUser
                            ? LinearGradient(
                                colors: <Color>[
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.tertiary,
                                ],
                              )
                            : null,
                        color: isUser
                            ? null
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isUser
                              ? Theme.of(
                                  context,
                                ).colorScheme.tertiary.withOpacity(0.35)
                              : Theme.of(
                                  context,
                                ).colorScheme.secondary.withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        msg.content,
                        style: TextStyle(
                          color: isUser
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Row(children: <Widget>[CircularProgressIndicator()]),
            ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Shortcuts(
                      shortcuts: <ShortcutActivator, Intent>{
                        SingleActivator(
                          LogicalKeyboardKey.enter,
                          control: true,
                        ): const _SendIntent(),
                        SingleActivator(LogicalKeyboardKey.enter, meta: true):
                            const _SendIntent(),
                      },
                      child: Actions(
                        actions: <Type, Action<Intent>>{
                          _SendIntent: CallbackAction<_SendIntent>(
                            onInvoke: (Intent intent) {
                              _onSend(ref);
                              return null;
                            },
                          ),
                        },
                        child: TextField(
                          controller: _textController,
                          minLines: 1,
                          maxLines: 8,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: 'Type a message',
                          ),
                          autofocus: true,
                          onSubmitted: (_) => _onSend(ref),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _onSend(ref),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSend(WidgetRef ref) {
    final String text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }
    ref.read(chatControllerProvider.notifier).sendMessage(content: text);
    _textController.clear();
  }
}

class _SendIntent extends Intent {
  const _SendIntent();
}

// removed _SubmitIntent (no longer needed with RawKeyboardListener)

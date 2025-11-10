import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Keyboard services import removed to restore default TextField behavior
import 'package:llm_interface/src/features/chat/application/chat_controller.dart';
import 'package:llm_interface/src/features/chat/application/chat_state.dart';
import 'package:llm_interface/src/features/chat/domain/chat_message.dart';
import 'package:llm_interface/src/features/settings/presentation/settings_drawer.dart';
import 'package:llm_interface/src/features/settings/application/settings_controller.dart';
import 'package:llm_interface/src/features/settings/domain/app_settings.dart';

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

  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      if (instant) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      } else {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
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
      (ChatState? prev, ChatState next) {
        final bool shouldInstantScroll = next.isLoading;
        _scrollToBottom(instant: shouldInstantScroll);
      },
    );
    // Try to get the current system summary to show at the top
    ChatMessage? summaryMessage;
    try {
      summaryMessage = state.messages.firstWhere(
        (ChatMessage m) => m.id == 'system-summary-current',
      );
    } catch (_) {
      summaryMessage = null;
    }
    // Try to get DnD rules to show at the top
    ChatMessage? dndRulesMessage;
    try {
      dndRulesMessage = state.messages.firstWhere(
        (ChatMessage m) => m.id == 'system-dnd-rules-current',
      );
    } catch (_) {
      dndRulesMessage = null;
    }
    final AppSettings settings = ref.watch(settingsProvider);
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
          if (dndRulesMessage != null && settings.showDndBanner)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.5),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.tertiary.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'DnD Rules',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dndRulesMessage.content,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          if (summaryMessage != null && settings.showSummaryBanner)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.5),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Summary',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      summaryMessage.content,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 8,
                bottom: state.isLoading ? 60 : 8,
              ),
              itemCount: state.messages.length + (state.isLoading ? 1 : 0),
              itemBuilder: (BuildContext context, int index) {
                if (index >= state.messages.length) {
                  return const SizedBox(height: 8);
                }
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
                  child: GestureDetector(
                    onLongPress: () => _showEditMessageDialog(
                      context: context,
                      ref: ref,
                      message: msg,
                    ),
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
                        child: msg.content.isEmpty && state.isLoading && !isUser
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                msg.content,
                                softWrap: true,
                                style: TextStyle(
                                  color: isUser
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
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

  void _showEditMessageDialog({
    required BuildContext context,
    required WidgetRef ref,
    required ChatMessage message,
  }) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _EditMessageDialog(
          message: message,
          onSave: (String newContent) {
            if (newContent.isNotEmpty) {
              ref
                  .read(chatControllerProvider.notifier)
                  .updateMessage(
                    messageId: message.id,
                    newContent: newContent,
                  );
            }
          },
        );
      },
    );
  }
}

class _SendIntent extends Intent {
  const _SendIntent();
}

class _EditMessageDialog extends StatefulWidget {
  const _EditMessageDialog({
    required this.message,
    required this.onSave,
  });

  final ChatMessage message;
  final void Function(String) onSave;

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.message.content);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit message'),
      content: TextField(
        controller: _editController,
        autofocus: true,
        maxLines: null,
        minLines: 5,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          hintText: 'Edit message content',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final String newContent = _editController.text.trim();
            widget.onSave(newContent);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// removed _SubmitIntent (no longer needed with RawKeyboardListener)

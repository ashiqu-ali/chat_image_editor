import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_settings.dart';
import '../demos_screen.dart';
import '../sample_image.dart';
import 'chat_composer.dart';
import 'chat_message.dart';
import 'chat_photo_editor.dart';
import 'conversation.dart';
import 'message_bubble.dart';
import 'photo_viewer_screen.dart';

/// A one-to-one chat where photos go through the editor before they're
/// sent, the way a messaging app would use the package.
class ChatScreen extends StatefulWidget {
  /// Creates the chat screen.
  const ChatScreen({super.key, required this.settings, this.conversation});

  /// App-wide appearance settings, passed on to the demos screen.
  final AppSettings settings;

  /// The chat to show. When `null` the screen starts [Conversation.demo]
  /// and owns it.
  final Conversation? conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const double _maxContentWidth = 720;

  final TextEditingController _draft = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Conversation? _ownConversation;
  Uint8List? _sampleBytes;
  bool _preparingPhoto = false;

  Conversation get _conversation =>
      widget.conversation ?? (_ownConversation ??= Conversation.demo());

  @override
  void dispose() {
    _draft.dispose();
    _ownConversation?.dispose();
    super.dispose();
  }

  void _sendText() {
    _conversation.sendText(_draft.text);
    _draft.clear();
  }

  Future<void> _attachPhoto() async {
    if (_preparingPhoto) return;
    // Hide the keyboard first. Otherwise the message field takes focus
    // back when the sheet closes, and on iOS it can keep the keyboard
    // after the native photo picker, typing into the chat underneath the
    // editor instead of into the caption.
    FocusManager.instance.primaryFocus?.unfocus();
    final source = await showPhotoSourceSheet(
      context,
      cameraAvailable: _picker.supportsImageSource(ImageSource.camera),
    );
    if (source == null || !mounted) return;

    setState(() => _preparingPhoto = true);
    Uint8List? photo;
    try {
      photo = await _loadPhoto(source);
    } on Exception catch (error) {
      _showMessage('Could not get the photo: $error');
    } finally {
      if (mounted) setState(() => _preparingPhoto = false);
    }
    if (photo == null || !mounted) return;

    final conversation = _conversation;
    final result = await editPhotoForChat(
      context,
      photo,
      recipient: conversation.contactName,
      draft: _draft.text.trim(),
    );
    if (result == null || !mounted) return;

    // The draft became the caption, so it leaves with the photo. This is
    // where a real app would upload result.bytes.
    _draft.clear();
    conversation.sendImage(result);
    if (result.exceedsMaxBytes) {
      _showMessage('This photo is still over 1 MB at the lowest quality.');
    }
  }

  Future<Uint8List?> _loadPhoto(PhotoSource source) async {
    final ImageSource pickerSource;
    switch (source) {
      case PhotoSource.sample:
        return _sampleBytes ??= await generateSampleImage();
      case PhotoSource.gallery:
        pickerSource = ImageSource.gallery;
      case PhotoSource.camera:
        pickerSource = ImageSource.camera;
    }
    // Ask for the original file. The editor decodes it at the size the
    // screen and the export need, so a picker-side resize would only add a
    // second lossy encode.
    final file = await _picker.pickImage(
      source: pickerSource,
      requestFullMetadata: false,
    );
    return file?.readAsBytes();
  }

  void _openPhoto(ChatMessage message) {
    // Start decoding the full-size photo now. The hero flies the bubble's
    // thumbnail meanwhile, so the viewer opens without a blank frame.
    precacheImage(MemoryImage(message.image!.bytes), context);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => PhotoViewerScreen(
          message: message,
          senderName: message.fromMe ? 'You' : _conversation.contactName,
        ),
      ),
    );
  }

  void _openDemos() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DemosScreen(settings: widget.settings),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor: scheme.tertiaryContainer,
              foregroundColor: scheme.onTertiaryContainer,
              child: Text(conversation.contactName.characters.first),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(conversation.contactName),
                  Text(
                    'online',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Customization demos',
            icon: const Icon(Icons.tune),
            onPressed: _openDemos,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListenableBuilder(
                  listenable: conversation,
                  builder: (context, _) => _MessageList(
                    messages: conversation.messages,
                    onOpenPhoto: _openPhoto,
                  ),
                ),
              ),
              ChatComposer(
                controller: _draft,
                busy: _preparingPhoto,
                onSend: _sendText,
                onAttach: _preparingPhoto ? null : _attachPhoto,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages, required this.onOpenPhoto});

  /// Newest first.
  final List<ChatMessage> messages;
  final ValueChanged<ChatMessage> onOpenPhoto;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // Newest at the bottom, and the list stays pinned there as messages
      // arrive.
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemCount: messages.length,
      // Keeps each bubble's element, and its decoded photo, attached to its
      // message when a new message shifts the indexes.
      findChildIndexCallback: (key) {
        final id = (key as ValueKey<String>).value;
        final index = messages.indexWhere((message) => message.id == id);
        return index < 0 ? null : index;
      },
      itemBuilder: (context, index) {
        final message = messages[index];
        final previous = index + 1 < messages.length
            ? messages[index + 1]
            : null;
        // A little more space where the sender changes.
        final gap = previous == null || previous.fromMe != message.fromMe
            ? 8.0
            : 2.0;
        return Padding(
          key: ValueKey<String>(message.id),
          padding: EdgeInsets.only(top: gap),
          child: MessageBubble(
            message: message,
            onOpenPhoto: message.image == null
                ? null
                : () => onOpenPhoto(message),
          ),
        );
      },
    );
  }
}

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_settings.dart';
import 'demos/demo.dart';
import 'result_screen.dart';
import 'sample_image.dart';
import 'widgets/appearance_card.dart';
import 'widgets/demo_tile.dart';
import 'widgets/image_source_card.dart';

/// Lists the demos, the image they open and the appearance switcher.
class HomeScreen extends StatefulWidget {
  /// Creates the home screen.
  const HomeScreen({super.key, required this.settings});

  /// App-wide appearance settings.
  final AppSettings settings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _maxContentWidth = 680;

  final ImagePicker _picker = ImagePicker();

  PickedImage? _picked;
  Uint8List? _sampleBytes;
  EditorDemo? _preparing;
  bool _picking = false;

  bool get _busy => _picking || _preparing != null;

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(source: source);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _picked = PickedImage(name: file.name, bytes: bytes));
    } on Exception catch (error) {
      _showMessage('Could not get an image: $error');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<Uint8List> _imageForDemos() async {
    final picked = _picked;
    if (picked != null) return picked.bytes;
    return _sampleBytes ??= await generateSampleImage();
  }

  Future<void> _openDemo(EditorDemo demo) async {
    if (_busy) return;
    setState(() => _preparing = demo);
    Uint8List? image;
    try {
      image = await _imageForDemos();
    } on Exception catch (error) {
      _showMessage('Could not prepare the image: $error');
    } finally {
      if (mounted) setState(() => _preparing = null);
    }
    if (image == null || !mounted) return;

    final result = await demo.launch(context, image);
    if (result == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ResultScreen(
          result: result,
          title: demo.title,
          maxBytes: demo.maxBytes,
        ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Chat image editor')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = math.max(
            16.0,
            (constraints.maxWidth - _maxContentWidth) / 2,
          );
          return ListView(
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
            children: <Widget>[
              const _SectionTitle('Image'),
              ImageSourceCard(
                picked: _picked,
                cameraAvailable: _picker.supportsImageSource(
                  ImageSource.camera,
                ),
                onPickFromGallery: _busy
                    ? null
                    : () => _pick(ImageSource.gallery),
                onPickFromCamera: _busy
                    ? null
                    : () => _pick(ImageSource.camera),
                onUseSample: _busy
                    ? null
                    : () => setState(() => _picked = null),
              ),
              const _SectionTitle('Appearance'),
              AppearanceCard(settings: widget.settings),
              const _SectionTitle('Demos'),
              for (final demo in editorDemos)
                DemoTile(
                  demo: demo,
                  preparing: identical(_preparing, demo),
                  onTap: _busy ? null : () => _openDemo(demo),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

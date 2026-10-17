import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_screen_header.dart';

abstract final class OrbitWritePostKeys {
  static const field = Key('orbit_write_post_field');
  static const preview = Key('orbit_write_post_preview');
  static const backToEdit = Key('orbit_write_post_back_to_edit');
}

/// UI-only text-post composer. No network API for text posts exists yet:
/// users can write and review their text, but no 'published' success is shown.
class OrbitWritePostScreen extends StatefulWidget {
  const OrbitWritePostScreen({super.key});

  @override
  State<OrbitWritePostScreen> createState() => _OrbitWritePostScreenState();
}

class _OrbitWritePostScreenState extends State<OrbitWritePostScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _preview = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 20),
              AppScreenHeader(
                title: _preview ? 'Post Preview' : 'Write a Post',
                onBack: () {
                  if (_preview) {
                    setState(() => _preview = false);
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
              ),
              const SizedBox(height: 30),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        _preview
                            ? 'Your post'
                            : 'Share something with your circle',
                        style: AppTypography.smallHeading,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _preview
                            ? 'Preview only · This post has not been published.'
                            : 'Write an update or a thought. You can preview it before publishing becomes available.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 22),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFEDECF2)),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x0A000000),
                              offset: Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _preview
                              ? Text(
                                  _controller.text,
                                  key: OrbitWritePostKeys.preview,
                                  style: AppTypography.body,
                                )
                              : TextField(
                                  key: OrbitWritePostKeys.field,
                                  controller: _controller,
                                  keyboardType: TextInputType.multiline,
                                  minLines: 6,
                                  maxLines: 10,
                                  maxLength: 1000,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  style: AppTypography.body,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: "What's on your mind?",
                                    hintStyle: AppTypography.body.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Text-post publishing requires a backend connection. Nothing will be sent from this preview.',
                        style: AppTypography.body.copyWith(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20, top: 8),
                child: AppPrimaryButton(
                  label: _preview ? 'Edit Post' : 'Preview Post',
                  enabled: _preview || _controller.text.trim().isNotEmpty,
                  onPressed: () => setState(() => _preview = !_preview),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../widgets/welcome_action_panel.dart';
import '../widgets/welcome_layout_metrics.dart';

abstract final class CreateCircleKeys {
  static const heading = Key('create_circle_heading');
  static const nameLabel = Key('create_circle_name_label');
  static const nameField = Key('create_circle_name_field');
  static const colorLabel = Key('create_circle_color_label');
  static const iconLabel = Key('create_circle_icon_label');
  static const nextButton = Key('create_circle_next_button');
  static const skipButton = Key('create_circle_skip_button');

  static Key color(int index) => Key('create_circle_color_$index');
  static Key icon(int index) => Key('create_circle_icon_$index');
}

class CreateCircleScreen extends StatefulWidget {
  const CreateCircleScreen({
    required this.onNext,
    this.onCreateRequested,
    this.onJoinRequested,
    this.enableTemporary = false,
    this.onSkip,
    super.key,
  });

  final VoidCallback onNext;
  final Future<void> Function(String name, String color, String icon, String key, String? expiresAt)? onCreateRequested;
  final VoidCallback? onJoinRequested;
  final bool enableTemporary;
  final VoidCallback? onSkip;

  @override
  State<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  static const double _contentPadding = 15;
  static const double _headingBottomGap = 15;
  static const double _sectionGap = 20;
  static const double _choiceLabelGap = 14;

  late final TextEditingController _nameController;
  int _selectedColorIndex = 0;
  int _selectedIconIndex = 0;
  bool _saving = false;
  DateTime? _expiresAt;
  String _idempotencyKey = const Uuid().v4();
  void _newDraft() { if (!_saving) _idempotencyKey = const Uuid().v4(); }

  static const List<_CircleColorOption> _colors = <_CircleColorOption>[
    _CircleColorOption(border: Color(0xFFF43F8E), fill: Color(0xFFEE8EB8)),
    _CircleColorOption(border: Color(0xFFC84ACD), fill: Color(0xFFDC7AD9)),
    _CircleColorOption(border: Color(0xFF16B393), fill: Color(0xFF67CFB1)),
    _CircleColorOption(border: Color(0xFF7C3AED), fill: Color(0xFFE9E4F6)),
    _CircleColorOption(border: Color(0xFF4B1DBE), fill: Color(0xFFC0B7E6)),
    _CircleColorOption(border: Color(0xFFFF5C00), fill: Color(0xFFF3AD83)),
    _CircleColorOption(border: Color(0xFF7C3AED), fill: Color(0xFFB084F4)),
  ];

  static const List<IconData> _icons = <IconData>[
    Icons.home_rounded,
    Icons.account_circle_outlined,
    Icons.star_border_rounded,
    Icons.music_note_rounded,
    Icons.location_on_outlined,
    Icons.wb_sunny_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.onCreateRequested == null ? 'Best Friends' : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _chooseExpiry() async {
    if (_saving) return;
    final today=DateTime.now();
    final date=await showDatePicker(context:context,
      initialDate:today.add(const Duration(days:1)), firstDate:today,
      lastDate:today.add(const Duration(days:365)));
    if(date==null || !mounted)return;
    final time=await showTimePicker(context:context,
      initialTime:const TimeOfDay(hour:18,minute:0));
    if(time==null || !mounted)return;
    final selected=DateTime(date.year,date.month,date.day,time.hour,time.minute);
    if(!selected.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Choose a future Circle expiry time.')));
      return;
    }
    _newDraft();
    setState(()=>_expiresAt=selected);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (_saving) return;
    if (name.isEmpty || name.length > 80) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a Circle name between 1 and 80 characters.')));
      return;
    }
    final save = widget.onCreateRequested;
    if (save == null) { widget.onNext(); return; }
    setState(() => _saving = true);
    try {
      // Explicit privacy review must precede the server mutation, not follow it.
      final consent = await showDialog<bool>(context:context,builder:(dialog)=>
        AlertDialog(backgroundColor:Colors.white,
          title:const Text('Create private Circle?'),
          content:const Text('Only invited people can join after accepting. '
            'Live location, presence, Moments, Ping, chat and SOS sharing all start OFF. '
            'You can invite friends after the Circle is created.'),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Cancel')),
            TextButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('Create')),
          ],
        ));
      if(consent != true || !mounted)return;
      final color = _colors[_selectedColorIndex].fill;
      final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
      const keys = <String>['home','person','star','music','location','sunny'];
      await save(name,hex,keys[_selectedIconIndex],_idempotencyKey,
        _expiresAt?.toUtc().toIso8601String());
      if (mounted) widget.onNext();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Unable to create Circle: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 720;
              final buttonHorizontalPadding =
                  WelcomeLayoutMetrics.horizontalPadding(constraints.maxWidth);
              final contentBottomInset =
                  WelcomeLayoutMetrics.contentBottomInset(context);

              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    bottom: contentBottomInset,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        _contentPadding,
                        compact ? 12 : 52,
                        _contentPadding,
                        16,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: compact
                              ? 0
                              : constraints.maxHeight - contentBottomInset - 68,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              'Create Your\nFirst Circle',
                              key: CreateCircleKeys.heading,
                              textAlign: TextAlign.center,
                              style: AppTypography.largeHeading,
                            ),
                            if (widget.onJoinRequested != null)
                              Align(alignment:Alignment.center,
                                child:TextButton.icon(
                                  onPressed:widget.onJoinRequested,
                                  icon:const Icon(Icons.group_add_outlined,
                                    size:18,color:Color(0xFF7C3AED)),
                                  label:const Text('Join with Code',
                                    style:TextStyle(fontFamily:AppTypography.fontFamily,
                                      color:Color(0xFF7C3AED))),
                                )),
                            const SizedBox(height: _headingBottomGap),
                            AppTextField(
                              label: 'Circle Name:',
                              labelKey: CreateCircleKeys.nameLabel,
                              fieldKey: CreateCircleKeys.nameField,
                              controller: _nameController,
                              onChanged: (_) => _newDraft(),
                              textInputAction: TextInputAction.done,
                              suffixIcon: const Icon(
                                Icons.favorite_rounded,
                                color: Color(0xFFE00000),
                                size: 25,
                              ),
                            ),
                            const SizedBox(height: _sectionGap),
                            const Text(
                              'Choose A Color:',
                              key: CreateCircleKeys.colorLabel,
                              style: _CreateCircleStyles.label,
                            ),
                            const SizedBox(height: _choiceLabelGap),
                            _ColorPicker(
                              options: _colors,
                              selectedIndex: _selectedColorIndex,
                              onSelected: (index) {
                                _newDraft();
                                setState(() => _selectedColorIndex = index);
                              },
                            ),
                            const SizedBox(height: _sectionGap),
                            const Text(
                              'Choose A Icon:',
                              key: CreateCircleKeys.iconLabel,
                              style: _CreateCircleStyles.label,
                            ),
                            const SizedBox(height: _choiceLabelGap),
                            _IconPicker(
                              icons: _icons,
                              selectedIndex: _selectedIconIndex,
                              onSelected: (index) {
                                _newDraft();
                                setState(() => _selectedIconIndex = index);
                              },
                            ),
                            if(widget.onCreateRequested != null && widget.enableTemporary) ...<Widget>[
                              const SizedBox(height:_sectionGap),
                              Row(children:[
                                Expanded(child:Text(
                                  _expiresAt == null
                                    ? 'Permanent Circle'
                                    : 'Temporary until ${_expiresAt!.toLocal().toString().substring(0,16)}',
                                  style:const TextStyle(
                                    fontFamily:AppTypography.fontFamily,
                                    color:Color(0xFF64748B),fontSize:13),
                                )),
                                TextButton(onPressed:_chooseExpiry,
                                  child:const Text('Set expiry')),
                                if(_expiresAt != null)
                                  IconButton(
                                    tooltip:'Clear expiry',
                                    onPressed:(){
                                      _newDraft();setState(()=>_expiresAt=null);
                                    },icon:const Icon(Icons.close,size:18)),
                              ]),
                              if(_expiresAt != null)
                                const Text('Read-only for 72 hours after expiry, '
                                  'then archived without automatic deletion.',
                                  style:TextStyle(
                                    fontFamily:AppTypography.fontFamily,
                                    fontSize:12,color:Color(0xFF64748B))),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: buttonHorizontalPadding,
                    right: buttonHorizontalPadding,
                    bottom: WelcomeLayoutMetrics.bottomSpacing,
                    child: Center(
                      child: WelcomeActionPanel(
                        primaryKey: CreateCircleKeys.nextButton,
                        primaryLabel: 'Create Circle',
                        onPrimaryPressed: _submit,
                        secondaryKey: widget.onSkip == null
                            ? null
                            : CreateCircleKeys.skipButton,
                        secondaryLabel: widget.onSkip == null ? null : 'Skip',
                        onSecondaryPressed: widget.onSkip,
                        reserveSecondarySlot: widget.onSkip == null,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

abstract final class _CreateCircleStyles {
  static const TextStyle label = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: const <String>[
      'Noto Color Emoji',
      'Apple Color Emoji',
      'Segoe UI Emoji',
    ],
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: Colors.black,
  );
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const double _gap = 10;

  final List<_CircleColorOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (var index = 0; index < options.length; index++) {
      if (index > 0) {
        children.add(const SizedBox(width: _gap));
      }

      final option = options[index];
      final selected = selectedIndex == index;

      children.add(
        Semantics(
          selected: selected,
          button: true,
          label: 'Circle color ${index + 1}',
          child: InkResponse(
            key: CreateCircleKeys.color(index),
            onTap: () => onSelected(index),
            radius: 22,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 140),
              scale: selected ? 1 : 0.94,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: option.fill,
                  border: Border.all(color: option.border, width: 2),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({
    required this.icons,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const double _gap = 20;
  static const double _itemSize = 40;

  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (var index = 0; index < icons.length; index++) {
      if (index > 0) {
        children.add(const SizedBox(width: _gap));
      }

      final selected = selectedIndex == index;

      children.add(
        Semantics(
          selected: selected,
          button: true,
          label: 'Circle icon ${index + 1}',
          child: Material(
            key: CreateCircleKeys.icon(index),
            color: selected ? const Color(0x1A7C3AED) : AppColors.white,
            borderRadius: BorderRadius.circular(6.67),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelected(index),
              child: Ink(
                width: _itemSize,
                height: _itemSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6.67),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset.zero,
                      blurRadius: 2.67,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  icons[index],
                  size: 25,
                  color: selected ? const Color(0xFF7C3AED) : Colors.black,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final requiredWidth =
        (icons.length * _itemSize) + ((icons.length - 1) * _gap);

    return LayoutBuilder(
      builder: (context, constraints) {
        final row = Row(mainAxisSize: MainAxisSize.min, children: children);

        if (constraints.maxWidth >= requiredWidth) {
          return Align(alignment: Alignment.centerLeft, child: row);
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: row,
        );
      },
    );
  }
}

class _CircleColorOption {
  const _CircleColorOption({required this.border, required this.fill});

  final Color border;
  final Color fill;
}

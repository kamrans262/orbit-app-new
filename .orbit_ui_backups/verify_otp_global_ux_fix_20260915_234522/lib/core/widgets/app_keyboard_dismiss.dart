import 'package:flutter/material.dart';

/// App-wide keyboard dismissal wrapper.
///
/// It listens without participating in the gesture arena, so taps continue to
/// reach fields, buttons, and other interactive controls. Taps outside the
/// currently focused control dismiss the keyboard.
class AppKeyboardDismiss extends StatelessWidget {
  const AppKeyboardDismiss({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        final focus = FocusManager.instance.primaryFocus;
        final focusContext = focus?.context;

        if (focus == null || focusContext == null) {
          return;
        }

        final renderObject = focusContext.findRenderObject();
        if (renderObject is RenderBox && renderObject.hasSize) {
          final localPosition = renderObject.globalToLocal(event.position);
          final focusedBounds = Offset.zero & renderObject.size;
          if (focusedBounds.contains(localPosition)) {
            return;
          }
        }

        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: child,
    );
  }
}

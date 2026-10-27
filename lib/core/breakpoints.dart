import 'package:flutter/widgets.dart';

enum WindowClass { compact, medium, expanded }

WindowClass windowClassOf(double width) => width < 600
    ? WindowClass.compact
    : width < 1200
    ? WindowClass.medium
    : WindowClass.expanded;

extension WindowClassContext on BuildContext {
  WindowClass get windowClass => windowClassOf(MediaQuery.sizeOf(this).width);
}

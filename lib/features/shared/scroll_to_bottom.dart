import 'package:flutter/widgets.dart';

/// Jumps a list to its absolute end and keeps correcting for lazy layout.
///
/// A `ListView` estimates `maxScrollExtent` before every child is built, so a
/// single jump can stop several items short. Repeating the jump across frames
/// until the extent stops growing reaches the real bottom in one tap.
void settleScrollToBottom(ScrollController controller, {int maxFrames = 16}) {
  if (!controller.hasClients) {
    return;
  }
  var frames = 0;
  var stableFrames = 0;
  double? lastExtent;

  void step() {
    if (!controller.hasClients) {
      return;
    }
    final extent = controller.position.maxScrollExtent;
    controller.jumpTo(extent);
    frames++;
    if (extent == lastExtent) {
      stableFrames++;
    } else {
      stableFrames = 0;
      lastExtent = extent;
    }
    if (frames < maxFrames && stableFrames < 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) => step());
    }
  }

  step();
}

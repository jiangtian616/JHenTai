import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Rewrite gesture mechanism
class EHReadPageStack extends Stack {
  const EHReadPageStack({
    super.key,
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
    super.children,
  });

  @override
  RenderStack createRenderObject(BuildContext context) {
    return RenderEHReadPageStack(
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      fit: fit,
      clipBehavior: clipBehavior,
    );
  }
}

class RenderEHReadPageStack extends RenderStack {
  RenderEHReadPageStack({
    super.children,
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
  });

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    bool hit = false;
    
    RenderBox? child = lastChild;
    while (child != null) {
      final ContainerBoxParentData<RenderBox> childParentData = child.parentData! as ContainerBoxParentData<RenderBox>;
      hit = hit |
          result.addWithPaintOffset(
            offset: childParentData.offset,
            position: position,
            hitTest: (BoxHitTestResult result, Offset transformed) {
              assert(transformed == position - childParentData.offset);
              return child!.hitTest(result, position: transformed);
            },
          );
      child = childParentData.previousSibling;
    }

    return hit;
  }
}

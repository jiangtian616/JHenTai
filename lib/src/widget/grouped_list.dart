import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/widget/fade_slide_widget.dart';

import 'eh_wheel_speed_controller.dart';

class GroupedList<G, E> extends StatefulWidget {
  final List<({G group, bool isOpen})> groups;
  final List<E> elements;

  final G Function(E element) elementGroup;

  final Object Function(G group) groupUniqueKey;
  final Object Function(E element) elementUniqueKey;

  final Widget Function(BuildContext context, G group, bool isOpen) groupBuilder;
  final Widget Function(BuildContext context, E element, bool isOpen) elementBuilder;

  final ScrollController? scrollController;

  final GroupedListController? controller;

  const GroupedList({
    Key? key,
    required this.groups,
    required this.elements,
    required this.elementGroup,
    required this.elementUniqueKey,
    required this.groupUniqueKey,
    required this.groupBuilder,
    required this.elementBuilder,
    this.scrollController,
    this.controller,
  }) : super(key: key);

  @override
  State<GroupedList<G, E>> createState() => _GroupedListState<G, E>();
}

class _GroupedListState<G, E> extends State<GroupedList<G, E>> {
  late ScrollController scrollController;

  late GroupedListController controller;

  final Map<Object, Completer<void>> deletingElements = {};

  @override
  void initState() {
    super.initState();

    if (widget.scrollController == null) {
      scrollController = ScrollController();
    } else {
      scrollController = widget.scrollController!;
    }

    if (widget.controller == null) {
      controller = GroupedListController();
    } else {
      controller = widget.controller!;
    }
    controller.attach(this);
  }

  @override
  void dispose() {
    super.dispose();

    controller.detach();
  }

  @override
  Widget build(BuildContext context) {
    return EHWheelSpeedController(
      controller: scrollController,
      child: CustomScrollView(
        controller: scrollController,
        cacheExtent: 20,
        slivers: _buildSlivers(context),
      ),
    );
  }

  List<Widget> _buildSlivers(BuildContext context) {
    List<Widget> slivers = [];

    Map<G, List<E>> group2Elements = widget.elements.groupListsBy<G>((e) => widget.elementGroup(e));

    for (({G group, bool isOpen}) groupInfo in widget.groups) {
      slivers.add(_buildGroup(context, groupInfo));

      if (group2Elements.containsKey(groupInfo.group)) {
        slivers.add(_buildElements(context, group2Elements[groupInfo.group]!, groupInfo.isOpen));
      }
    }

    return slivers;
  }

  Widget _buildGroup(BuildContext context, ({G group, bool isOpen}) groupInfo) {
    return SliverToBoxAdapter(
      child: widget.groupBuilder(context, groupInfo.group, groupInfo.isOpen),
    );
  }

  Widget _buildElements(BuildContext context, List<E> elements, bool isOpen) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildElement(context, elements[index], isOpen),
        childCount: elements.length,
      ),
    );
  }

  Widget _buildElement(BuildContext context, E element, bool isOpen) {
    return FadeSlideWidget(
      show: isOpen && !deletingElements.containsKey(widget.elementUniqueKey(element)),
      child: widget.elementBuilder(context, element, isOpen),
      afterDisappear: () {
        Completer<void>? completer = deletingElements[widget.elementUniqueKey(element)];
        if (completer != null) {
          setState(() {
            deletingElements.remove(widget.elementUniqueKey(element));
          });
          completer.complete();
        }
      },
    );
  }

  Future<void> removeElement(E element) {
    Completer<void> completer = Completer();
    setState(() {
      deletingElements[widget.elementUniqueKey(element)] = completer;
    });
    return completer.future;
  }
}

class GroupedListController<G, E> {
  bool get isAttached => _groupedListState != null;

  _GroupedListState<G, E>? _groupedListState;

  void attach(_GroupedListState<G, E> state) {
    assert(_groupedListState == null);

    _groupedListState = state;
  }

  void detach() {
    assert(_groupedListState != null);

    _groupedListState = null;
  }

  Future<void> removeElement(E element) {
    assert(isAttached);

    return _groupedListState!.removeElement(element);
  }
}

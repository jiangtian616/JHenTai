import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/widget/fade_slide_widget.dart';

import 'eh_wheel_speed_controller.dart';

class GroupedList<G, E> extends StatefulWidget {
  final Map<G, bool> groups;
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

  final Map<G, bool> groups = {};

  final Map<G, Completer<void>> togglingGroups = {};
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

    _initGroups(widget.groups);
  }

  @override
  void dispose() {
    super.dispose();

    controller.detach();
  }

  @override
  void didUpdateWidget(covariant GroupedList<G, E> oldWidget) {
    super.didUpdateWidget(oldWidget);

    _initGroups(widget.groups);
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

    groups.forEach((group, isOpen) {
      slivers.add(_buildGroup(context, group, isOpen));

      if (group2Elements.containsKey(group)) {
        slivers.add(_buildElements(context, group2Elements[group]!, group, isOpen, togglingGroups.containsKey(group)));
      }
    });

    return slivers;
  }

  Widget _buildGroup(BuildContext context, G group, bool isOpen) {
    return SliverToBoxAdapter(
      child: widget.groupBuilder(context, group, isOpen),
    );
  }

  Widget _buildElements(BuildContext context, List<E> elements, G group, bool isOpen, bool isToggling) {
    /// dont render when closed
    if (!isToggling) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => FadeSlideWidget(
            show: isOpen && !deletingElements.containsKey(widget.elementUniqueKey(elements[index])),
            child: widget.elementBuilder(context, elements[index], isOpen),
            afterDisappear: () {
              Completer<void>? completer = deletingElements[widget.elementUniqueKey(elements[index])];
              if (completer != null) {
                setState(() {
                  deletingElements.remove(widget.elementUniqueKey(elements[index]));
                  completer.complete();
                });
              }
            },
          ),
          childCount: elements.length,
        ),
      );
    }

    return SliverToBoxAdapter(
      child: FadeSlideWidget(
        show: isOpen,
        animateWhenInitialization: true,
        child: Column(
          children: elements.map((element) => widget.elementBuilder(context, element, isOpen)).toList(),
        ),
        afterInitAnimation: () {
          setState(() {
            Completer<void> completer = togglingGroups.remove(group)!;
            completer.complete();
          });
        },
      ),
    );
  }

  Future<void> removeElement(E element) {
    Completer<void> completer = Completer();
    setState(() {
      deletingElements[widget.elementUniqueKey(element)] = completer;
    });
    return completer.future;
  }

  Future<void> toggleGroup(G group) {
    if (togglingGroups.containsKey(group) || !groups.containsKey(group)) {
      return Future.value();
    }

    Completer<void> completer = Completer();
    setState(() {
      groups[group] = !groups[group]!;
      togglingGroups[group] = completer;
    });
    return completer.future;
  }

  void _initGroups(Map<G, bool> groups) {
    this.groups.clear();
    this.groups.addAll(groups);
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

  Future<void> toggleGroup(G group) {
    assert(isAttached);

    return _groupedListState!.toggleGroup(group);
  }
}

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/widget/fade_slide_widget.dart';

import 'eh_wheel_speed_controller.dart';

class GroupedListLogic extends GetxController {}

class GroupedList<G, E> extends StatefulWidget {
  final Map<G, bool> groups;
  final List<E> elements;

  final G Function(E element) elementGroup;

  final String Function(G group) groupUniqueKey;
  final String Function(E element) elementUniqueKey;

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
  late GroupedListLogic logic;

  late ScrollController scrollController;

  late GroupedListController controller;

  final Map<G, bool> groups = {};
  final Set<G> togglingGroups = {};

  final Map<Object, Completer<void>> deletingElements = {};

  @override
  void initState() {
    super.initState();

    logic = GroupedListLogic();

    _initGroups(widget.groups);

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
        cacheExtent: 200,
        slivers: _buildSlivers(context),
      ),
    );
  }

  List<Widget> _buildSlivers(BuildContext context) {
    List<Widget> slivers = [];

    Map<G, List<E>> group2Elements = widget.elements.groupListsBy<G>((e) => widget.elementGroup(e));

    for (G group in groups.keys) {
      slivers.add(_buildGroup(context, group));

      if (group2Elements.containsKey(group)) {
        slivers.add(_buildElements(context, group2Elements[group]!, group));
      }
    }

    return slivers;
  }

  Widget _buildGroup(BuildContext context, G group) {
    return SliverToBoxAdapter(
      child: GetBuilder<GroupedListLogic>(
        id: 'group::${widget.groupUniqueKey(group)}',
        global: false,
        init: logic,
        builder: (_) {
          bool isOpen = groups[group] ?? false;
          return widget.groupBuilder(context, group, isOpen);
        },
      ),
    );
  }

  Widget _buildElements(BuildContext context, List<E> elements, G group) {
    /// dont render when closed
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return GetBuilder<GroupedListLogic>(
            id: 'group::${widget.groupUniqueKey(group)}',
            global: false,
            init: logic,
            builder: (_) {
              return GetBuilder<GroupedListLogic>(
                id: 'element::${widget.elementUniqueKey(elements[index])}',
                global: false,
                init: logic,
                builder: (_) {
                  bool isOpen = groups[group] ?? false;
                  return FadeSlideWidget(
                    key: ValueKey(widget.elementUniqueKey(elements[index])),
                    show: isOpen && !deletingElements.containsKey(widget.elementUniqueKey(elements[index])),
                    child: widget.elementBuilder(context, elements[index], isOpen),
                    afterAnimation: (bool show, bool isInit) {
                      if (!show && !isInit) {
                        deletingElements.remove(widget.elementUniqueKey(elements[index]))?.complete();
                      }
                    },
                  );
                },
              );
            },
          );
        },
        childCount: elements.length,
      ),
    );
  }

  Future<void> removeElement(E element) {
    Completer<void> completer = Completer();
    String elementKey = widget.elementUniqueKey(element);
    deletingElements[elementKey] = completer;
    logic.update(['element::$elementKey']);
    return completer.future;
  }

  void toggleGroup(G group) {
    if (!groups.containsKey(group)) {
      return;
    }
    groups[group] = !groups[group]!;
    logic.updateSafely(['group::${widget.groupUniqueKey(group)}']);
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

  void toggleGroup(G group) {
    assert(isAttached);

    return _groupedListState!.toggleGroup(group);
  }
}

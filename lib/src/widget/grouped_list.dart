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

  final int maxGalleryNum4Animation;

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
    required this.maxGalleryNum4Animation,
    this.scrollController,
    this.controller,
  }) : super(key: key);

  @override
  State<GroupedList<G, E>> createState() => _GroupedListState<G, E>();
}

class _GroupedListState<G, E> extends State<GroupedList<G, E>> {
  late GroupedListLogic logic;

  late int maxGalleryNum4Animation;

  late ScrollController scrollController;

  late GroupedListController controller;

  final Map<G, bool> _groups = {};
  Map<G, List<E>> _group2Elements = {};

  final Map<Object, Completer<void>> _deletingElements = {};

  @override
  void initState() {
    super.initState();

    logic = GroupedListLogic();

    maxGalleryNum4Animation = widget.maxGalleryNum4Animation;

    _initGroupsAndElements(widget);

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

    maxGalleryNum4Animation = widget.maxGalleryNum4Animation;

    _initGroupsAndElements(widget);
  }

  @override
  Widget build(BuildContext context) {
    return _buildInListView();

    return _buildInCustomScrollView(context);
  }

  EHWheelSpeedController _buildInListView() {
    return EHWheelSpeedController(
      controller: scrollController,
      child: ListView.builder(
        controller: scrollController,
        cacheExtent: 200,
        itemCount: _groups.length + widget.elements.length,
        itemBuilder: (context, index) {
          int i = 0;
          int groupIndex = 0;
          while (true) {
            G group = _groups.keys.elementAt(groupIndex);

            if (i == index) {
              return _buildGroup(group, context);
            }

            List<E> elements = _group2Elements[group] ?? [];

            if (i + 1 + elements.length > index) {
              return _buildElement(
                context,
                elements[index - i - 1],
                group,
                elements.length <= maxGalleryNum4Animation,
              );
            }

            i += 1 + elements.length;
            groupIndex++;
          }
        },
      ),
    );
  }

  EHWheelSpeedController _buildInCustomScrollView(BuildContext context) {
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

    for (G group in _groups.keys) {
      slivers.add(_buildGroupSliver(context, group));

      if (group2Elements.containsKey(group)) {
        slivers.add(_buildElementsSliver(context, group2Elements[group]!, group));
      }
    }

    return slivers;
  }

  Widget _buildGroupSliver(BuildContext context, G group) {
    return SliverToBoxAdapter(
      child: _buildGroup(group, context),
    );
  }

  Widget _buildElementsSliver(BuildContext context, List<E> elements, G group) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return GetBuilder<GroupedListLogic>(
            id: 'group::${widget.groupUniqueKey(group)}',
            global: false,
            init: logic,
            builder: (_) {
              return _buildElement(context, elements[index], group, elements.length <= maxGalleryNum4Animation);
            },
          );
        },
        childCount: elements.length,
      ),
    );
  }

  GetBuilder<GroupedListLogic> _buildGroup(group, BuildContext context) {
    return GetBuilder<GroupedListLogic>(
      id: 'group::${widget.groupUniqueKey(group)}',
      global: false,
      init: logic,
      builder: (_) {
        bool isOpen = _groups[group] ?? false;
        return widget.groupBuilder(context, group, isOpen);
      },
    );
  }

  Widget _buildElement(BuildContext context, E element, G group, bool enableAnimation) {
    return GetBuilder<GroupedListLogic>(
      id: 'group::${widget.groupUniqueKey(group)}',
      global: false,
      init: logic,
      builder: (_) {
        return GetBuilder<GroupedListLogic>(
          id: 'element::${widget.elementUniqueKey(element)}',
          global: false,
          init: logic,
          builder: (_) {
            bool isOpen = _groups[group] ?? false;
            return FadeSlideWidget(
              key: ValueKey(widget.elementUniqueKey(element)),
              show: isOpen && !_deletingElements.containsKey(widget.elementUniqueKey(element)),
              enableOpacityTransition: enableAnimation,
              enableSlideTransition: enableAnimation,
              child: widget.elementBuilder(context, element, isOpen),
              afterAnimation: (bool show, bool isInit) {
                if (!show && !isInit) {
                  _deletingElements.remove(widget.elementUniqueKey(element))?.complete();
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> removeElement(E element) {
    Completer<void> completer = Completer();
    String elementKey = widget.elementUniqueKey(element);
    _deletingElements[elementKey] = completer;

    G group = widget.elementGroup(element);
    _group2Elements[group]!.remove(element);
    
    logic.update(['element::$elementKey']);
    return completer.future;
  }

  void toggleGroup(G group) {
    if (!_groups.containsKey(group)) {
      return;
    }
    _groups[group] = !_groups[group]!;
    logic.updateSafely(['group::${widget.groupUniqueKey(group)}']);
  }

  void _initGroupsAndElements(GroupedList<G, E> widget) {
    this._groups.clear();
    this._group2Elements.clear();

    this._groups.addAll(widget.groups);
    this._group2Elements = widget.elements.groupListsBy<G>((e) => widget.elementGroup(e));
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

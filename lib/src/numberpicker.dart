import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infinite_listview/infinite_listview.dart';

typedef TextMapper = String Function(String numberText);

class NumberPicker extends StatefulWidget {
  final int minValue;
  final int maxValue;
  final int value;
  final ValueChanged<int> onChanged;
  final int itemCount;
  final int step;
  final double itemHeight;
  final double itemWidth;
  final Axis axis;
  final TextStyle? textStyle;
  final TextStyle? selectedTextStyle; // Correctly declare without initialization
  final bool haptics;
  final TextMapper? textMapper;
  final bool zeroPad;
  final Decoration? decoration;
  final bool infiniteLoop;

  const NumberPicker({
    Key? key,
    required this.minValue,
    required this.maxValue,
    required this.value,
    required this.onChanged,
    this.itemCount = 3,
    this.step = 1,
    this.itemHeight = 50,
    this.itemWidth = 100,
    this.axis = Axis.vertical,
    this.textStyle,
    this.selectedTextStyle, // Pass through constructor
    this.haptics = false,
    this.decoration,
    this.zeroPad = false,
    this.textMapper,
    this.infiniteLoop = false,
  })  : assert(minValue <= value),
        assert(value <= maxValue),
        super(key: key);

  @override
  _NumberPickerState createState() => _NumberPickerState();
}

class _NumberPickerState extends State<NumberPicker> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.infiniteLoop
        ? InfiniteScrollController(initialScrollOffset: (widget.value - widget.minValue) ~/ widget.step * itemExtent)
        : ScrollController(initialScrollOffset: (widget.value - widget.minValue) ~/ widget.step * itemExtent);
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    final indexOfMiddleElement = (_scrollController.offset / itemExtent).round() % itemCount;
    final intValueInTheMiddle = _intValueFromIndex(indexOfMiddleElement + additionalItemsOnEachSide);

    if (widget.value != intValueInTheMiddle) {
      widget.onChanged(intValueInTheMiddle);
      if (widget.haptics) {
        HapticFeedback.selectionClick();
      }
    }
  }

  @override
  void didUpdateWidget(NumberPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _maybeCenterValue();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get isScrolling => _scrollController.position.isScrollingNotifier.value;
  double get itemExtent => widget.axis == Axis.vertical ? widget.itemHeight : widget.itemWidth;
  int get itemCount => (widget.maxValue - widget.minValue) ~/ widget.step + 1;
  int get listItemsCount => itemCount + 2 * additionalItemsOnEachSide;
  int get additionalItemsOnEachSide => (widget.itemCount - 1) ~/ 2;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    // Determine the selectedTextStyle here within the build method where themeData is accessible
    final TextStyle? selectedTextStyle = widget.selectedTextStyle ?? themeData.textTheme.headline5?.copyWith(color: themeData.colorScheme.secondary);

    return SizedBox(
      width: widget.axis == Axis.vertical ? widget.itemWidth : widget.itemCount * widget.itemWidth,
      height: widget.axis == Axis.vertical ? widget.itemCount * widget.itemHeight : widget.itemHeight,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          if (notification.dragDetails?.primaryVelocity == 0) {
            Future.microtask(() => _maybeCenterValue());
          }
          return true;
        },
        child: Stack(
          children: [
            ListView.builder(
              itemCount: widget.infiniteLoop ? null : listItemsCount,
              scrollDirection: widget.axis,
              controller: _scrollController,
              itemExtent: itemExtent,
              itemBuilder: (context, index) => _itemBuilder(context, index, selectedTextStyle),
              padding: EdgeInsets.zero,
            ),
            _NumberPickerSelectedItemDecoration(
              axis: widget.axis,
              itemExtent: itemExtent,
              decoration: widget.decoration,
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemBuilder(BuildContext context, int index) {
    final themeData = Theme.of(context);
    final defaultStyle = widget.textStyle ?? themeData.textTheme.bodyText2;
    final selectedStyle = widget.selectedTextStyle ??
        themeData.textTheme.headline5?.copyWith(color: themeData.colorScheme.secondary);

    final value = _intValueFromIndex(index % itemCount);
    final isExtra = !widget.infiniteLoop &&
        (index < additionalItemsOnEachSide ||
            index >= listItemsCount - additionalItemsOnEachSide);
    final itemStyle = value == widget.value ? selectedStyle : defaultStyle;

    final child = isExtra
        ? SizedBox.shrink()
        : Text(
            _getDisplayedValue(value),
            style: itemStyle,
          );

    return Container(
      width: widget.itemWidth,
      height: widget.itemHeight,
      alignment: Alignment.center,
      child: child,
    );
  }

  String _getDisplayedValue(int value) {
    final text = widget.zeroPad
        ? value.toString().padLeft(widget.maxValue.toString().length, '0')
        : value.toString();
    if (widget.textMapper != null) {
      return widget.textMapper!(text);
    } else {
      return text;
    }
  }

  int _intValueFromIndex(int index) {
    index -= additionalItemsOnEachSide;
    index %= itemCount;
    return widget.minValue + index * widget.step;
  }

  void _maybeCenterValue() {
    if (_scrollController.hasClients && !isScrolling) {
      int diff = widget.value - widget.minValue;
      int index = diff ~/ widget.step;
      if (widget.infiniteLoop) {
        final offset = _scrollController.offset + 0.5 * itemExtent;
        final cycles = (offset / (itemCount * itemExtent)).floor();
        index += cycles * itemCount;
      }
      _scrollController.animateTo(
        index * itemExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }
}

class _NumberPickerSelectedItemDecoration extends StatelessWidget {
  final Axis axis;
  final double itemExtent;
  final Decoration? decoration;

  const _NumberPickerSelectedItemDecoration({
    Key? key,
    required this.axis,
    required this.itemExtent,
    required this.decoration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IgnorePointer(
        child: Container(
          width: isVertical ? double.infinity : itemExtent,
          height: isVertical ? itemExtent : double.infinity,
          decoration: decoration,
        ),
      ),
    );
  }

  bool get isVertical => axis == Axis.vertical;
}

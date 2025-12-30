import 'dart:math';

import 'package:flutter/material.dart';

/// A generic animated card stack widget that displays items in a draggable stack.
///
/// When the top card is dragged past the [dragThreshold] and released,
/// it animates away and rebounds to the bottom of the stack.
class AnimatedCardStack<T> extends StatefulWidget {
  const AnimatedCardStack({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.dragThreshold = 100.0,
    this.animationDuration = const Duration(milliseconds: 400),
    this.enableShadows = true,
    this.visibleCardCount = 3,
    this.cardWidth = 300.0,
    this.cardHeight = 400.0,
    this.reboundScale = 0.7,
  });

  /// The list of data objects to display.
  final List<T> items;

  /// Builder function to create the widget for each item.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// The drag distance required to trigger the cycle animation.
  final double dragThreshold;

  /// Duration of the rebound animation.
  final Duration animationDuration;

  /// Whether to display shadows for a 3D depth effect.
  final bool enableShadows;

  /// Number of cards visible in the stack.
  final int visibleCardCount;

  /// Width of each card.
  final double cardWidth;

  /// Height of each card.
  final double cardHeight;

  /// Scale to shrink to during rebound animation (0.0 to 1.0).
  /// Smaller values hide the card edges when it slides behind the stack.
  final double reboundScale;

  @override
  State<AnimatedCardStack<T>> createState() => _AnimatedCardStackState<T>();
}

class _AnimatedCardStackState<T> extends State<AnimatedCardStack<T>> with TickerProviderStateMixin {
  /// Current order of item indices (first = top card).
  late List<int> _itemOrder;

  /// Per-item rotations - each card keeps its rotation once visible.
  final Map<int, double> _itemRotations = {};

  /// Per-item offsets - each card keeps its offset once visible.
  final Map<int, Offset> _itemOffsets = {};

  /// Current drag offset of the top card.
  Offset _dragOffset = Offset.zero;

  /// Velocity when the drag ended.
  Velocity _dragVelocity = Velocity.zero;

  /// Animation controller for the throw + rebound sequence.
  late AnimationController _animationController;

  /// Animation for position during throw/rebound.
  Animation<Offset>? _positionAnimation;

  /// Animation for rotation during rebound.
  Animation<double>? _rotationAnimation;

  /// Animation for scale during rebound (shrinks card so edges don't stick out).
  Animation<double>? _scaleAnimation;

  /// Whether the card is currently animating through the cycle.
  bool _isAnimating = false;

  /// Whether we're in the rebound phase (card should render behind stack).
  bool _isInReboundPhase = false;

  /// Animation progress threshold where rebound phase begins (after throw + exit).
  static const double _reboundPhaseStart = 0.55; // 30% + 25% = 55%

  /// Whether this is a cycle animation (vs snap-back).
  bool _isCycleAnimation = false;

  /// Pool of distinct rotations to ensure cards look different.
  /// Values in radians, roughly -5° to +5°.
  static const List<double> _rotationPool = [
    -0.087, // -5°
    0.052, // +3°
    -0.035, // -2°
    0.070, // +4°
    -0.061, // -3.5°
    0.044, // +2.5°
    -0.079, // -4.5°
    0.026, // +1.5°
  ];

  /// Pool of distinct offsets for visual variety.
  static const List<Offset> _offsetPool = [
    Offset(-6, 3),
    Offset(8, -2),
    Offset(-4, -4),
    Offset(7, 5),
    Offset(-9, 1),
    Offset(5, -3),
    Offset(-3, 6),
    Offset(10, 2),
  ];

  @override
  void initState() {
    super.initState();
    _initializeItemOrder();
    _animationController = AnimationController(vsync: this, duration: widget.animationDuration);
    _animationController.addStatusListener(_onAnimationStatusChanged);
    _animationController.addListener(_checkReboundPhase);
  }

  /// Check if we've entered the rebound phase and update z-order accordingly.
  void _checkReboundPhase() {
    if (_isAnimating && _isCycleAnimation) {
      final shouldBeInRebound = _animationController.value >= _reboundPhaseStart;
      if (shouldBeInRebound != _isInReboundPhase) {
        setState(() {
          _isInReboundPhase = shouldBeInRebound;
        });
      }
    }
  }

  void _initializeItemOrder() {
    _itemOrder = List.generate(widget.items.length, (i) => i);
    _initializeVisibleCardStyles();
  }

  /// Assign initial rotations/offsets to visible cards based on stack position.
  void _initializeVisibleCardStyles() {
    final visibleCount = widget.visibleCardCount.clamp(0, widget.items.length);
    for (var stackPos = 0; stackPos < visibleCount; stackPos++) {
      final itemIndex = _itemOrder[stackPos];
      if (!_itemRotations.containsKey(itemIndex)) {
        _itemRotations[itemIndex] = _getInitialRotation(stackPos);
        _itemOffsets[itemIndex] = _getInitialOffset(stackPos);
      }
    }
  }

  /// Get initial rotation for a stack position (used when card first becomes visible).
  double _getInitialRotation(int stackPosition) {
    final cycleLength = widget.visibleCardCount - 1;
    if (cycleLength <= 0) return _rotationPool[0];
    final rotationIndex = stackPosition % cycleLength;
    return _rotationPool[rotationIndex % _rotationPool.length];
  }

  /// Get initial offset for a stack position.
  Offset _getInitialOffset(int stackPosition) {
    final cycleLength = widget.visibleCardCount - 1;
    if (cycleLength <= 0) return _offsetPool[0];
    final offsetIndex = stackPosition % cycleLength;
    return _offsetPool[offsetIndex % _offsetPool.length];
  }

  @override
  void didUpdateWidget(AnimatedCardStack<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      _initializeItemOrder();
    }
    if (widget.animationDuration != oldWidget.animationDuration) {
      _animationController.duration = widget.animationDuration;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Get the rotation for a specific item (by item index, not stack position).
  double _getItemRotation(int itemIndex) {
    return _itemRotations[itemIndex] ?? _rotationPool[0];
  }

  /// Get the offset for a specific item (by item index, not stack position).
  Offset _getItemOffset(int itemIndex) {
    return _itemOffsets[itemIndex] ?? _offsetPool[0];
  }

  void _onPanStart(DragStartDetails details) {
    if (_isAnimating) {
      // If we are in the rebound phase (sliding back), allow the user to interrupt
      // and immediately grab the next card. The old card snaps to its final position.
      if (_isInReboundPhase) {
        _animationController.stop();
        _onAnimationStatusChanged(AnimationStatus.completed);
        // Fall through to process the new drag start
      } else {
        // If we are in the throw phase (fly out), do not interrupt
        return;
      }
    }

    setState(() {
      _dragOffset = Offset.zero;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isAnimating) return;

    _dragVelocity = details.velocity;
    final dragDistance = _dragOffset.distance;
    final velocityMagnitude = _dragVelocity.pixelsPerSecond.distance;

    // Check if threshold is met (either by distance or velocity)
    final thresholdMet = dragDistance > widget.dragThreshold || velocityMagnitude > 800;

    if (thresholdMet && widget.items.length > 1) {
      _startCycleAnimation();
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    setState(() {
      _isAnimating = true;
    });

    // Get the top card's actual resting position and rotation
    final topItemIndex = _itemOrder[0];
    final cardOffset = _getItemOffset(topItemIndex);
    final cardRotation = _getItemRotation(topItemIndex);

    // Current position is cardOffset + dragOffset, animate back to cardOffset
    final currentPosition = cardOffset + _dragOffset;
    _positionAnimation = _animationController.drive(
      Tween<Offset>(begin: currentPosition, end: cardOffset).chain(CurveTween(curve: Curves.easeOutBack)),
    );

    // Animate rotation back to base rotation
    final currentRotation = cardRotation + (_dragOffset.dx / 500).clamp(-0.15, 0.15);
    _rotationAnimation = _animationController.drive(
      Tween<double>(begin: currentRotation, end: cardRotation).chain(CurveTween(curve: Curves.easeOutBack)),
    );

    _isCycleAnimation = false;
    _scaleAnimation = null;

    _animationController.duration = const Duration(milliseconds: 300);
    _animationController.forward(from: 0);
  }

  void _startCycleAnimation() {
    setState(() {
      _isAnimating = true;
      _isCycleAnimation = true;
    });

    // Calculate throw target (continue in drag direction with momentum)
    final velocityFactor = 0.15;
    // Calculate throw target and exit point
    // We must include cardOffset in all calculations because the visual position
    // includes it (position = cardOffset + dragOffset).
    final topItemIndex = _itemOrder[0];
    final cardOffset = _getItemOffset(topItemIndex);

    final throwTarget =
        _dragOffset +
        Offset(_dragVelocity.pixelsPerSecond.dx * velocityFactor, _dragVelocity.pixelsPerSecond.dy * velocityFactor);

    // Normalize direction for exit
    final exitDirection = _dragOffset.distance > 0
        ? Offset(_dragOffset.dx / _dragOffset.distance, _dragOffset.dy / _dragOffset.distance)
        : const Offset(1, 0);

    // Exit point (far off screen in drag direction)
    final exitTarget = exitDirection * 500;

    // Build animation sequence with cardOffset added to all points
    _positionAnimation = TweenSequence<Offset>([
      // Phase 1: Throw with momentum (decelerate)
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: cardOffset + _dragOffset,
          end: cardOffset + throwTarget,
        ).chain(CurveTween(curve: Curves.decelerate)),
        weight: 30,
      ),
      // Phase 2: Continue to exit point
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: cardOffset + throwTarget,
          end: cardOffset + exitTarget,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      // Phase 3: Rebound to back of stack (arc movement)
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: cardOffset + exitTarget,
          end: cardOffset, // Rebound back to resting offset
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
    ]).animate(_animationController);

    // Rotation during throw - start from current visual rotation
    final cardRotation = _getItemRotation(topItemIndex);
    // Use same calculation as _buildCard for consistency (divisor 500, clamp -0.15 to 0.15)
    final currentRotation = cardRotation + (_dragOffset.dx / 500).clamp(-0.15, 0.15);

    // Additional rotation during throw is proportional to velocity (smooth when velocity is 0)
    final velocityMagnitude = _dragVelocity.pixelsPerSecond.distance;
    final additionalRotation = (velocityMagnitude / 5000).clamp(0.0, 0.1);

    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: currentRotation, end: currentRotation + additionalRotation),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: currentRotation + additionalRotation, end: cardRotation),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: cardRotation, end: cardRotation),
        weight: 45,
      ),
    ]).animate(_animationController);

    // Scale animation: stay at 1.0 during throw/exit, shrink during rebound
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 25),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: widget.reboundScale).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
    ]).animate(_animationController);

    _animationController.duration = widget.animationDuration * 2;
    _animationController.forward(from: 0);
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        // If this was a cycle animation (not snap back), move top card to bottom
        if (_isCycleAnimation) {
          final topCard = _itemOrder.removeAt(0);
          _itemOrder.add(topCard);

          // The new bottom card (next to become visible) should inherit
          // the new top card's rotation for smooth entry
          final visibleCount = widget.visibleCardCount.clamp(0, widget.items.length);
          if (visibleCount > 0 && _itemOrder.length > visibleCount - 1) {
            final newBottomItemIndex = _itemOrder[visibleCount - 1];
            final newTopItemIndex = _itemOrder[0];
            // New bottom card gets the same rotation/offset as the new top card
            _itemRotations[newBottomItemIndex] = _getItemRotation(newTopItemIndex);
            _itemOffsets[newBottomItemIndex] = _getItemOffset(newTopItemIndex);
          }
        }
        _dragOffset = Offset.zero;
        _isAnimating = false;
        _isInReboundPhase = false;
        _isCycleAnimation = false;
        _positionAnimation = null;
        _rotationAnimation = null;
        _scaleAnimation = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: widget.cardWidth + 40,
      height: widget.cardHeight + 40,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: _buildCards());
        },
      ),
    );
  }

  List<Widget> _buildCards() {
    final cards = <Widget>[];
    final visibleCount = min(widget.visibleCardCount, widget.items.length);

    // During rebound phase, the animating card should be at the BOTTOM (rendered first)
    if (_isInReboundPhase) {
      // Add the animating top card first (will be at bottom of z-order)
      final topItemIndex = _itemOrder[0];
      final topItem = widget.items[topItemIndex];
      cards.add(_buildCard(topItem, 0));

      // Then add background cards on top
      for (var i = visibleCount - 1; i >= 1; i--) {
        final itemIndex = _itemOrder[i];
        final item = widget.items[itemIndex];
        cards.add(_buildCard(item, i));
      }
    } else {
      // Normal order: bottom to top (background cards first, top card last)
      for (var i = visibleCount - 1; i >= 0; i--) {
        final itemIndex = _itemOrder[i];
        final item = widget.items[itemIndex];
        cards.add(_buildCard(item, i));
      }
    }

    return cards;
  }

  Widget _buildCard(T item, int stackPosition) {
    final isTopCard = stackPosition == 0;
    final itemIndex = _itemOrder[stackPosition];

    // Get the card's persistent rotation and offset (stays with the card)
    final cardRotation = _getItemRotation(itemIndex);
    final cardOffset = _getItemOffset(itemIndex);

    // Determine position, rotation, and scale
    Offset position;
    double rotation;
    double scale = 1.0;

    if (isTopCard) {
      if (_isAnimating && _positionAnimation != null) {
        position = _positionAnimation!.value;
        rotation = _rotationAnimation?.value ?? cardRotation;
        scale = _scaleAnimation?.value ?? 1.0;
      } else {
        // Top card: uses its persistent rotation + drag rotation on top
        position = cardOffset + _dragOffset;
        rotation = cardRotation + (_dragOffset.dx / 500).clamp(-0.15, 0.15);
      }
    } else {
      // Background cards: use their persistent rotation/offset
      position = cardOffset;
      rotation = cardRotation;
    }

    Widget cardContent = Container(
      width: widget.cardWidth,
      height: widget.cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: widget.enableShadows
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 2,
                ),
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 4)),
              ]
            : null,
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: widget.itemBuilder(context, item)),
    );

    Widget transformedCard = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translate(position.dx, position.dy)
        ..rotateZ(rotation)
        ..scale(scale),
      child: cardContent,
    );

    // Only top card is draggable
    if (isTopCard && !_isAnimating) {
      return GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: transformedCard,
      );
    }

    return transformedCard;
  }
}

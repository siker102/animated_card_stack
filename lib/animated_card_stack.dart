import 'dart:math';

import 'package:flutter/material.dart';

/// Controller for programmatically controlling an [AnimatedCardStack].
///
/// Use [swipeNext] to programmatically trigger a card swipe animation.
class AnimatedCardStackController {
  _AnimatedCardStackState? _state;

  /// Attach this controller to the given state.
  void _attach(_AnimatedCardStackState state) {
    _state = state;
  }

  /// Detach this controller from its current state.
  void _detach() {
    _state = null;
  }

  /// Programmatically swipe the top card.
  ///
  /// If [direction] is provided, the card will fly out in that direction.
  /// If [direction] is null, a random direction will be used.
  ///
  /// Returns true if the swipe was triggered, false if there are less than 2 items.
  bool swipeNext({Offset? direction}) {
    return _state?._triggerProgrammaticSwipe(direction: direction) ?? false;
  }
}

/// Holds the state of a single "detached" card animation.
///
/// When a card is thrown, it becomes an ActiveAnimation that runs independently
/// of the main stack, allowing the next card to be immediately interactive.
class ActiveAnimation<T> {
  final AnimationController controller;
  final Animation<Offset> position;
  final Animation<double> rotation;
  final Animation<double>? scale;
  final T item;
  final int itemIndex;

  /// Whether this animation is in the rebound phase (card should render behind stack).
  bool isRebounding;

  /// Animation progress threshold where rebound phase begins (after throw + exit).
  static const double reboundPhaseStart = 0.55; // 30% + 25% = 55%

  ActiveAnimation({
    required this.controller,
    required this.position,
    required this.rotation,
    this.scale,
    required this.item,
    required this.itemIndex,
    this.isRebounding = false,
  });

  void dispose() {
    controller.dispose();
  }
}

/// A generic animated card stack widget that displays items in a draggable stack.
///
/// When the top card is dragged past the [dragThreshold] and released,
/// it animates away and rebounds to the bottom of the stack.
class AnimatedCardStack<T> extends StatefulWidget {
  const AnimatedCardStack({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.controller,
    this.onTap,
    this.onDoubleTap,
    this.onCardChanged,
    this.placeholderBuilder,
    this.dragThreshold = 100.0,
    this.animationDuration = const Duration(milliseconds: 400),
    this.enableShadows = true,
    this.visibleCardCount = 3,
    this.cardWidth = 300.0,
    this.cardHeight = 400.0,
    this.reboundScale = 0.7,
  });

  /// Optional controller for programmatic control.
  final AnimatedCardStackController? controller;

  /// Called when the top card is tapped.
  ///
  /// The callback receives the item data of the tapped card.
  final void Function(T item)? onTap;

  /// Called when the top card is double-tapped.
  ///
  /// The callback receives the item data of the tapped card.
  final void Function(T item)? onDoubleTap;

  /// Called when the top card changes after a swipe animation starts.
  ///
  /// The callback receives the index and item data of the new top card.
  final void Function(int index, T item)? onCardChanged;

  /// Builder for a placeholder widget shown when the items list is empty.
  ///
  /// If null, an empty [SizedBox] is shown when items is empty.
  final WidgetBuilder? placeholderBuilder;

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
  /// Smaller values hide the card edges when it slides behind the stack. Usually 0.7 is enough to hide the edges before the card vanishes.
  final double reboundScale;

  @override
  State<AnimatedCardStack<T>> createState() => _AnimatedCardStackState<T>();
}

class _AnimatedCardStackState<T> extends State<AnimatedCardStack<T>>
    with TickerProviderStateMixin {
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

  /// List of active animations (cards that are currently animating independently).
  final List<ActiveAnimation<T>> _activeAnimations = [];

  /// Animation controller for snap-back only.
  AnimationController? _snapBackController;
  Animation<Offset>? _snapBackPositionAnimation;
  Animation<double>? _snapBackRotationAnimation;
  bool _isSnappingBack = false;

  /// Whether the top card is currently being dragged by the user.
  /// When true, animation listeners skip setState() calls to prevent race conditions.
  bool _isDragging = false;

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

  /// Random number generator for programmatic swipes.
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeItemOrder();
    widget.controller?._attach(this);
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
    // Handle controller changes
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _snapBackController?.dispose();
    for (final anim in _activeAnimations) {
      anim.dispose();
    }
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

  /// Triggered by the controller to programmatically swipe the top card.
  bool _triggerProgrammaticSwipe({Offset? direction}) {
    // Need at least 2 items to cycle
    if (widget.items.length < 2) return false;

    // Block if already animating (prevents race conditions)
    if (_isDragging) return false;

    // Block if the top card is already animating (prevents duplicate keys)
    final topItemIndex = _itemOrder[0];
    if (_activeAnimations.any((a) => a.itemIndex == topItemIndex)) return false;

    // If snapping back, cancel it
    if (_isSnappingBack) {
      _snapBackController?.stop();
      _isSnappingBack = false;
      _snapBackPositionAnimation = null;
      _snapBackRotationAnimation = null;
    }

    // Generate random direction if not provided
    final swipeDirection = direction ?? _generateRandomDirection();

    // Simulate a drag offset and velocity for the animation
    // Use a distance past the threshold to ensure it triggers
    final simulatedDragOffset = swipeDirection * (widget.dragThreshold * 1.5);
    final simulatedVelocity = Velocity(pixelsPerSecond: swipeDirection * 1200);

    // Set up the simulated values and trigger the cycle animation
    _dragOffset = simulatedDragOffset;
    _dragVelocity = simulatedVelocity;
    _startCycleAnimation();

    return true;
  }

  /// Generate a random normalized direction vector.
  Offset _generateRandomDirection() {
    // Random angle in radians (0 to 2π)
    final angle = _random.nextDouble() * 2 * pi;
    return Offset(cos(angle), sin(angle));
  }

  void _onPanStart(DragStartDetails details) {
    // If we're snapping back, cancel it and allow new drag
    if (_isSnappingBack) {
      _snapBackController?.stop();
      _isSnappingBack = false;
      _snapBackPositionAnimation = null;
      _snapBackRotationAnimation = null;
    }

    // Set flag to prevent animation rebuilds during drag
    _isDragging = true;

    setState(() {
      _dragOffset = Offset.zero;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isSnappingBack) return;
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isSnappingBack) return;

    // Clear flag to allow animation rebuilds
    _isDragging = false;

    _dragVelocity = details.velocity;
    final dragDistance = _dragOffset.distance;
    final velocityMagnitude = _dragVelocity.pixelsPerSecond.distance;

    // Check if threshold is met (either by distance or velocity)
    final thresholdMet =
        dragDistance > widget.dragThreshold || velocityMagnitude > 800;

    if (thresholdMet && widget.items.length > 1) {
      _startCycleAnimation();
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    // Get the top card's actual resting position and rotation
    final topItemIndex = _itemOrder[0];
    final cardOffset = _getItemOffset(topItemIndex);
    final cardRotation = _getItemRotation(topItemIndex);

    // Create or reuse snap-back controller
    _snapBackController?.dispose();
    _snapBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Current position is cardOffset + dragOffset, animate back to cardOffset
    final currentPosition = cardOffset + _dragOffset;
    _snapBackPositionAnimation = _snapBackController!.drive(
      Tween<Offset>(
        begin: currentPosition,
        end: cardOffset,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
    );

    // Animate rotation back to base rotation
    final currentRotation =
        cardRotation + (_dragOffset.dx / 500).clamp(-0.15, 0.15);
    _snapBackRotationAnimation = _snapBackController!.drive(
      Tween<double>(
        begin: currentRotation,
        end: cardRotation,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
    );

    _isSnappingBack = true;
    _snapBackController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isSnappingBack = false;
          _dragOffset = Offset.zero;
          _snapBackPositionAnimation = null;
          _snapBackRotationAnimation = null;
        });
      }
    });

    _snapBackController!.forward(from: 0);
    setState(() {}); // Trigger rebuild to start animation
  }

  void _startCycleAnimation() {
    // Capture current visual state BEFORE modifying anything
    final topItemIndex = _itemOrder[0];

    // Prevent starting animation if this card is already animating
    if (_activeAnimations.any((a) => a.itemIndex == topItemIndex)) return;

    final topItem = widget.items[topItemIndex];
    final cardOffset = _getItemOffset(topItemIndex);
    final cardRotation = _getItemRotation(topItemIndex);

    // Current visual position/rotation (exactly where the user's finger left off)
    final startPosition = cardOffset + _dragOffset;
    final startRotation =
        cardRotation + (_dragOffset.dx / 500).clamp(-0.15, 0.15);

    // Determine if this card will be visible at its target position (back of stack)
    final targetStackPosition = widget.items.length - 1;
    final willBeVisibleAtBack = targetStackPosition < widget.visibleCardCount;

    // Create a new animation controller for this card
    final controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration * 2,
    );

    // Calculate throw target (continue in drag direction with momentum)
    const velocityFactor = 0.15;
    final throwTarget =
        _dragOffset +
        Offset(
          _dragVelocity.pixelsPerSecond.dx * velocityFactor,
          _dragVelocity.pixelsPerSecond.dy * velocityFactor,
        );

    // Normalize direction for exit
    final exitDirection = _dragOffset.distance > 0
        ? Offset(
            _dragOffset.dx / _dragOffset.distance,
            _dragOffset.dy / _dragOffset.distance,
          )
        : const Offset(1, 0);

    // Exit point (far off screen in drag direction)
    final exitTarget = exitDirection * 500;

    // Build animation sequence with cardOffset added to all points
    final positionAnimation = TweenSequence<Offset>([
      // Phase 1: Throw with momentum (decelerate)
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: startPosition,
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
    ]).animate(controller);

    // Rotation during throw - start from current visual rotation
    final velocityMagnitude = _dragVelocity.pixelsPerSecond.distance;
    final additionalRotation = (velocityMagnitude / 5000).clamp(0.0, 0.1);

    final rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: startRotation,
          end: startRotation + additionalRotation,
        ),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: startRotation + additionalRotation,
          end: cardRotation,
        ),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: cardRotation, end: cardRotation),
        weight: 45,
      ),
    ]).animate(controller);

    // Scale animation: adapt based on whether card will be visible at the end
    Animation<double> scaleAnimation;
    if (willBeVisibleAtBack) {
      // Card will be visible: shrink during exit, then grow back to 1.0
      scaleAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.0),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: widget.reboundScale),
          weight: 25,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: widget.reboundScale,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 45,
        ),
      ]).animate(controller);
    } else {
      // Card won't be visible: shrink and stay shrunk (current behavior)
      scaleAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.0),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.0),
          weight: 25,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.0,
            end: widget.reboundScale,
          ).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 45,
        ),
      ]).animate(controller);
    }

    // Create the active animation
    final activeAnimation = ActiveAnimation<T>(
      controller: controller,
      position: positionAnimation,
      rotation: rotationAnimation,
      scale: scaleAnimation,
      item: topItem,
      itemIndex: topItemIndex,
      isRebounding: false,
    );

    // Add listener to check for rebound phase and cleanup on completion
    controller.addListener(() {
      final shouldBeInRebound =
          controller.value >= ActiveAnimation.reboundPhaseStart;

      if (shouldBeInRebound != activeAnimation.isRebounding) {
        // Update state immediately so it's correct even if we don't rebuild yet
        activeAnimation.isRebounding = shouldBeInRebound;

        // Only trigger rebuild if NOT dragging (if dragging, next frame update will catch it)
        if (!_isDragging) {
          setState(() {});
        }
      }
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Cleanup immediately so state doesn't get corrupted
        _activeAnimations.remove(activeAnimation);
        activeAnimation.dispose();

        // Only trigger rebuild if NOT dragging
        if (!_isDragging) {
          setState(() {});
        }
      }
    });

    // IMMEDIATELY update item order - move the animating item to the bottom
    final topCard = _itemOrder.removeAt(0);
    _itemOrder.add(topCard);

    // Only reassign rotation/offset if card will NOT be visible during rebound
    // This prevents visual snaps when card remains visible at the back
    final visibleCount = widget.visibleCardCount.clamp(0, widget.items.length);
    if (!willBeVisibleAtBack &&
        visibleCount > 0 &&
        _itemOrder.length > visibleCount - 1) {
      final newBottomItemIndex = _itemOrder[visibleCount - 1];
      final newTopItemIndex = _itemOrder[0];
      _itemRotations[newBottomItemIndex] = _getItemRotation(newTopItemIndex);
      _itemOffsets[newBottomItemIndex] = _getItemOffset(newTopItemIndex);
    }

    // IMMEDIATELY reset drag offset so the new top card starts at rest position
    // The animating card already captured its start position, so this is safe
    _dragOffset = Offset.zero;

    // Notify callback about the new top card
    final newTopItemIndex = _itemOrder[0];
    final newTopItem = widget.items[newTopItemIndex];
    widget.onCardChanged?.call(newTopItemIndex, newTopItem);

    // Add to active animations and start
    _activeAnimations.add(activeAnimation);
    controller.forward(from: 0);

    setState(() {}); // Trigger rebuild
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return widget.placeholderBuilder?.call(context) ??
          const SizedBox.shrink();
    }

    return SizedBox(
      width: widget.cardWidth + 40,
      height: widget.cardHeight + 40,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          if (_snapBackController != null) _snapBackController!,
          ..._activeAnimations.map((a) => a.controller),
        ]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: _buildCards(),
          );
        },
      ),
    );
  }

  List<Widget> _buildCards() {
    final cards = <Widget>[];
    final visibleCount = min(widget.visibleCardCount, widget.items.length);

    // Collect item indices that are currently animating (should not be rendered in the static stack)
    final animatingItemIndices = _activeAnimations
        .map((a) => a.itemIndex)
        .toSet();

    // BOTTOM LAYER: Rebounding animations (render first = behind everything)
    for (final anim in _activeAnimations.where((a) => a.isRebounding)) {
      cards.add(_buildAnimatingCard(anim));
    }

    // MIDDLE LAYER: Static interactive stack (excluding items that are animating)
    for (var i = visibleCount - 1; i >= 0; i--) {
      final itemIndex = _itemOrder[i];
      if (animatingItemIndices.contains(itemIndex))
        continue; // Skip if animating
      final item = widget.items[itemIndex];
      cards.add(_buildCard(item, i));
    }

    // TOP LAYER: Throwing animations (render last = in front of everything)
    for (final anim in _activeAnimations.where((a) => !a.isRebounding)) {
      cards.add(_buildAnimatingCard(anim));
    }

    return cards;
  }

  Widget _buildAnimatingCard(ActiveAnimation<T> anim) {
    final position = anim.position.value;
    final rotation = anim.rotation.value;
    final scale = anim.scale?.value ?? 1.0;

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
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: widget.itemBuilder(context, anim.item),
      ),
    );

    return Transform(
      key: ValueKey(anim.itemIndex),
      alignment: Alignment.center,
      transform: Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(position.dx, position.dy)
        ..rotateZ(rotation)
        // ignore: deprecated_member_use
        ..scale(scale),
      child: cardContent,
    );
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
      if (_isSnappingBack && _snapBackPositionAnimation != null) {
        position = _snapBackPositionAnimation!.value;
        rotation = _snapBackRotationAnimation?.value ?? cardRotation;
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
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: widget.itemBuilder(context, item),
      ),
    );

    Widget transformedCard = Transform(
      key: isTopCard ? null : ValueKey(itemIndex),
      alignment: Alignment.center,
      transform: Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(position.dx, position.dy)
        ..rotateZ(rotation)
        // ignore: deprecated_member_use
        ..scale(scale),
      child: cardContent,
    );

    // Only top card is interactive (when not snapping back)
    // During active drag, animation listeners skip rebuilds to prevent conflicts
    if (isTopCard && !_isSnappingBack) {
      return GestureDetector(
        key: ValueKey(itemIndex),
        onTap: widget.onTap != null ? () => widget.onTap!(item) : null,
        onDoubleTap: widget.onDoubleTap != null
            ? () => widget.onDoubleTap!(item)
            : null,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: () {
          if (_isDragging) {
            _isDragging = false;
            _snapBack();
          }
        },
        child: transformedCard,
      );
    }

    return transformedCard;
  }
}

# Animated Card Stack

A high-performance, interactive Flutter widget that renders a stack of cards with physics-based drag-and-rebound animations. Perfect for dating apps, flashcards, or any content requiring a fun, tactile way to cycle through items.

## Features

*   **Smooth Animations**: Physics-based drag callbacks and "rebound" effects.
*   **Fast Cycling**: Supports parallel animations - grab the next card while the previous is still animating.
*   **Controller Support**: Programmatically trigger swipes with `AnimatedCardStackController`.
*   **Callbacks**: Listen to interactions: `onTap`, `onDoubleTap`, and `onCardChanged`.
*   **Empty State**: Show a custom placeholder when the items list is empty.
*   **Customizable**: Control drag thresholds, animation duration, visible card count, and 3D shadow intensity.
*   **Performance Focused**: Efficient builder pattern for rendering only visible cards.

## Testing & CI
This project includes a comprehensive suite of **Widget Tests** and a **GitHub Actions** CI pipeline.
- **Tests**: Run `flutter test` to verify rendering, interactions, and callbacks.
- **CI**: Every push to `main` triggers analysis and testing on `ubuntu-latest`.

## Getting Started

### ⚠️ Important Note for Contributors

To keep the repository clean and platform-agnostic, we **do not commit** platform-specific build folders (`android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`) to version control.

**If you are cloning this repository for the first time:**

1.  Clone the repository.
2.  Open your terminal in the project root.
3.  Run the following command to regenerate the necessary platform runners:
    ```bash
    flutter create .
    ```
4.  Run the app as normal!

## Usage

### Basic Usage

```dart
AnimatedCardStack<String>(
  items: ['Card 1', 'Card 2', 'Card 3'],
  dragThreshold: 100.0,
  enableShadows: true,
  itemBuilder: (context, item) {
    return Container(
      color: Colors.white,
      child: Center(child: Text(item)),
    );
  },
)
```

### With Controller (Programmatic Swipe)

```dart
final controller = AnimatedCardStackController();

AnimatedCardStack<MyData>(
  items: myItems,
  controller: controller,
  itemBuilder: (context, item) => MyCardWidget(item),
)

// Trigger a swipe programmatically
controller.swipeNext();              // Random direction
controller.swipeNext(direction: Offset(1, 0));  // Swipe right
```

### With Callbacks (Like Instagram)

```dart
AnimatedCardStack<CardData>(
  items: myCards,
  onTap: (card) {
    // Single tap action
    showDialog(...);
  },
  onDoubleTap: (card) {
    // Like functionality
    setState(() => card.isLiked = !card.isLiked);
  },
  onCardChanged: (index, card) {
    print('Now showing: ${card.title}');
  },
  itemBuilder: (context, card) => MyCardWidget(card),
)
```

### With Empty State Placeholder

```dart
AnimatedCardStack<CardData>(
  items: myCards,  // Could be empty
  placeholderBuilder: (context) => Center(
    child: Text('No cards available'),
  ),
  itemBuilder: (context, card) => MyCardWidget(card),
)
```

## API Reference

### AnimatedCardStack Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `items` | `List<T>` | required | The data source |
| `itemBuilder` | `Widget Function(BuildContext, T)` | required | Builder for card content |
| `controller` | `AnimatedCardStackController?` | null | Optional programmatic control |
| `onTap` | `void Function(T)?` | null | Called when top card is tapped |
| `onDoubleTap` | `void Function(T)?` | null | Called when top card is double-tapped |
| `onCardChanged` | `void Function(int, T)?` | null | Called when top card changes |
| `placeholderBuilder` | `WidgetBuilder?` | null | Shown when items is empty |
| `dragThreshold` | `double` | 100.0 | Distance to trigger cycle |
| `animationDuration` | `Duration` | 400ms | Base animation duration |
| `enableShadows` | `bool` | true | Toggle 3D shadow effects |
| `visibleCardCount` | `int` | 3 | Cards visible in stack |
| `cardWidth` | `double` | 300.0 | Card width |
| `cardHeight` | `double` | 400.0 | Card height |
| `reboundScale` | `double` | 0.7 | Scale during rebound |

### AnimatedCardStackController Methods

| Method | Description |
|--------|-------------|
| `swipeNext({Offset? direction})` | Triggers a swipe. Random direction if not specified. Returns `false` if < 2 items. |
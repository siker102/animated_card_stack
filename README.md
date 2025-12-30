# Animated Card Stack

A high-performance, interactive Flutter widget that renders a stack of cards with physics-based drag-and-rebound animations. Perfect for dating apps, flashcards, or any content requiring a fun, tactile way to cycle through items.

## Features

*   **Smooth Animations**: Physics-based drag callbacks and "rebound" effects.
*   **Customizable**: Control drag thresholds, animation duration, and 3D shadow intensity.
*   **Performance Focused**: Efficient builder pattern for rendering only visible cards.
*   **Fun UX**: Cards that fly off and shuffle to the bottom with momentum.

## Getting Started

### ⚠️ Important Note for Contributors

To keep the repository clean and platform-agnostic, we **do not commit** platform-specific build folders (`android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`) to version control.

**If you are cloning this repository for the first time on a new machine:**

1.  Clone the repository.
2.  Open your terminal in the project root.
3.  Run the following command to regenerate the necessary platform runners:
    ```bash
    flutter create .
    ```
4.  Run the app as normal!

## Usage

Using the `AnimatedCardStack` is simple. Just provide a list of items and a builder:

```dart
AnimatedCardStack<String>(
  items: ['Card 1', 'Card 2', 'Card 3'],
  dragThreshold: 100.0,
  enableShadows: true,
  itemBuilder: (context, item) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Text(item),
      ),
    );
  },
)
```

## Upcoming Features

*   **Controller Support**: Programmatically trigger swipes (e.g., "Next" button).
*   **Callbacks**: Listen to index changes and card interactions.
*   **Empty State**: Custom builder support for when the stack is empty.
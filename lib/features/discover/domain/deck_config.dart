/// Central configuration for the swipeable Discover deck.
library;

enum SwipeAction {
  dismiss,
  save,
}

enum SwipeDirection {
  left,
  right,
}

/// Central mapping constant deciding the swipe direction for saving trips.
///
/// Default: [SwipeDirection.left] (swipe LEFT = save, swipe RIGHT = dismiss).
///
/// Flipping this constant swaps the mapping, the overlay labels,
/// and the action button order everywhere across the application.
const SwipeDirection kSaveDirection = SwipeDirection.left;

/// Helper extensions to resolve actions, labels, and button placement dynamically
extension SwipeDirectionMapping on SwipeDirection {
  /// The action performed when swiping in this direction.
  SwipeAction get action =>
      this == kSaveDirection ? SwipeAction.save : SwipeAction.dismiss;

  /// The overlay badge label displayed during drag.
  String get overlayLabel =>
      action == SwipeAction.save ? 'SAVED' : 'SKIP';

  /// Whether this direction corresponds to saving a trip.
  bool get isSave => action == SwipeAction.save;

  /// Whether this direction corresponds to dismissing/skipping a trip.
  bool get isDismiss => action == SwipeAction.dismiss;
}

/// Whether to use a decorative notched clip path on deck cards instead of standard rounded rectangle.
const bool kUseNotchedCardClip = false;

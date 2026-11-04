import 'package:flutter/widgets.dart';

/// A [Hero] for a chat photo that always flies the bubble's thumbnail.
///
/// The thumbnail is already decoded at bubble size, so the flight never
/// waits for the full-size photo to decode.
class PhotoHero extends StatelessWidget {
  /// Creates the hero. Use the message id as [tag].
  const PhotoHero({super.key, required this.tag, required this.child});

  /// Shared by the bubble and the viewer.
  final Object tag;

  /// The photo.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Hero(tag: tag, flightShuttleBuilder: _shuttle, child: child);
  }

  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    // The chat is the page underneath the viewer, so it's the "from" side
    // when opening and the "to" side when closing.
    final chatSide = direction == HeroFlightDirection.push
        ? fromHeroContext
        : toHeroContext;
    return (chatSide.widget as Hero).child;
  }
}

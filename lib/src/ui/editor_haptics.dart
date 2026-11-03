import 'dart:async';

import 'package:flutter/services.dart';

/// Light haptic feedback for snaps, color picks and the delete target.
///
/// Does nothing when [enabled] is `false`. Platforms without haptics are
/// ignored silently.
void editorHaptic({required bool enabled}) {
  if (!enabled) return;
  unawaited(HapticFeedback.selectionClick().catchError((Object _) {}));
}

#ifndef MULTITOUCH_BRIDGE_H
#define MULTITOUCH_BRIDGE_H

typedef enum {
    GSSwipeLeft = 0,
    GSSwipeRight = 1,
    GSSwipeUp = 2,
    GSSwipeDown = 3,
} GSSwipeDirection;

typedef void (*GSSwipeCallback)(GSSwipeDirection direction, void *context);

/// Sets the finger count a swipe needs and how far (0..1 of the trackpad) the fingers must travel.
void GSMultitouchConfigure(int fingers, float threshold);

/// (Re)starts listening on every multitouch device. Safe to call again after wake or hotplug.
/// Returns the number of devices, or -1 if MultitouchSupport could not be loaded.
/// The callback runs on a MultitouchSupport thread.
int GSMultitouchStart(GSSwipeCallback callback, void *context);

/// Number of multitouch devices currently attached, or -1 if MultitouchSupport could not be loaded.
int GSMultitouchDeviceCount(void);

#endif

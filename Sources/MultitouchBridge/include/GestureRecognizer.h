#ifndef GESTURE_RECOGNIZER_H
#define GESTURE_RECOGNIZER_H

#define GS_MAX_CONTACTS 16

typedef struct {
    int identifier;
    float x, y;
} GSContact;

/// Turns trackpad frames into at most one swipe per touch. Each finger is measured from where it was
/// when the required finger count was first reached, so fingers landing at different times or briefly
/// dropping out don't restart the swipe.
typedef struct {
    int fingers;
    float threshold;
    int active;
    int armed;
    int fired;
    int poisoned;
    double lastTimestamp;
    int startCount;
    GSContact starts[GS_MAX_CONTACTS];
} GSRecognizer;

void GSRecognizerInit(GSRecognizer *recognizer, int fingers, float threshold);

/// Feeds one frame of contacts that are on the surface. Returns a GSSwipeDirection, or -1.
int GSRecognizerFeed(GSRecognizer *recognizer, const GSContact *contacts, int count, double timestamp);

#endif

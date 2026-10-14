#include "GestureRecognizer.h"
#include "MultitouchBridge.h"

#include <math.h>
#include <string.h>

/// A gap this long between frames means the previous touch ended without a final empty frame.
static const double kStaleFrameGap = 0.25;

void GSRecognizerInit(GSRecognizer *r, int fingers, float threshold) {
    memset(r, 0, sizeof(*r));
    r->fingers = fingers;
    r->threshold = threshold;
}

static void reset(GSRecognizer *r) {
    r->active = 0;
    r->armed = 0;
    r->fired = 0;
    r->poisoned = 0;
    r->startCount = 0;
}

static const GSContact *start_for(const GSRecognizer *r, int identifier) {
    for (int i = 0; i < r->startCount; i++) {
        if (r->starts[i].identifier == identifier) return &r->starts[i];
    }
    return NULL;
}

static void remember(GSRecognizer *r, const GSContact *contact) {
    if (r->startCount < GS_MAX_CONTACTS && !start_for(r, contact->identifier)) {
        r->starts[r->startCount++] = *contact;
    }
}

int GSRecognizerFeed(GSRecognizer *r, const GSContact *contacts, int count, double timestamp) {
    if (r->active && timestamp - r->lastTimestamp > kStaleFrameGap) reset(r);
    r->lastTimestamp = timestamp;

    if (count <= 0) {
        reset(r);
        return -1;
    }
    r->active = 1;

    // More fingers than asked for (a resting thumb, a five-finger pinch) is a different gesture.
    if (count > r->fingers) r->poisoned = 1;
    if (r->poisoned || r->fired) return -1;

    if (!r->armed) {
        if (count < r->fingers) return -1;
        r->armed = 1;
        r->startCount = 0;
        for (int i = 0; i < count; i++) remember(r, &contacts[i]);
        return -1;
    }

    // Tolerate one finger dropping out mid-swipe, but not a hand lifting off.
    if (count < r->fingers - 1) return -1;

    float dx = 0, dy = 0;
    int measured = 0;
    for (int i = 0; i < count; i++) {
        const GSContact *start = start_for(r, contacts[i].identifier);
        if (!start) {
            remember(r, &contacts[i]);
            continue;
        }
        dx += contacts[i].x - start->x;
        dy += contacts[i].y - start->y;
        measured++;
    }
    if (measured == 0) return -1;
    dx /= measured;
    dy /= measured;

    if (fabsf(dx) < r->threshold && fabsf(dy) < r->threshold) return -1;
    r->fired = 1;
    if (fabsf(dx) > fabsf(dy)) return dx > 0 ? GSSwipeRight : GSSwipeLeft;
    return dy > 0 ? GSSwipeUp : GSSwipeDown;
}

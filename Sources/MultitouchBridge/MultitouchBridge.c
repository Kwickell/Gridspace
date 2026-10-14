#include "MultitouchBridge.h"
#include "GestureRecognizer.h"

#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <math.h>
#include <os/lock.h>

typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTVector;

// MultitouchSupport's private contact layout, as used by every known consumer of the framework.
typedef struct {
    int frame;
    double timestamp;
    int identifier;
    int state;
    int fingerID;
    int handID;
    MTVector normalized;
    float size;
    int zero1;
    float angle;
    float majorAxis;
    float minorAxis;
    MTVector absolute;
    int zero2[2];
    float density;
} MTTouch;

typedef void *MTDeviceRef;
typedef int (*MTContactCallback)(MTDeviceRef, const MTTouch *, int, double, int);
typedef CFArrayRef (*MTDeviceCreateListFn)(void);
typedef void (*MTRegisterContactFrameCallbackFn)(MTDeviceRef, MTContactCallback);
typedef void (*MTUnregisterContactFrameCallbackFn)(MTDeviceRef, MTContactCallback);
typedef void (*MTDeviceStartFn)(MTDeviceRef, int);
typedef void (*MTDeviceStopFn)(MTDeviceRef);

// Contact states from "making touch" through "breaking touch"; hovering and lingering fingers are ignored.
enum { MTTouchStateMakeTouch = 3, MTTouchStateBreakTouch = 5 };

static struct {
    int loaded;
    MTDeviceCreateListFn createList;
    MTRegisterContactFrameCallbackFn registerCallback;
    MTUnregisterContactFrameCallbackFn unregisterCallback;
    MTDeviceStartFn start;
    MTDeviceStopFn stop;
} mt;

static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
static GSSwipeCallback swipeCallback;
static void *swipeContext;
static GSRecognizer recognizer = { .fingers = 4, .threshold = 0.1f };
static CFArrayRef devices;

static int load(void) {
    if (mt.loaded) return mt.loaded > 0;
    void *handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
    if (handle) {
        mt.createList = (MTDeviceCreateListFn)dlsym(handle, "MTDeviceCreateList");
        mt.registerCallback = (MTRegisterContactFrameCallbackFn)dlsym(handle, "MTRegisterContactFrameCallback");
        mt.unregisterCallback = (MTUnregisterContactFrameCallbackFn)dlsym(handle, "MTUnregisterContactFrameCallback");
        mt.start = (MTDeviceStartFn)dlsym(handle, "MTDeviceStart");
        mt.stop = (MTDeviceStopFn)dlsym(handle, "MTDeviceStop");
    }
    int ok = mt.createList && mt.registerCallback && mt.unregisterCallback && mt.start && mt.stop;
    mt.loaded = ok ? 1 : -1;
    return ok;
}

static int contactFrame(MTDeviceRef device, const MTTouch *touches, int count, double timestamp, int frame) {
    GSContact contacts[GS_MAX_CONTACTS];
    int n = 0;
    for (int i = 0; i < count && n < GS_MAX_CONTACTS; i++) {
        if (touches[i].state < MTTouchStateMakeTouch || touches[i].state > MTTouchStateBreakTouch) continue;
        contacts[n++] = (GSContact){ touches[i].identifier, touches[i].normalized.position.x, touches[i].normalized.position.y };
    }

    os_unfair_lock_lock(&lock);
    int direction = GSRecognizerFeed(&recognizer, contacts, n, timestamp);
    GSSwipeCallback callback = swipeCallback;
    void *context = swipeContext;
    os_unfair_lock_unlock(&lock);

    if (direction >= 0 && callback) callback((GSSwipeDirection)direction, context);
    return 0;
}

void GSMultitouchConfigure(int fingers, float threshold) {
    os_unfair_lock_lock(&lock);
    GSRecognizerInit(&recognizer, fingers, threshold);
    os_unfair_lock_unlock(&lock);
}

int GSMultitouchStart(GSSwipeCallback callback, void *context) {
    if (!load()) return -1;

    os_unfair_lock_lock(&lock);
    swipeCallback = callback;
    swipeContext = context;
    os_unfair_lock_unlock(&lock);

    if (devices) {
        for (CFIndex i = 0; i < CFArrayGetCount(devices); i++) {
            MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(devices, i);
            mt.unregisterCallback(device, contactFrame);
            mt.stop(device);
        }
        CFRelease(devices);
        devices = NULL;
    }

    devices = mt.createList();
    if (!devices) return 0;
    CFIndex n = CFArrayGetCount(devices);
    for (CFIndex i = 0; i < n; i++) {
        MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(devices, i);
        mt.registerCallback(device, contactFrame);
        mt.start(device, 0);
    }
    return (int)n;
}

int GSMultitouchDeviceCount(void) {
    if (!load()) return -1;
    CFArrayRef list = mt.createList();
    if (!list) return 0;
    int n = (int)CFArrayGetCount(list);
    CFRelease(list);
    return n;
}

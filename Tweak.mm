#import "Tweak.h"
#import <stdint.h>

static MPCMediaRemoteController *_player;
static NSInteger _lastEventCount = 0;
static uint8_t _status;
static NSTimer *_hold;
static NSTimer *_timer;
static BOOL _isOnCoolDown = YES;
static MPVolumeController *_volumeController;

#define HOLD_TIME 0.3
#define RESET_TIME 0.5

@class MPRemoteCommandStatus;
static inline void sendCommand(int cmd) { [_player sendCommand:cmd options:0 completion:^(MPRemoteCommandStatus *status){ /* GCLog(@"status: %@", status); */ }]; }
static id (* orig_init) (MPCMediaRemoteController *, SEL);
static id hook_init(MPCMediaRemoteController *self, SEL _cmd) { // Initialised late.. maybe we can force it?
	id orig = _player = orig_init(self, _cmd);
	GCLog(@"got player: %@", _player);
	return orig;
}

@class SpringBoard;
static BOOL (* orig_handlePhysicalButtonEvent) (SpringBoard *, SEL, UIPressesEvent *);
static BOOL hook_handlePhysicalButtonEvent(SpringBoard *self, SEL _cmd, UIPressesEvent *event) {
	BOOL orig = orig_handlePhysicalButtonEvent(self, _cmd, event);
	NSInteger count = _lastEventCount = event.allPresses.allObjects.count;

	GCLog(@"count: %ld", (long)count);

	if (count == 2) { // we want to look for key combos
		NSArray *allPresses = event.allPresses.allObjects;
		UIPress *press1 = allPresses[0];
		UIPress *press2 = allPresses[1];

		if (press1.force != press2.force) return orig;

		UIPressType t1 = press1.type;
		UIPressType t2 = press2.type;

		if (t1 != 102 && t1 != 103) return orig; // Guess I'll find out what those constants are some time
		if (t2 != 102 && t2 != 103) return orig; // Guess I'll find out what those constants are some time

		// Play / Pause playback
		sendCommand(2);
	}

	return orig;
}

@class SBVolumeHardwareButton;
static void handle(SBVolumeHardwareButton *, SEL, SBPressGestureRecognizer *gestureRecognizer, uint8_t, void (*orig)(SBVolumeHardwareButton *, SEL, SBPressGestureRecognizer *));
static void (* orig_volumeIncreasePress) (SBVolumeHardwareButton *, SEL, SBPressGestureRecognizer *);
static void hook_volumeIncreasePress(SBVolumeHardwareButton *self, SEL _cmd, SBPressGestureRecognizer *gestureRecognizer) {
	return handle(self, _cmd, gestureRecognizer, 0, orig_volumeIncreasePress);
}

static void (* orig_volumeDecreasePress) (SBVolumeHardwareButton *, SEL, SBPressGestureRecognizer *);
static void hook_volumeDecreasePress(SBVolumeHardwareButton *self, SEL _cmd, SBPressGestureRecognizer *gestureRecognizer) {
	return handle(self, _cmd, gestureRecognizer, 1, orig_volumeDecreasePress);
}

static void handle(SBVolumeHardwareButton *self, SEL _cmd, SBPressGestureRecognizer *gestureRecognizer, uint8_t down, void (*orig)(SBVolumeHardwareButton *, SEL, SBPressGestureRecognizer *)) {
	if (_lastEventCount == 2) // Don't do anything, if we already paused/resumed
		return orig(self, _cmd, gestureRecognizer);

	long long pressPhase = [gestureRecognizer latestPressPhase];
	if (pressPhase == 3) { // Press ended
		orig(self, _cmd, gestureRecognizer);
		_status |= (1 << down);
		[_hold invalidate];
		sendCommand(9 | (down << 1));

		_timer = [NSTimer scheduledTimerWithTimeInterval:RESET_TIME repeats:NO block:^(NSTimer * _Nonnull timer) { _status = _isOnCoolDown = 0; }];

		if (_status == 3 && !_isOnCoolDown) {
			sendCommand(4 | down); // Previous track
			_isOnCoolDown = YES;
		}
	} else {
		if (_status == down+1) return orig(self, _cmd, gestureRecognizer);

		union { // this part is hella cursed and kinda undefined behaviour, as floats aren't guaranteed to be IEEE-754
			int a;
			float b = 0.0625;
		} caster;
		caster.a ^= down << 31;
		[_volumeController adjustVolumeValue:caster.b];

		[_timer invalidate];
		_hold = [NSTimer scheduledTimerWithTimeInterval:HOLD_TIME repeats:NO block:^(NSTimer * _Nonnull timer) {
			GCLog(@"%s _volDown: %d, _volUp: %d", down ? "DOWN" : "UP" , _status & 1, _status & 2);
			if (_status == down+1) return;
			sendCommand(8 | (down << 1));
			_status = 0;
		}];
	}
}

static void __attribute__((constructor)) ctor() {
	GCLog(@"Loaded");
	_volumeController = [[objc_getClass("MPVolumeController") alloc] init];
	MSHookMessageEx(objc_getClass("MPCMediaRemoteController"), @selector(_init), (IMP)&hook_init, (IMP*)&orig_init);
	MSHookMessageEx(objc_getClass("SpringBoard"), @selector(_handlePhysicalButtonEvent:), (IMP)&hook_handlePhysicalButtonEvent, (IMP*)&orig_handlePhysicalButtonEvent);

	Class volButton = objc_getClass("SBVolumeHardwareButton");
	MSHookMessageEx(volButton, @selector(volumeIncreasePress:), (IMP)&hook_volumeIncreasePress, (IMP*)&orig_volumeIncreasePress);
	MSHookMessageEx(volButton, @selector(volumeDecreasePress:), (IMP)&hook_volumeDecreasePress, (IMP*)&orig_volumeDecreasePress);
}
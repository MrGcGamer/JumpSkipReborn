#import "Tweak.hh"

static MPCMediaRemoteController *_player;
static NSInteger _lastEventCount = 0;
static BOOL _volUp = NO;
static BOOL _volDown = NO;
static NSTimer *_hold;
static NSTimer *_timer;
static BOOL _isOnCoolDown = YES;

@class MPRemoteCommandStatus;
static inline void sendCommand(int cmd) { [_player sendCommand:cmd options:0 completion:^(MPRemoteCommandStatus *status){ /* NSLog(@"GC - [JumpSkipReborn] status: %@", status); */ }]; }
static id (* orig_init) (MPCMediaRemoteController *, SEL);
static id hook_init(MPCMediaRemoteController *self, SEL _cmd) {
	id orig = _player = orig_init(self, _cmd);
	NSLog(@"GC - [JumpSkipReborn] got player: %@", _player);
	return orig;
}

@class SpringBoard;
static BOOL (* orig_handlePhysicalButtonEvent) (SpringBoard *, SEL, UIPressesEvent *);
static BOOL hook_handlePhysicalButtonEvent(SpringBoard *self, SEL _cmd, UIPressesEvent *event) {
	BOOL orig = orig_handlePhysicalButtonEvent(self, _cmd, event);
	NSInteger count = _lastEventCount = event.allPresses.allObjects.count;

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
static void (* orig_volumeIncreasePress) (SBVolumeHardwareButton *, SEL, SBPressGestureRecognizer *);
static void hook_volumeIncreasePress(SBVolumeHardwareButton *self, SEL _cmd, SBPressGestureRecognizer *gestureRecognizer) {
	if (_lastEventCount == 2) // Don't do anything, if we already paused/resumed
		return orig_volumeIncreasePress(self, _cmd, gestureRecognizer);

	long long pressPhase = [gestureRecognizer latestPressPhase];
	if (pressPhase == 3) {
		orig_volumeIncreasePress(self, _cmd, gestureRecognizer);
		_volUp = YES;
		[_hold invalidate];
		_hold = nil;
		sendCommand(9);

		_timer = [NSTimer scheduledTimerWithTimeInterval:0.4 repeats:NO block:^(NSTimer * _Nonnull timer) { _volDown = _volUp = _isOnCoolDown = NO; }];

		if (_volDown && _volUp) {
			if (!_isOnCoolDown) {
				sendCommand(4); // Next track
				_isOnCoolDown = YES;
			}

			if ([[objc_getClass("SBMediaController") sharedInstance] isPlaying]) {
				return sendCommand(0);
			}
		}
	} else {
		if (!_volDown || _volUp) return orig_volumeIncreasePress(self, _cmd, gestureRecognizer);
		// [[[objc_getClass("SBUIController") sharedInstance] valueForKey:@"_volumeControl"] increaseVolume];
		[_timer invalidate];
		_timer = nil;

		_hold = [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:NO block:^(NSTimer * _Nonnull timer) {
			if (_volUp || !_volDown) return;
			sendCommand(8);
			_volDown = _volUp = NO;
		}];
	}
}
static void (* orig_volumeDecreasePress) (SBVolumeHardwareButton *, SEL, SBPressGestureRecognizer *);
static void hook_volumeDecreasePress(SBVolumeHardwareButton *self, SEL _cmd, SBPressGestureRecognizer *gestureRecognizer) {
	if (_lastEventCount == 2) // Don't do anything, if we already paused/resumed
		return orig_volumeDecreasePress(self, _cmd, gestureRecognizer);

	long long pressPhase = [gestureRecognizer latestPressPhase];
	if (pressPhase == 3) {
		orig_volumeDecreasePress(self, _cmd, gestureRecognizer);
		_volDown = YES;
		[_hold invalidate];
		_hold = nil;
		sendCommand(11);

		_timer = [NSTimer scheduledTimerWithTimeInterval:0.4 repeats:NO block:^(NSTimer * _Nonnull timer) { _volDown = _volUp = _isOnCoolDown = NO; }];

		if (_volDown && _volUp) {
			if (!_isOnCoolDown) {
				sendCommand(5); // Previous track
				_isOnCoolDown = YES;
			}

			if ([[objc_getClass("SBMediaController") sharedInstance] isPlaying])
				return sendCommand(0);
		}
	} else {
		if (_volDown || !_volUp) return orig_volumeDecreasePress(self, _cmd, gestureRecognizer);
		// [[[objc_getClass("SBUIController") sharedInstance] valueForKey:@"_volumeControl"] decreaseVolume];
		[_timer invalidate];
		_timer = nil;

		_hold = [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:NO block:^(NSTimer * _Nonnull timer) {
			if (!_volUp || _volDown) return;
			sendCommand(10);
			_volDown = _volUp = NO;
		}];
	}
}


static void __attribute__((constructor)) ctor() {
	NSLog(@"GC - [JumpSkipReborn] Loaded");
	MSHookMessageEx(objc_getClass("MPCMediaRemoteController"), @selector(_init), (IMP)&hook_init, (IMP*)&orig_init);
	MSHookMessageEx(objc_getClass("SpringBoard"), @selector(_handlePhysicalButtonEvent:), (IMP)&hook_handlePhysicalButtonEvent, (IMP*)&orig_handlePhysicalButtonEvent);

	Class volButton = objc_getClass("SBVolumeHardwareButton");
	MSHookMessageEx(volButton, @selector(volumeIncreasePress:), (IMP)&hook_volumeIncreasePress, (IMP*)&orig_volumeIncreasePress);
	MSHookMessageEx(volButton, @selector(volumeDecreasePress:), (IMP)&hook_volumeDecreasePress, (IMP*)&orig_volumeDecreasePress);

}
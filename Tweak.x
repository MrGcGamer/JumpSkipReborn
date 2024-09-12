#import "Tweak.h"

static MPCMediaRemoteController *_player;
static NSInteger _lastEventCount = 0;
static BOOL _volUp = NO;
static BOOL _volDown = NO;
static NSTimer *_hold;
static NSTimer *_timer;
static BOOL _isOnCoolDown = YES;
static MPVolumeController *_volumeController;

#define HOLD_TIME 0.3
#define RESET_TIME 0.5

@class MPRemoteCommandStatus;
static inline void sendCommand(int cmd) { [_player sendCommand:cmd options:0 completion:^(MPRemoteCommandStatus *status){ /* GCLog(@"status: %@", status); */ }]; }
%hook MPCMediaRemoteController
- (id)_init {
	id orig = _player = %orig;
	GCLog(@"got player: %@", _player);
	return orig;
}
%end // MPCMediaRemoteController

%hook SpringBoard
- (BOOL)_handlePhysicalButtonEvent:(UIPressesEvent *)event {
	BOOL orig = %orig;

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
%end // SpringBoard

%hook SBVolumeHardwareButton
- (void)volumeIncreasePress:(SBPressGestureRecognizer *)gestureRecognizer {
	if (_lastEventCount == 2) // Don't do anything, if we already paused/resumed
		return %orig;

	long long pressPhase = [gestureRecognizer latestPressPhase];
	if (pressPhase == 3) {
		%orig;
		_volUp = YES;
		[_hold invalidate];
		sendCommand(9);

		_timer = [NSTimer scheduledTimerWithTimeInterval:RESET_TIME repeats:NO block:^(NSTimer * _Nonnull timer) { _volDown = _volUp = _isOnCoolDown = NO; }];

		if (_volDown && _volUp && !_isOnCoolDown) {
			sendCommand(4); // Next track
			_isOnCoolDown = YES;
		}
	} else {
		if (!_volDown || _volUp) return %orig;
		[_volumeController adjustVolumeValue:0.0625];

		[_timer invalidate];
		_hold = [NSTimer scheduledTimerWithTimeInterval:HOLD_TIME repeats:NO block:^(NSTimer * _Nonnull timer) {
			GCLog(@"UP _volDown: %d, _volUp: %d", _volDown, _volUp);
			if (_volUp || !_volDown) return %orig;
			sendCommand(8);
			_volDown = _volUp = NO;
		}];
	}
}
- (void)volumeDecreasePress:(SBPressGestureRecognizer *)gestureRecognizer {
	if (_lastEventCount == 2) // Don't do anything, if we already paused/resumed
		return %orig;

	long long pressPhase = [gestureRecognizer latestPressPhase];
	if (pressPhase == 3) {
		%orig;
		_volDown = YES;
		[_hold invalidate];
		sendCommand(11);

		_timer = [NSTimer scheduledTimerWithTimeInterval:RESET_TIME repeats:NO block:^(NSTimer * _Nonnull timer) { _volDown = _volUp = _isOnCoolDown = NO; }];

		if (_volDown && _volUp && !_isOnCoolDown) {
			sendCommand(5); // Previous track
			_isOnCoolDown = YES;
		}
	} else {
		if (_volDown || !_volUp) return %orig;
		[_volumeController adjustVolumeValue:-0.0625];

		[_timer invalidate];
		_hold = [NSTimer scheduledTimerWithTimeInterval:HOLD_TIME repeats:NO block:^(NSTimer * _Nonnull timer) {
			GCLog(@"DOWN _volDown: %d, _volUp: %d", _volDown, _volUp);
			if (!_volUp || _volDown) return %orig;
			sendCommand(10);
			_volDown = _volUp = NO;
		}];
	}
}
%end // SBVolumeHardwareButton

%ctor {
	GCLog(@"Loaded");
	_volumeController = [[objc_getClass("MPVolumeController") alloc] init];
}
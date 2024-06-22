#import <substrate.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h> // already importet by substrate.h...

#ifdef DEBUG
#define __FILENAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)
#define GCLog(fmt, ...) do {NSLog((@"GC - [JumpSkipReborn] - [%s:%d]: " fmt), __FILENAME__, __LINE__, ##__VA_ARGS__);} while(0)
#else
#define GCLog(...)
#endif

@interface MPCMediaRemoteController : NSObject
-(id)_init;
-(void)sendCommand:(unsigned)arg1 options:(id)arg2 completion:(/*^block*/id)arg3;
@end

@interface SBPressGestureRecognizer : UIGestureRecognizer
-(long long)latestPressPhase;
@end

@interface SBVolumeControl : NSObject
-(void)increaseVolume;
-(void)decreaseVolume;
@end

@interface SBUIController : NSObject {
	SBVolumeControl* _volumeControl;
}
+(id)sharedInstance;
@end

@interface SBMediaController : NSObject
+(instancetype)sharedInstance;
-(BOOL)isPlaying;
@end
#include <UIKit/UIGestureRecognizer.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/objc.h>
#import <substrate.h>


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
#import <Foundation/Foundation.h>
@class PlayerState;

typedef NS_ENUM(NSInteger, PlaybackCommand) {
    PlaybackCommandPlayPause,
    PlaybackCommandNext,
    PlaybackCommandPrevious
};

@interface SafariBridge : NSObject
- (PlayerState *)fetchState;
- (void)sendCommand:(PlaybackCommand)command;
- (void)seekToProgress:(double)progress;
@end

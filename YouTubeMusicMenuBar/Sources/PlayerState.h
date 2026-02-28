#import <Foundation/Foundation.h>

@interface PlayerState : NSObject
@property (nonatomic, assign) BOOL foundTab;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *albumArtURL;
@property (nonatomic, assign) double currentSeconds;
@property (nonatomic, assign) double durationSeconds;
@property (nonatomic, copy) NSString *lyrics;

+ (instancetype)emptyState;
- (NSString *)statusText;
- (double)progress;
@end

#import "PlayerState.h"

@implementation PlayerState

+ (instancetype)emptyState {
    PlayerState *state = [[PlayerState alloc] init];
    state.foundTab = NO;
    state.isPlaying = NO;
    state.title = @"";
    state.artist = @"";
    state.albumArtURL = @"";
    state.currentSeconds = 0;
    state.durationSeconds = 0;
    state.lyrics = @"";
    return state;
}

- (NSString *)statusText {
    if (self.artist.length == 0 && self.title.length == 0) {
        return @"";
    }
    if (self.artist.length == 0) {
        return self.title;
    }
    if (self.title.length == 0) {
        return self.artist;
    }
    return [NSString stringWithFormat:@"%@ - %@", self.artist, self.title];
}

- (double)progress {
    if (self.durationSeconds <= 0) {
        return 0;
    }
    double value = self.currentSeconds / self.durationSeconds;
    if (value < 0) {
        return 0;
    }
    if (value > 1) {
        return 1;
    }
    return value;
}

@end

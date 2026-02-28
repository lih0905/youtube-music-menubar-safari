#import "PopoverViewController.h"
#import "SafariBridge.h"
#import "PlayerState.h"

@interface PopoverViewController ()
@property (nonatomic, strong) SafariBridge *bridge;
@property (nonatomic, strong) NSImageView *albumImageView;
@property (nonatomic, strong) NSSlider *progressSlider;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *artistLabel;
@property (nonatomic, strong) NSTextView *lyricsTextView;
@property (nonatomic, strong) NSButton *prevButton;
@property (nonatomic, strong) NSButton *playPauseButton;
@property (nonatomic, strong) NSButton *nextButton;
@property (nonatomic, assign) BOOL isUserDraggingSlider;
@property (nonatomic, copy) NSString *lastAlbumArtURL;
@end

@implementation PopoverViewController

- (instancetype)initWithBridge:(SafariBridge *)bridge {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _bridge = bridge;
    }
    return self;
}

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 380, 520)];
    [self setupUI];
}

- (void)updateWithState:(PlayerState *)state {
    self.titleLabel.stringValue = state.title.length > 0 ? state.title : @"Not Playing";
    self.artistLabel.stringValue = state.artist ?: @"";
    if (!self.isUserDraggingSlider) {
        self.progressSlider.doubleValue = [state progress] * 100.0;
    }

    if (state.lyrics.length > 0) {
        self.lyricsTextView.string = state.lyrics;
    } else {
        self.lyricsTextView.string = @"가사를 불러오지 못했습니다. YouTube Music 가사 탭을 열어두면 인식률이 올라갑니다.";
    }

    [self updatePlaybackIconsForPlaying:state.isPlaying];

    [self loadAlbumArt:state.albumArtURL];
}

- (void)setupUI {
    NSStackView *root = [[NSStackView alloc] initWithFrame:self.view.bounds];
    root.translatesAutoresizingMaskIntoConstraints = NO;
    root.orientation = NSUserInterfaceLayoutOrientationVertical;
    root.spacing = 10;
    root.edgeInsets = NSEdgeInsetsMake(14, 14, 14, 14);

    self.albumImageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 180, 180)];
    self.albumImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.albumImageView.imageScaling = NSImageScaleAxesIndependently;
    self.albumImageView.wantsLayer = YES;
    self.albumImageView.layer.cornerRadius = 8;
    self.albumImageView.layer.masksToBounds = YES;
    self.albumImageView.image = [NSImage imageWithSystemSymbolName:@"music.note" accessibilityDescription:nil];

    NSView *albumWrap = [[NSView alloc] init];
    albumWrap.translatesAutoresizingMaskIntoConstraints = NO;
    [albumWrap addSubview:self.albumImageView];
    [NSLayoutConstraint activateConstraints:@[
        [self.albumImageView.centerXAnchor constraintEqualToAnchor:albumWrap.centerXAnchor],
        [self.albumImageView.topAnchor constraintEqualToAnchor:albumWrap.topAnchor],
        [self.albumImageView.bottomAnchor constraintEqualToAnchor:albumWrap.bottomAnchor],
        [self.albumImageView.widthAnchor constraintEqualToConstant:180],
        [self.albumImageView.heightAnchor constraintEqualToConstant:180]
    ]];

    self.titleLabel = [NSTextField labelWithString:@""];
    self.titleLabel.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    self.artistLabel = [NSTextField labelWithString:@""];
    self.artistLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    self.artistLabel.textColor = [NSColor secondaryLabelColor];

    self.progressSlider = [[NSSlider alloc] init];
    self.progressSlider.minValue = 0;
    self.progressSlider.maxValue = 100;
    self.progressSlider.doubleValue = 0;
    self.progressSlider.continuous = YES;
    self.progressSlider.target = self;
    self.progressSlider.action = @selector(onSeekSliderChanged:);

    NSStackView *controls = [[NSStackView alloc] init];
    controls.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    controls.spacing = 16;
    controls.distribution = NSStackViewDistributionFillEqually;

    self.prevButton = [self makeIconButton:@"backward.fill"
                              fallbackTitle:@"이전"
                                     action:@selector(onPrevious)];
    self.playPauseButton = [self makeIconButton:@"play.fill"
                                   fallbackTitle:@"재생"
                                          action:@selector(onPlayPause)];
    self.nextButton = [self makeIconButton:@"forward.fill"
                              fallbackTitle:@"다음"
                                     action:@selector(onNext)];

    [controls addArrangedSubview:self.prevButton];
    [controls addArrangedSubview:self.playPauseButton];
    [controls addArrangedSubview:self.nextButton];

    NSTextField *lyricsTitle = [NSTextField labelWithString:@"가사"];
    lyricsTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];

    self.lyricsTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 340, 170)];
    self.lyricsTextView.editable = NO;
    self.lyricsTextView.font = [NSFont systemFontOfSize:13];
    self.lyricsTextView.string = @"가사를 불러오는 중...";

    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = self.lyricsTextView;

    [NSLayoutConstraint activateConstraints:@[
        [scroll.heightAnchor constraintEqualToConstant:170]
    ]];

    NSButton *quit = [self makeButton:@"앱 종료" action:@selector(onQuit)];

    [root addArrangedSubview:albumWrap];
    [root addArrangedSubview:self.titleLabel];
    [root addArrangedSubview:self.artistLabel];
    [root addArrangedSubview:self.progressSlider];
    [root addArrangedSubview:controls];
    [root addArrangedSubview:lyricsTitle];
    [root addArrangedSubview:scroll];
    [root addArrangedSubview:quit];

    [self.view addSubview:root];

    [NSLayoutConstraint activateConstraints:@[
        [root.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [root.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [root.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [root.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (NSButton *)makeButton:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.bezelStyle = NSBezelStyleTexturedRounded;
    return button;
}

- (NSButton *)makeIconButton:(NSString *)symbolName fallbackTitle:(NSString *)fallbackTitle action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:@"" target:self action:action];
    button.bezelStyle = NSBezelStyleRegularSquare;
    button.bordered = YES;
    button.translatesAutoresizingMaskIntoConstraints = NO;

    NSImage *image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:fallbackTitle];
    if (image) {
        image.size = NSMakeSize(16, 16);
        button.image = image;
        button.imagePosition = NSImageOnly;
        button.title = @"";
    } else {
        button.title = fallbackTitle;
    }

    button.toolTip = fallbackTitle;
    [button.heightAnchor constraintEqualToConstant:56].active = YES;
    [button.widthAnchor constraintEqualToConstant:72].active = YES;
    return button;
}

- (void)updatePlaybackIconsForPlaying:(BOOL)isPlaying {
    NSString *symbol = isPlaying ? @"pause.fill" : @"play.fill";
    NSString *title = isPlaying ? @"일시정지" : @"재생";
    NSImage *image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:title];
    if (image) {
        image.size = NSMakeSize(16, 16);
        self.playPauseButton.image = image;
        self.playPauseButton.imagePosition = NSImageOnly;
        self.playPauseButton.title = @"";
    } else {
        self.playPauseButton.title = title;
    }
    self.playPauseButton.toolTip = title;
}

- (void)loadAlbumArt:(NSString *)urlString {
    NSString *normalizedURL = urlString ?: @"";
    if ([self.lastAlbumArtURL isEqualToString:normalizedURL]) {
        return;
    }
    self.lastAlbumArtURL = normalizedURL;

    if (normalizedURL.length == 0) {
        self.albumImageView.image = [NSImage imageWithSystemSymbolName:@"music.note" accessibilityDescription:nil];
        return;
    }
    NSURL *url = [NSURL URLWithString:normalizedURL];
    if (!url) {
        return;
    }
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error || !data) {
            return;
        }
        NSImage *image = [[NSImage alloc] initWithData:data];
        if (!image) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.albumImageView.image = image;
        });
    }] resume];
}

- (void)onPrevious {
    [self.bridge sendCommand:PlaybackCommandPrevious];
    [self refreshSoon];
}

- (void)onPlayPause {
    [self.bridge sendCommand:PlaybackCommandPlayPause];
    [self refreshSoon];
}

- (void)onNext {
    [self.bridge sendCommand:PlaybackCommandNext];
    [self refreshSoon];
}

- (void)onQuit {
    [NSApplication.sharedApplication terminate:nil];
}

- (void)onSeekSliderChanged:(NSSlider *)sender {
    self.isUserDraggingSlider = YES;
    double progress = sender.doubleValue / 100.0;
    [self.bridge seekToProgress:progress];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        self.isUserDraggingSlider = NO;
        [self refreshSoon];
    });
}

- (void)refreshSoon {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(120 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            PlayerState *state = [self.bridge fetchState];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateWithState:state];
            });
        });
    });
}

@end

#import "SafariBridge.h"
#import "PlayerState.h"
#import <Cocoa/Cocoa.h>

@implementation SafariBridge

- (NSString *)runJavaScriptOnYouTubeMusicTab:(NSString *)js {
    NSString *escaped = [[js stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
                         stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];

    NSString *source = [NSString stringWithFormat:
                        @"tell application \"Safari\"\n"
                        "    if not running then return \"__ERR__NO_SAFARI__\"\n"
                        "    repeat with w in windows\n"
                        "        repeat with t in tabs of w\n"
                        "            set tabURL to URL of t\n"
                        "            if tabURL starts with \"https://music.youtube.com\" then\n"
                        "                try\n"
                        "                    set current tab of w to t\n"
                        "                end try\n"
                        "                try\n"
                        "                    return do JavaScript \"%@\" in t\n"
                        "                on error errMsg number errNum\n"
                        "                    return \"__ERR__\" & (errNum as text) & \":\" & errMsg\n"
                        "                end try\n"
                        "            end if\n"
                        "        end repeat\n"
                        "    end repeat\n"
                        "    return \"__ERR__NO_TAB__\"\n"
                        "end tell\n", escaped];

    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
    NSDictionary *error = nil;
    NSAppleEventDescriptor *result = [script executeAndReturnError:&error];
    if (error || !result.stringValue) {
        NSLog(@"[SafariBridge] runJavaScriptOnYouTubeMusicTab failed: %@", error);
        return nil;
    }
    return result.stringValue;
}

- (PlayerState *)fetchState {
    NSString *scriptSource =
    @"tell application \"Safari\"\n"
    "    if not running then return \"NO_TAB\"\n"
    "    set targetTab to missing value\n"
    "    repeat with w in windows\n"
    "        repeat with t in tabs of w\n"
    "            set tabURL to URL of t\n"
    "            if tabURL starts with \"https://music.youtube.com\" then\n"
    "                set targetTab to t\n"
    "                exit repeat\n"
    "            end if\n"
    "        end repeat\n"
    "        if targetTab is not missing value then exit repeat\n"
    "    end repeat\n"
    "    if targetTab is missing value then return \"NO_TAB\"\n"
    "\n"
    "    set tabName to name of targetTab\n"
    "    set tabAudible to false\n"
    "    try\n"
    "        set tabAudible to (audible of targetTab)\n"
    "    end try\n"
    "\n"
    "    set titleText to \"\"\n"
    "    set artistText to \"\"\n"
    "    set albumArt to \"\"\n"
    "    set currentSec to \"0\"\n"
    "    set durationSec to \"0\"\n"
    "    set isPlayingText to \"0\"\n"
    "    set lyricsText to \"\"\n"
    "\n"
    "    try\n"
    "        set titleText to do JavaScript \"(()=>{ const m=(navigator.mediaSession&&navigator.mediaSession.metadata)?navigator.mediaSession.metadata:null; if(m&&m.title) return String(m.title).trim(); const n=document.querySelector('ytmusic-player-bar .title'); return n?String(n.textContent||'').trim():''; })()\" in targetTab\n"
    "    end try\n"
    "\n"
    "    try\n"
    "        set artistText to do JavaScript \"(()=>{ const m=(navigator.mediaSession&&navigator.mediaSession.metadata)?navigator.mediaSession.metadata:null; if(m&&m.artist) return String(m.artist).trim(); const n=document.querySelector('ytmusic-player-bar .byline'); if(!n) return ''; return String(n.textContent||'').split('•')[0].trim(); })()\" in targetTab\n"
    "    end try\n"
    "\n"
    "    try\n"
    "        set albumArt to do JavaScript \"(()=>{ const m=(navigator.mediaSession&&navigator.mediaSession.metadata)?navigator.mediaSession.metadata:null; if(m&&m.artwork&&m.artwork.length){ const x=m.artwork[m.artwork.length-1]; if(x&&x.src) return String(x.src); } const i=document.querySelector('ytmusic-player-bar img.image')||document.querySelector('ytmusic-player-bar #song-image img'); return i&&i.src?String(i.src):''; })()\" in targetTab\n"
    "    end try\n"
    "\n"
    "    try\n"
    "        set currentSec to do JavaScript \"(()=>{ const v=document.querySelector('video'); if(!v) return '0'; return String(Number.isFinite(v.currentTime)?Number(v.currentTime):0); })()\" in targetTab\n"
    "    end try\n"
    "\n"
    "    try\n"
    "        set durationSec to do JavaScript \"(()=>{ const v=document.querySelector('video'); if(!v) return '0'; return String(Number.isFinite(v.duration)?Number(v.duration):0); })()\" in targetTab\n"
    "    end try\n"
    "\n"
    "    try\n"
    "        set isPlayingText to do JavaScript \"(()=>{ const v=document.querySelector('video'); return (v && !v.paused) ? '1' : '0'; })()\" in targetTab\n"
    "    end try\n"
    "\n"
    "    try\n"
    "        set lyricsText to do JavaScript \"(()=>{ const pick=()=>document.querySelector('#lyrics #description')||document.querySelector('ytmusic-player-page #lyrics #description')||document.querySelector('ytmusic-tab-renderer[tab-id=\\\"MUSIC_PAGE_TYPE_TRACK_LYRICS\\\"] #description')||document.querySelector('ytmusic-tab-renderer[tab-id=\\\"lyrics\\\"] #description')||document.querySelector('ytmusic-description-shelf-renderer #description'); let n=pick(); if(!n){ const tabs=Array.from(document.querySelectorAll('ytmusic-player-page tp-yt-paper-tab, ytmusic-player-page .tabs tp-yt-paper-tab, ytmusic-player-page [role=\\\"tab\\\"]')); const lyricTab=tabs.find(x=>{const s=(x.innerText||x.textContent||'').trim().toLowerCase(); return s.includes('lyric')||s.includes('가사');}); if(lyricTab) lyricTab.click(); n=pick(); } if(!n) return ''; const s=String(n.innerText||n.textContent||'').trim(); return s.length>12000?s.slice(0,12000):s; })()\" in targetTab\n"
    "    end try\n"
    "\n"
    "    set titleText to my clean(titleText)\n"
    "    set artistText to my clean(artistText)\n"
    "    set albumArt to my clean(albumArt)\n"
    "    set lyricsText to my clean(lyricsText)\n"
    "    set tabName to my clean(tabName)\n"
    "\n"
    "    return titleText & \"|||\" & artistText & \"|||\" & albumArt & \"|||\" & currentSec & \"|||\" & durationSec & \"|||\" & isPlayingText & \"|||\" & lyricsText & \"|||\" & tabName & \"|||\" & (tabAudible as string)\n"
    "end tell\n"
    "\n"
    "on clean(v)\n"
    "    set s to (v as text)\n"
    "    set s to my repl(\"|||\", \" \", s)\n"
    "    set s to my repl(return, \"\\n\", s)\n"
    "    set s to my repl(linefeed, \"\\n\", s)\n"
    "    return s\n"
    "end clean\n"
    "\n"
    "on repl(f, r, t)\n"
    "    set AppleScript's text item delimiters to f\n"
    "    set arr to every text item of t\n"
    "    set AppleScript's text item delimiters to r\n"
    "    set outText to arr as text\n"
    "    set AppleScript's text item delimiters to \"\"\n"
    "    return outText\n"
    "end repl\n";

    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptSource];
    if (!appleScript) {
        return [PlayerState emptyState];
    }

    NSDictionary *error = nil;
    NSAppleEventDescriptor *result = [appleScript executeAndReturnError:&error];
    if (error || !result.stringValue) {
        NSLog(@"[SafariBridge] fetch failed: %@", error);
        return [PlayerState emptyState];
    }

    NSString *raw = result.stringValue;
    if ([raw isEqualToString:@"NO_TAB"]) {
        return [PlayerState emptyState];
    }

    NSArray<NSString *> *parts = [raw componentsSeparatedByString:@"|||"];
    PlayerState *state = [PlayerState emptyState];
    state.foundTab = YES;

    state.title = parts.count > 0 ? [self cleanedTrackText:parts[0]] : @"";
    state.artist = parts.count > 1 ? [self cleanedTrackText:parts[1]] : @"";
    state.albumArtURL = parts.count > 2 ? parts[2] : @"";
    state.currentSeconds = parts.count > 3 ? [parts[3] doubleValue] : 0;
    state.durationSeconds = parts.count > 4 ? [parts[4] doubleValue] : 0;
    state.isPlaying = (parts.count > 5 && [parts[5] isEqualToString:@"1"]);
    state.lyrics = parts.count > 6 ? [parts[6] stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"] : @"";

    NSString *tabName = parts.count > 7 ? parts[7] : @"";
    BOOL tabAudible = (parts.count > 8 && [[parts[8] lowercaseString] isEqualToString:@"true"]);

    [self normalizeState:state tabName:tabName];

    (void)tabAudible;

    return state;
}

- (void)normalizeState:(PlayerState *)state tabName:(NSString *)tabName {
    state.title = [self cleanedTrackText:state.title];
    state.artist = [self cleanedTrackText:state.artist];

    if (state.title.length == 0 && tabName.length > 0) {
        NSString *cleanTab = [self cleanedTrackText:tabName];
        NSRange sep = [cleanTab rangeOfString:@" - "];
        if (sep.location != NSNotFound) {
            NSString *left = [self cleanedTrackText:[cleanTab substringToIndex:sep.location]];
            NSString *right = [self cleanedTrackText:[cleanTab substringFromIndex:(sep.location + sep.length)]];
            if (left.length > 0 && right.length > 0) {
                state.artist = left;
                state.title = right;
                return;
            }
        }
        state.title = cleanTab;
    }
}

- (NSString *)cleanedTrackText:(NSString *)text {
    if (text.length == 0) {
        return @"";
    }

    NSString *s = [text stringByReplacingOccurrencesOfString:@"YouTube Music" withString:@""];
    s = [s stringByReplacingOccurrencesOfString:@" - YouTube Music" withString:@""];

    NSRange pipe = [s rangeOfString:@"|"];
    if (pipe.location != NSNotFound) {
        s = [s substringToIndex:pipe.location];
    }

    while ([s hasSuffix:@"-"] || [s hasSuffix:@"|"] || [s hasSuffix:@":"] || [s hasSuffix:@"•"]) {
        s = [s substringToIndex:(s.length - 1)];
        s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (s.length == 0) {
            break;
        }
    }

    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return s;
}

- (void)sendCommand:(PlaybackCommand)command {
    NSString *jsAction = @"";
    switch (command) {
        case PlaybackCommandPlayPause:
            jsAction = @"(()=>{ const sels=['#play-pause-button','ytmusic-player-bar tp-yt-paper-icon-button.play-pause-button','ytmusic-player-bar .play-pause-button']; for (const s of sels){ const b=document.querySelector(s); if(b){ b.click(); return '1'; } } const v=document.querySelector('video'); if(v){ if(v.paused){ v.play(); } else { v.pause(); } return '1'; } return '0'; })();";
            break;
        case PlaybackCommandNext:
            jsAction = @"(()=>{ const sels=['#next-button','ytmusic-player-bar tp-yt-paper-icon-button.next-button','ytmusic-player-bar .next-button','button[aria-label*=\\\"Next\\\"]','button[title*=\\\"Next\\\"]','button[aria-label*=\\\"다음\\\"]','button[title*=\\\"다음\\\"]']; for (const s of sels){ const b=document.querySelector(s); if(b){ b.click(); return '1'; } } return '0'; })();";
            break;
        case PlaybackCommandPrevious:
            jsAction = @"(()=>{ const sels=['#previous-button','ytmusic-player-bar tp-yt-paper-icon-button.previous-button','ytmusic-player-bar .previous-button','button[aria-label*=\\\"Previous\\\"]','button[title*=\\\"Previous\\\"]','button[aria-label*=\\\"이전\\\"]','button[title*=\\\"이전\\\"]']; for (const s of sels){ const b=document.querySelector(s); if(b){ b.click(); return '1'; } } return '0'; })();";
            break;
    }

    NSString *result = [self runJavaScriptOnYouTubeMusicTab:jsAction];
    if (!result || [result hasPrefix:@"__ERR__"] || ![result isEqualToString:@"1"]) {
        NSLog(@"[SafariBridge] command failed or no-op: %@", result);
    }
}

- (void)seekToProgress:(double)progress {
    if (progress < 0) {
        progress = 0;
    } else if (progress > 1) {
        progress = 1;
    }

    NSString *jsAction = [NSString stringWithFormat:
                          @"(()=>{ const v=document.querySelector('video'); if(!v || !Number.isFinite(v.duration) || v.duration<=0) return '0'; const target=%f*v.duration; v.currentTime=target; try{v.dispatchEvent(new Event('timeupdate'));}catch(e){} return '1'; })();",
                          progress];

    NSString *result = [self runJavaScriptOnYouTubeMusicTab:jsAction];
    if (!result || [result hasPrefix:@"__ERR__"] || ![result isEqualToString:@"1"]) {
        NSLog(@"[SafariBridge] seek failed or no-op: %@", result);
    }
}

@end

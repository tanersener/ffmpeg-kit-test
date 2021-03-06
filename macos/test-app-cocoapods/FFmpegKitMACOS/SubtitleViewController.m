/*
 * Copyright (c) 2018-2021 Taner Sener
 *
 * This file is part of FFmpegKitTest.
 *
 * FFmpegKitTest is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * FFmpegKitTest is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with FFmpegKitTest.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <AVFoundation/AVFoundation.h>
#include <AVKit/AVKit.h>
#include <ffmpegkit/FFmpegKit.h>
#include "SubtitleViewController.h"
#include "ProgressIndicator.h"
#include "Video.h"

typedef enum {
    IdleState = 1,
    CreatingState = 2,
    BurningState = 3
} UITestState;

@interface SubtitleViewController ()

@property (strong) IBOutlet NSButton *burnSubtitlesButton;
@property (strong) IBOutlet AVPlayerView *videoPlayerFrame;

@end

@implementation SubtitleViewController {

    // Video player references
    AVQueuePlayer *player;

    ProgressIndicator *indicator;

    Statistics *statistics;

    UITestState state;

    long sessionId;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // STYLE UPDATE
    [Util applyButtonStyle: self.burnSubtitlesButton];
    [Util applyVideoPlayerFrameStyle: self.videoPlayerFrame];

    // VIDEO PLAYER INIT
    player = [[AVQueuePlayer alloc] init];
    self.videoPlayerFrame.player = player;

    indicator = [[ProgressIndicator alloc] init];
    statistics = nil;

    state = IdleState;
    
    sessionId = 0;

    addUIAction(^{
        [self setActive];
    });
}

- (void)enableLogCallback {
    [FFmpegKitConfig enableLogCallback:^(Log* log){
        NSLog(@"%@", [log getMessage]);
    }];
}

- (void)enableStatisticsCallback {
    [FFmpegKitConfig enableStatisticsCallback:^(Statistics *statistics){
        addUIAction(^{
            self->statistics = statistics;
            [self updateProgressDialog];
        });
    }];
}

- (IBAction)burnSubtitles:(id)sender {
    NSString *resourceFolder = [[NSBundle mainBundle] resourcePath];
    NSString *image1 = [resourceFolder stringByAppendingPathComponent: @"machupicchu.jpg"];
    NSString *image2 = [resourceFolder stringByAppendingPathComponent: @"pyramid.jpg"];
    NSString *image3 = [resourceFolder stringByAppendingPathComponent: @"stonehenge.jpg"];
    NSString *subtitle = [self getSubtitlePath];
    NSString *videoFile = [self getVideoPath];
    NSString *videoWithSubtitlesFile = [self getVideoWithSubtitlesPath];
    
    if (player != nil) {
        [player removeAllItems];
    }

    NSLog(@"Testing SUBTITLE burning\n");

    [self showProgressDialog:@"Creating video\n\n"];

    NSString* ffmpegCommand = [Video generateVideoEncodeScript:image1:image2:image3:videoFile:@"mpeg4":@""];
    
    NSLog(@"FFmpeg process started with arguments\n'%@'.\n", ffmpegCommand);
    
    self->state = CreatingState;
    
    sessionId = [[FFmpegKit executeAsync:ffmpegCommand withExecuteCallback:^(id<Session> session) {

        NSLog(@"FFmpeg process exited with state %@ and rc %@.%@", [FFmpegKitConfig sessionStateToString:[session getState]], [session getReturnCode], notNull([session getFailStackTrace], @"\n"));

        addUIAction(^{
            [self hideProgressDialog];
        });

        if ([ReturnCode isSuccess:[session getReturnCode]]) {
            NSLog(@"Create completed successfully; burning subtitles.\n");

            NSString *burnSubtitlesCommand = [NSString stringWithFormat:@"-hide_banner -y -i %@ -vf subtitles=%@:force_style='FontName=MyFontName' %@", videoFile, subtitle, videoWithSubtitlesFile];

            addUIAction(^{
                [self showProgressDialog:@"Burning subtitles\n\n"];
            });

            NSLog(@"FFmpeg process started with arguments\n'%@'.\n", burnSubtitlesCommand);

            self->state = BurningState;
            
            [FFmpegKit executeAsync:burnSubtitlesCommand withExecuteCallback:^(id<Session> secondSession) {
                
                addUIAction(^{
                    [self hideProgressDialog];

                    if ([ReturnCode isSuccess:[secondSession getReturnCode]]) {
                        NSLog(@"Burn subtitles completed successfully; playing video.\n");
                        [self playVideo];
                    } else if ([ReturnCode isCancel:[secondSession getReturnCode]]) {
                        NSLog(@"Burn subtitles operation cancelled\n");
                        [Util alert:self.view.window withTitle:@"Error" message:@"Burn subtitles operation cancelled." buttonText:@"OK" andHandler:nil];
                    } else {
                        NSLog(@"Burn subtitles failed with state %@ and rc %@.%@", [FFmpegKitConfig sessionStateToString:[secondSession getState]], [secondSession getReturnCode], notNull([secondSession getFailStackTrace], @"\n"));

                        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 1.3 * NSEC_PER_SEC);
                        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                            [self hideProgressDialogAndAlert:@"Burn subtitles failed. Please check logs for the details."];
                        });
                    }
                });
            }];
        }
    }] getSessionId];

    NSLog(@"Async FFmpeg process started with sessionId %ld.\n", sessionId);
}

- (void)playVideo {
    NSString *videoWithSubtitlesFile = [self getVideoWithSubtitlesPath];
    NSURL*videoWithSubtitlesURL=[NSURL fileURLWithPath:videoWithSubtitlesFile];
    
    AVAsset *asset = [AVAsset assetWithURL:videoWithSubtitlesURL];
    NSArray *assetKeys = @[@"playable", @"hasProtectedContent"];
    
    AVPlayerItem *newVideo = [AVPlayerItem playerItemWithAsset:asset
                                  automaticallyLoadedAssetKeys:assetKeys];
    
    [player insertItem:newVideo afterItem:nil];
    [player play];
}

- (NSString*)getSubtitlePath {
    NSString *resourceFolder = [[NSBundle mainBundle] resourcePath];
    return [resourceFolder stringByAppendingPathComponent: @"subtitle.srt"];
}

- (NSString*)getVideoPath {
    NSString* docFolder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [docFolder stringByAppendingPathComponent: @"video.mp4"];
}

- (NSString*)getVideoWithSubtitlesPath {
    NSString* docFolder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [docFolder stringByAppendingPathComponent: @"video-with-subtitles.mp4"];
}
- (void)setActive {
    NSLog(@"Subtitle Tab Activated");
    [self enableLogCallback];
    [self enableStatisticsCallback];
}

- (void)showProgressDialog:(NSString*)dialogMessage {

    // CLEAN STATISTICS
    statistics = nil;

    [indicator show:self.view message:dialogMessage indeterminate:false asyncBlock:^{
        if (self->state == CreatingState) {
            if (self->sessionId != 0) {
                [FFmpegKit cancel:self->sessionId];
            }
        } else if (self->state == BurningState) {
            [FFmpegKit cancel];
        }
    }];
}

- (void)updateProgressDialog {
    if (statistics == nil) {
        return;
    }

    int timeInMilliseconds = [statistics getTime];
    if (timeInMilliseconds > 0) {
        int totalVideoDuration = 9000;

        int percentage = timeInMilliseconds*100/totalVideoDuration;

        if (state == CreatingState) {
            [indicator updateMessage:@"Creating video" percentage:percentage];
        } else if (state == BurningState) {
            [indicator updateMessage:@"Burning subtitles" percentage:percentage];
        }
    }
}

- (void)hideProgressDialog {
    [indicator hide];
}

- (void)hideProgressDialogAndAlert:(NSString*)message {
    [indicator hide];
    [Util alert:self.view.window withTitle:@"Error" message:message buttonText:@"OK" andHandler:nil];
}

@end

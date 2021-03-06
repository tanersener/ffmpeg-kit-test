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
#include <ffmpegkit/FFmpegKitConfig.h>
#include <ffmpegkit/FFmpegKit.h>
#include "SubtitleViewController.h"
#include "VideoViewController.h"
#include "Video.h"

typedef enum {
    IdleState = 1,
    CreatingState = 2,
    BurningState = 3
} UITestState;

@interface SubtitleViewController ()

@property (strong, nonatomic) IBOutlet UILabel *header;
@property (strong, nonatomic) IBOutlet UIButton *burnSubtitlesButton;
@property (strong, nonatomic) IBOutlet UILabel *videoPlayerFrame;

@end

@implementation SubtitleViewController  {
    
    // Video player references
    AVQueuePlayer *player;
    AVPlayerLayer *playerLayer;
    
    // Loading view
    UIAlertController *alertController;
    UIActivityIndicatorView* indicator;

    Statistics *statistics;
    
    UITestState state;
    
    long sessionId;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // STYLE UPDATE
    [Util applyButtonStyle: self.burnSubtitlesButton];
    [Util applyVideoPlayerFrameStyle: self.videoPlayerFrame];    
    [Util applyHeaderStyle: self.header];

    // VIDEO PLAYER INIT
    player = [[AVQueuePlayer alloc] init];
    playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    
    CGRect rectangularFrame = self.view.layer.bounds;
    rectangularFrame.size.width = self.view.layer.bounds.size.width - 40;
    rectangularFrame.origin.x = 20;
    rectangularFrame.origin.y = self.burnSubtitlesButton.layer.bounds.origin.y + 80;
    
    playerLayer.frame = rectangularFrame;
    [self.view.layer addSublayer:playerLayer];
    
    alertController = nil;
    statistics = nil;

    state = IdleState;
    
    sessionId = 0;

    addUIAction(^{
        [self setActive];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
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
                        [self->indicator stopAnimating];
                        [Util alert:self withTitle:@"Error" message:@"Burn subtitles operation cancelled." andButtonText:@"OK"];
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

- (void)showProgressDialog:(NSString*) dialogMessage {

    // CLEAN STATISTICS
    statistics = nil;

    alertController = [UIAlertController alertControllerWithTitle:nil
                                                                     message:dialogMessage
                                                              preferredStyle:UIAlertControllerStyleAlert];
    indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    indicator.color = [UIColor blackColor];
    indicator.translatesAutoresizingMaskIntoConstraints=NO;
    [alertController.view addSubview:indicator];
    NSDictionary * views = @{@"pending" : alertController.view, @"indicator" : indicator};
    
    UIAlertAction* cancelAction = [UIAlertAction
                                   actionWithTitle:@"CANCEL"
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction * action) {
        if (self->state == CreatingState) {
            if (self->sessionId != 0) {
                [FFmpegKit cancel:self->sessionId];
            }
        } else if (self->state == BurningState) {
            [FFmpegKit cancel];
        }
    }];
    [alertController addAction:cancelAction];

    NSArray * constraintsVertical = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[indicator]-(56)-|" options:0 metrics:nil views:views];
    NSArray * constraintsHorizontal = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[indicator]|" options:0 metrics:nil views:views];
    NSArray * constraints = [constraintsVertical arrayByAddingObjectsFromArray:constraintsHorizontal];
    [alertController.view addConstraints:constraints];
    [indicator startAnimating];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)updateProgressDialog {
    if (statistics == nil) {
        return;
    }
    
    if (alertController != nil) {
        int timeInMilliseconds = [statistics getTime];
        if (timeInMilliseconds > 0) {
            int totalVideoDuration = 9000;
            
            int percentage = timeInMilliseconds*100/totalVideoDuration;
            
            if (state == CreatingState) {
                [alertController setMessage:[NSString stringWithFormat:@"Creating video  %% %d \n\n", percentage]];
            } else if (state == BurningState) {
                [alertController setMessage:[NSString stringWithFormat:@"Burning subtitles  %% %d \n\n", percentage]];
            }            
        }
    }
}

- (void)hideProgressDialog {
    [indicator stopAnimating];
    [self dismissViewControllerAnimated:TRUE completion:nil];
}

- (void)hideProgressDialogAndAlert: (NSString*)message {
    [indicator stopAnimating];
    [self dismissViewControllerAnimated:TRUE completion:^{
        [Util alert:self withTitle:@"Error" message:message andButtonText:@"OK"];
    }];
}

@end

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

#include <ffmpegkit/FFmpegKitConfig.h>
#include <ffmpegkit/FFmpegKit.h>
#include "OtherViewController.h"

@interface OtherViewController ()

@property (strong, nonatomic) IBOutlet UILabel *header;
@property (strong, nonatomic) IBOutlet UITextField *otherTestText;
@property (strong, nonatomic) IBOutlet UIButton *runButton;
@property (strong, nonatomic) IBOutlet UITextView *outputText;

@end

@implementation OtherViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // STYLE UPDATE
    [Util applyEditTextStyle: self.otherTestText];
    [Util applyButtonStyle: self.runButton];
    [Util applyOutputTextStyle: self.outputText];
    [Util applyHeaderStyle: self.header];
    
    addUIAction(^{
        [self setActive];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)runTest:(id)sender {
    NSString *selectedTest = [self.otherTestText text];

    [self clearOutput];

    if ([selectedTest isEqualToString:@"chromaprint"]) {
        [self testChromaprint];
    } else if ([selectedTest isEqualToString:@"dav1d"]) {
        [self testDav1d];
    } else if ([selectedTest isEqualToString:@"webp"]) {
        [self testWebp];
    }
}

-(void)testChromaprint {
    NSLog(@"Testing 'chromaprint' mutex\n");
    
    NSString *audioSampleFile = [self getChromaprintSamplePath];
    [[NSFileManager defaultManager] removeItemAtPath:audioSampleFile error:NULL];

    NSString *ffmpegCommand = [NSString stringWithFormat:@"-hide_banner -y -f lavfi -i sine=frequency=1000:duration=5 -c:a pcm_s16le %@", audioSampleFile];

    NSLog(@"Creating audio sample with '%@'.\n", ffmpegCommand);

    [FFmpegKit executeAsync:ffmpegCommand withExecuteCallback:^(id<Session> session) {

        NSLog(@"FFmpeg process exited with state %@ and rc %@.%@", [FFmpegKitConfig sessionStateToString:[session getState]], [session getReturnCode], notNull([session getFailStackTrace], @"\n"));

        if ([ReturnCode isSuccess:[session getReturnCode]]) {

            NSLog(@"AUDIO sample created\n");

            NSString *chromaprintCommand = [NSString stringWithFormat:@"-hide_banner -y -i %@ -f chromaprint -fp_format 2 %@", audioSampleFile, [self getChromaprintOutputPath]];

            NSLog(@"FFmpeg process started with arguments\n'%@'.\n", chromaprintCommand);
            
            [FFmpegKit executeAsync:chromaprintCommand withExecuteCallback:^(id<Session> session) {
                
                NSLog(@"FFmpeg process exited with state %@ and rc %@.%@", [FFmpegKitConfig sessionStateToString:[session getState]], [session getReturnCode], notNull([session getFailStackTrace], @"\n"));

            } withLogCallback:^(Log *log) {
                addUIAction(^{
                    [self appendOutput: [log getMessage]];
                });
            } withStatisticsCallback:nil];
        }
    }];
}

-(void)testDav1d {
    NSLog(@"Testing decoding 'av1' codec\n");

    NSString *ffmpegCommand = [NSString stringWithFormat:@"-hide_banner -y -i %@ %@", DAV1D_TEST_DEFAULT_URL, [self getDav1dOutputPath]];

    NSLog(@"FFmpeg process started with arguments\n'%@'.\n", ffmpegCommand);

    [FFmpegKit executeAsync:ffmpegCommand withExecuteCallback:^(id<Session> session) {
        NSLog(@"FFmpeg process exited with state %@ and rc %@.%@", [FFmpegKitConfig sessionStateToString:[session getState]], [session getReturnCode], notNull([session getFailStackTrace], @"\n"));
    } withLogCallback:^(Log *log) {
        addUIAction(^{
            [self appendOutput: [log getMessage]];
        });
    } withStatisticsCallback:nil];
}

-(void)testWebp {
    NSString *resourceFolder = [[NSBundle mainBundle] resourcePath];
    NSString *imageFile = [resourceFolder stringByAppendingPathComponent: @"machupicchu.jpg"];
    NSString* docFolder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *outputFile = [docFolder stringByAppendingPathComponent: @"video.webp"];

    NSLog(@"Testing 'webp' codec\n");

    NSString *ffmpegCommand = [NSString stringWithFormat:@"-hide_banner -y -i %@ %@", imageFile, outputFile];

    NSLog(@"FFmpeg process started with arguments\n'%@'.\n", ffmpegCommand);

    [FFmpegKit executeAsync:ffmpegCommand withExecuteCallback:^(id<Session> session) {

        NSLog(@"FFmpeg process exited with state %@ and rc %@.%@", [FFmpegKitConfig sessionStateToString:[session getState]], [session getReturnCode], notNull([session getFailStackTrace], @"\n"));

    } withLogCallback:^(Log *log) {
        addUIAction(^{
            [self appendOutput: [log getMessage]];
        });
    } withStatisticsCallback:nil];
}

- (NSString*)getChromaprintSamplePath {
    NSString* docFolder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [docFolder stringByAppendingPathComponent: @"audio-sample.wav"];
}

- (NSString*)getDav1dOutputPath {
    NSString* docFolder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [docFolder stringByAppendingPathComponent: @"video.mp4"];
}

- (NSString*)getChromaprintOutputPath {
    NSString* docFolder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [docFolder stringByAppendingPathComponent: @"chromaprint.txt"];
}

- (void)setActive {
    NSLog(@"Other Tab Activated");
}

- (void)appendOutput:(NSString*) message {
    self.outputText.text = [self.outputText.text stringByAppendingString:message];
    
    if (self.outputText.text.length > 0 ) {
        NSRange bottom = NSMakeRange(self.outputText.text.length - 1, 1);
        [self.outputText scrollRangeToVisible:bottom];
    }
}

- (void)clearOutput {
    [[self outputText] setText:@""];
}

@end

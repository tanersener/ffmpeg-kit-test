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
#include <ffmpegkit/FFprobeKit.h>
#include "HttpsViewController.h"

@interface HttpsViewController ()

@property (strong) IBOutlet NSTextField *urlText;
@property (strong) IBOutlet NSButton *getInfoFromUrlButton;
@property (strong) IBOutlet NSButton *getRandomInfoButton1;
@property (strong) IBOutlet NSButton *getRandomInfoButton2;
@property (strong) IBOutlet NSButton *getInfoAndFailButton;
@property (strong) IBOutlet NSTextView *outputText;

@end

@implementation HttpsViewController{
    NSObject *outputLock;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // STYLE UPDATE
    [Util applyEditTextStyle: self.urlText];
    [Util applyButtonStyle: self.getInfoFromUrlButton];
    [Util applyButtonStyle: self.getRandomInfoButton1];
    [Util applyButtonStyle: self.getRandomInfoButton2];
    [Util applyButtonStyle: self.getInfoAndFailButton];
    [Util applyOutputTextStyle: self.outputText];
    
    outputLock = [[NSObject alloc] init];

    addUIAction(^{
        [self setActive];
    });
}

- (IBAction)runGetInfoFromUrl:(id)sender {
    [self runGetMediaInformation:1];
}

- (IBAction)runGetRandomInfo1:(id)sender {
    [self runGetMediaInformation:2];
}

- (IBAction)runGetRandomInfo2:(id)sender {
    [self runGetMediaInformation:3];
}

- (IBAction)runGetInfoAndFail:(id)sender {
    [self runGetMediaInformation:4];
}

- (void)runGetMediaInformation:(int)buttonNumber {

    // SELECT TEST URL
    NSString *testUrl;
    switch (buttonNumber) {
        case 1: {
            testUrl = [self.urlText stringValue];
            if ([testUrl length] == 0) {
                testUrl = HTTPS_TEST_DEFAULT_URL;
                [self.urlText setStringValue:testUrl];
            }
        }
        break;
        case 2:
        case 3: {
            testUrl = [self getRandomTestUrl];
        }
        break;
        case 4:
        default: {
            testUrl = HTTPS_TEST_FAIL_URL;
            [self.urlText setStringValue:testUrl];
        }
    }

    NSLog(@"Testing HTTPS with for button %d using url %@.", buttonNumber, testUrl);

    if (buttonNumber == 4) {

        // ONLY THIS BUTTON CLEARS THE TEXT VIEW
        [self clearOutput];
    }

    [FFprobeKit getMediaInformationAsync:testUrl withExecuteCallback:[self createNewExecuteCallback]];
}

- (void)setActive {
    NSLog(@"Https Tab Activated");
    [FFmpegKitConfig enableLogCallback:nil];
    [FFmpegKitConfig enableStatisticsCallback:nil];
}

- (void)appendOutput:(NSString*) message {
    [self.outputText setString:[self.outputText.string stringByAppendingString:message]];
    [self.outputText scrollRangeToVisible:NSMakeRange([[self.outputText string] length], 0)];
}

- (void)clearOutput {
    [[self outputText] setString:@""];
}

- (NSString*)getRandomTestUrl {
    switch (arc4random_uniform(3)) {
        case 0:
            return HTTPS_TEST_RANDOM_URL_1;
        case 1:
            return HTTPS_TEST_RANDOM_URL_2;
        default:
            return HTTPS_TEST_RANDOM_URL_3;
    }
}

- (ExecuteCallback)createNewExecuteCallback {
    return ^(id<Session> session){
        addUIAction(^{
            @synchronized (self->outputLock) {
                MediaInformation *information = [((MediaInformationSession*) session) getMediaInformation];
                if (information == nil) {
                    [self appendOutput:@"Get media information failed\n"];
                    [self appendOutput:[NSString stringWithFormat:@"State: %@\n", [FFmpegKitConfig sessionStateToString:[session getState]]]];
                    [self appendOutput:[NSString stringWithFormat:@"Duration: %ld\n", [session getDuration]]];
                    [self appendOutput:[NSString stringWithFormat:@"Return Code: %@\n", [session getReturnCode]]];
                    [self appendOutput:[NSString stringWithFormat:@"Fail stack trace: %@\n", notNull([session getFailStackTrace], @"\n")]];
                    [self appendOutput:[NSString stringWithFormat:@"Output: %@\n", [session getOutput]]];
                } else {
                    [self appendOutput:[NSString stringWithFormat:@"Media information for %@\n", [information getFilename]]];

                    if ([information getFormat] != nil) {
                        [self appendOutput:[NSString stringWithFormat:@"Format: %@\n", [information getFormat]]];
                    }
                    if ([information getBitrate] != nil) {
                        [self appendOutput:[NSString stringWithFormat:@"Bitrate: %@\n", [information getBitrate]]];
                    }
                    if ([information getDuration] != nil) {
                        [self appendOutput:[NSString stringWithFormat:@"Duration: %@\n", [information getDuration]]];
                    }
                    if ([information getStartTime] != nil) {
                        [self appendOutput:[NSString stringWithFormat:@"Start time: %@\n", [information getStartTime]]];
                    }
                    if ([information getTags] != nil) {
                        NSDictionary* tags = [information getTags];
                        for(NSString *key in [tags allKeys]) {
                            [self appendOutput:[NSString stringWithFormat:@"Tag: %@:%@", key, [tags objectForKey:key]]];
                        }
                    }
                    if ([information getStreams] != nil) {
                        for (StreamInformation* stream in [information getStreams]) {
                            if ([stream getIndex] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream index: %@\n", [stream getIndex]]];
                            }
                            if ([stream getType] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream type: %@\n", [stream getType]]];
                            }
                            if ([stream getCodec] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream codec: %@\n", [stream getCodec]]];
                            }
                            if ([stream getFullCodec] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream full codec: %@\n", [stream getFullCodec]]];
                            }
                            if ([stream getFormat] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream format: %@\n", [stream getFormat]]];
                            }

                            if ([stream getWidth] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream width: %@\n", [stream getWidth]]];
                            }
                            if ([stream getHeight] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream height: %@\n", [stream getHeight]]];
                            }

                            if ([stream getBitrate] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream bitrate: %@\n", [stream getBitrate]]];
                            }
                            if ([stream getSampleRate] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream sample rate: %@\n", [stream getSampleRate]]];
                            }
                            if ([stream getSampleFormat] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream sample format: %@\n", [stream getSampleFormat]]];
                            }
                            if ([stream getChannelLayout] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream channel layout: %@\n", [stream getChannelLayout]]];
                            }

                            if ([stream getSampleAspectRatio] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream sample aspect ratio: %@\n", [stream getSampleAspectRatio]]];
                            }
                            if ([stream getDisplayAspectRatio] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream display ascpect ratio: %@\n", [stream getDisplayAspectRatio]]];
                            }
                            if ([stream getAverageFrameRate] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream average frame rate: %@\n", [stream getAverageFrameRate]]];
                            }
                            if ([stream getRealFrameRate] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream real frame rate: %@\n", [stream getRealFrameRate]]];
                            }
                            if ([stream getTimeBase] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream time base: %@\n", [stream getTimeBase]]];
                            }
                            if ([stream getCodecTimeBase] != nil) {
                                [self appendOutput:[NSString stringWithFormat:@"Stream codec time base: %@\n", [stream getCodecTimeBase]]];
                            }

                            if ([stream getTags] != nil) {
                                NSDictionary* tags = [stream getTags];
                                for(NSString *key in [tags allKeys]) {
                                    [self appendOutput:[NSString stringWithFormat:@"Stream tag: %@:%@", key, [tags objectForKey:key]]];
                                }
                            }
                        }
                    }
                }
            }
        });
    };
}

@end

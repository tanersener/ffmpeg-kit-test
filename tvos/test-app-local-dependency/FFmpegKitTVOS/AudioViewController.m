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
#include "AudioViewController.h"

@interface AudioViewController ()

@property (strong, nonatomic) IBOutlet UILabel *header;
@property (strong, nonatomic) IBOutlet UITextField *audioCodecText;
@property (strong, nonatomic) IBOutlet UIButton *encodeButton;
@property (strong, nonatomic) IBOutlet UITextView *outputText;

@end

@implementation AudioViewController {

    // Video codec data
    NSArray *codecData;

    // Loading view
    UIActivityIndicatorView* indicator;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // STYLE UPDATE
    [Util applyEditTextStyle: self.audioCodecText];
    [Util applyButtonStyle: self.encodeButton];
    [Util applyOutputTextStyle: self.outputText];
    [Util applyHeaderStyle: self.header];


    // BUTTON DISABLED UNTIL AUDIO SAMPLE IS CREATED
    [self.encodeButton setEnabled:false];
    
    [self createAudioSample];

    addUIAction(^{
        [self setActive];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)enableLogCallback {
    [FFmpegKitConfig enableLogCallback: ^(Log* log){
        addUIAction(^{
            [self appendOutput:[log getMessage]];
        });
    }];
}

- (void)disableLogCallback {
    [FFmpegKitConfig enableLogCallback:nil];
}

- (void)disableStatisticsCallback {
    [FFmpegKitConfig enableStatisticsCallback:nil];
}

- (IBAction)encodeAudio:(id)sender {
    NSString *audioOutputFile = [self getAudioOutputFilePath];
    [[NSFileManager defaultManager] removeItemAtPath:audioOutputFile error:NULL];

    NSString *audioCodec = [[self audioCodecText] text];
    
    NSLog(@"Testing AUDIO encoding with '%@' codec\n", audioCodec);
    
    NSString *ffmpegCommand = [self generateAudioEncodeScript];
    
    [self showProgressDialog:@"Encoding audio\n\n"];

    [self clearOutput];
        
    NSLog(@"FFmpeg process started with arguments\n'%@'.\n", ffmpegCommand);
    
    [FFmpegKit executeAsync:ffmpegCommand withExecuteCallback:^(id<Session> session) {
        SessionState state = [session getState];
        ReturnCode* returnCode = [session getReturnCode];
        
        if ([ReturnCode isSuccess:returnCode]) {
            NSLog(@"Encode completed successfully.\n");
            addUIAction(^{
                [self hideProgressDialogAndAlert:@"Success" and:@"Encode completed successfully."];
            });
        } else {
            NSLog(@"Encode failed with state %@ and rc %@.%@", [FFmpegKitConfig sessionStateToString:state], returnCode, notNull([session getFailStackTrace], @"\n"));
            addUIAction(^{
                [self hideProgressDialogAndAlert:@"Error" and:@"Encode failed. Please check logs for the details."];
            });
        }
    }];
}

- (void)createAudioSample {
    NSLog(@"Creating AUDIO sample before the test.\n");
    
    NSString *audioSampleFile = [self getAudioSamplePath];
    [[NSFileManager defaultManager] removeItemAtPath:audioSampleFile error:NULL];
    
    NSString *ffmpegCommand = [NSString stringWithFormat:@"-y -f lavfi -i sine=frequency=1000:duration=5 -c:a pcm_s16le %@", audioSampleFile];
    
    NSLog(@"Creating audio sample with '%@'\n", ffmpegCommand);
    
    FFmpegSession* session = [FFmpegKit execute:ffmpegCommand];
    ReturnCode* returnCode = [session getReturnCode];
    if ([ReturnCode isSuccess:returnCode]) {
        [self.encodeButton setEnabled:true];
        NSLog(@"AUDIO sample created\n");
    } else {
        NSLog(@"Creating AUDIO sample failed with state %@ and rc %@.%@", [FFmpegKitConfig sessionStateToString:[session getState]], returnCode, notNull([session getFailStackTrace], @"\n"));
        addUIAction(^{
            [Util alert:self withTitle:@"Error" message:@"Creating AUDIO sample failed. Please check logs for the details." andButtonText:@"OK"];
        });
    }
}

- (NSString*)getAudioOutputFilePath {
    NSString *audioCodec = [[self audioCodecText] text];
    
    NSString *extension;
    if ([audioCodec isEqualToString:@"aac (audiotoolbox)"]) {
        extension = @"m4a";
    } else if ([audioCodec isEqualToString:@"mp2 (twolame)"]) {
        extension = @"mpg";
    } else if ([audioCodec isEqualToString:@"mp3 (liblame)"] || [audioCodec isEqualToString:@"mp3 (libshine)"]) {
        extension = @"mp3";
    } else if ([audioCodec isEqualToString:@"vorbis"]) {
        extension = @"ogg";
    } else if ([audioCodec isEqualToString:@"opus"]) {
        extension = @"opus";
    } else if ([audioCodec isEqualToString:@"amr-nb"]) {
        extension = @"amr";
    } else if ([audioCodec isEqualToString:@"amr-wb"]) {
        extension = @"amr";
    } else if ([audioCodec isEqualToString:@"ilbc"]) {
        extension = @"lbc";
    } else if ([audioCodec isEqualToString:@"speex"]) {
        extension = @"spx";
    } else if ([audioCodec isEqualToString:@"wavpack"]) {
        extension = @"wv";
    } else {
        
        // soxr
        extension = @"wav";
    }
    
    NSString* docFolder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [[docFolder stringByAppendingPathComponent: @"audio."] stringByAppendingString: extension];
}

- (NSString*)getAudioSamplePath {
    NSString* docFolder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [docFolder stringByAppendingPathComponent: @"audio-sample.wav"];
}

- (void)setActive {
    NSLog(@"Audio Tab Activated");
    [self disableStatisticsCallback];
    [self disableLogCallback];
    [self createAudioSample];
    [self enableLogCallback];
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

- (void)showProgressDialog:(NSString*) dialogMessage {
    UIAlertController *pending = [UIAlertController alertControllerWithTitle:nil
                                                                     message:dialogMessage
                                                              preferredStyle:UIAlertControllerStyleAlert];
    indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    indicator.color = [UIColor blackColor];
    indicator.translatesAutoresizingMaskIntoConstraints=NO;
    [pending.view addSubview:indicator];
    NSDictionary * views = @{@"pending" : pending.view, @"indicator" : indicator};
    
    NSArray * constraintsVertical = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[indicator]-(20)-|" options:0 metrics:nil views:views];
    NSArray * constraintsHorizontal = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[indicator]|" options:0 metrics:nil views:views];
    NSArray * constraints = [constraintsVertical arrayByAddingObjectsFromArray:constraintsHorizontal];
    [pending.view addConstraints:constraints];
    [indicator startAnimating];
    [self presentViewController:pending animated:YES completion:nil];
}

- (void)hideProgressDialog {
    [indicator stopAnimating];
    [self dismissViewControllerAnimated:TRUE completion:nil];
}

- (void)hideProgressDialogAndAlert: (NSString*)title and:(NSString*)message {
    [indicator stopAnimating];
    [self dismissViewControllerAnimated:TRUE completion:^{
        [Util alert:self withTitle:title message:message andButtonText:@"OK"];
    }];
}

- (NSString*)generateAudioEncodeScript {
    NSString *audioCodec = [[self audioCodecText] text];
    NSString *audioSampleFile = [self getAudioSamplePath];
    NSString *audioOutputFile = [self getAudioOutputFilePath];

    if ([audioCodec containsString:@"aac"]) {
        return [NSString stringWithFormat:@"-hide_banner -y -i %@ -c:a aac_at -b:a 192k %@", audioSampleFile, audioOutputFile];
    } else if ([audioCodec containsString:@"mp2"]) {
        return [NSString stringWithFormat:@"-hide_banner -y -i %@ -c:a mp2 -b:a 192k %@", audioSampleFile, audioOutputFile];
    } else if ([audioCodec containsString:@"mp3"]) {
        return [NSString stringWithFormat:@"-hide_banner -y -i %@ -c:a libmp3lame -qscale:a 2 %@", audioSampleFile, audioOutputFile];
    } else if ([audioCodec containsString:@"mp3 (libshine)"]) {
        return [NSString stringWithFormat:@"-hide_banner -y -i %@ -c:a libshine -qscale:a 2 %@", audioSampleFile, audioOutputFile];
    } else if ([audioCodec containsString:@"vorbis"]) {
        return [NSString stringWithFormat:@"-hide_banner -y -i %@ -c:a libvorbis -b:a 64k %@", audioSampleFile, audioOutputFile];
    } else if ([audioCodec containsString:@"opus"]) {
        return [NSString stringWithFormat:@"-hide_banner -y -i %@ -c:a libopus -b:a 64k -vbr on -compression_level 10 %@", audioSampleFile, audioOutputFile];
    } else if ([audioCodec containsString:@"amr-nb"]) {
        return [NSString stringWithFormat:@"-hide_banner -y -i %@ -ar 8000 -ab 12.2k -c:a libopencore_amrnb %@", audioSampleFile, audioOutputFile];
    } else if ([audioCodec containsString:@"amr-wb"]) {
        return [NSString stringWithFormat:@"-hide_banner -y -i %@ -ar 8000 -ab 12.2k -c:a libvo_amrwbenc -strict experimental %@", audioSampleFile, audioOutputFile];
    } else if ([audioCodec containsString:@"ilbc"]) {
        return [NSString stringWithFormat:@"-hide_banner -y -i %@ -c:a ilbc -ar 8000 -b:a 15200 %@", audioSampleFile, audioOutputFile];
    } else if ([audioCodec containsString:@"speex"]) {
        return [NSString stringWithFormat:@"-hide_banner -y -i %@ -c:a libspeex -ar 16000 %@", audioSampleFile, audioOutputFile];
    } else if ([audioCodec containsString:@"wavpack"]) {
        return [NSString stringWithFormat:@"-hide_banner -y -i %@ -c:a wavpack -b:a 64k %@", audioSampleFile, audioOutputFile];
    } else {
        
        // soxr
        return [NSString stringWithFormat:@"-hide_banner -y -i %@ -af aresample=resampler=soxr -ar 44100 %@", audioSampleFile, audioOutputFile];
    }
}

@end

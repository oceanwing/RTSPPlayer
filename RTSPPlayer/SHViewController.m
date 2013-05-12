//
//  SHViewController.m
//  RTSPPlayer
//
//  Created by ken on 13. 5. 7..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import "SHViewController.h"
#import "KNGLView.h"
#import "KNFFmpegFileReader.h"
#import "KNFFmpegDecoder.h"
#import "KNAudioManager.h"

@interface SHViewController ()
@property (retain, nonatomic) KNGLView* glView;
@property (retain, nonatomic) KNFFmpegFileReader* reader;
@property (retain, nonatomic) KNFFmpegDecoder* decoder;
@property (retain, nonatomic) KNAudioManager* audioMgr;
@end

@implementation SHViewController

@synthesize tfURL = _tfURL;
@synthesize viewRender = _viewRender;
@synthesize audioMgr = _audioMgr;

- (void)dealloc {
    [_tfURL release];
    [_viewRender release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    KNGLView* glView = [[KNGLView alloc] initWithFrame:self.viewRender.bounds];
    self.glView = glView;
    [glView release];
    [self.viewRender addSubview:_glView];
    
    KNAudioManager* am  = [[KNAudioManager alloc] init];
    self.audioMgr = am;
    [am release];
    
    _audioMgr.outputBlock = ^(float *data, UInt32 numFrames, UInt32 numChannels) {
        
    };
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction)playStop:(id)sender {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [_btnPlay setEnabled:NO];
        
        NSString* url = _tfURL.text;
        NSLog(@"URL : %@", _tfURL.text);
        if (url.length <= 0) {
            NSLog(@"URL : %@", _tfURL.placeholder.description);
            url = _tfURL.placeholder;
        }

        
        
        if (!url || url.length <= 0) {
            [_btnPlay setEnabled:YES];
            return;
        }
        
        KNFFmpegFileReader* r = [[KNFFmpegFileReader alloc] initWithURL:url withOption:kNetTCP];
        self.reader = r;
        [r release];
        
        KNFFmpegDecoder* d = [[KNFFmpegDecoder alloc] initWithVideoCodecCtx:_reader.videoCodecCtx
                                                                videoStream:_reader.videoStreamIndex
                                                              audioCodecCtx:_reader.audioCodecCtx
                                                                audioStream:_reader.audioStreamIndex];
        self.decoder = d;
        [d release];
        
        
        [_reader readFrame:^(AVPacket *packet, int streamIndex) {
            
            if (streamIndex == _reader.videoStreamIndex) {

                [_decoder decodeVideo:packet completion:^(NSDictionary *frameData) {
                    [_glView render:frameData];
                }];
            }
            
            if (streamIndex == _reader.audioStreamIndex) {
                [_decoder decodeAudio:packet completion:^(NSDictionary *frameData) {
                    NSLog(@"audio dec data size : %d", [[frameData objectForKey:@"size"] integerValue]);
                }];
            }
           
        } completion:^(BOOL finish) {
            NSLog(@"-> done");
            
            [_btnPlay setEnabled:YES];
        }];
        
    });
}


#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [_tfURL resignFirstResponder];
    return YES;
}


- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [_tfURL resignFirstResponder];
}


@end

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

@interface SHViewController ()
@property (retain, nonatomic) KNGLView* glView;
@property (retain, nonatomic) KNFFmpegFileReader* reader;
@property (retain, nonatomic) KNFFmpegDecoder* decoder;
@end

@implementation SHViewController

@synthesize tfURL = _tfURL;
@synthesize viewRender = _viewRender;

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
        
        KNFFmpegDecoder* d = [[KNFFmpegDecoder alloc] initWithCodecContext:_reader.videoCodecCtx videoStreamIndex:_reader.videoStreamIndex];
        self.decoder = d;
        [d release];
        
        
        [_reader readFrame:^(AVPacket *packet, int streamIndex) {
            
            if (streamIndex == _reader.videoStreamIndex) {

                [_decoder decodeFrame:packet completion:^(NSDictionary *frameData) {
                    [_glView render:frameData];
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

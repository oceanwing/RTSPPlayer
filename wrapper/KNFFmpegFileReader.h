//
//  KNFFmpegFileReader.h
//  GLKDrawTest
//
//  Created by Choi Yeong Hyeon on 12. 11. 25..
//  Copyright (c) 2012년 Choi Yeong Hyeon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "avcodec.h"
#import "avformat.h"

typedef enum {

    kNetNone = 0,
    kNetUDP,
    kNetTCP,
    
}KNNetOption;

@interface KNFFmpegFileReader : NSObject

@property (assign) AVCodecContext* videoCodecCtx;
@property (assign) AVCodecContext* audioCodecCtx;
@property (assign) AVFormatContext* formatCtx;
@property (readonly) int videoStreamIndex;
@property (readonly) int audioStreamIndex;

- (id)initWithURL:(NSString *)url withOption:(KNNetOption)opt;
- (void)readFrame:(void(^)(AVPacket* packet, int streamIndex))readBlock completion:(void(^)(BOOL finish))completion;
- (void)cancelReadFrame;

- (void)nextFrame:(void(^)(AVPacket* packet, int streamIndex, BOOL readFinish))readBlock;

@end

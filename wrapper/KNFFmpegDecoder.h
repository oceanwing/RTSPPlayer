//
//  KNFFmpegDecoder.h
//  GLKDrawTest
//
//  Created by Choi Yeong Hyeon on 12. 11. 25..
//  Copyright (c) 2012년 Choi Yeong Hyeon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "avcodec.h"

#define kKNFFDecKeyWidth        @"width"
#define kKNFFDecKeyHeigth       @"height"
#define kKNFFDecKeyLuma         @"luma"
#define kKNFFDecKeyChromaB      @"chromaB"
#define kKNFFDecKeyChromaR      @"chromaR"


@interface KNFFmpegDecoder : NSObject

- (id)initWithVideoCodecCtx:(AVCodecContext *)vcodecCtx
                videoStream:(int)vstream
              audioCodecCtx:(AVCodecContext *)acodecCtx
                audioStream:(int)astream;

/*
    frameData key
    width
    heigth
    ydata
    udata
    vdata
 */
//- (void)decodeFrame:(AVPacket *)packet
//         completion:(void(^)(NSDictionary* frameData))completion;

- (void)decodeVideo:(AVPacket *)packet
         completion:(void(^)(NSDictionary* frameData))completion;

- (void)decodeAudio:(AVPacket *)packet
         completion:(void(^)(NSDictionary* frameData))completion;


- (void)endDecode;
@end

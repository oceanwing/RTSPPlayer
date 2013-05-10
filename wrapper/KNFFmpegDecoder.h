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
- (id)initWithCodecContext:(AVCodecContext *)codecCtx
          videoStreamIndex:(int)index;

/*
    frameData key
    width
    heigth
    ydata
    udata
    vdata
 */
- (void)decodeFrame:(AVPacket *)packet
         completion:(void(^)(NSDictionary* frameData))completion;

- (void)endDecode;
@end

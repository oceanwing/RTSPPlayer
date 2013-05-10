//
//  KNFFmpegDecoder.m
//  GLKDrawTest
//
//  Created by Choi Yeong Hyeon on 12. 11. 25..
//  Copyright (c) 2012년 Choi Yeong Hyeon. All rights reserved.
//

#import "KNFFmpegDecoder.h"
#import "avformat.h"
#import "swscale.h"


@interface KNFFmpegDecoder() {
    AVCodecContext* pCodecCtx;
    AVCodec* pCodec;
    AVFrame* pFrame;
    int videoStreamIndex;
}
- (NSData *)copYUVData:(UInt8 *)src
              linesize:(int)linesize
                 width:(int)width
                height:(int)height;
- (NSDictionary *)makeFrameData;
@end

@implementation KNFFmpegDecoder


- (void)dealloc {
    
    if (pFrame) {
        av_free(pFrame);
        pFrame = NULL;
    }
    
    [super dealloc];
}

- (id)initWithCodecContext:(AVCodecContext *)codecCtx
          videoStreamIndex:(int)index {
    
    self = [super init];
    if (self) {
        
        pCodecCtx = codecCtx;
        videoStreamIndex = index;
        pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
        if (pCodec == NULL) {
            NSLog(@"%s avcodec_find_decoder failed", __func__);
            return nil;
        }
        if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
            NSLog(@"%s avcodec_open2 failed", __func__);
            return nil;            
        }
        
        pFrame = avcodec_alloc_frame();
    }
    return self;
}

- (void)decodeFrame:(AVPacket *)packet
         completion:(void(^)(NSDictionary* frameData))completion {

    int got_picture = 0;
    if (packet->stream_index == videoStreamIndex) {

        int len = avcodec_decode_video2(pCodecCtx, pFrame, &got_picture, packet);

        if (len < 0) {
            NSLog(@"avcodec_decode_video2 error : len : %d", len);
            return;
        }
        
        if (!got_picture) {
            NSLog(@"avcodec_decode_video2 error : got_picture_ptr : %d", got_picture);
            return;
        }

        if (completion) {
            NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
            NSDictionary* frameData = [[self makeFrameData] retain];;
            completion(frameData);
            [frameData release];
            [pool release];
        }
    }
}

- (void)endDecode {
    av_free(pFrame);
    pFrame = NULL;
}

- (NSDictionary *)makeFrameData {

    NSMutableDictionary* frameData = [NSMutableDictionary dictionary];
    [frameData setObject:[NSNumber numberWithInt:pCodecCtx->width] forKey:kKNFFDecKeyWidth];
    [frameData setObject:[NSNumber numberWithInt:pCodecCtx->height] forKey:kKNFFDecKeyHeigth];

    NSData* ydata = [self copYUVData:pFrame->data[0] linesize:pFrame->linesize[0] width:pCodecCtx->width height:pCodecCtx->height];
    NSData* udata = [self copYUVData:pFrame->data[1] linesize:pFrame->linesize[1] width:pCodecCtx->width/2 height:pCodecCtx->height/2];
    NSData* vdata = [self copYUVData:pFrame->data[2] linesize:pFrame->linesize[2] width:pCodecCtx->width/2 height:pCodecCtx->height/2];
    [frameData setObject:ydata forKey:kKNFFDecKeyLuma];
    [frameData setObject:udata forKey:kKNFFDecKeyChromaB];
    [frameData setObject:vdata forKey:kKNFFDecKeyChromaR];

    return frameData;
}

- (NSData *)copYUVData:(UInt8 *)src linesize:(int)linesize width:(int)width height:(int)height {

    width = MIN(linesize, width);
    NSMutableData *md = [NSMutableData dataWithLength: width * height];
    Byte *dst = md.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i) {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    return md;
}

@end

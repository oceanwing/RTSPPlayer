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

    AVCodecContext* pVideoCodeCtx_;
    AVCodec* pVideoCodec_;
    AVFrame* pVideoFrame_;
    int videoStreamIndex_;

    AVCodecContext* pAudioCodeCtx_;
    AVCodec* pAudioCodec_;
    AVFrame* pAudioFrame_;
    int audioStreamIndex_;

}
- (NSData *)copYUVData:(UInt8 *)src
              linesize:(int)linesize
                 width:(int)width
                height:(int)height;
- (NSDictionary *)makeFrameData;
@end

@implementation KNFFmpegDecoder


- (void)dealloc {
    
    if (pVideoFrame_) {
        av_free(pVideoFrame_);
        pVideoFrame_ = NULL;
    }
    
    if (pAudioFrame_) {
        av_free(pAudioFrame_);
        pAudioFrame_ = NULL;
    }
    
    [super dealloc];
}

- (id)initWithVideoCodecCtx:(AVCodecContext *)vcodecCtx
                videoStream:(int)vstream
              audioCodecCtx:(AVCodecContext *)acodecCtx
                audioStream:(int)astream {
    
    self = [super init];
    if (self) {

        //init video codec.
        pVideoCodeCtx_ = vcodecCtx;
        videoStreamIndex_ = vstream;
        pVideoCodec_ = avcodec_find_decoder(pVideoCodeCtx_->codec_id);
        if (pVideoCodec_ == NULL) {
            NSLog(@"%s Video decoder find error.", __func__);
            [self release];
            return nil;
        }
        if (avcodec_open2(pVideoCodeCtx_, pVideoCodec_, NULL) < 0) {
            NSLog(@"%s Video decoder open error.", __func__);
            [self release];
            return nil;
        }
        pVideoFrame_ = avcodec_alloc_frame();
        
        
        ///init audio codec.
        pAudioCodeCtx_ = acodecCtx;
        audioStreamIndex_ = astream;
        pAudioCodec_ = avcodec_find_decoder(pAudioCodeCtx_->codec_id);
        if (pAudioCodec_ == NULL) {
            NSLog(@"%s Audio decoder find error.", __func__);
            [self release];
            return nil;
        }
        if (avcodec_open2(pAudioCodeCtx_, pAudioCodec_, NULL) < 0) {
            NSLog(@"%s Audio decoder open error.", __func__);
            [self release];
            return nil;
        }
        pAudioFrame_ = avcodec_alloc_frame();
    }
    return self;
}

- (void)decodeVideo:(AVPacket *)packet
         completion:(void(^)(NSDictionary* frameData))completion {

    int got_picture = 0;
    if (packet->stream_index != videoStreamIndex_)
        return;

    int len = avcodec_decode_video2(pVideoCodeCtx_, pVideoFrame_, &got_picture, packet);

    if (len < 0) {
        NSLog(@"avcodec_decode_video2 error : len : %d", len);
        return;
    }
    
    if (!got_picture) {
        NSLog(@"avcodec_decode_video2 error : got_picture_ptr : %d", got_picture);
        return;
    }

    if (completion) {
        @autoreleasepool {
            NSDictionary* frameData = [[self makeFrameData] retain];;
            completion(frameData);
            [frameData release];
        }
    }
}

- (void)decodeAudio:(AVPacket *)packet
         completion:(void(^)(NSDictionary* frameData))completion {

    int got_picture = 0;
    if (packet->stream_index != audioStreamIndex_)
        return;
    
    int len = avcodec_decode_audio4(pAudioCodeCtx_, pAudioFrame_, &got_picture, packet);

    if (len < 0) {
        NSLog(@"avcodec_decode_audio4 error : len : %d", len);
        return;
    }
    
    if (!got_picture) {
        NSLog(@"avcodec_decode_audio4 error : got_picture_ptr : %d", got_picture);
        return;
    }
    
    if (pAudioCodeCtx_->sample_fmt != AV_SAMPLE_FMT_S16) {
        
        NSLog(@"Audio not AV_SAMPLE_FMT_S16.");
        
    } else {
        
        if (completion) {
            @autoreleasepool {
                
                int decSize = av_samples_get_buffer_size(NULL,
                                                         pAudioCodeCtx_->channels,
                                                         pAudioFrame_->nb_samples,
                                                         pAudioCodeCtx_->sample_fmt,
                                                         1);
                
                NSMutableData *md = [NSMutableData dataWithLength:len];
                Byte *dst = md.mutableBytes;
                memcpy(dst, pAudioFrame_->data[0], decSize);
                
                NSMutableDictionary* decData = [[NSMutableDictionary alloc] initWithCapacity:2];
                [decData setObject:[NSNumber numberWithInt:decSize] forKey:@"size"];
                [decData setObject:decData forKey:@"data"];
                [md release];
                
                completion(decData);
                [decData release];
            }
        }
    }
}


- (void)endDecode {
    
    avcodec_close(pVideoCodeCtx_);
    av_free(pVideoFrame_);
    pVideoFrame_ = NULL;
    
    avcodec_close(pAudioCodeCtx_);
    av_free(pAudioFrame_);
    pAudioFrame_ = NULL;
}

- (NSDictionary *)makeFrameData {

    NSMutableDictionary* frameData = [NSMutableDictionary dictionary];
    [frameData setObject:[NSNumber numberWithInt:pVideoCodeCtx_->width] forKey:kKNFFDecKeyWidth];
    [frameData setObject:[NSNumber numberWithInt:pVideoCodeCtx_->height] forKey:kKNFFDecKeyHeigth];

    NSData* ydata = [self copYUVData:pVideoFrame_->data[0] linesize:pVideoFrame_->linesize[0] width:pVideoCodeCtx_->width height:pVideoCodeCtx_->height];
    NSData* udata = [self copYUVData:pVideoFrame_->data[1] linesize:pVideoFrame_->linesize[1] width:pVideoCodeCtx_->width/2 height:pVideoCodeCtx_->height/2];
    NSData* vdata = [self copYUVData:pVideoFrame_->data[2] linesize:pVideoFrame_->linesize[2] width:pVideoCodeCtx_->width/2 height:pVideoCodeCtx_->height/2];
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

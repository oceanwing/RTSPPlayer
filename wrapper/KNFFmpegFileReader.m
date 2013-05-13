//
//  KNFFmpegFileReader.m
//  GLKDrawTest
//
//  Created by Choi Yeong Hyeon on 12. 11. 25..
//  Copyright (c) 2012년 Choi Yeong Hyeon. All rights reserved.
//

#import "KNFFmpegFileReader.h"

@interface KNFFmpegFileReader() {
    BOOL cancelReadFrame_;
    KNNetOption netOption_;
}

@property (copy, nonatomic) NSString* inputURL;
@property (assign) int videoStreamIndex;
@property (assign) int audioStreamIndex;

@end

@implementation KNFFmpegFileReader
@synthesize videoCodecCtx       = _videoCodecCtx;
@synthesize audioCodecCtx       = _audioCodecCtx;
@synthesize formatCtx           = _formatCtx;
@synthesize inputURL            = _inputURL;
@synthesize videoStreamIndex    = _videoStreamIndex;
@synthesize audioStreamIndex    = _audioStreamIndex;


- (void)dealloc {
    [_inputURL release];
    
    if (_videoCodecCtx) {
        avcodec_close(_videoCodecCtx);
        _videoCodecCtx = NULL;
    }
    
    if (_audioCodecCtx) {
        avcodec_close(_audioCodecCtx);
        _audioCodecCtx = NULL;
    }

    
    if (_formatCtx) {
        avformat_close_input(&_formatCtx);
        _formatCtx = NULL;
    }
    [super dealloc];
}

- (id)initWithURL:(NSString *)url withOption:(KNNetOption)opt {

    self = [super init];
    if (self) {
        
        _videoStreamIndex = _audioStreamIndex = -1;
        
        self.inputURL = url;
        netOption_ = opt;
        if ([self initInput] == NO) {
            [self release];
            return nil;
        }
    }
    return self;
}

- (BOOL)initInput {
    
    av_register_all();
    avcodec_register_all();
    avformat_network_init();


    AVDictionary *opts = 0;
    if (netOption_ == kNetTCP)
        av_dict_set(&opts, "rtsp_transport", "tcp", 0);
    else
        av_dict_set(&opts, "rtsp_transport", "udp", 0);
        
    if (avformat_open_input(&_formatCtx, [_inputURL UTF8String], 0, &opts) != 0) {
        NSLog(@"avformat_open_input failed.");
        av_dict_free(&opts);
        return NO;
    }
    av_dict_free(&opts);

    
    if (avformat_find_stream_info(_formatCtx, 0) < 0) {
        NSLog(@"avformat_find_stream_info failed.");
        return NO;
    }

    if (_formatCtx->nb_streams <= 0) {
        NSLog(@"avformat_find_stream_info nb_stream is 0.");
        return NO;
    }

    for (int i = 0; i < _formatCtx->nb_streams; i++) {
        if (_formatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            _videoStreamIndex = i;
            break;
        }
    }
    
    for (int i = 0; i < _formatCtx->nb_streams; i++) {
        if (_formatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
            _audioStreamIndex = i;
            break;
        }
    }


    if (_videoStreamIndex != -1) {
        _videoCodecCtx = _formatCtx->streams[_videoStreamIndex]->codec;
    }
    
    if (_audioStreamIndex != -1) {
        _audioCodecCtx = _formatCtx->streams[_audioStreamIndex]->codec;
    }
    
    if (_videoStreamIndex == -1 && _audioStreamIndex == -1)
        return NO;
    
    return YES;
}

- (void)readFrame:(void(^)(AVPacket* packet, int streamIndex))readBlock
       completion:(void(^)(BOOL finish))completion {

    if (cancelReadFrame_) {
        NSLog(@"Frame read canceled.");
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        AVPacket packet;
        av_init_packet(&packet);
        BOOL cancel = NO;

        while (av_read_frame(_formatCtx, &packet) >= 0) {
            
            @synchronized(self){
                if (readBlock) {
                    readBlock(&packet, packet.stream_index);
                }
                av_free_packet(&packet);
                av_init_packet(&packet);
            }
            
            if (cancelReadFrame_) {
                cancel = YES;
                break;
            }
        }
        avcodec_close(_videoCodecCtx);
        _videoCodecCtx = NULL;
        
        avcodec_close(_audioCodecCtx);
        _audioCodecCtx = NULL;

        avformat_close_input(&_formatCtx);
        _formatCtx = NULL;
        
        if (completion) {
            completion(!cancel);
        }
    });
}

- (void)cancelReadFrame {
    cancelReadFrame_ = YES;
}

- (void)nextFrame:(void(^)(AVPacket* packet, int streamIndex, BOOL readFinish))readBlock {

    AVPacket packet;
    int ret = av_read_frame(_formatCtx, &packet);
    if (ret <= 0) {
        
        if (readBlock) {
            readBlock(&packet, packet.stream_index, NO);
            av_free_packet(&packet);
        }
        
    } else {
        NSLog(@"read packet error : %d", ret);
        ///에러 또는 프레임끝처리.
        readBlock(NULL, -1, NO);
    }
}

@end

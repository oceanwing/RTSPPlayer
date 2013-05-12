//
//  KNAudioManager.h
//  PCMStreamPlayer
//
//  Created by cyh on 13. 2. 13..
//  Copyright (c) 2013년 saeha. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^KxAudioManagerOutputBlock)(float *data, UInt32 numFrames, UInt32 numChannels);

@interface KNAudioManager : NSObject

@property (readonly) UInt32             numOutputChannels;
@property (readonly) UInt32             numBytesPerSample;
@property (readonly) Float64            samplingRate;
@property (assign)   Float32            outputVolume;
@property (assign)   UInt32             bufferSize;
@property (readonly) BOOL               playing;


@property (readwrite, copy) KxAudioManagerOutputBlock outputBlock;

- (BOOL) activateAudioSession;
- (void) deactivateAudioSession;
- (BOOL) play;
- (void) pause;


@end

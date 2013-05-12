//
//  KNAudioManager.m
//  PCMStreamPlayer
//
//  Created by cyh on 13. 2. 13..
//  Copyright (c) 2013년 saeha. All rights reserved.
//

#import "KNAudioManager.h"
#import <AudioToolbox/AudioToolbox.h>

static void sessionInterruptionListener(void *inClientData,
                                        UInt32 inInterruption);

static void sessionPropertyListener(void *inClientData,
                                    AudioSessionPropertyID inID,
                                    UInt32 inDataSize,
                                    const void *inData);

static OSStatus renderCallback (void *inRefCon,
                                AudioUnitRenderActionFlags	*ioActionFlags,
                                const AudioTimeStamp * inTimeStamp,
                                UInt32 inOutputBusNumber,
                                UInt32 inNumberFrames,
                                AudioBufferList* ioData);


@interface KNAudioManager() {
    AudioUnit audioUnit_;
    AudioStreamBasicDescription outputFormat_;
    
    float* outData_;
    BOOL activated_;
}
- (BOOL)checkError:(OSStatus)result message:(NSString *)message;
- (void)renderFrames:(UInt32) numFrames
              ioData:(AudioBufferList *) ioData;

@property (copy, nonatomic) NSString* audioRoute;
@property (readwrite) BOOL playAfterSessionEndInterruption;
@property AudioBufferList *inputBuffer;
@property BOOL isInterleaved;

@end

@implementation KNAudioManager

@synthesize audioRoute                      = _audioRoute;
@synthesize playAfterSessionEndInterruption = _playAfterSessionEndInterruption;
@synthesize samplingRate                    = _samplingRate;
@synthesize numOutputChannels               = _numOutputChannels;
@synthesize numBytesPerSample               = _numBytesPerSample;
@synthesize outputVolume                    = _outputVolume;
@synthesize playing                         = _playing;
@synthesize inputBuffer                     = _inputBuffer;
@synthesize isInterleaved                   = _isInterleaved;
@synthesize bufferSize                      = _bufferSize;
@synthesize outputBlock                     = _outputBlock;

- (void)dealloc {
    
    if (_outputBlock) {
        [_outputBlock release];
        _outputBlock = nil;
    }
    
    if (outData_) {
        free(outData_);
        outData_ = 0;
    }
    
    [super dealloc];
}

- (id)init {
    self = [super init];
	if (self) {
        _bufferSize = 4096;
        outData_ = (float *)malloc(_bufferSize);
        _outputVolume = 0.5;
	}
	return self;
}


- (BOOL) checkAudioRoute {

    // Check what the audio route is.
    UInt32 propertySize = sizeof(CFStringRef);
    CFStringRef route;
    OSStatus result;
    
    result = AudioSessionGetProperty(kAudioSessionProperty_AudioRoute,
                                     &propertySize,
                                     &route);
    if ([self checkError:result message:@"Couldn't check the audio route"] == NO) {
        return NO;
    }
           
    _audioRoute = CFBridgingRelease(route);
    NSLog(@"AudioRoute: %@", _audioRoute);
    
    return YES;
}

- (BOOL) setupAudio {
    
    OSStatus result;
    
    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
//    UInt32 sessionCategory = kAudioSessionCategory_PlayAndRecord;
    
    result = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
                                     sizeof(sessionCategory),
                                     &sessionCategory);
    if ([self checkError:result message:@"Couldn't set audio category"] == NO)
        return NO;
    
    
    
    result = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange,
                                             sessionPropertyListener,
                                             (void *)(self));
    if ([self checkError:result message:@"Couldn't add audio session property listener : kAudioSessionProperty_AudioRouteChange"] == NO)
        return NO;
    
    
    result = AudioSessionAddPropertyListener(kAudioSessionProperty_CurrentHardwareOutputVolume,
                                             sessionPropertyListener,
                                             (void *)(self));
    if ([self checkError:result message:@"Couldn't add audio session property listener : kAudioSessionProperty_CurrentHardwareOutputVolume"] == NO)
        return NO;
    
    
#if !TARGET_IPHONE_SIMULATOR
    Float32 preferredBufferSize = 0.0232;
    result = AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration,
                                     sizeof(preferredBufferSize),
                                     &preferredBufferSize);
    [self checkError:result message:@"Couldn't set the preferred buffer duration"];
#endif
    
    result = AudioSessionSetActive(YES);
    if ([self checkError:result message:@"Couldn't activate the audio session"] == NO)
        return NO;
    

    [self checkSessionProperties];
    

    AudioComponentDescription description = {0,};
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = kAudioUnitSubType_RemoteIO;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    

    AudioComponent component = AudioComponentFindNext(NULL, &description);
    result = AudioComponentInstanceNew(component, &audioUnit_);
    if ([self checkError:result message:@"Couldn't create the output audio unit"] == NO)
        return NO;
    
    
    UInt32 size;
	size = sizeof(AudioStreamBasicDescription);
    result = AudioUnitGetProperty(audioUnit_,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &outputFormat_,
                                  &size);
    if ([self checkError:result message:@"Couldn't get the hardware output stream format"] == NO)
        return NO;
    
    
    outputFormat_.mSampleRate = _samplingRate;
    result =  AudioUnitSetProperty(audioUnit_,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Input,
                                   0,
                                   &outputFormat_,
                                   size);
    if ([self checkError:result message:@"Couldn't set the hardware output stream format"] == NO)
        return NO;
    
    _numBytesPerSample = outputFormat_.mBitsPerChannel / 8;
    _numOutputChannels = outputFormat_.mChannelsPerFrame;
    
    NSLog(@"Current output bytes per sample: %ld", _numBytesPerSample);
    NSLog(@"Current output num channels: %ld", _numOutputChannels);
    
    
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = renderCallback;
    callbackStruct.inputProcRefCon = (void *)(self);
    result = AudioUnitSetProperty(audioUnit_,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  0,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    if ([self checkError:result message:@"Couldn't set the render callback on the audio unit"] == NO)
        return NO;
                                  
    
    
    result = AudioUnitInitialize(audioUnit_);
    if ([self checkError:result message:@"Couldn't initialize the audio unit"] == NO)
        return NO;
    
    
    AudioStreamBasicDescription streamFormat = {0,};
    streamFormat.mSampleRate        = _samplingRate;
    streamFormat.mFormatID			= kAudioFormatLinearPCM;
    streamFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    streamFormat.mFramesPerPacket	= 1;
    streamFormat.mChannelsPerFrame	= 2;
    streamFormat.mBitsPerChannel	= 16;
    streamFormat.mBytesPerPacket	= streamFormat.mChannelsPerFrame * sizeof (SInt16);
    streamFormat.mBytesPerFrame		= streamFormat.mChannelsPerFrame * sizeof (SInt16);;
    result = AudioUnitSetProperty(audioUnit_,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &streamFormat,
                                  sizeof(AudioStreamBasicDescription));
    if ([self checkError:result message:@"Couldn't initialize the audio unit"] == NO)
        return NO;

    return YES;
}

- (BOOL) checkSessionProperties
{
    [self checkAudioRoute];
    
    OSStatus result;
    UInt32 newNumChannels;
    UInt32 size = sizeof(newNumChannels);
    
    result = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareOutputNumberChannels,
                                     &size,
                                     &newNumChannels);
    if ([self checkError:result message:@"Checking number of output channels"] == NO)
        return NO;
    NSLog(@"We've got %lu output channels", newNumChannels);
    
    size = sizeof(_samplingRate);
    result = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate,
                                     &size,
                                     &_samplingRate);
    if ([self checkError:result message:@"Checking hardware sampling rate"] == NO)
        return NO;
    NSLog(@"Current sampling rate: %f", _samplingRate);
    
    
    
    size = sizeof(_outputVolume);
    result = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareOutputVolume,
                                     &size,
                                     &_outputVolume);
    if ([self checkError:result message:@"Checking current hardware output volume"] == NO)
        return NO;
    NSLog(@"Current output volume: %f", _outputVolume);

    return YES;
}



- (BOOL)checkError:(OSStatus)result message:(NSString *)message {
    
    if (result != kAudioSessionNoError) {
        NSLog(@"%@ : (ERROR : %ld)", message, result);
        return NO;
    }
    return YES;
}



- (void)renderFrames:(UInt32) numFrames
              ioData:(AudioBufferList *) ioData {

    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }

    if (_playing && _outputBlock ) {
        memset(outData_, 0, _bufferSize);
        _outputBlock(outData_, numFrames, _numOutputChannels);
        
        for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
            
            int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
            for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                memcpy(ioData->mBuffers[iBuffer].mData, outData_, _bufferSize);
            }
        }
    }
}

#pragma mark - public
- (BOOL) activateAudioSession {
    
    if (!activated_) {

        OSStatus result;
        
        result = AudioSessionInitialize(NULL,
                                        NULL,
                                        sessionInterruptionListener,
                                        (void *)(self));
        if (kAudioSessionAlreadyInitialized != result)
            [self checkError:result message:@"Couldn't initialize audio session"];
        
        if ([self checkAudioRoute] && [self setupAudio]) {
            activated_ = YES;
        }
    }
    return activated_;
}

- (void) deactivateAudioSession {
    
    if (activated_) {
        
        OSStatus result;

        [self pause];
        
        result = AudioUnitUninitialize(audioUnit_);
        [self checkError:result message:@"Couldn't uninitialize the audio unit"];
        
        result = AudioComponentInstanceDispose(audioUnit_);
        [self checkError:result message:@"Couldn't dispose the output audio unit"];

        result = AudioSessionSetActive(NO);
        [self checkError:result message:@"Couldn't deactivate the audio session"];
        
        
//        result = AudioUnitSetProperty(audioUnit_,
//                                      kAudioUnitProperty_SetRenderCallback,
//                                      kAudioUnitScope_Input,
//                                      0,
//                                      NULL,
//                                      0);
//        [self checkError:result message:@"Couldn't clear the render callback on the audio unit"];
        
        
        result = AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_AudioRouteChange,
                                                                sessionPropertyListener,
                                                                (void *)(self));
        [self checkError:result message:@"Couldn't remove audio session property listener"];

        
        result = AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_CurrentHardwareOutputVolume,
                                                                sessionPropertyListener,
                                                                (void *)(self));
        [self checkError:result message:@"Couldn't remove audio session property listener"];
        
        
        activated_ = NO;
    }
}

- (BOOL) play {
 
    if (!_playing) {
        
        if ([self activateAudioSession]) {
            
            OSStatus result = AudioOutputUnitStart(audioUnit_);
            _playing = [self checkError:result message:@"Couldn't start the output unit"];
        }
	}
    
    return _playing;
}

- (void) pause {
    
    if (_playing) {
        NSLog(@"PAUSE");
        OSStatus result = AudioOutputUnitStop(audioUnit_);
        _playing = ![self checkError:result message:@"Couldn't stop the output unit"];
	}

}

#pragma mark - callbacks
void sessionInterruptionListener(void *inClientData,
                                 UInt32 inInterruption) {
    
    KNAudioManager *sm = (KNAudioManager *)inClientData;
    
	if (inInterruption == kAudioSessionBeginInterruption) {
        
		NSLog(@"Begin interuption");
        sm.playAfterSessionEndInterruption = sm.playing;
        [sm pause];
        
	} else if (inInterruption == kAudioSessionEndInterruption) {
		
        NSLog(@"End interuption");
        if (sm.playAfterSessionEndInterruption) {
            sm.playAfterSessionEndInterruption = NO;
            [sm play];
        }
	}
}

void sessionPropertyListener(void *inClientData,
                             AudioSessionPropertyID inID,
                             UInt32 inDataSize,
                             const void *inData) {
    
    KNAudioManager *sm = (KNAudioManager *)inClientData;
    
	if (inID == kAudioSessionProperty_AudioRouteChange) {
        
        if ([sm checkAudioRoute]) {
            [sm checkSessionProperties];
        }
        
    } else if (inID == kAudioSessionProperty_CurrentHardwareOutputVolume) {
        
        if (inData && inDataSize == 4) {
            
            sm.outputVolume = *(float *)inData;
        }
    }
    
}

OSStatus renderCallback (void *inRefCon,
                         AudioUnitRenderActionFlags	*ioActionFlags,
                         const AudioTimeStamp * inTimeStamp,
                         UInt32 inOutputBusNumber,
                         UInt32 inNumberFrames,
                         AudioBufferList* ioData) {
    
    KNAudioManager *sm = (KNAudioManager *)inRefCon;
    
    if (sm->activated_ == NO)
        return 0;

    [sm renderFrames:inNumberFrames ioData:ioData];
    
    return kAudioSessionNoError;
}

@end

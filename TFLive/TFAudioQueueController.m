//
//  TFAudioQueueController.m
//  TFLive
//
//  Created by wei shi on 2017/7/4.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import "TFAudioQueueController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>



@interface TFAudioQueueController (){
    
    AudioQueueRef _audioQueue;
    AudioQueueBufferRef _audioBufferArray[TFAudioQueueBufferCount];
    
    BOOL _isPaused;
    BOOL _isStoped;
    NSLock *_lock;
}

@end

@implementation TFAudioQueueController

-(instancetype)initWithSpecifics:(const TFAudioSpecifics *)specifics{
    if (self = [super init]) {
        _specifics = *specifics;
        
        if (_specifics.format != AUDIO_S16) {
            printf("specifics's format is not signed-16-bits\n");
            self = nil;
            return nil;
        }
        if (_specifics.channels > 2) {
            NSLog(@"aout_open_audio: unsupported channels %d\n", (int)_specifics.channels);
            return nil;
        }
        
        AudioStreamBasicDescription audioDesc;
        configAudioDescWithSpecifics(&audioDesc, &_specifics);
        
        _specifics.bufferSize = SDL_AUDIO_BITSIZE(_specifics.format) / 8 * _specifics.channels * _specifics.samples;
        
        
        AudioQueueNewOutput(&audioDesc, TFAudioQueueHasEmptyBufferCallBack, (__bridge void*)self, NULL, (__bridge CFStringRef)NSRunLoopCommonModes, 0, &(_audioQueue));
        
        OSStatus status = AudioQueueStart(_audioQueue, NULL);
        if (status != noErr) {
            NSLog(@"audio queue start error");
            
            self = nil;
            return nil;
        }
        
        for (int i = 0; i<TFAudioQueueBufferCount; i++) {
            AudioQueueAllocateBuffer(_audioQueue, _specifics.bufferSize, &_audioBufferArray[i]);
            _audioBufferArray[i]->mAudioDataByteSize = _specifics.bufferSize;
            memset(_audioBufferArray[i]->mAudioData, 0, _specifics.bufferSize);
            AudioQueueEnqueueBuffer(_audioQueue, _audioBufferArray[i], 0, NULL);
        }
        
        _isStoped = NO;
        _isPaused = NO;
        _lock = [[NSLock alloc] init];
    }
    
    return self;
}

static void configAudioDescWithSpecifics(AudioStreamBasicDescription *audioDesc, TFAudioSpecifics *specifics){
    
    audioDesc->mSampleRate = specifics->sampleRate;
    audioDesc->mFormatID = kAudioFormatLinearPCM;
    audioDesc->mFormatFlags = kLinearPCMFormatFlagIsPacked;
    audioDesc->mFramesPerPacket = 1;
    audioDesc->mChannelsPerFrame = specifics->channels;
    
    audioDesc->mBitsPerChannel = SDL_AUDIO_BITSIZE(specifics->format);
    if (SDL_AUDIO_ISBIGENDIAN(specifics->format))
        audioDesc->mFormatFlags |= kLinearPCMFormatFlagIsBigEndian;
    if (SDL_AUDIO_ISFLOAT(specifics->format))
        audioDesc->mFormatFlags |= kLinearPCMFormatFlagIsFloat;
    if (SDL_AUDIO_ISSIGNED(specifics->format))
        audioDesc->mFormatFlags |= kLinearPCMFormatFlagIsSignedInteger;
    
    audioDesc->mBytesPerFrame = audioDesc->mBitsPerChannel * audioDesc->mChannelsPerFrame / 8;
    audioDesc->mBytesPerPacket = audioDesc->mBytesPerFrame * audioDesc->mFramesPerPacket;
    
    
}

-(void)play{
    if (!_audioQueue) {
        return;
    }
    
    [_lock lock];
    
    if (!_isPaused && !_isStoped) {
        [_lock unlock];
        return;
    }
    
    NSError *error;
    
    if ([[AVAudioSession sharedInstance] setActive:YES error:&error]) {
        NSLog(@"audio session active error: %@",error);
        [_lock unlock];
        return;
    }
    
    OSStatus status = AudioQueueStart(_audioQueue, NULL);
    if (status != noErr) {
        NSLog(@"audio queue start error");
        [_lock unlock];
        return;
    }
    
    _isPaused = NO;
    _isStoped = NO;
    
    
    
    [_lock unlock];
}

-(void)pause{
    [_lock lock];
    
    if (!_isPaused) {
        [_lock unlock];
        return;
    }
    
    AudioQueuePause(_audioQueue);
    _isPaused = YES;
    
    [_lock unlock];
}

-(void)stop{
    [_lock lock];
    
    if (_isStoped) {
        [_lock unlock];
        return;
    }
    
    AudioQueueStop(_audioQueue, YES);
    _isStoped = YES;
    
    [_lock unlock];
}

static void TFAudioQueueHasEmptyBufferCallBack(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer){
    TFAudioQueueController *controller = (__bridge TFAudioQueueController *)(inUserData);
    
    if (!controller) {
        return;
    }
    if (controller->_isStoped || controller->_isPaused) {
        return;
    }
    
    if (controller.specifics.fillBufferfunc) {
        int retval = controller.specifics.fillBufferfunc(inBuffer->mAudioData, inBuffer->mAudioDataByteSize, controller.specifics.callbackData);
        if (retval == -1) {
            return;
        }
        
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    }
}

-(void)dealloc{
    NSLog(@"AUDIO QUEUE DEALLOCED");
}

@end

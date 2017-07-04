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

#define TFAudioQueueBufferCount     3

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
        
        AudioStreamBasicDescription audioDesc;
        configAudioDescWithSpecifics(&audioDesc, &_specifics);
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
    
    //TODO: format
    audioDesc->mBitsPerChannel = 0xff;
    
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

@end

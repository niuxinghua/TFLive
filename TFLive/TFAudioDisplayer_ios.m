//
//  TFAudioDisplayer_ios.c
//  TFLive
//
//  Created by wei shi on 2017/7/4.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#include "TFAudioDisplayer_ios.h"
#import "TFAudioQueueController.h"

int openAudio(TFAudioDisplayer *audioDisplayer, TFAudioSpecifics *wantedAudioSpec, TFAudioSpecifics *feasiableSpec);
int closeAudio(TFAudioDisplayer *audioDisplayer);
int bufferCallbackTimesPerSecond(TFAudioDisplayer *audioDisplayer);

TFAudioDisplayer *createAudioDisplayer(){
    TFAudioDisplayer *audioDisplayer = malloc(sizeof(TFAudioDisplayer));
    memset(audioDisplayer, 0, sizeof(TFAudioDisplayer));
    
    audioDisplayer->openAudio = openAudio;
    audioDisplayer->closeAudio = closeAudio;
    audioDisplayer->bufferCallbackTimesPerSecond = bufferCallbackTimesPerSecond;
    
    return audioDisplayer;
}

TFAudioQueueController *strongAQController = nil;
int openAudio(TFAudioDisplayer *audioDisplayer, TFAudioSpecifics *wantedAudioSpec, TFAudioSpecifics *feasiableSpec){
    TFAudioQueueController *AQController = [[TFAudioQueueController alloc] initWithSpecifics:wantedAudioSpec];
    
    audioDisplayer->audioQueue = (__bridge void *)(AQController);
    
    if (!AQController) {
        return -1;
    }
    
    *feasiableSpec = AQController.specifics;
    
    strongAQController = AQController;
    
    return 0;
}

int bufferCallbackTimesPerSecond(TFAudioDisplayer *audioDisplayer){
    return 15;
}

int closeAudio(TFAudioDisplayer *audioDisplayer){
    
    TFAudioQueueController *AQController = (__bridge TFAudioQueueController *)(audioDisplayer->audioQueue);
    [AQController stop];
    
    strongAQController = nil;
    
    return 0;
}


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

TFAudioDisplayer *createAudioDisplayer(){
    TFAudioDisplayer *audioDisplayer = malloc(sizeof(TFAudioDisplayer));
    memset(audioDisplayer, 0, sizeof(TFAudioDisplayer));
    
    audioDisplayer->openAudio = openAudio;
    
    return audioDisplayer;
}

int openAudio(TFAudioDisplayer *audioDisplayer, TFAudioSpecifics *wantedAudioSpec, TFAudioSpecifics *feasiableSpec){
    TFAudioQueueController *AQController = [[TFAudioQueueController alloc] initWithSpecifics:wantedAudioSpec];
    
    audioDisplayer->audioQueue = (__bridge void *)(AQController);
    
    if (!AQController) {
        return -1;
    }
    
    *feasiableSpec = AQController.specifics;
    
    return 0;
}


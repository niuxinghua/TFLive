//
//  TFVideoDisplayer_ios.c
//  TFLive
//
//  Created by wei shi on 2017/7/4.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#include "TFVideoDisplayer_ios.h"
#import "TFDisplayView.h"

int fillVideoFrameFunc(TFOverlay *overlay, const AVFrame *frame){
    overlay->width = frame->width;
    overlay->height = frame->height;
    
    for (int i = 0; i < AV_NUM_DATA_POINTERS; ++i) {
        overlay->pixels[i] = frame->data[i];
        overlay->linesize[i] = frame->linesize[i];
    }
    overlay->format = frame->format;
    
    return 0;
}

TFOverlay *voutOverlayCreate(){
    TFOverlay *overlay = av_mallocz(sizeof(TFOverlay));
    overlay->fillVideoFrameFunc = fillVideoFrameFunc;
    
    return overlay;
}

int displayOverlay(TFVideoDisplayer *displayer, TFOverlay *overlay){
    TFDisplayView *dispalyView = (__bridge TFDisplayView *)(displayer->displayView);
    [dispalyView displayOverlay:overlay];
    
    return 0;
}


TFVideoDisplayer *VideoDisplayCreate(void *displayView){
    TFVideoDisplayer *display = av_mallocz(sizeof(TFVideoDisplayer));
    display->createOverlay = voutOverlayCreate;
    display->displayOverlay = displayOverlay;
    display->displayView = displayView;
    
    return display;
}

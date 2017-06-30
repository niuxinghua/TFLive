//
//  TFDisplay.m
//  TFLive
//
//  Created by wei shi on 2017/6/30.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import "TFDisplay.h"
#include "mem.h"
#include "avformat.h"
#include "avcodec.h"
#import <CoreVideo/CoreVideo.h>

#include "TFDisplayView.h"


inline static TFOverlay *voutOverlayCreate();

TFFrameDisplayer *frameDisplayCreate(void *displayView){
    TFFrameDisplayer *display = av_mallocz(sizeof(TFFrameDisplayer));
    display->createOverlay = voutOverlayCreate;
    display->displayOverlay = displayOverlay;
    display->displayView = displayView;
    
    return display;
}

int func_fill_frame(TFOverlay *overlay, const AVFrame *frame){
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
    overlay->func_fill_frame = func_fill_frame;
    
    return overlay;
}

int displayOverlay(TFFrameDisplayer *displayer, TFOverlay *overlay){
    TFDisplayView *dispalyView = (__bridge TFDisplayView *)(displayer->displayView);
    [dispalyView displayOverlay:overlay];
    
    return 0;
}

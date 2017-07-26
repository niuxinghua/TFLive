//
//  TFVideoDisplayer_ios.c
//  TFLive
//
//  Created by wei shi on 2017/7/4.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#include "TFVideoDisplayer_ios.h"
#include <libavutil/time.h>
#if TFVIDEO_DISPLAYER_IOS_OPENGLES
#import "TFOPGLESDisplayView.h"
#else
#import "TFImageDisplayView.h"
#endif
#import "TFTime.h"

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
    TFOverlay *overlay = (TFOverlay*)av_mallocz(sizeof(TFOverlay));
#if DEBUG
    overlay->identifier = av_gettime_relative();
#endif
    overlay->fillVideoFrameFunc = fillVideoFrameFunc;
    
    return overlay;
}

double lastTime = 0;
int displayOverlay(TFVideoDisplayer *displayer, TFOverlay *overlay){
    
//    double curTime = machTimeToSecs(mach_absolute_time());
//    printf("delta: %.1f\n",1/(curTime - lastTime));
//    lastTime = curTime;
    
#if TFVIDEO_DISPLAYER_IOS_OPENGLES
        TFOPGLESDisplayView *displayView = (__bridge TFOPGLESDisplayView *)(displayer->displayView);
        [displayView displayOverlay:overlay];
#else
        TFImageDisplayView *dispalyView = (__bridge TFImageDisplayView *)(displayer->displayView);
        [dispalyView displayOverlay:overlay];
#endif
        av_free(overlay);
            
    return 0;
}


TFVideoDisplayer *VideoDisplayCreate(void *displayView){
    TFVideoDisplayer *display = (TFVideoDisplayer*)av_mallocz(sizeof(TFVideoDisplayer));
    display->createOverlay = voutOverlayCreate;
    display->displayOverlay = displayOverlay;
    display->displayView = displayView;
    
    return display;
}

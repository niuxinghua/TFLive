//
//  TFDisplay.h
//  TFLive
//
//  Created by wei shi on 2017/6/30.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#ifndef TFDisplay_h
#define TFDisplay_h

#import <Foundation/Foundation.h>
#include "avcodec.h"
//#include "TFDisplayView.h"

typedef struct TFOverlay TFOverlay;
typedef struct TFFrameDisplayer TFFrameDisplayer;

struct TFOverlay {
    int width;
    int height;
    UInt32 format;
    
    UInt8 *pixels[AV_NUM_DATA_POINTERS];
    UInt16 linesize[AV_NUM_DATA_POINTERS];
    
    
    int (*func_fill_frame)(TFOverlay *overlay, const AVFrame *frame);
};

struct TFFrameDisplayer{
    
    void *displayView;
    
    TFOverlay *(*createOverlay)();
    int (*displayOverlay)(TFFrameDisplayer *displayer, TFOverlay *overlay);
};

int displayOverlay(TFFrameDisplayer *displayer, TFOverlay *overlay);

TFFrameDisplayer *frameDisplayCreate(void *displayView);

#endif /* TFDisplay_h */

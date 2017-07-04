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

/***** video display *****/

typedef struct TFOverlay TFOverlay;
typedef struct TFVideoDisplayer TFVideoDisplayer;

typedef struct TFAudioDisplayer TFAudioDisplayer;

struct TFOverlay {
    int width;
    int height;
    UInt32 format;
    int planes;
    
    UInt8 *pixels[AV_NUM_DATA_POINTERS];
    UInt16 linesize[AV_NUM_DATA_POINTERS];
    
    
    int (*fillVideoFrameFunc)(TFOverlay *overlay, const AVFrame *frame);
};

struct TFVideoDisplayer{
    
    void *displayView;
    
    TFOverlay *(*createOverlay)();
    int (*displayOverlay)(TFVideoDisplayer *displayer, TFOverlay *overlay);
};

/***** audio display *****/

/**
 填充音频buffer的函数指针
 
 @param buffer  将要被填充的音频buffer
 @param len     被填充的buffer的长度
 @param data    自定义内容，在回调时被传回,值为TFAudioSpecifics的callbackData
 @return        返回处理结果，成功为0，-1为播放结束
 */
typedef int (*TFFillAudioBufferFunc)(UInt8 *buffer, int len, void *data);

typedef struct AudioParams {
    int freq;
    int channels;
    int64_t channel_layout;
    enum AVSampleFormat fmt;
    int frame_size;
    int bytes_per_sec;
} AudioParams;

//音频数据格式的特征，在流程上属于音频数据的抽象
typedef struct TFAudioSpecifics{
    uint32_t format;
    int sampleRate;
    uint8_t channels;
    
    uint32_t bufferSize;
    
    void *callbackData;
    TFFillAudioBufferFunc fillBufferfunc;
    
}TFAudioSpecifics;

struct TFAudioDisplayer {
    void *audioQueue;
    
    int (*openAudio)(TFAudioDisplayer *audioDisplayer, TFAudioSpecifics *wantedAudioSpec, TFAudioSpecifics *feasiableSpec);
};

#endif /* TFDisplay_h */

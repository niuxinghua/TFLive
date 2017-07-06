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
    
#if DEBUG
    uint64_t identifier;
#endif
    
    int (*fillVideoFrameFunc)(TFOverlay *overlay, const AVFrame *frame);
};

struct TFVideoDisplayer{
    
    void *displayView;
    
    TFOverlay *(*createOverlay)();
    int (*displayOverlay)(TFVideoDisplayer *displayer, TFOverlay *overlay);
};

/***** audio display *****/

typedef uint16_t SDL_AudioFormat;

#define SDL_AUDIO_MASK_BITSIZE       (0xFF)
#define SDL_AUDIO_MASK_DATATYPE      (1<<8)
#define SDL_AUDIO_MASK_ENDIAN        (1<<12)
#define SDL_AUDIO_MASK_SIGNED        (1<<15)
#define SDL_AUDIO_BITSIZE(x)         (x & SDL_AUDIO_MASK_BITSIZE)
#define SDL_AUDIO_ISFLOAT(x)         (x & SDL_AUDIO_MASK_DATATYPE)
#define SDL_AUDIO_ISBIGENDIAN(x)     (x & SDL_AUDIO_MASK_ENDIAN)
#define SDL_AUDIO_ISSIGNED(x)        (x & SDL_AUDIO_MASK_SIGNED)
#define SDL_AUDIO_ISINT(x)           (!SDL_AUDIO_ISFLOAT(x))
#define SDL_AUDIO_ISLITTLEENDIAN(x)  (!SDL_AUDIO_ISBIGENDIAN(x))
#define SDL_AUDIO_ISUNSIGNED(x)      (!SDL_AUDIO_ISSIGNED(x))

#define AUDIO_INVALID   0x0000
#define AUDIO_U8        0x0008  /**< Unsigned 8-bit samples */
#define AUDIO_S8        0x8008  /**< Signed 8-bit samples */
#define AUDIO_U16LSB    0x0010  /**< Unsigned 16-bit samples */
#define AUDIO_S16LSB    0x8010  /**< Signed 16-bit samples */
#define AUDIO_U16MSB    0x1010  /**< As above, but big-endian byte order */
#define AUDIO_S16MSB    0x9010  /**< As above, but big-endian byte order */
#define AUDIO_U16       AUDIO_U16LSB
#define AUDIO_S16       AUDIO_S16LSB

#define AUDIO_S32LSB    0x8020  /**< 32-bit integer samples */
#define AUDIO_S32MSB    0x9020  /**< As above, but big-endian byte order */
#define AUDIO_S32       AUDIO_S32LSB

#define AUDIO_F32LSB    0x8120  /**< 32-bit floating point samples */
#define AUDIO_F32MSB    0x9120  /**< As above, but big-endian byte order */
#define AUDIO_F32       AUDIO_F32LSB

#if SDL_BYTEORDER == SDL_LIL_ENDIAN
#define AUDIO_U16SYS    AUDIO_U16LSB
#define AUDIO_S16SYS    AUDIO_S16LSB
#define AUDIO_S32SYS    AUDIO_S32LSB
#define AUDIO_F32SYS    AUDIO_F32LSB
#else
#define AUDIO_U16SYS    AUDIO_U16MSB
#define AUDIO_S16SYS    AUDIO_S16MSB
#define AUDIO_S32SYS    AUDIO_S32MSB
#define AUDIO_F32SYS    AUDIO_F32MSB
#endif


#define AUDIO_DEFAULT_BUFFER_TIMES_PER_SECOND       30

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
    int samples;
    //uint32_t bitsPerChannel;
    
    uint32_t bufferSize;
    
    void *callbackData;
    TFFillAudioBufferFunc fillBufferfunc;
    
    
}TFAudioSpecifics;

struct TFAudioDisplayer {
    void *audioQueue;
    
    int (*openAudio)(TFAudioDisplayer *audioDisplayer, TFAudioSpecifics *wantedAudioSpec, TFAudioSpecifics *feasiableSpec);
    int (*closeAudio)(TFAudioDisplayer *audioDisplayer);
    
    //提供每秒fillbuffer回调的次数，sample_rate/这个数量 = 每次fillbuffer的sample数，决定了buffer的大小。
    int (*bufferCallbackTimesPerSecond)(TFAudioDisplayer *audioDisplayer);
};

#endif /* TFDisplay_h */

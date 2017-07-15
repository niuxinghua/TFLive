//
//  TFSyncClock.h
//  TFLive
//
//  Created by shiwei on 2017/7/8.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#ifndef TFSyncClock_h
#define TFSyncClock_h

#include <stdio.h>
#include <avcodec.h>

enum TFSyncClockType{
    TFSyncClockTypeAudio,
    TFSyncClockTypeVideo
};

typedef struct TFSyncClock TFSyncClock;
struct TFSyncClock {
    uint64_t lastFrameTime;      //the time of display last frame in macrosecond.
    
    enum TFSyncClockType type;
    
    //video params
    uint64_t lastVideoPts;
    
    //audio params

    double ptsRealTimeDiff;
    
    uint64_t samplesRate;
    
};

double nextVideoTimeAdjustByClock(TFSyncClock *clock, double nextPts);

#endif /* TFSyncClock_h */

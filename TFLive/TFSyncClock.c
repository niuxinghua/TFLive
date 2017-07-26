//
//  TFSyncClock.c
//  TFLive
//
//  Created by shiwei on 2017/7/8.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#include "TFSyncClock.h"
#include "time.h"

//音频或视频开始后才会有ptsRealTimeDiff，之前这个钟是不起作用的
double nextVideoTimeAdjustByClock(TFSyncClock *clock, double nextPts){
    if (clock->ptsRealTimeDiff <= 0) {
        printf("ptsRealTimeDiff undefined\n");
        return -1;
    }
    double nextPts2 = (nextPts + clock->ptsRealTimeDiff);
    
    return nextPts2;
}

//
//  TFSyncClock.c
//  TFLive
//
//  Created by shiwei on 2017/7/8.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#include "TFSyncClock.h"
#include "time.h"

double nextVideoTimeAdjustByClock(TFSyncClock *clock, double nextPts){
    
    double nextPts2 = (nextPts + clock->ptsRealTimeDiff);
    
    return nextPts2;
}

//
//  TFTime.c
//  SmoothnessTest
//
//  Created by shiwei on 2017/7/21.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#include "TFTime.h"

double machTimeToSecs(uint64_t time)
{
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    return (double)time * (double)timebase.numer /
    (double)timebase.denom /1e9;
}

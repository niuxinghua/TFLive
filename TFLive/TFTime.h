//
//  TFTime.h
//  SmoothnessTest
//
//  Created by shiwei on 2017/7/21.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#ifndef TFTime_h
#define TFTime_h

#import <mach/mach_time.h>

double machTimeToSecs(uint64_t time);

#define TFTIME_TAG_NAME(index)  time_tag_##index

#define TFTIME_TAG(index)   uint64_t TFTIME_TAG_NAME(index) = mach_absolute_time();\

#define TFTIME_TAG_AND_LOG_DELTA(index1, index2)        \
    uint64_t TFTIME_TAG_NAME(index2) = mach_absolute_time();\
    NSLog(@"time%d->time%d: %.6f",index1,index2,machTimeToSecsTFTIME_TAG_NAME(index2) - TFTIME_TAG_NAME(index1));\

#define TFTIME_TAG_AND_LOG_DELTA_TEXT(index1, index2, text)  \
    uint64_t TFTIME_TAG_NAME(index2) = mach_absolute_time();\
    NSLog(@"%s: %.6f\n",text,machTimeToSecs(TFTIME_TAG_NAME(index2) - TFTIME_TAG_NAME(index1)));\


#endif /* TFTime_h */

//
//  TFLivePlayController.m
//  TFLive
//
//  Created by wei shi on 2017/6/28.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import "TFLivePlayController.h"
#import "TFThreadConvience.h"
#import "mem.h"

@implementation TFLivePlayController

-(instancetype)initWithLiveURL:(NSURL *)liveURL{
    if (self = [super init]) {
        self.liveURL = liveURL;
        
        [self playerInit];
    }
    
    return self;
}

int threadTestFunc(void * data){
    char *str = (char*)data;
    printf("%s",str);
    
    return 1;
}

-(void)playerInit{
    TFSDL_thread thread1;
    char *data = (char *)av_mallocz(sizeof(char *) * 30);
    strcpy(data, "文案v5");
    
    TFSDL_createThreadEx(&thread1, threadTestFunc, data, "test-thread");
}

-(void)prepareToPlay{
    
}

-(void)stop{
    
}

@end

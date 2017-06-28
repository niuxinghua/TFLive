//
//  TFThreadConvience.h
//  TFLive
//
//  Created by wei shi on 2017/6/28.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#ifndef TFThreadConvience_h
#define TFThreadConvience_h

#import <Foundation/Foundation.h>
#import <pthread.h>

typedef struct TFSDL_thread{
    pthread_t thread_id;
    int (*func)(void *);
    void *data;
    char name[32];
    int retval;
}TFSDL_thread;

TFSDL_thread *TFSDL_createThreadEx(TFSDL_thread *thread, int(*func)(void*), void* data, const char *name);

#endif /* TFThreadConvience_h */

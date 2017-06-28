//
//  TFThreadConvience.m
//  TFLive
//
//  Created by wei shi on 2017/6/28.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import "TFThreadConvience.h"

static void *SDL_RunThread(void *data)
{
    @autoreleasepool {
        TFSDL_thread *thread = data;
        pthread_setname_np(thread->name);
        thread->retval = thread->func(thread->data);
        return NULL;
    }
}
TFSDL_thread *TFSDL_createThreadEx(TFSDL_thread *thread, int(*func)(void*), void* data, const char *name){
    thread->func = func;
    thread->data = data;
    strcpy(thread->name, name);
    
    int val = pthread_create(&thread->thread_id, NULL, SDL_RunThread, thread);
    if (val) {
        return NULL;
    }
    return thread;
}

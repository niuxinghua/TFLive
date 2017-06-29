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


//lock

typedef struct TFSDL_mutex {
    pthread_mutex_t id;
} TFSDL_mutex;

TFSDL_mutex *TFSDL_CreateMutex(void);

void TFSDL_DestroyMutex(TFSDL_mutex *mutex);

void TFSDL_DestroyMutexP(TFSDL_mutex **mutex);

int TFSDL_LockMutex(TFSDL_mutex *mutex);

int TFSDL_UnlockMutex(TFSDL_mutex *mutex);



#endif /* TFThreadConvience_h */

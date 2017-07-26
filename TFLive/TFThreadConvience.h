//
//  TFThreadConvience.h
//  TFLive
//
//  Created by wei shi on 2017/6/28.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#ifndef TFThreadConvience_h
#define TFThreadConvience_h


#import <pthread.h>

typedef struct TFSDL_thread{
    pthread_t thread_id;
    int (*func)(void *);
    void *data;
    char name[32];
    int retval;
}TFSDL_thread;

typedef struct SDL_cond {
    pthread_cond_t id;
} TFSDL_cond;


TFSDL_thread *TFSDL_createThreadEx(TFSDL_thread *thread, int(*func)(void*), void* data, const char *name);

void TFSDL_exitThread(TFSDL_thread *thread);


//lock

typedef struct TFSDL_mutex {
    pthread_mutex_t id;
} TFSDL_mutex;

TFSDL_mutex *TFSDL_CreateMutex(void);

void TFSDL_DestroyMutex(TFSDL_mutex *mutex);
void TFSDL_DestroyMutexP(TFSDL_mutex **mutex);
int TFSDL_LockMutex(TFSDL_mutex *mutex);
int TFSDL_UnlockMutex(TFSDL_mutex *mutex);



TFSDL_cond *TFSDL_CreateCond(void);
void TFSDL_DestroyCond(TFSDL_cond *cond);
void TFSDL_DestroyCondP(TFSDL_cond **mutex);
int TFSDL_CondSignal(TFSDL_cond *cond);
int TFSDL_CondBroadcast(TFSDL_cond *cond);
int TFSDL_CondWait(TFSDL_cond *cond, TFSDL_mutex *mutex);


#endif /* TFThreadConvience_h */

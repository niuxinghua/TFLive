//
//  TFThreadConvience.m
//  TFLive
//
//  Created by wei shi on 2017/6/28.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import "TFThreadConvience.h"
#import <Foundation/Foundation.h>

static void *SDL_RunThread(void *data)
{
    @autoreleasepool {
        TFSDL_thread *thread = data;
        pthread_setname_np(thread->name);
        thread->retval = thread->func(thread->data);
        
        printf("%s end*** \n",thread->name);
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

/***** lock *****/

inline static void *mallocz(size_t size)
{
    void *mem = malloc(size);
    if (!mem)
        return mem;
    
    memset(mem, 0, size);
    return mem;
}

TFSDL_mutex *TFSDL_CreateMutex(void)
{
    TFSDL_mutex *mutex;
    mutex = (TFSDL_mutex *) mallocz(sizeof(TFSDL_mutex));
    if (!mutex)
        return NULL;
    
    if (pthread_mutex_init(&mutex->id, NULL) != 0) {
        free(mutex);
        return NULL;
    }
    
    return mutex;
}

void TFSDL_DestroyMutex(TFSDL_mutex *mutex)
{
    if (mutex) {
        pthread_mutex_destroy(&mutex->id);
        free(mutex);
    }
}

void TFSDL_DestroyMutexP(TFSDL_mutex **mutex)
{
    if (mutex) {
        TFSDL_DestroyMutex(*mutex);
        *mutex = NULL;
    }
}

int TFSDL_UnlockMutex(TFSDL_mutex *mutex)
{
    assert(mutex);
    if (!mutex)
        return -1;
    
    return pthread_mutex_unlock(&mutex->id);
}

int TFSDL_LockMutex(TFSDL_mutex *mutex)
{
    assert(mutex);
    if (!mutex)
        return -1;
    
    return pthread_mutex_lock(&mutex->id);
}


/***** condition *****/

TFSDL_cond *TFSDL_CreateCond(void)
{
    TFSDL_cond *cond;
    cond = (TFSDL_cond *) mallocz(sizeof(TFSDL_cond));
    if (!cond)
        return NULL;
    
    if (pthread_cond_init(&cond->id, NULL) != 0) {
        free(cond);
        return NULL;
    }
    
    return cond;
}

void TFSDL_DestroyCond(TFSDL_cond *cond)
{
    if (cond) {
        pthread_cond_destroy(&cond->id);
        free(cond);
    }
}

void TFSDL_DestroyCondP(TFSDL_cond **cond)
{
    
    if (cond) {
        TFSDL_DestroyCond(*cond);
        *cond = NULL;
    }
}

int TFSDL_CondSignal(TFSDL_cond *cond)
{
    assert(cond);
    if (!cond)
        return -1;
    
    return pthread_cond_signal(&cond->id);
}

int TFSDL_CondBroadcast(TFSDL_cond *cond)
{
    assert(cond);
    if (!cond)
        return -1;
    
    return pthread_cond_broadcast(&cond->id);
}

int TFSDL_CondWait(TFSDL_cond *cond, TFSDL_mutex *mutex)
{
    assert(cond);
    assert(mutex);
    if (!cond || !mutex)
        return -1;
    
    return pthread_cond_wait(&cond->id, &mutex->id);
}





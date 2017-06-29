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




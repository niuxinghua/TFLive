//
//  TFFFplayer.c
//  TFLive
//
//  Created by wei shi on 2017/6/30.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#include "TFFFplayer.h"
#include "TFAudioQueueController.h"

#pragma mark - definitions

void startReadPackets(TFVideoState *videoState);
int decodeStream(TFLivePlayer *player, int streamIndex);

void packetQueueInit(TFPacketQueue *pktQueue, char *name);
void packetQueuePut(TFPacketQueue *pktQueue, AVPacket *pkt);
AVPacket* packetQueueGet(TFPacketQueue *pktQueue, bool *finished);
void packetQueueDestory(TFPacketQueue *pktQueue);

void frameQueueInit(TFFrameQueue *frameQueue, char *name);
void frameQueuePut(TFFrameQueue *frameQueue, AVFrame *frame, void *data);
TFFrame* frameQueueGet(TFFrameQueue *frameQueue, bool *finished);
void frameQueueDestory(TFFrameQueue *frameQueue);

inline static TFFrame *TFVideoFrameFillOrAlloc(TFFrame *compositeFrame, AVFrame *originalFrame, void *data);
inline static TFFrame *TFAudioFrameConvert(TFFrame *compositeFrame, AVFrame *originalFrame, void *data);

int audioOpen(TFLivePlayer *player, int64_t wanted_channel_layout, int wanted_nb_channels, int wanted_sample_rate, AudioParams *resultAudioParams);

#pragma mark -

int findStreams(void *data){
    
    TFLivePlayer *player = data;
    TFVideoState *videoState = player->videoState;
    
    AVFormatContext *formatCtx = avformat_alloc_context();
    if (avformat_open_input(&formatCtx, videoState->filename, NULL, NULL) != 0) {
        printf("open stream failed");
        return -1;
    }
    
    if (avformat_find_stream_info(formatCtx, NULL) != 0) {
        printf("find stream info failed");
        return -1;
    }
    int nb_streams = formatCtx->nb_streams;
    printf("after nb_streams: %d",nb_streams);
    
    videoState->formatCtx = formatCtx;
    
    //find stream by type
    int streamIndex[AVMEDIA_TYPE_NB];
    memset(streamIndex, -1, sizeof(streamIndex));
    
    streamIndex[AVMEDIA_TYPE_VIDEO] = av_find_best_stream(formatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    streamIndex[AVMEDIA_TYPE_AUDIO] = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
    streamIndex[AVMEDIA_TYPE_SUBTITLE] = av_find_best_stream(formatCtx, AVMEDIA_TYPE_SUBTITLE, -1, -1, NULL, 0);
    
    //video
    if (streamIndex[AVMEDIA_TYPE_VIDEO] >= 0) {
        decodeStream(player, streamIndex[AVMEDIA_TYPE_VIDEO]);
        
        //subtitle
        if (streamIndex[AVMEDIA_TYPE_SUBTITLE] >= 0) {
            decodeStream(player, streamIndex[AVMEDIA_TYPE_SUBTITLE]);
        }
    }
    
    //audio
    if (streamIndex[AVMEDIA_TYPE_AUDIO] >= 0) {
        decodeStream(player, streamIndex[AVMEDIA_TYPE_AUDIO]);
    }
    
    startReadPackets(videoState);
    
    return 0;
}

int decodeStream(TFLivePlayer *player, int streamIndex){
    
    TFVideoState *videoState = player->videoState;
    AVFormatContext *formatCtx = videoState->formatCtx;
    
    AVCodecContext *codecCtx = avcodec_alloc_context3(NULL);
    int retval = avcodec_parameters_to_context(codecCtx, formatCtx->streams[streamIndex]->codecpar);
    
    if (retval) {
        printf("con't set codec parameters to codec context");
        avcodec_free_context(&codecCtx);
        return -1;
    }
    
    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
    if (!codec ) {
        printf("No codec could be found with id %d",codecCtx->codec_id);
        avcodec_free_context(&codecCtx);
        return -1;
    }
    if (avcodec_open2(codecCtx, codec, NULL) < 0) {
        printf("open codec error");
        return -1;
    }
    
    //is it not accurate？
    codecCtx->codec_id = codec->id;
    if (codec->type == AVMEDIA_TYPE_VIDEO) {
        
        videoState->videoStreamIndex = streamIndex;
        videoState->videoStream = formatCtx->streams[streamIndex];
        
        packetQueueInit(&videoState->videoPktQueue, "视频packet");
        frameQueueInit(&videoState->videoFrameQueue, "视频frame");
        videoState->videoFrameQueue.convertFunc = TFVideoFrameFillOrAlloc;
        
        //init decoder
        videoState->videoFrameDecoder = frameDecoderInit(codecCtx);
        TFSDL_createThreadEx(&videoState->videoFrameDecoder->frameReadThread, videoFrameRead, player, "videoFrameRead");
        
    }else if (codec->type == AVMEDIA_TYPE_AUDIO){
        
        videoState->audioStreamIndex = streamIndex;
        videoState->audioStream = formatCtx->streams[streamIndex];
        
        packetQueueInit(&videoState->audioPktQueue, "音频packet");
        frameQueueInit(&videoState->audioFrameQueue, "音频frame");
        videoState->audioFrameQueue.convertFunc = TFAudioFrameConvert;
        
        //audio open
        audioOpen(player, codecCtx->channel_layout, codecCtx->channels, codecCtx->sample_rate, &videoState->targetAudioParams);
        videoState->sourceAudioParams = videoState->targetAudioParams;
        
        videoState->audioFrameDecoder = frameDecoderInit(codecCtx);
        TFSDL_createThreadEx(&videoState->audioFrameDecoder->frameReadThread, audioFrameRead, player, "audioFrameRead");
        
    }else if (codec->type == AVMEDIA_TYPE_SUBTITLE){
        
    }
    
    return 0;
}

#pragma mark - packet queue

void startReadPackets(TFVideoState *videoState){
    
    AVFormatContext *formatCtx = videoState->formatCtx;
    AVPacket pkt1, *pkt = &pkt1;
    
    while (!videoState->abortRequest) {
        
        if (!videoState->videoPktQueue.canInsert) {
            continue;
        }
        
        //printf("%s",formatCtx == NULL ?"formatCtx is null\n": "read packet\n");
        //printf("*************\n");
        int retval = av_read_frame(formatCtx, pkt);
        //printf("read packet ended\n");
        if (retval < 0) {
            if (retval == AVERROR_EOF) {
                //printf("read frame ended");
            }
            
            continue;
        }
        
        if (pkt->stream_index == videoState->videoStreamIndex) {
            
            packetQueuePut(&videoState->videoPktQueue, pkt);
            
        }else if (pkt->stream_index == videoState->audioStreamIndex){
            packetQueuePut(&videoState->audioPktQueue, pkt);
        }
        
    }
    
    videoState->videoPktQueue.abortRequest = true;
}

void packetQueueInit(TFPacketQueue *pktQueue, char *name){
    
    pktQueue->initilized = true;
    
    strcpy(pktQueue->name, name);
    pktQueue->mutex = TFSDL_CreateMutex();
    pktQueue->maxAllocCount = kMaxAllocPacketNodeCount;
    pktQueue->canInsert = true;
    
    TFPacketNode *head = av_mallocz(sizeof(TFPacketNode));
    pktQueue->usedPacketNodeLast = head;
    pktQueue->recyclePacketNodeLast = head;
    
    //first init 30 nodes
    TFPacketNode *cur = head;
    for (int i = 1; i<kMaxAllocPacketNodeCount/10; i++) {
        TFPacketNode *node = av_mallocz(sizeof(TFPacketNode));
        node->pre = cur;
        cur->next = node;
        cur = node;
    }
    
    //cycle the link
    head->pre = cur;
    cur->next = head;
    
    pktQueue->allocCount = 10;
    pktQueue->recycleCount = 10;
}

void packetQueuePut(TFPacketQueue *pktQueue, AVPacket *pkt){
    //printf("will put packet");
    TFSDL_LockMutex(pktQueue->mutex);
    
    //Alloc and insert new node if recycle node has used up.
    if (pktQueue->recycleCount == 0) {
        
        //recyclePacketNodeLast->pre == usedPacketNodeLast
        TFPacketNode *node = av_mallocz(sizeof(TFPacketNode));
        
        pktQueue->recyclePacketNodeLast->next->pre = node;
        node->next = pktQueue->recyclePacketNodeLast->next;
        
        node->pre = pktQueue->usedPacketNodeLast;
        pktQueue->usedPacketNodeLast->next = node;
        
        pktQueue->recyclePacketNodeLast = node;
        
        pktQueue->allocCount ++;
        pktQueue->recycleCount ++;
        
        //printf("alloc new packet");
        
        if (pktQueue->allocCount >= pktQueue->maxAllocCount) {
            pktQueue->canInsert = false;
        }
    }
    
    //sorting packets by dts
    TFPacketNode *curPkt = pktQueue->recyclePacketNodeLast->next;
    TFPacketNode *insertMarkPkt = NULL;
    while (curPkt != pktQueue->usedPacketNodeLast->next ) {
        if (curPkt->packet.dts > pkt->dts) {
            curPkt = curPkt->next;
        }else{
            insertMarkPkt = curPkt;
            break;
        }
    }
    
    //first
    if (insertMarkPkt == pktQueue->recyclePacketNodeLast->next) {
        pktQueue->recyclePacketNodeLast->packet = *pkt;
        pktQueue->recycleCount --;
        pktQueue->recyclePacketNodeLast = pktQueue->recyclePacketNodeLast->pre;
    }else if (insertMarkPkt == NULL){
        //out used range
        pktQueue->usedPacketNodeLast->next->packet = *pkt;
        pktQueue->usedPacketNodeLast = pktQueue->usedPacketNodeLast->next;
        pktQueue->recycleCount --;
    }else{
        //alloc new node and insert it to be previous of insertMarkPkt
        
        TFPacketNode *node = av_mallocz(sizeof(TFPacketNode));
        insertMarkPkt->pre->next = node;
        node->pre = insertMarkPkt->pre;
        node->next = insertMarkPkt;
        insertMarkPkt->pre = node;
        
        node->packet = *pkt;
        
        pktQueue->allocCount ++;
        
        printf(">>>>>>>>insert early packet: %lld ->(%lld - %lld)\n",pkt->dts, pktQueue->recyclePacketNodeLast->next->packet.dts,pktQueue->usedPacketNodeLast->packet.dts);
    }
    //printf("\ninsert packet: %d-%d\n",pktQueue->allocCount,pktQueue->recycleCount);
    
    TFSDL_UnlockMutex(pktQueue->mutex);
    //printf("put end packet");
}

AVPacket* packetQueueGet(TFPacketQueue *pktQueue, bool *finished){
    
    
    if (pktQueue->abortRequest) {
        *finished = true;
        return NULL;
    }
    
    TFSDL_LockMutex(pktQueue->mutex);
    
    if (pktQueue->recycleCount > pktQueue->allocCount * 0.75) {
        //printf("|");
        TFSDL_UnlockMutex(pktQueue->mutex);
        return NULL;
    }
    
    AVPacket *firstPkt = &pktQueue->usedPacketNodeLast->packet;
    
    //pktQueue->usedPacketNodeLast->packet = NULL;
    pktQueue->recycleCount ++;
    
    pktQueue->usedPacketNodeLast = pktQueue->usedPacketNodeLast->pre;
    
    if (!pktQueue->canInsert && pktQueue->recycleCount > pktQueue->allocCount/2) {
        pktQueue->canInsert = true;
    }
    
    //printf("\nmove out packet: %d-%d\n",pktQueue->allocCount,pktQueue->recycleCount);
    
    TFSDL_UnlockMutex(pktQueue->mutex);
    
    //printf("packet dts: %lld\n",firstPkt->dts);
    
    return firstPkt;
}

void packetQueueDestory(TFPacketQueue *pktQueue){
    if (pktQueue == NULL || !pktQueue->initilized) {
        return;
    }
    TFSDL_LockMutex(pktQueue->mutex);
    
    TFPacketNode *first = pktQueue->usedPacketNodeLast;
    TFPacketNode *cur = first->pre;
    while (cur != NULL) {
        
        if (cur == first) {
            av_free(cur);
            break;
        }
        
        TFPacketNode *pre = cur->pre;
        av_free(cur);
        cur = pre;
    }
    
    TFSDL_UnlockMutex(pktQueue->mutex);
}

#pragma mark - frame queue

TFFrameDecoder *frameDecoderInit(AVCodecContext *codecCtx){
    TFFrameDecoder *decoder = av_mallocz(sizeof(TFFrameDecoder));
    decoder->codexCtx = codecCtx;
    
    return decoder;
}

//视频:读取packet到frame
int videoFrameRead(void *data){
    
    TFLivePlayer *player = data;
    TFVideoState *videoState = player->videoState;
    AVCodecContext *codecCtx = videoState->videoFrameDecoder->codexCtx;
    
    bool finished = false;
    AVFrame *frame = av_frame_alloc();
    
    int64_t curDts = 0;
    
    while (!finished && !videoState->abortRequest) {
        if (!videoState->videoFrameQueue.canInsert) {
            continue;
        }
        //printf("will get packet ");
        AVPacket *pkt = packetQueueGet(&videoState->videoPktQueue,&finished);
//        printf("get end packet\n");
        
        if (pkt == NULL) {
            continue;
        }
        
        //printf("send packet!! %lld",pkt->dts);
        if (pkt->dts < curDts) {
            printf("<<<<<<<<find early packet! %lld -- %lld\n",pkt->dts, curDts);
        }
        curDts = pkt->dts;
        int retval = avcodec_send_packet(codecCtx, pkt);
        //printf("got packet!! %lld\n",pkt->dts);
        
        
        if (retval != 0) {
            printf("avcodec_send_packet error:%d\n",retval);
        }
        retval = avcodec_receive_frame(codecCtx, frame);
        if (retval < 0) {
            printf("decode frame error: %d\n",retval);
        }
        if (frame->pict_type >= AV_PICTURE_TYPE_B) {
            printf("%d\n",frame->pict_type);
        }

        frameQueuePut(player->videoDispalyer, &videoState->videoFrameQueue, frame);
    }
    
    if (videoState->abortRequest) {
        if (videoState->videoFrameDecoder) {
            if (videoState->videoFrameDecoder->codexCtx) {
                avcodec_close(videoState->videoFrameDecoder->codexCtx);
            }
            av_free(videoState->videoFrameDecoder);
        }
        
        if (videoState->formatCtx) {
            NSLog(@"release formatCtx");
            avformat_close_input(&videoState->formatCtx);
        }
        
        packetQueueDestory(&videoState->videoPktQueue);
        frameQueueDestory(&videoState->videoFrameQueue);
    }
    
    return 0;
}

//音频:读取packet到frame
int audioFrameRead(void *data){
    TFLivePlayer *player = data;
    TFVideoState *videoState = player->videoState;
    
    AVFrame *frame = av_frame_alloc();
    
    bool finished = false;
    while (!finished && !videoState->abortRequest) {
        AVPacket *pkt = packetQueueGet(&videoState->audioPktQueue, &finished);
        
        int retval = avcodec_send_packet(videoState->audioFrameDecoder->codexCtx, pkt);
        if (retval != 0) {
            printf("send audio packet error: %d",retval);
            continue;
        }
        while (1) {
            
            retval = avcodec_receive_frame(videoState->audioFrameDecoder->codexCtx, frame);
            if (retval != 0) {
                break;
            }
            
            frameQueuePut(&videoState->audioFrameQueue, frame, NULL);
            
        }
        
    }
    
    return 0;
}

void frameQueueInit(TFFrameQueue *frameQueue, char *name){
    
    frameQueue->initilized = true;
    
    strcpy(frameQueue->name, name);
    frameQueue->mutex = TFSDL_CreateMutex();
    frameQueue->maxAllocCount = kMaxAllocFrameNodeCount;
    frameQueue->canInsert = YES;
    
    
    TFFrameNode *head = av_mallocz(sizeof(TFFrameNode));
    frameQueue->usedFrameNodeLast = head;
    frameQueue->recycleFrameNodeLast = head;
    
    //first init 30 nodes
    TFFrameNode *cur = head;
    for (int i = 1; i<kMaxAllocFrameNodeCount/10; i++) {
        TFFrameNode *node = av_mallocz(sizeof(TFFrameNode));
        node->pre = cur;
        cur->next = node;
        cur = node;
    }
    
    //cycle the link
    head->pre = cur;
    cur->next = head;
    
    frameQueue->allocCount = 10;
    frameQueue->recycleCount = 10;
}

void frameQueuePut(TFFrameQueue *frameQueue, AVFrame *frame, void *data){
    
    TFSDL_LockMutex(frameQueue->mutex);
    
    //Alloc and insert new node if recycle node has used up.
    if (frameQueue->recycleCount == 0) {
        //recycleFrameNodeLast->pre == usedFrameNodeLast
        TFFrameNode *node = av_mallocz(sizeof(TFFrameNode));
        
        frameQueue->recycleFrameNodeLast->pre = node;
        node->next = frameQueue->recycleFrameNodeLast;
        
        node->pre = frameQueue->usedFrameNodeLast;
        frameQueue->usedFrameNodeLast->next = node;
        
        frameQueue->recycleFrameNodeLast = node;
        
        frameQueue->allocCount ++;
        frameQueue->recycleCount ++;
        
        //可以超过，但是会开始限制
        if (frameQueue->allocCount >= frameQueue->maxAllocCount) {
            frameQueue->canInsert = false;
        }
        
        //printf("alloc new frame");
    }
    
    TFFrameNode *curFrame = frameQueue->recycleFrameNodeLast->next;
    TFFrameNode *insertMarkFrame = NULL;
    while (curFrame != frameQueue->usedFrameNodeLast->next ) {
        if (curFrame->frame->frame->pts > frame->pts) {
            curFrame = curFrame->next;
        }else{
            insertMarkFrame = curFrame;
            break;
        }
    }
    
    //first
    TFFrame *newFrame = frameQueue->convertFunc(frameQueue->recycleFrameNodeLast->frame, frame, data);
    //TFFRameFillOrAlloc(display, frameQueue->recycleFrameNodeLast->frame, frame);
    
    if (insertMarkFrame == frameQueue->recycleFrameNodeLast->next) {
        frameQueue->recycleFrameNodeLast->frame = newFrame;
        frameQueue->recycleCount --;
        frameQueue->recycleFrameNodeLast = frameQueue->recycleFrameNodeLast->pre;
    }else if (insertMarkFrame == NULL){
        //out used range
        frameQueue->usedFrameNodeLast->next->frame = newFrame;
        frameQueue->usedFrameNodeLast = frameQueue->usedFrameNodeLast->next;
        frameQueue->recycleCount --;
    }else{
        //alloc new node and insert it to be previous of insertMarkPkt
        
        TFFrameNode *node = av_mallocz(sizeof(TFFrameNode));
        insertMarkFrame->pre->next = node;
        node->pre = insertMarkFrame->pre;
        node->next = insertMarkFrame;
        insertMarkFrame->pre = node;
        
        node->frame = newFrame;
        
        frameQueue->allocCount ++;
    }
    
    TFSDL_UnlockMutex(frameQueue->mutex);
}

TFFrame *frameQueueGet(TFFrameQueue *frameQueue, bool *finished){
    
    if (frameQueue->abortRequest) {
        *finished = true;
        return NULL;
    }
    if (frameQueue->allocCount == 0 || frameQueue->recycleCount == frameQueue->allocCount) {
        *finished = false;
        return NULL;
    }
    
    TFFrame *firstFrame = frameQueue->usedFrameNodeLast->frame;
    
    return firstFrame;
}

void frameQueueUseOne(TFFrameQueue *frameQueue, bool *finished){
    
    TFSDL_LockMutex(frameQueue->mutex);
    
    if (frameQueue->abortRequest) {
        *finished = true;
        TFSDL_UnlockMutex(frameQueue->mutex);
        return;
    }
    if (frameQueue->allocCount == 0) {
        *finished = false;
        TFSDL_UnlockMutex(frameQueue->mutex);
        return;
    }
    
    if (frameQueue->recycleCount == frameQueue->allocCount) {
        //printf("=");
        TFSDL_UnlockMutex(frameQueue->mutex);
        return;
    }
    
    frameQueue->usedFrameNodeLast->frame = NULL;
    frameQueue->recycleCount ++;
    
    frameQueue->usedFrameNodeLast = frameQueue->usedFrameNodeLast->pre;
    
    if (!frameQueue->canInsert && frameQueue->recycleCount > frameQueue->allocCount/2) {
        frameQueue->canInsert = true;
    }
    
    TFSDL_UnlockMutex(frameQueue->mutex);
}

void frameQueueDestory(TFFrameQueue *frameQueue){
    if (frameQueue == NULL || !frameQueue->initilized) {
        return;
    }
    
    TFSDL_LockMutex(frameQueue->mutex);
    
    TFFrameNode *first = frameQueue->usedFrameNodeLast;
    TFFrameNode *cur = first->pre;
    while (cur != NULL) {
        if (cur->frame) {
            //av_frame_free(&cur->frame->frame);
            av_free(cur->frame->bitmap);
            av_free(cur->frame);
        }
        
        if (cur == first) {
            av_free(cur);
            break;
        }
        
        TFFrameNode *pre = cur->pre;
        
        av_free(cur);
        cur = pre;
    }
    
    TFSDL_UnlockMutex(frameQueue->mutex);
}

#pragma mark - display frame

//视频frame的转换方法
inline static TFFrame *TFVideoFrameFillOrAlloc(TFFrame *compositeFrame, AVFrame *originalFrame, void *data){
    TFVideoDisplayer *display = data;
    if (compositeFrame == NULL) {
        compositeFrame = av_mallocz(sizeof(TFFrame));
    }
    compositeFrame->frame = originalFrame;
    
    //overlay的create和fill因平台不同，这里做解耦处理
    if (display->createOverlay) {
        TFOverlay *bitmap = display->createOverlay();
        if (bitmap->fillVideoFrameFunc) {
            bitmap->fillVideoFrameFunc(bitmap, originalFrame);
        }
        compositeFrame->bitmap = bitmap;
    }
    
    return compositeFrame;
}

//音频frame的转换方法
inline static TFFrame *TFAudioFrameConvert(TFFrame *compositeFrame, AVFrame *originalFrame, void *data){
    
    if (compositeFrame == NULL) {
        compositeFrame = av_mallocz(sizeof(TFFrame));
    }
    compositeFrame->frame = originalFrame;
    
    return compositeFrame;
}

int startDisplayFrames(void *data){
    TFLivePlayer *player = data;
    TFVideoState *videoState = player->videoState;
    
    bool finished = false;
    while (!finished) {
        
        TFFrame *frame = frameQueueGet(&videoState->videoFrameQueue, &finished);
        //sleep(1);
        if (frame == NULL) {
            continue;
        }
        
        double delay = 0.05;
        double time = av_gettime_relative() / 1000000.0;
        if (time < videoState->frameTimer + delay) {
            continue;
        }
        
        frameQueueUseOne(&videoState->videoFrameQueue, &finished);
        
        if (player->videoDispalyer->displayOverlay) {
            videoState->frameTimer = av_gettime_relative() / 1000000.0;
            player->videoDispalyer->displayOverlay(player->videoDispalyer, frame->bitmap);
        }
        
    }
    
    return 0;
}

int audioOpen(TFLivePlayer *player, int64_t wanted_channel_layout, int wanted_nb_channels, int wanted_sample_rate, AudioParams *resultAudioParams){
    
    TFAudioDisplayer *audioDisplayer = player->audioDisplayer;
    
    if (!wanted_channel_layout || wanted_nb_channels != av_get_channel_layout_nb_channels(wanted_channel_layout)) {
        wanted_channel_layout = av_get_default_channel_layout(wanted_nb_channels);
    }
    
    wanted_nb_channels = av_get_channel_layout_nb_channels(wanted_channel_layout);
    
    TFAudioSpecifics wanted_spec, spec;
    wanted_spec.channels = wanted_nb_channels;
    wanted_spec.sampleRate = wanted_sample_rate;
    if (wanted_spec.channels <= 0 || wanted_spec.sampleRate <= 0) {
        printf("invilid channels or sample rate!");
        return -1;
    }
    wanted_spec.format = 0x8010; /**< Signed 16-bit samples */
    //wanted_spec.silence
    //wanted_spec.samples
    wanted_spec.fillBufferfunc = fill_audio_buffer;
    wanted_spec.callbackData = player;
    if (audioDisplayer->openAudio(audioDisplayer, &wanted_spec, &spec) < 0) {
        printf("can't find feasiable audio specifics");
        return -1;
    }
    
    resultAudioParams->freq = spec.sampleRate;
    resultAudioParams->channels = spec.channels;
    resultAudioParams->channel_layout = wanted_channel_layout;
    resultAudioParams->fmt = AV_SAMPLE_FMT_S16;
    resultAudioParams->frame_size = av_samples_get_buffer_size(NULL, resultAudioParams->channels, 1, resultAudioParams->fmt, 1);
    resultAudioParams->bytes_per_sec = av_samples_get_buffer_size(NULL, resultAudioParams->channels, resultAudioParams->freq, resultAudioParams->fmt, 1);
    if (resultAudioParams->bytes_per_sec <= 0 || resultAudioParams->frame_size <= 0) {
        av_log(NULL, AV_LOG_ERROR, "av_samples_get_buffer_size failed\n");
        return -1;
    }
    
    return 0;
}


int obtainOneAudioBuffer(TFVideoState *videoState){
    bool finished = false;
    TFFrame *compositeFrame = NULL;
    while (compositeFrame == NULL) {
        compositeFrame = frameQueueGet(&videoState->audioFrameQueue, &finished);
        if (finished) {
            return -1;
        }
    }
    
    AVFrame *frame = compositeFrame->frame;
    if (frame->channel_layout != videoState->sourceAudioParams.channel_layout
        || frame->nb_samples != videoState->sourceAudioParams.channels
        || frame->sample_rate != videoState->sourceAudioParams.freq) {
        
    }
}

int fill_audio_buffer(uint8_t *buffer, int len, void *data){
    TFLivePlayer *player = data;
    TFVideoState *videoState = player->videoState;
    
    while (len > 0) {
        if (videoState->audioBufferIndex >= videoState->audioBufferSize) {
            int bufferSize = obtainOneAudioBuffer(videoState);
            if (bufferSize <= 0) {
                videoState->audioBuffer = NULL;
                videoState->audioBufferSize = SDL_AUDIO_MIN_BUFFER_SIZE ;
                //  (/ videoState->targetAudioParams.frame_size * videoState->targetAudioParams.frame_size;)这一段是？
                
            }else{
                videoState->audioBufferSize = bufferSize;
            }
            videoState->audioBufferIndex = 0;
        }
        
        
        int copyLen = videoState->audioBufferSize - videoState->audioBufferIndex;
        if (copyLen > len) {
            copyLen = len;
        }
        
        memcpy(buffer, (uint8_t*)videoState->audioBuffer + videoState->audioBufferIndex, copyLen);
        
        len -= copyLen;
        buffer += copyLen;
        videoState->audioBufferIndex += copyLen;
    }
    
    
    return 0;
}





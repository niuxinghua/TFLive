//
//  TFGLView.m
//  OPGLES_iOS
//
//  Created by wei shi on 2017/7/12.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import "TFGLView.h"

@interface TFGLView ()

@end

@implementation TFGLView

+(Class)layerClass{
    return [CAEAGLLayer class];
}

-(instancetype)initWithFrame:(CGRect)frame{
    if (self = [super initWithFrame:frame]) {
        if (![self commonInit]) {
            return nil;
        }
    }
    
    return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder{
    if (self = [super initWithCoder:aDecoder]) {
        if (![self commonInit]) {
            return nil;
        }
    }
    
    return self;
}

-(BOOL)commonInit{
    _renderLayer = (CAEAGLLayer *)self.layer;
    _renderLayer.contentsScale = [UIScreen mainScreen].scale;
    
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    if (!_context) {
        NSLog(@"alloc EAGLContext failed!");
        return false;
    }
    if (![EAGLContext setCurrentContext:_context]) {
        NSLog(@"set current EAGLContext failed!");
        return false;
    }
    [self setupFrameBuffer];
    [self startRender];
    
    return true;
}

-(void)setupFrameBuffer{
    glGenBuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    
    glGenRenderbuffers(1, &_colorBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorBuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_renderLayer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorBuffer);
    
    GLint width,height;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height);
    
    _bufferSize.width = width;
    _bufferSize.height = height;
    
    glViewport(0, 0, _bufferSize.width, _bufferSize.height);
    
    GLuint depthRenderbuffer;
    glGenRenderbuffers(1, &depthRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, width, height);
    //[_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_layer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER) ;
    if(status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x", status);
    }
}

-(void)startRender{
    
}

@end

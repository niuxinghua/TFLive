//
//  TFGLView.h
//  OPGLES_iOS
//
//  Created by wei shi on 2017/7/12.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/ES3/gl.h>

@interface TFGLView : UIView

@property (nonatomic, strong, readonly) EAGLContext *context;

@property (nonatomic, strong, readonly) CAEAGLLayer *renderLayer;

@property (nonatomic, assign, readonly) GLuint frameBuffer;

@property (nonatomic, assign, readonly) GLuint colorBuffer;

@property (nonatomic, assign, readonly) CGSize bufferSize;

//must call super if override it.
-(void)setupFrameBuffer;

/**
 override by subclass
 */
-(void)startRender;

@end

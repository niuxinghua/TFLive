//
//  TFOPGLESDisplayView.h
//  OPGLES_iOS
//
//  Created by wei shi on 2017/7/12.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TFGLView.h"
#import "TFVideoDisplayer_ios.h"

typedef struct TFImageBuffer {
    int width;
    int height;
    UInt32 format;
    int planes;
    
    UInt8 *pixels[8];
    UInt16 linesize[8];
}TFImageBuffer;

@interface TFOPGLESDisplayView : TFGLView

-(void)renderImageBuffer:(TFImageBuffer *)imageBuf;

-(void)displayOverlay:(TFOverlay *)overlay;

@end

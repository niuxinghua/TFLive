//
//  TFDisplayView.m
//  TFLive
//
//  Created by wei shi on 2017/6/30.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import "TFDisplayView.h"
#import <CoreVideo/CoreVideo.h>

@interface TFDisplayView (){
    UIImageView *_playImgView;
    CVPixelBufferPoolRef pixelBufferPool;
}

@end

@implementation TFDisplayView

-(instancetype)initWithFrame:(CGRect)frame{
    if (self = [super initWithFrame:frame]) {
        _playImgView = [[UIImageView alloc] initWithFrame:self.bounds];
        _playImgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_playImgView];
    }
    
    return self;
}

uint8_t *rgbbuf;
-(void)displayOverlay:(TFOverlay *)overlay{
    if(!overlay || !overlay->pixels[0] || !overlay->pixels[1]){
        return ;
    }
    
    int width = overlay->width;
    int height = overlay->height;
    int linesize = overlay->linesize[0];
    
    if (!rgbbuf) {
        rgbbuf = av_mallocz(width*height*sizeof(uint8_t)*4);
    }
    
    //uint8_t rgbbuf[width*height*24];
    convertYUV420pToRGBA(overlay, rgbbuf, linesize*4, height);
    //TODO: free overlay
    //av_free(overlay);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef contextRef = CGBitmapContextCreate(rgbbuf, width, height, 8,width*4, colorSpace, kCGImageAlphaNoneSkipFirst);
    CGImageRef imageRef = CGBitmapContextCreateImage(contextRef);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    
    CGImageRelease(imageRef);
    CGContextRelease(contextRef);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _playImgView.image = image;
    });
}

static void convertYUV420pToRGBA(TFOverlay * overlay, uint8_t *outbuf, int linesize, int height)
{
    const int linesizeY = overlay->linesize[0];
    const int linesizeU = overlay->linesize[1];
    const int linesizeV = overlay->linesize[2];
    
    assert(height == overlay->height);
    assert(linesize  <= linesizeY * 4);
    assert(linesizeY == linesizeU * 2);
    assert(linesizeY == linesizeV * 2);
    
    uint8_t *pY = overlay->pixels[0];
    uint8_t *pU = overlay->pixels[1];
    uint8_t *pV = overlay->pixels[2];
    
    const int width = linesize / 4;
    
    for (int y = 0; y < height; y += 2) {
        
        uint8_t *dst1 = outbuf + y       * linesize;
        uint8_t *dst2 = outbuf + (y + 1) * linesize;
        
        uint8_t *py1  = pY  +  y       * linesizeY;
        uint8_t *py2  = py1 +            linesizeY;
        uint8_t *pu   = pU  + (y >> 1) * linesizeU;
        uint8_t *pv   = pV  + (y >> 1) * linesizeV;
        
        for (int i = 0; i < width; i += 2) {
            
            int Y1 = py1[i];
            int Y2 = py2[i];
            int Y3 = py1[i+1];
            int Y4 = py2[i+1];
            
            int U = pu[(i >> 1)] - 128;
            int V = pv[(i >> 1)] - 128;
            
            int dr = (int)(             1.402f * V);
            int dg = (int)(0.344f * U + 0.714f * V);
            int db = (int)(1.772f * U);
            
            int r1 = Y1 + dr;
            int g1 = Y1 - dg;
            int b1 = Y1 + db;
            
            int r2 = Y2 + dr;
            int g2 = Y2 - dg;
            int b2 = Y2 + db;
            
            int r3 = Y3 + dr;
            int g3 = Y3 - dg;
            int b3 = Y3 + db;
            
            int r4 = Y4 + dr;
            int g4 = Y4 - dg;
            int b4 = Y4 + db;
            
            r1 = r1 > 255 ? 255 : r1 < 0 ? 0 : r1;
            g1 = g1 > 255 ? 255 : g1 < 0 ? 0 : g1;
            b1 = b1 > 255 ? 255 : b1 < 0 ? 0 : b1;
            
            r2 = r2 > 255 ? 255 : r2 < 0 ? 0 : r2;
            g2 = g2 > 255 ? 255 : g2 < 0 ? 0 : g2;
            b2 = b2 > 255 ? 255 : b2 < 0 ? 0 : b2;
            
            r3 = r3 > 255 ? 255 : r3 < 0 ? 0 : r3;
            g3 = g3 > 255 ? 255 : g3 < 0 ? 0 : g3;
            b3 = b3 > 255 ? 255 : b3 < 0 ? 0 : b3;
            
            r4 = r4 > 255 ? 255 : r4 < 0 ? 0 : r4;
            g4 = g4 > 255 ? 255 : g4 < 0 ? 0 : g4;
            b4 = b4 > 255 ? 255 : b4 < 0 ? 0 : b4;
            
            //dst1[4*i + 0] = 255;
            dst1[4*i + 1] = r1;
            dst1[4*i + 2] = g1;
            dst1[4*i + 3] = b1;
            
            //dst2[4*i + 0] = 255;
            dst2[4*i + 1] = r2;
            dst2[4*i + 2] = g2;
            dst2[4*i + 3] = b2;
            
            //dst1[4*i + 4] = 255;
            dst1[4*i + 5] = r3;
            dst1[4*i + 6] = g3;
            dst1[4*i + 7] = b3;
            
            //dst2[4*i + 4] = 255;
            dst2[4*i + 5] = r4;
            dst2[4*i + 6] = g4;
            dst2[4*i + 7] = b4;
        }
    }
}


@end

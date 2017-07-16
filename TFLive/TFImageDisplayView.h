//
//  TFImageDisplayView.h
//  TFLive
//
//  Created by wei shi on 2017/6/30.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TFVideoDisplayer_ios.h"

//Converting overlay(video frame buffer) to UIImage and displaying it on UIImageView.
@interface TFImageDisplayView : UIView

-(void)displayOverlay:(TFOverlay *)overlay;

@end

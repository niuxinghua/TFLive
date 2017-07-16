//
//  TFOPGLESDisplayView.m
//  OPGLES_iOS
//
//  Created by wei shi on 2017/7/12.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import "TFOPGLESDisplayView.h"
#import <OpenGLES/ES3/gl.h>
#import "TFOPGLProgram.hpp"

#define TFMAX_TEXTURE_COUNT     3

@interface TFOPGLESDisplayView (){
    
    TFOPGLProgram *_triangleProgram;
    GLuint VAO;
    GLuint textures[TFMAX_TEXTURE_COUNT];
}

@end

@implementation TFOPGLESDisplayView

-(void)layoutSubviews{
    [super layoutSubviews];
    
    //[self rendering];
}

-(void)startRender{
    
    GLfloat vertices[] = {
        -1.0f, -1.0f, 0.0f, 0.0f, 1.0f,
        1.0f, -1.0f, 0.0f, 1.0f, 1.0f,
        1.0f, 1.0f, 0.0f, 1.0f, 0.0f,
        -1.0f, 1.0f, 0.0f, 0.0f, 0.0f
    };
    GLuint indices[] = {
        0, 1, 2,
        0, 3, 2
    };
    
    NSString *vertexPath = [[NSBundle mainBundle] pathForResource:@"frameDisplay" ofType:@"vs"];
    NSString *fragmentPath = [[NSBundle mainBundle] pathForResource:@"frameDisplay" ofType:@"fs"];
    _triangleProgram = new TFOPGLProgram([vertexPath UTF8String], [fragmentPath UTF8String]);
    
    
    glGenVertexArrays(1, &VAO);
    glBindVertexArray(VAO);
    
    GLuint VBO;
    glGenBuffers(1, &VBO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5*sizeof(GL_FLOAT), 0);
    glEnableVertexAttribArray(0);
    
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5*sizeof(GL_FLOAT), (void*)(3*(sizeof(GL_FLOAT))));
    glEnableVertexAttribArray(1);
    
    GLuint EBO;
    glGenBuffers(1, &EBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
    
    
    //gen textures
    glGenTextures(TFMAX_TEXTURE_COUNT, textures);
    for (int i = 0; i<TFMAX_TEXTURE_COUNT; i++) {
        glBindTexture(GL_TEXTURE_2D, textures[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    }
}

-(void)renderImageBuffer:(TFImageBuffer *)imageBuf{
    float width = imageBuf->width;
    float height = imageBuf->height;
    
    CGSize viewPort;
    if (width / height > self.bufferSize.width / self.bufferSize.height) {
        viewPort.width = self.bufferSize.width;
        viewPort.height = height / width * self.bufferSize.width;
    }else{
        viewPort.width = width / height * self.bufferSize.height;
        viewPort.height = self.bufferSize.height;
    }
    
    glViewport(0, 0, viewPort.width, viewPort.height);
    
    
    glBindTexture(GL_TEXTURE_2D, textures[0]);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageBuf->pixels[0]);
    glGenerateMipmap(GL_TEXTURE_2D);
    
    [self rendering];
}

-(void)displayOverlay:(TFOverlay *)overlay{    
    float width = overlay->width;
    float height = overlay->height;
    
    CGSize viewPort;
    if (width / height > self.bufferSize.width / self.bufferSize.height) {
        viewPort.width = self.bufferSize.width;
        viewPort.height = height / width * self.bufferSize.width;
    }else{
        viewPort.width = width / height * self.bufferSize.height;
        viewPort.height = self.bufferSize.height;
    }
    
    glViewport(0, 0, viewPort.width, viewPort.height);
    
    //yuv420p has 3 planes: y u v. U plane and v plane have half width and height of y plane.
    glBindTexture(GL_TEXTURE_2D, textures[0]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width, height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, overlay->pixels[0]);
    glGenerateMipmap(GL_TEXTURE_2D);
    
    glBindTexture(GL_TEXTURE_2D, textures[1]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width/2, height/2, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, overlay->pixels[1]);
    glGenerateMipmap(GL_TEXTURE_2D);
    
    glBindTexture(GL_TEXTURE_2D, textures[2]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width/2, height/2, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, overlay->pixels[2]);
    glGenerateMipmap(GL_TEXTURE_2D);
    
    [self rendering];
}

-(void)rendering{
    
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT);
    
    _triangleProgram->use();
    
    _triangleProgram->setTexture("yPlaneTex", GL_TEXTURE_2D, textures[0], 0);
    _triangleProgram->setTexture("uPlaneTex", GL_TEXTURE_2D, textures[1], 1);
    _triangleProgram->setTexture("vPlaneTex", GL_TEXTURE_2D, textures[2], 2);
    
    glBindVertexArray(VAO);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    
    glBindRenderbuffer(GL_RENDERBUFFER, self.colorBuffer);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

@end

//
//  Impl_EEPixelViewerGitHub.h
//  OpenGLTesting
//
//  Created by sbond75 on 5/10/20.
//  Copyright © 2020 sbond75. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "EEPixelViewer/EEPixelViewer.h"
#import <CoreVideo/CoreVideo.h>

@interface CustomView : EEPixelViewer {
@public
    CVDisplayLinkRef displayLink; // (CADisplayLink isn't on macOS)
    EEPixelViewerPlane plane;
    UInt8* pixelBuffer;
    UInt8 counter;
    long long startingMilliseconds;
}

- (id)initWithFrame:(CGRect)rect pixelBufferWidth:(size_t)width pixelBufferHeight:(size_t)height;

@end

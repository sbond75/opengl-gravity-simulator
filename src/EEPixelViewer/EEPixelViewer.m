//    Copyright (c) 2016, Eldad Eilam
//    All rights reserved.
//
//    Redistribution and use in source and binary forms, with or without modification, are
//    permitted provided that the following conditions are met:
//
//    1. Redistributions of source code must retain the above copyright notice, this list of
//       conditions and the following disclaimer.
//
//    2. Redistributions in binary form must reproduce the above copyright notice, this list
//       of conditions and the following disclaimer in the documentation and/or other materials
//       provided with the distribution.
//
//    3. Neither the name of the copyright holder nor the names of its contributors may be used
//       to endorse or promote products derived from this software without specific prior written
//       permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
//    OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
//    AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
//    CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//    DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//    WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
//    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "EEPixelViewer.h"
#import <QuartzCore/QuartzCore.h>

//#import <OpenGL/OpenGL.h>

#import "OGLProgramManager.h"

#import <Accelerate/Accelerate.h>

#import "NSLabel.h"

#pragma mark - Internal Definitions

typedef struct {
    float x;
    float y;
} Vertex;

struct RectVertexes
{
    Vertex	bottomLeft;
    Vertex	topLeft;
    Vertex	topRight;
    Vertex	bottomRight;
};

#define RectBottomLeft { -1, -1 }
#define RectTopLeft { -1, 1 }
#define RectTopRight  { 1, 1 }
#define RectBottomRight { 1, -1 }

static Vertex SquareVertices[] =
{
    RectBottomLeft,
    RectTopLeft,
    RectBottomRight,
    RectBottomRight,
    RectTopLeft,
    RectTopRight,
};

static const GLubyte SquareIndices[] =
{
    0, 1, 2,
    3, 4, 5,
};

typedef enum ContentModeCustom {
    ContentModeCustomScaleAspectFit = 0 // Based on https://developer.apple.com/documentation/uikit/uiviewcontentmode/uiviewcontentmodescaleaspectfit?language=objc
} ContentModeCustom;

@interface EEPixelViewer()
{
    OGLProgramManager *program;
    
    GLuint clippedRectVertexBuffer;
    GLuint clippedRectIndexBuffer;
    
    GLuint rectVertexBuffer;
    GLuint rectIndexBuffer;
    
    GLuint textures[4];
    
    NSLabel *fpsLabel;
    
    NSDate *lastTimestamp;
    NSTimeInterval totalTime;
    int totalFrames;
    int maxFrames;
    
    struct pixel_buffer_parameters
    {
        GLenum  pixelDataFormat;
        GLenum  dataType;
        GLint   internalFormat;
        int     bytesPerPixel;
    }  pixelBufferParameters[4];
    
    ContentModeCustom pixelViewerContentMode;
    
    // This is a special optimization for OpenGL ES 2.0 devices that somewhat improves performance
    // for 24bpp formats such as 24RGB, 24BGR, and 444YpCbCr.
    BOOL treat24bppAs3Planes;
}
@end

@implementation EEPixelViewer

#pragma mark - Initialization Code

-(NSOpenGLContext*) makeContext {
    NSOpenGLContext* ctx = [[NSOpenGLContext alloc] initWithFormat: [EEPixelViewer defaultPixelFormat] shareContext:nil];
    NSOpenGLContextParameter vals[] = {
        1
    };
    //[ctx setValues:vals forParameter:NSOpenGLContextParameterSwapInterval]; // "The swap interval is represented as one long. If the swap interval is set to 0 (the default), the flushBuffer method executes as soon as possible, without regard to the vertical refresh rate of the monitor. If the swap interval is set to 1, the buffers are swapped only during the vertical retrace of the monitor."
    // This syncs the OpenGL context to the VBL to prevent tearing
    
    GLint one = 1;
    [ctx setValues:&one forParameter:NSOpenGLCPSwapInterval];

    return ctx;
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    self.context = [self makeContext];
    
    /*
    if (self.context == nil)
    {
        self.context = [[EAGLContext alloc] initWithAPI: kEAGLRenderingAPIOpenGLES2];
        NSLog(@"EEPixelViewer: Initialized with OpenGL ES 2.0");
        treat24bppAs3Planes = YES;
    }
    else
    {
        NSLog(@"EEPixelViewer: Initialized with OpenGL ES 3.0");
        treat24bppAs3Planes = NO;
    }
     */
    return self;
}

+ (NSOpenGLPixelFormat*)defaultPixelFormat
{
    NSOpenGLPixelFormatAttribute attribs[] =
    {
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersionLegacy, // NSOpenGLProfileVersion3_2Core
        NSOpenGLPFAColorSize    , 24                           ,
        NSOpenGLPFAAlphaSize    , 8                            ,
        NSOpenGLPFADoubleBuffer , // TODO: wow, NOT having double buffer here was causing the no rendering issue!...
        NSOpenGLPFAAccelerated  ,
        NSOpenGLPFANoRecovery   ,
        0
    };
    //NSOpenGLPixelFormatAttribute attribs[1] = { 0 }; // NOTE: Array literals like this is a GNU extension..
    //NSOpenGLPixelFormatAttribute attribs [] = {
        //NSOpenGLPFADoubleBuffer,
    //    (NSOpenGLPixelFormatAttribute)nil };
    return [(NSOpenGLPixelFormat *)[NSOpenGLPixelFormat alloc]
            initWithAttributes:attribs];
}

- (id)initWithFrame:(CGRect)frame {
    self = [self initWithFrame: frame context: [self makeContext]];
    return self;
}

- (id)initWithFrame:(CGRect)frame context:(NSOpenGLContext *)context
{
    [context makeCurrentContext];
    self = [super initWithFrame:frame];
    self.openGLContext = context;
    return self;
}

- (void)setupVBOs
{
	[program use];
    glGenBuffers(1, &rectVertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, rectVertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(SquareVertices), SquareVertices, GL_STATIC_DRAW);
    
    glGenBuffers(1, &rectIndexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, rectIndexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(SquareIndices), SquareIndices, GL_STATIC_DRAW);
	
	// Set our clipping rect vertex array (that gets calculated dynamically during scene rendering):
    glGenBuffers(1, &clippedRectVertexBuffer);
    glGenBuffers(1, &clippedRectIndexBuffer);
}

- (void) layoutSubviews
{
    [super layoutSubtreeIfNeeded];
    
    if (fpsLabel != nil)
        fpsLabel.frame = CGRectMake(0, 0, self.bounds.size.width / 2, 30);
    
    //[self deleteDrawable];
    //[self bindDrawable];
        
    //[program use];
    
    //[self setupShadersForCropAndScaling];
    
    [self display];

}

- (void) setContext:(NSOpenGLContext *)newContext
{
    [self setOpenGLContext:newContext];
}
- (void) setOpenGLContext:(NSOpenGLContext *)newContext
{
    if (newContext == nil)
        return;
    
    [newContext makeCurrentContext];
    [super setOpenGLContext:newContext];
    
    [super setLayerContentsRedrawPolicy: NSViewLayerContentsRedrawBeforeViewResize]; //[super setContentMode: UIViewContentModeRedraw];
    
    //self.layer.borderColor = [NSColor greenColor].CGColor;
    //self.layer.borderWidth = 2.0;
    
    // TODO: port these below.
    /*
    self.enableSetNeedsDisplay = NO;
        
    self.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    self.drawableMultisample = GLKViewDrawableMultisample4X;
    */
    
    if (textures[0] == 0) {
        glGenTextures(4, (GLuint *) &textures);
    }
    
    [self setupVBOs];
}

#pragma mark - Internal Implementation

- (void) setPixelFormat:(OSType)pixelFormat
{
    [self.openGLContext makeCurrentContext];
    //[super setPixelFormat: ];
    
    NSString *shaderName = nil;
    
    int planeCount = 0;
    
    switch(pixelFormat)
    {
        case kCVPixelFormatType_420YpCbCr8Planar:           /* Planar Component Y'CbCr 8-bit 4:2:0. */
        case kCVPixelFormatType_420YpCbCr8PlanarFullRange:  /* Planar Component Y'CbCr 8-bit 4:2:0, full range.*/
            shaderName = @"PixelViewer_YpCbCr_3P";
            planeCount = 3;
            
            glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            
            for (int plane = 0; plane < planeCount; plane++)
            {
                pixelBufferParameters[plane].dataType = GL_UNSIGNED_BYTE;
#define     GL_LUMINANCE   0x1909 // https://halide-lang.org/docs/mini__opengl_8h.html
                pixelBufferParameters[plane].pixelDataFormat = GL_LUMINANCE;
                pixelBufferParameters[plane].internalFormat = GL_LUMINANCE;
                pixelBufferParameters[plane].bytesPerPixel = 1;
            }

            break;
        case kCVPixelFormatType_422YpCbCr8:     /* Component Y'CbCr 8-bit 4:2:2, ordered Cb Y'0 Cr Y'1 */
            // We treat the 422YpCbCr interleaved format as a 2-plane format (even though it is not).
            // This format is packed as Cb Y'0 Cr Y'1, and so each luma pixel is packed with either
            // a Cb or a Cr value. We first load the luma pixels as a RG 16-bit texture, and tell the shader
            // to only extract the G value (the 2nd byte) as the luma. Then we load another copy of the same
            // data as a 2nd plane, as a width/2 32-bpp texture, from which we extract the Cr and Cb values
            // (which are stored as the 1st and 3rd bytes of each fragment).
            shaderName = @"PixelViewer_YpCbCr_2P";
            planeCount = 2;
            
            glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            
            pixelBufferParameters[0].dataType = GL_UNSIGNED_BYTE;
            pixelBufferParameters[0].pixelDataFormat = GL_RG;
            pixelBufferParameters[0].internalFormat = GL_RG8;
            pixelBufferParameters[0].bytesPerPixel = 2;

            pixelBufferParameters[1].dataType = GL_UNSIGNED_BYTE;
            pixelBufferParameters[1].pixelDataFormat = GL_RGBA;
            pixelBufferParameters[1].internalFormat = GL_RGBA8;
            pixelBufferParameters[1].bytesPerPixel = 4;

            break;
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:   /*  Bi-Planar Component Y'CbCr 8-bit 4:2:0, video-range */
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:    /* Bi-Planar Component Y'CbCr 8-bit 4:2:0, full-range */
            shaderName = @"PixelViewer_YpCbCr_2P";
            planeCount = 2;
            
            glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            
            pixelBufferParameters[0].dataType = GL_UNSIGNED_BYTE;
            pixelBufferParameters[0].pixelDataFormat = GL_LUMINANCE;
            pixelBufferParameters[0].internalFormat = GL_LUMINANCE;
            pixelBufferParameters[0].bytesPerPixel = 1;
            
            pixelBufferParameters[1].dataType = GL_UNSIGNED_BYTE;
            pixelBufferParameters[1].pixelDataFormat = GL_RG;
            pixelBufferParameters[1].internalFormat = GL_RG8;
            pixelBufferParameters[1].bytesPerPixel = 2;
            
            break;
            
        case kCVPixelFormatType_444YpCbCr8:     /* Component Y'CbCr 8-bit 4:4:4 */
            if (treat24bppAs3Planes == YES)
            {
                // For kCVPixelFormatType_444YpCbCr8, we describe it as a 3-planar format because
                // that appears to be a quicker way to load the textures. Rather than load a single 24-bpp
                // buffer, we use the Accelerate framework to break it down into three separate 8-bpp planes,
                // which we then proceed to load as three distinct textures. It ends up being much faster
                // on older devices.
                shaderName = @"PixelViewer_YpCbCr_3P";
                pixelBufferParameters[0].dataType = GL_UNSIGNED_BYTE;
                pixelBufferParameters[0].pixelDataFormat = GL_LUMINANCE;
                pixelBufferParameters[0].internalFormat = GL_LUMINANCE;
                pixelBufferParameters[0].bytesPerPixel = 1;
                
                pixelBufferParameters[1].dataType = GL_UNSIGNED_BYTE;
                pixelBufferParameters[1].pixelDataFormat = GL_LUMINANCE;
                pixelBufferParameters[1].internalFormat = GL_LUMINANCE;
                pixelBufferParameters[1].bytesPerPixel = 1;
                
                pixelBufferParameters[2].dataType = GL_UNSIGNED_BYTE;
                pixelBufferParameters[2].pixelDataFormat = GL_LUMINANCE;
                pixelBufferParameters[2].internalFormat = GL_LUMINANCE;
                pixelBufferParameters[2].bytesPerPixel = 1;
                
                planeCount = 3;
                glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            }
            else
            {
                shaderName = @"PixelViewer_YpCbCrA_1P";
                planeCount = 1;
                
                glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
                
                pixelBufferParameters[0].dataType = GL_UNSIGNED_BYTE;
                pixelBufferParameters[0].pixelDataFormat = GL_RGB;
                pixelBufferParameters[0].internalFormat = GL_RGB8;
                pixelBufferParameters[0].bytesPerPixel = 3;
            }
    
            break;
        case kCVPixelFormatType_4444YpCbCrA8:   /* Component Y'CbCrA 8-bit 4:4:4:4, ordered Cb Y' Cr A */
        case kCVPixelFormatType_4444AYpCbCr8:   /* Component Y'CbCrA 8-bit 4:4:4:4, ordered A Y' Cb Cr, full range alpha, video range Y'CbCr. */
            shaderName = @"PixelViewer_YpCbCrA_1P";
            planeCount = 1;
            
            glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
            
            pixelBufferParameters[0].dataType = GL_UNSIGNED_BYTE;
            pixelBufferParameters[0].pixelDataFormat = GL_RGBA;
            pixelBufferParameters[0].internalFormat = GL_RGBA8;
            pixelBufferParameters[0].bytesPerPixel = 4;

            break;
            
        case kCVPixelFormatType_24RGB:      /* 24 bit RGB */
        case kCVPixelFormatType_24BGR:      /* 24 bit BGR */
            if (treat24bppAs3Planes == YES)
            {
                // We treat 24-bpp RGB formats as 3-planar formats because that appears to be a
                // quicker way to load the textures. Rather than load a single 24-bpp buffer, we use
                // the Accelerate framework to break it down into three separate 8-bpp planes,
                // which we then proceed to load as three distinct textures. It ends up being much faster
                // on older devices.
                
                shaderName = @"PixelViewer_RGB_3P";
                pixelBufferParameters[0].dataType = GL_UNSIGNED_BYTE;
                pixelBufferParameters[0].pixelDataFormat = GL_LUMINANCE;
                pixelBufferParameters[0].internalFormat = GL_LUMINANCE;
                pixelBufferParameters[0].bytesPerPixel = 1;
                
                pixelBufferParameters[1].dataType = GL_UNSIGNED_BYTE;
                pixelBufferParameters[1].pixelDataFormat = GL_LUMINANCE;
                pixelBufferParameters[1].internalFormat = GL_LUMINANCE;
                pixelBufferParameters[1].bytesPerPixel = 1;
                
                pixelBufferParameters[2].dataType = GL_UNSIGNED_BYTE;
                pixelBufferParameters[2].pixelDataFormat = GL_LUMINANCE;
                pixelBufferParameters[2].internalFormat = GL_LUMINANCE;
                pixelBufferParameters[2].bytesPerPixel = 1;
                
                planeCount = 3;
                glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            }
            else
            {
                shaderName = @"PixelViewer_RGBA";
                pixelBufferParameters[0].dataType = GL_UNSIGNED_BYTE;
                pixelBufferParameters[0].pixelDataFormat = GL_RGB;
                pixelBufferParameters[0].internalFormat = GL_RGB8;
                pixelBufferParameters[0].bytesPerPixel = 3;
                
                planeCount = 1;
                glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            }
            break;
            
        case kCVPixelFormatType_32ARGB:     /* 32 bit ARGB */
        case kCVPixelFormatType_32BGRA:     /* 32 bit BGRA */
        case kCVPixelFormatType_32ABGR:     /* 32 bit ABGR */
        case kCVPixelFormatType_32RGBA:     /* 32 bit RGBA */
            shaderName = @"PixelViewer_RGBA";
            pixelBufferParameters[0].dataType = GL_UNSIGNED_BYTE;
            pixelBufferParameters[0].pixelDataFormat = GL_RGBA;
            pixelBufferParameters[0].internalFormat = GL_RGBA8;
            pixelBufferParameters[0].bytesPerPixel = 4;

            planeCount = 1;
            glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
            break;
            
        case kCVPixelFormatType_16LE555:      /* 16 bit BE RGB 555 */
            shaderName = @"PixelViewer_RGB";
            pixelBufferParameters[0].dataType = GL_UNSIGNED_SHORT_5_5_5_1;
            pixelBufferParameters[0].pixelDataFormat = GL_RGBA;
            pixelBufferParameters[0].internalFormat = GL_RGB5_A1;
            pixelBufferParameters[0].bytesPerPixel = 2;
            planeCount = 1;
            glPixelStorei(GL_UNPACK_ALIGNMENT, 2);
            break;
        case kCVPixelFormatType_16LE5551:     /* 16 bit LE RGB 5551 */
            shaderName = @"PixelViewer_RGBA";
            pixelBufferParameters[0].dataType = GL_UNSIGNED_SHORT_5_5_5_1;
            pixelBufferParameters[0].pixelDataFormat = GL_RGBA;
            pixelBufferParameters[0].internalFormat = GL_RGB5_A1;
            pixelBufferParameters[0].bytesPerPixel = 2;
            planeCount = 1;
            glPixelStorei(GL_UNPACK_ALIGNMENT, 2);
            break;
        case kCVPixelFormatType_16LE565:      /* 16 bit BE RGB 565 */
            shaderName = @"PixelViewer_RGBA";
            pixelBufferParameters[0].dataType = GL_UNSIGNED_SHORT_5_6_5;
            pixelBufferParameters[0].pixelDataFormat = GL_RGB;
            pixelBufferParameters[0].internalFormat = GL_RGB565;
            pixelBufferParameters[0].bytesPerPixel = 2;
            
            planeCount = 1;
            glPixelStorei(GL_UNPACK_ALIGNMENT, 2);
            break;
            
    }
    
    program = [OGLProgramManager programWithVertexShader:@"VertexShader" fragmentShader:shaderName];
    
    switch(pixelFormat)
    {
            // We use the same shader for all 32-bit RGBA type formats, and the shader loads a
            // permute map that can use any color/alpha ordering:
        case kCVPixelFormatType_24BGR:
            glUniform4i([program uniform:@"PermuteMap"], 2, 1, 0, 3);
            break;
        case kCVPixelFormatType_32ARGB:
            glUniform4i([program uniform:@"PermuteMap"], 1, 2, 3, 0);      
            break;
        case kCVPixelFormatType_32BGRA:
            glUniform4i([program uniform:@"PermuteMap"], 2, 1, 0, 3);
            break;
        case kCVPixelFormatType_32ABGR:
            glUniform4i([program uniform:@"PermuteMap"], 3, 2, 1, 0);
            break;
        case kCVPixelFormatType_32RGBA:
            glUniform4i([program uniform:@"PermuteMap"], 0, 1, 2, 3);
            break;
        case kCVPixelFormatType_16LE555:
        case kCVPixelFormatType_16LE5551:
            glUniform4i([program uniform:@"PermuteMap"], 0, 1, 2, 3);
            break;
        case kCVPixelFormatType_422YpCbCr8:
            glUniform4i([program uniform:@"PermuteMap"], 1, 0, 2, 0);
            [self setupYpCbCrCoefficientsWithVideoRange];
            break;
            
        case kCVPixelFormatType_4444AYpCbCr8:
            glUniform4i([program uniform:@"PermuteMap"], 1, 2, 3, 0);
            [self setupYpCbCrCoefficientsWithVideoRange];
            break;

        case kCVPixelFormatType_4444YpCbCrA8:
            // ordered Cb Y' Cr A. Our shader expects Y' Cb Cr A.
            glUniform4i([program uniform:@"PermuteMap"], 1, 0, 2, 3);
            [self setupYpCbCrCoefficientsWithVideoRange];
            break;
            
        case kCVPixelFormatType_444YpCbCr8:
            // The shader is configured for YpCbCr (A) ordering, but this format APPEARS to be
            // CbYpCr, so we use the PermuteMap to flip the bytes in the GPU:
            glUniform4i([program uniform:@"PermuteMap"], 1, 2, 0, 3);
        case kCVPixelFormatType_420YpCbCr8Planar:
            [self setupYpCbCrCoefficientsWithVideoRange];
            break;
        case kCVPixelFormatType_420YpCbCr8PlanarFullRange:
            [self setupYpCbCrCoefficientsWithFullRange];
            break;

        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            glUniform4i([program uniform:@"PermuteMap"], 0, 0, 1, 0);
            [self setupYpCbCrCoefficientsWithVideoRange];
            break;
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            glUniform4i([program uniform:@"PermuteMap"], 0, 0, 1, 0);
            [self setupYpCbCrCoefficientsWithFullRange];
            break;

        default:
            glUniform4i([program uniform:@"PermuteMap"], 0, 1, 2, 3);
            break;
    }
    
    glEnableVertexAttribArray([program attribute: @"Position"]);
    
    glUniform4f([program uniform:@"VertexPositionScale"], 1.0, 1.0, 1.0, 1.0);
    glUniform4f([program uniform:@"VertexPositionShift"], 0.0, 0.0, 0.0, 0.0);
    
    for (int texture = 0 ; texture < planeCount; texture++)
        glUniform1i([program uniform: [NSString stringWithFormat:@"texture%d", texture + 1]], texture);
    
    if (CGSizeEqualToSize(self.sourceImageSize, CGSizeZero) != false)
        [self setupShadersForCropAndScaling];
}

- (CGRect) calculateAspectFitFillRect
{
	CGFloat scale;
	CGRect scaledRect;
    
    // Get view dimensions in pixels
    NSRect backingBounds = [self convertRectToBacking:[self bounds]];
    GLsizei backingPixelWidth  = (GLsizei)(backingBounds.size.width),
            backingPixelHeight = (GLsizei)(backingBounds.size.height);
    
    if (pixelViewerContentMode == ContentModeCustomScaleAspectFit)
    {
        scale = MIN( backingPixelWidth/*self.drawableWidth*/ / self.textureCropRect.size.width,
                    backingPixelHeight/*self.drawableHeight*/ / self.textureCropRect.size.height);
    }
    else
    {
        scale = MAX( backingPixelWidth/*self.drawableWidth*/ / self.textureCropRect.size.width,
                    backingPixelHeight/*self.drawableHeight*/ / self.textureCropRect.size.height);
    }
	
	scaledRect.origin.x = (backingPixelWidth/*self.drawableWidth*/ - self.textureCropRect.size.width * scale) / 2;
	scaledRect.origin.y = (backingPixelHeight/*self.drawableHeight*/ - self.textureCropRect.size.height * scale) / 2;
	
	scaledRect.size.width = self.textureCropRect.size.width * scale;
	scaledRect.size.height = self.textureCropRect.size.height * scale;
	
	return scaledRect;
}

- (void) setSourceImageSize:(CGSize)sourceImageSize
{
    _sourceImageSize = sourceImageSize;
    _textureCropRect = CGRectMake(0, 0, sourceImageSize.width, sourceImageSize.height);
}

- (void) setupShadersForCropAndScaling
{
    // Get view dimensions in pixels
    NSRect backingBounds = [self convertRectToBacking:[self bounds]];
    GLsizei backingPixelWidth  = (GLsizei)(backingBounds.size.width),
    backingPixelHeight = (GLsizei)(backingBounds.size.height);
    
	CGSize viewSize = CGSizeMake(backingPixelWidth/*self.drawableWidth*/, backingPixelHeight/*self.drawableHeight*/);
	CGPoint scaleFactor = CGPointMake(self.sourceImageSize.width / backingPixelWidth/*self.drawableWidth*/, self.sourceImageSize.height / backingPixelHeight/*self.drawableHeight*/);
	CGPoint textureOffset = CGPointMake(0.0, 0.0);
		
	CGFloat cropCoordinates[4] = { 0, viewSize.height, viewSize.width, 0};
    
    /*
	switch (self.contentMode) {
		case UIViewContentModeTopLeft:
			cropCoordinates[0] = self.textureCropRect.origin.x;
			cropCoordinates[1] = viewSize.height - self.textureCropRect.origin.y;
			cropCoordinates[2] = self.textureCropRect.origin.x + self.textureCropRect.size.width;
			cropCoordinates[3] = viewSize.height - (self.textureCropRect.origin.y + self.textureCropRect.size.height);
			break;
        case UIViewContentModeLeft:
            cropCoordinates[0] = self.textureCropRect.origin.x;
            cropCoordinates[1] = (viewSize.height - self.textureCropRect.size.height) / 2;
            cropCoordinates[2] = self.textureCropRect.origin.x + self.textureCropRect.size.width;
            cropCoordinates[3] = cropCoordinates[1] + self.textureCropRect.size.height;
            textureOffset = CGPointMake(0, cropCoordinates[1] / viewSize.height);
            break;
        case UIViewContentModeBottom:
            cropCoordinates[0] = (viewSize.width - self.textureCropRect.size.width) / 2;
            cropCoordinates[1] = self.textureCropRect.size.height;
            cropCoordinates[2] = cropCoordinates[0] + self.textureCropRect.size.width;
            cropCoordinates[3] = 0;
            textureOffset = CGPointMake(cropCoordinates[0] / viewSize.width, 1 - cropCoordinates[1] / viewSize.height);
            break;
        case UIViewContentModeBottomLeft:
            cropCoordinates[0] = self.textureCropRect.origin.x;
            cropCoordinates[1] = self.textureCropRect.size.height;
            cropCoordinates[2] = self.textureCropRect.origin.x + self.textureCropRect.size.width;
            cropCoordinates[3] = 0;
            textureOffset = CGPointMake(0, 1 - cropCoordinates[1] / viewSize.height);
            break;
        case UIViewContentModeRight:
            cropCoordinates[0] = viewSize.width - self.textureCropRect.size.width;
            cropCoordinates[1] = (viewSize.height - self.textureCropRect.size.height) / 2;
            cropCoordinates[2] = viewSize.width;
            cropCoordinates[3] = cropCoordinates[1] + self.textureCropRect.size.height;
            textureOffset = CGPointMake(cropCoordinates[0] / viewSize.width, cropCoordinates[1] / viewSize.height);
            break;
    
        case UIViewContentModeBottomRight:
            cropCoordinates[0] = viewSize.width - self.textureCropRect.size.width;
            cropCoordinates[1] = self.textureCropRect.size.height;
            cropCoordinates[2] = viewSize.width;
            cropCoordinates[3] = 0;
            textureOffset = CGPointMake(cropCoordinates[0] / viewSize.width, 1 - cropCoordinates[1] / viewSize.height);
            break;

        case UIViewContentModeTopRight:
            cropCoordinates[0] = viewSize.width - self.textureCropRect.size.width;
            cropCoordinates[1] = viewSize.height - self.textureCropRect.origin.y;
            cropCoordinates[2] = viewSize.width;
            cropCoordinates[3] = viewSize.height - (self.textureCropRect.origin.y + self.textureCropRect.size.height);
            textureOffset = CGPointMake(cropCoordinates[0] / viewSize.width, 0);
            break;
        case UIViewContentModeTop:
            cropCoordinates[0] = (viewSize.width - self.textureCropRect.size.width) / 2;
            cropCoordinates[1] = viewSize.height - self.textureCropRect.origin.y;
            cropCoordinates[2] = cropCoordinates[0] + self.textureCropRect.size.width;
            cropCoordinates[3] = viewSize.height - (self.textureCropRect.origin.y + self.textureCropRect.size.height);
            textureOffset = CGPointMake(cropCoordinates[0] / viewSize.width, 0);
            break;
        case UIViewContentModeCenter:
            cropCoordinates[0] = (viewSize.width - self.textureCropRect.size.width) / 2;
            cropCoordinates[1] = (viewSize.height - self.textureCropRect.size.height) / 2;
            cropCoordinates[2] = cropCoordinates[0] + self.textureCropRect.size.width;
            cropCoordinates[3] = cropCoordinates[1] + self.textureCropRect.size.height;
            textureOffset = CGPointMake(cropCoordinates[0] / viewSize.width, cropCoordinates[1] / viewSize.height);
            break;
		case UIViewContentModeScaleToFill:
            scaleFactor.x = 1.0;
            scaleFactor.y = 1.0;
			break;
		case UIViewContentModeScaleAspectFill:
		case UIViewContentModeScaleAspectFit:
		{
            CGRect fittedRect;

            scaleFactor = CGPointMake(self.sourceImageSize.width / self.textureCropRect.size.width,
                                      self.sourceImageSize.height / self.textureCropRect.size.height);
            
            fittedRect = [self calculateAspectFitFillRect];

            textureOffset = CGPointMake(fittedRect.origin.x / self.drawableWidth, fittedRect.origin.y / self.drawableHeight);
            scaleFactor = CGPointMake(scaleFactor.x * (fittedRect.size.width / self.drawableWidth), scaleFactor.y * (fittedRect.size.height / self.drawableHeight));
			
			cropCoordinates[0] = fittedRect.origin.x;
			cropCoordinates[1] = self.drawableHeight - fittedRect.origin.y;
			cropCoordinates[2] = fittedRect.origin.x + fittedRect.size.width;
			cropCoordinates[3] = self.drawableHeight - (fittedRect.origin.y + fittedRect.size.height);
			
			break;
		}
		default:
			break;
	}
     */
    
	// Convert cropCoordinates to vertex coordinates (-1.0 -> 1.0). We do (x * 2 - 1) in order to normalize the values into a -1 -> 1.0 coordinate system. We essentially use the vertex array in order to clip the texture as specified.
	struct RectVertexes rectVertexes;
	rectVertexes.topLeft.x = cropCoordinates[0] / backingPixelWidth/*self.drawableWidth*/ * 2 - 1;
	rectVertexes.topLeft.y = cropCoordinates[1] / backingPixelHeight/*self.drawableHeight*/ * 2 - 1;

	rectVertexes.bottomLeft.x = cropCoordinates[0] / backingPixelWidth/*self.drawableWidth*/ * 2 - 1;
	rectVertexes.bottomLeft.y = cropCoordinates[3] / backingPixelHeight/*self.drawableHeight*/ * 2 - 1;

	rectVertexes.topRight.x = cropCoordinates[2] / backingPixelWidth/*self.drawableWidth*/ * 2 - 1;
	rectVertexes.topRight.y = cropCoordinates[1] / backingPixelHeight/*self.drawableHeight*/ * 2 - 1;

	rectVertexes.bottomRight.x = cropCoordinates[2] / backingPixelWidth/*self.drawableWidth*/ * 2 - 1;
	rectVertexes.bottomRight.y = cropCoordinates[3] / backingPixelHeight/*self.drawableHeight*/ * 2 - 1;
	
	Vertex finalVertexes[] = { rectVertexes.bottomLeft, rectVertexes.topLeft, rectVertexes.bottomRight, rectVertexes.bottomRight, rectVertexes.topLeft, rectVertexes.topRight };
	
    glBindBuffer(GL_ARRAY_BUFFER, clippedRectVertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(finalVertexes), finalVertexes, GL_STATIC_DRAW);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, clippedRectIndexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(SquareIndices), SquareIndices, GL_STATIC_DRAW);
	
	glVertexAttribPointer([program attribute:@"Position"], 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 2, 0);
	
	glUniform2f([program uniform: @"scaleFactor"], scaleFactor.x, scaleFactor.y);
	glUniform2f([program uniform:@"textureOffset"], textureOffset.x, textureOffset.y);
}

- (void) setupYpCbCrCoefficientsWithFullRange
{
    // BT.601 colorspace, full range:
    float coefficientMatrix[] = {   1.0,  0.000,  1.402, 0.0,
                                    1.0,  -0.34414, -0.71414, 0.0,
                                    1.0,  1.772,  0.000, 0.0,
                                    0.0, 0.0, 0.0, 1.0 };
    
    glUniformMatrix4fv([program uniform: @"coefficientMatrix"], 1, GL_FALSE, coefficientMatrix);
    
    glUniform4f([program uniform: @"YpCbCrOffsets"], 0.0, 0.5, 0.5, 0.0);
}

- (void) setupYpCbCrCoefficientsWithVideoRange
{
    // BT.601 colorspace, video range:
    float coefficientMatrix[] = {   1.1643,  0.000,  1.5958, 0.0,
                                    1.1643,  -0.39173, -0.81290, 0.0,
                                    1.1643,  2.017,  0.000, 0.0,
                                    0.0, 0.0, 0.0, 1.0 };
    
    glUniformMatrix4fv([program uniform: @"coefficientMatrix"], 1, GL_FALSE, coefficientMatrix);
    
    
    glUniform4f([program uniform: @"YpCbCrOffsets"], 0.0625, 0.5, 0.5, 0.0);
}

- (void) loadTextureForPlane: (EEPixelViewerPlane *) plane forTextureIndex: (int) textureIndex
{
    glActiveTexture(GL_TEXTURE0 + textureIndex);
    
    glBindTexture(GL_TEXTURE_2D, textures[textureIndex]);
    
    if (1)//self.context.API == kEAGLRenderingAPIOpenGLES3)
    {
        glPixelStorei(GL_UNPACK_ROW_LENGTH, (GLint) plane->rowBytes / pixelBufferParameters[textureIndex].bytesPerPixel);
    }
    else
    {
        // For OpenGL ES 2.0 we set internal format to the same as the incoming buffer format:
        pixelBufferParameters[textureIndex].internalFormat = pixelBufferParameters[textureIndex].pixelDataFormat;
    }
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glTexImage2D(GL_TEXTURE_2D,                                         // target
                 0,                                                     // level
                 pixelBufferParameters[textureIndex].internalFormat,    // internalFormat
                 (GLsizei) plane->width,                                // width
                 (GLsizei) plane->height,                               // height
                 0,                                                     // border
                 pixelBufferParameters[textureIndex].pixelDataFormat,   // format
                 pixelBufferParameters[textureIndex].dataType,          // type
                 plane->data);                                          // pixels
    
    GLenum errorCode = glGetError();
    
    if (errorCode != GL_NO_ERROR)
        NSLog(@"glTexImage2D failed with error %d", errorCode);
}

- (void) drawRect:(CGRect)rect
{
    // First make sure we don't try to run OGL code in the background -- it crashes the app:
    //if (![NSApplication sharedApplication].active)
    //    return;

    [super drawRect: rect];
    
    //[self.openGLContext makeCurrentContext];
	
	[program use];
    
    //[self setupShadersForCropAndScaling];
    
    /* int planeCount=1;
    for (int i = 0; i < planeCount; i++)
    {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, textures[i]);
    } */
    
    CGFloat red, green, blue, alpha;
    //[self.backgroundColor getRed: &red green: &green blue: &blue alpha: &alpha];
    //glClearColor(red, green, blue, alpha);
    //glClearColor(0.5f, 0.0f, 0.0f, 1.0f);
    //glClear(GL_COLOR_BUFFER_BIT);
		
    // Get view dimensions in pixels
    NSRect backingBounds = [self convertRectToBacking:[self bounds]];
    GLsizei backingPixelWidth  = (GLsizei)(backingBounds.size.width),
    backingPixelHeight = (GLsizei)(backingBounds.size.height);
    
	glViewport(0, 0, (GLsizei) backingPixelWidth/*self.drawableWidth*/, (GLsizei) backingPixelHeight/*self.drawableHeight*/);
	
    //GLint vao;
    //glGetIntegerv(GL_VERTEX_ARRAY_BINDING, &vao);
	
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_BYTE, 0);
    
    if (_fpsIndicator == YES)
        [self updateFPSIndicator];
    
    [self.openGLContext flushBuffer];
}

- (void) setFpsIndicator:(BOOL)fpsIndicator
{
    if (fpsIndicator == YES)
    {
        fpsLabel = [[NSLabel alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, 30)]; //[[NSLabel alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
        //fpsLabel.autoresizingMask = NSViewWidthSizable;
        /* https://stackoverflow.com/questions/2654580/how-to-resize-nstextview-according-to-its-content :
         NSTextView *textView = [[NSTextView alloc] init];
         textView.font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
         textView.string = @"Lorem ipsum";
         
         [textView.layoutManager ensureLayoutForTextContainer:textView.textContainer];
         
         textView.frame = [textView.layoutManager usedRectForTextContainer:textView.textContainer];

         */
        fpsLabel.textColor = [NSColor whiteColor];
        fpsLabel.backgroundColor = [NSColor blackColor];
        [self addSubview: fpsLabel];
        
        fpsLabel.text = @"";
        maxFrames = 30;
    }
    _fpsIndicator = fpsIndicator;
}

- (void) updateFPSIndicator
{
    NSTimeInterval latestInterval = 0;
    
    if (lastTimestamp != nil)
        latestInterval = -[lastTimestamp timeIntervalSinceNow];
    
    if (totalFrames >= maxFrames)
    {
        totalTime -= (totalTime / totalFrames);
    }
    else
        totalFrames++;
    
    totalTime += latestInterval;
    
    [fpsLabel performSelectorOnMainThread: @selector(setText:) withObject:[NSString stringWithFormat: @"Resolution: %dx%d. Average FPS:%.0f", (int) _sourceImageSize.width, (int) _sourceImageSize.height, (float) totalFrames / (float) totalTime] waitUntilDone:NO];
    lastTimestamp = [NSDate date];
}

- (void) display
{
    //if (![NSApplication sharedApplication].active)
    //    return;
    
    //[program use];
    
    //[self setupShadersForCropAndScaling];
    
    [self setNeedsDisplay:YES]; //[super display];
}

- (void) setContentMode:(ContentModeCustom)contentMode
{
    pixelViewerContentMode = contentMode;
}

- (ContentModeCustom) contentMode
{
    return pixelViewerContentMode;
}

- (void) dealloc
{
    [self.openGLContext makeCurrentContext];
	
    glDeleteTextures(4, textures);
	glDeleteBuffers(1, &rectVertexBuffer);
	glDeleteBuffers(1, &rectIndexBuffer);
}

#pragma mark - Public API
- (void) displayPixelBufferPlanes:(EEPixelViewerPlane *)planes count:(int)planeCount withCompletion: (void (^)())completionBlock
{
    [self displayPixelBufferPlanes: planes count:planeCount];
    
    if (completionBlock != nil)
        completionBlock();
}

// load24bppAsPlanarTextures: This is an optimization for ES 2.0 where we convert any 24bpp formats
// to 3 8bpp planes which are then loaded to the GPU. The conversion is done efficiently on multiple
// threads using Accelerate.framework. On devices that support OpenGL ES 3.0 we just load the 24bpp
// textures directly, which seems to be an overall better compromise.
- (void) load24bppAsPlanarTextures: (EEPixelViewerPlane *) planes count: (int) planeCount
{
    vImage_Buffer destPlanarBuffers[3] = { malloc(_sourceImageSize.width * _sourceImageSize.height), _sourceImageSize.height, _sourceImageSize.width, _sourceImageSize.width,
        
        malloc(_sourceImageSize.width * _sourceImageSize.height), _sourceImageSize.height, _sourceImageSize.width, _sourceImageSize.width,
        
        malloc(_sourceImageSize.width * _sourceImageSize.height), _sourceImageSize.height, _sourceImageSize.width, _sourceImageSize.width};
    
    vImage_Buffer sourceRGBBuffer = { planes[0].data, planes[0].height, planes[0].width, planes[0].rowBytes };

    switch ([self pixelFormat])
    {
        case kCVPixelFormatType_24RGB:
            vImageConvert_RGB888toPlanar8(&sourceRGBBuffer, &destPlanarBuffers[0], &destPlanarBuffers[1], &destPlanarBuffers[2], kvImageNoFlags);
            break;
        case kCVPixelFormatType_444YpCbCr8:
            vImageConvert_RGB888toPlanar8(&sourceRGBBuffer, &destPlanarBuffers[2], &destPlanarBuffers[0], &destPlanarBuffers[1], kvImageNoFlags);
            break;
        case kCVPixelFormatType_24BGR:
            vImageConvert_RGB888toPlanar8(&sourceRGBBuffer, &destPlanarBuffers[2], &destPlanarBuffers[1], &destPlanarBuffers[0], kvImageNoFlags);
            break;
    }
    
    for (int planeIndex = 0 ; planeIndex < 3; planeIndex ++)
    {
        EEPixelViewerPlane pvPlane = { destPlanarBuffers[planeIndex].data, destPlanarBuffers[planeIndex].height, destPlanarBuffers[planeIndex].width, destPlanarBuffers[planeIndex].rowBytes };
        [self loadTextureForPlane: &pvPlane forTextureIndex: planeIndex];
        free (destPlanarBuffers[planeIndex].data);
    }
}

- (void) displayPixelBufferPlanes: (EEPixelViewerPlane *) planes count: (int) planeCount
{
    [self.openGLContext makeCurrentContext];
    [program use];
    
    switch ([self pixelFormat])
    {
        case kCVPixelFormatType_422YpCbCr8:
            // Special case for an interleaved 4:2:2 YpCbCr case because we need to load the same texture twice in
            // order to correctly parse this one:
            [self loadTextureForPlane: &planes[0] forTextureIndex: 0];
            planes[0].width = planes[0].width / 2;
            [self loadTextureForPlane: &planes[0] forTextureIndex: 1];
            break;
        case kCVPixelFormatType_444YpCbCr8:
        case kCVPixelFormatType_24BGR:
        case kCVPixelFormatType_24RGB:
        {
            if (treat24bppAs3Planes == YES)
            {
                [self load24bppAsPlanarTextures: (EEPixelViewerPlane *) planes count: (int) planeCount];
                break;
            }
            // NOTE: If we're treating 24-bpp formats as usual, just flow on to the default case.
            // These switch cases MUST be kept last before the default block!
        }
        default:
            for (int i = 0; i < planeCount; i++)
            {
                [self loadTextureForPlane: &planes[i] forTextureIndex: i];
            }
            break;
    }
    
    [self display];
}

@end

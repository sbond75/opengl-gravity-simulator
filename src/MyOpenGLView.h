// https://stackoverflow.com/questions/22427776/the-simplest-minimalistic-opengl-3-2-cocoa-project

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>

@interface MyOpenGLView : NSOpenGLView
{
    GLuint shaderProgram;
    GLuint vertexArrayObject;
    GLuint vertexBuffer;
    
    GLint positionUniform;
    GLint colourAttribute;
    GLint positionAttribute;
}
@end

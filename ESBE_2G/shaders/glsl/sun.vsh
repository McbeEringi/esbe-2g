// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "vertexVersionCentroidUV.h"

attribute POS4 POSITION;
attribute vec2 TEXCOORD_0;
uniform MAT4 WORLDVIEWPROJ;
varying vec2 p;

void main()
{
	gl_Position = WORLDVIEWPROJ * (POSITION*vec2(10.,1.).xyxy);
	p = (POSITION.xz*10.)*mat2(.8,.6,-.6,.8);

	uv = TEXCOORD_0;
}

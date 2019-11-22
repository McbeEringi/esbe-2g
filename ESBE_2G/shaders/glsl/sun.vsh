// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "vertexVersionCentroidUV.h"

attribute POS4 POSITION;
attribute vec2 TEXCOORD_0;
uniform MAT4 WORLDVIEWPROJ;
varying vec2 p;

void main()
{
	gl_Position = WORLDVIEWPROJ * POSITION;
	p = POSITION.xz;

	uv = TEXCOORD_0;
}

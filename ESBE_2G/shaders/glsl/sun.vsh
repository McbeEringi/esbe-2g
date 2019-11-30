// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#if __VERSION__ >= 300
	#define attribute in
	#define varying out
	#ifdef MSAA_FRAMEBUFFER_ENABLED
		#define _centroid centroid
	#else
		#define _centroid
	#endif
	_centroid out vec2 uv;
#else
	varying vec2 uv;
#endif

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

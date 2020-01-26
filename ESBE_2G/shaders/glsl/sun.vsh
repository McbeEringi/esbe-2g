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
uniform MAT4 WORLDVIEW;
varying vec2 pos;
varying vec4 lf;

void main()
{
	POS4 p = POSITION*vec2(10.,1.).xyxy;
	gl_Position = WORLDVIEWPROJ * p;
	pos = mat2(.8,.6,-.6,.8)*p.xz;
	lf = vec4(p.xz,(WORLDVIEW * p).xy);
	uv = TEXCOORD_0;
}

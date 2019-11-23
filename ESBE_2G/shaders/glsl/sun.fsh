// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "fragmentVersionCentroidUV.h"

#if __VERSION__ >= 420
	#define LAYOUT_BINDING(x) layout(binding = x)
#else
	#define LAYOUT_BINDING(x)
#endif

LAYOUT_BINDING(0) uniform sampler2D TEXTURE_0;
varying vec2 p;

void main()
{
	float l = length(p);
	float esbe = mix((step(.25,uv.x)+step(.5,uv.x)+step(.75,uv.x))*.1+step(.5,uv.y)*.4,1.,step(.5,texture2D(TEXTURE_0,vec2(.5)).r));//[0.~.7,1.]

	gl_FragColor = vec4(max(cos(min(l*10.,1.58)),.5-l));
}

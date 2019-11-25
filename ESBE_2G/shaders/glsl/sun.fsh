// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "fragmentVersionCentroidUV.h"
#include "snoise.h"

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
	float sun = max(cos(min(l*12.,1.58)),.5-l*.7);
	float mp = (floor(uv.x*4.)*.25+step(uv.y,.5))*3.1415;//[0~2pi]
	float r =.13;//月半径 ~0.5
	vec3 n = normalize(vec3(p,sqrt(r*r-l*l)));
	float moon = dot(-vec3(sin(mp),0.,cos(mp)),n);
	moon = smoothstep(-r,0.,moon)*(moon*.2+.8)*smoothstep(r,r-r*.1,l);
	moon *= 1.-smoothstep(1.5,0.,snoise(p+n.xy+5.)*.5+snoise((p+n.xy)*3.)*.25+.75)*.15;
	moon = max(moon,cos(min(l*2.,1.58))*sin(mp*.5)*.6);//拡散光

	gl_FragColor = vec4(1.,.95,.81,1.)*mix(moon,sun,step(.5,texture2D(TEXTURE_0,vec2(.5)).r));
}

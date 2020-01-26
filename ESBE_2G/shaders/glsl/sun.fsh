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
uniform vec2 FOG_CONTROL;
varying vec4 pos;

void main()
{
	vec2 p = pos.xy;
	float l = length(p);
	float s;
	if(texture2D(TEXTURE_0,vec2(.5)).r>.5)
		s = max(cos(min(l*12.,1.58)),.5-l*.7);
	else{
		float mp = (floor(uv.x*4.)*.25+step(uv.y,.5))*3.1415;//[0~2pi]
		float r =.13;//月半径 ~0.5
		vec3 n = normalize(vec3(p,sqrt(r*r-l*l)));
		s = smoothstep(-.3,.5,dot(-vec3(sin(mp),0.,cos(mp)),n));
		s *= smoothstep(r,r-r*.05,l);
		s *= 1.-smoothstep(1.5,0.,snoise(p+n.xy+5.)*.5+snoise((p+n.xy)*3.)*.25+.75)*.15;
		s = max(s,cos(min(l*2.,1.58))*sin(mp*.5)*.6);//拡散光
	}
	gl_FragColor = vec4(1.,.95,.81,smoothstep(.7,1.,FOG_CONTROL.y))*s;
}

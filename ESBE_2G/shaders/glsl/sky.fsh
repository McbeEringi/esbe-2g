// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#if __VERSION__ >= 300
	#define varying in
	#define texture2D texture
	out vec4 FragColor;
	#define gl_FragColor FragColor
#else
#endif

#ifdef GL_FRAGMENT_PRECISION_HIGH
	#define HM highp
#else
	#define HM mediump
#endif
uniform vec4 FOG_COLOR;
uniform vec2 FOG_CONTROL;
uniform vec4 CURRENT_COLOR;
uniform HM float TOTAL_REAL_WORLD_TIME;

varying float fog;
varying highp vec2 pos;

#include "snoise.h"

highp float fBM(const int octaves, const float lowerBound, const float upperBound, highp vec2 st) {
	highp float value = 0.0;
	highp float amplitude = 0.5;
	for (int i = 0; i < octaves; i++) {
		value += amplitude * (snoise(st) * 0.5 + 0.5);
		if (value >= upperBound) break;
		else if (value + amplitude <= lowerBound) break;
		st        *= 2.0;
		st.x      -=TOTAL_REAL_WORLD_TIME*.002*float(i+1);
		amplitude *= 0.5;
	}
	return smoothstep(lowerBound, upperBound, value);
}


void main()
{
	//DATABASE
	float day = smoothstep(0.15,0.25,FOG_COLOR.g);
	float weather = smoothstep(0.8,1.0,FOG_CONTROL.y);
	float ss = clamp(FOG_COLOR.r-FOG_COLOR.g,0.,.5)*2.;
	bool uw = FOG_CONTROL.x==0.;

	vec3 top_col = mix(mix(vec3(0.0,0.0,0.1),vec3(-0.1,0.0,0.1),day),vec3(.5),ss*.5)*weather;
	vec3 hor_col = mix(mix(vec3(0.0,0.1,0.2),vec3(0.2,0.1,-0.05),day),vec3(.7),ss*.5)*weather;

	vec4 col = vec4(mix(CURRENT_COLOR.rgb+top_col,FOG_COLOR.rgb+hor_col,smoothstep(0.,.4,fog)),1.);

		//AURORA
		float aflag = (1.-day)*weather;
		if(aflag > 0.){
			vec2 apos = vec2(pos.x-TOTAL_REAL_WORLD_TIME*.004,pos.y*10.);
			apos.y += sin(pos.x*20.+TOTAL_REAL_WORLD_TIME*.1)*.15;
			vec3 ac = mix(/*オーロラ色1*/vec3(0.,.8,.4),/*オーロラ色2*/vec3(.4,.2,.8),sin(apos.x+apos.y+TOTAL_REAL_WORLD_TIME*.01)*.5+.5);
			float am = fBM(4,.5,1.,apos);
			col.rgb += ac*am*smoothstep(.5,0.,length(pos))*aflag;
		}

		//CLOUDS
		vec3 cc = mix(/*雨*/vec3(mix(.2,.9,day)),mix(mix(/*夜*/vec3(.1,.18,.38),/*昼*/vec3(.97,.96,.90),day),/*日没*/vec3(.97,.72,.38),ss),weather);
		float lb = mix(.1,.5,weather);
		float cm = fBM(uw?4:6,lb,.8,pos*3.-TOTAL_REAL_WORLD_TIME*.002);
		if(cm>0.){
			float br = fBM(uw?2:4,lb,.9,pos*2.6-TOTAL_REAL_WORLD_TIME*.002);
			cc *= mix(1.03,.8,br*(1.-ss*.7));
		}
		col.rgb = mix(col.rgb,cc,cm);

	gl_FragColor = mix(col,FOG_COLOR,fog);
}

// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "fragmentVersionCentroid.h"

#if __VERSION__ >= 300
	#ifndef BYPASS_PIXEL_SHADER
		#if defined(TEXEL_AA) && defined(TEXEL_AA_FEATURE)
			_centroid in highp vec2 uv0;
			_centroid in highp vec2 uv1;
		#else
			_centroid in vec2 uv0;
			_centroid in vec2 uv1;
		#endif
	#endif
#else
	#ifndef BYPASS_PIXEL_SHADER
		varying vec2 uv0;
		varying vec2 uv1;
	#endif
#endif

varying vec4 color;
#ifdef FOG
	varying float fog;
#endif

#ifdef GL_FRAGMENT_PRECISION_HIGH
	#define HM highp
#else
	#define HM mediump
#endif
varying HM vec3 cPos;
varying HM vec3 wPos;
varying float wf;

#include "uniformShaderConstants.h"
#include "uniformPerFrameConstants.h"
#include "util.h"
#include "snoise.h"

LAYOUT_BINDING(0) uniform sampler2D TEXTURE_0;
LAYOUT_BINDING(1) uniform sampler2D TEXTURE_1;
LAYOUT_BINDING(2) uniform sampler2D TEXTURE_2;

//#define DEBUG//デバッグ画面

vec3 curve(vec3 x){
	float A = 0.50;
	float B = 0.10;
	float C = 0.40;
	float D = 0.65;
	float E = 0.05;
	float F = 0.20;
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

vec3 tonemap(vec3 col, vec3 gamma){
	float saturation = 1.2;
	float exposure = 1.0;
	col = pow(col,1./gamma);
	float luma = dot(col, vec3(0.298912, 0.586611, 0.114478));
	col = curve((col-luma)*saturation+luma);
	return col/curve(vec3(1./exposure));
}

float flat_sh(float dusk){
	vec3 n = normalize(cross(dFdx(cPos),dFdy(cPos)));
	float s = min(1.,dot(n,vec3(0.,.8,.6))*.45+.64);
	return mix(s,max(dot(n,vec3(.9,.44,0.)),dot(n,vec3(-.9,.44,0.)))*1.3+.2,dusk);
}

vec4 water(vec4 col,float weather,float uw,highp float time){
	float sun = smoothstep(.5,.75,uv1.y);
	float cosT = 1.-dot(normalize(abs(wPos)).y,1.);
	col.rgb = mix(col.rgb,FOG_COLOR.rgb,cosT*cosT*sun*uw*.6);

	vec3 p = cPos;
	p.xz = p.xz*vec2(1.0,0.4)//縦横比 aspect ratio
		+smoothstep(0.,8.,abs(p.y-8.))*.5;
	float n = (snoise(p.xz-time*.5)+snoise(vec2(p.x-time,(p.z+time)*.5)))/4.+.5;//[0.0~1.0]

	//highp vec2 skp = (wPos.xz+n*2.*wPos.xz/max(length(wPos.xz),.5))*cosT*.1;//反射ズレ計算
	vec2 skp = wPos.xz*cosT*.1;
	float skn = snoise(vec2(skp.x-time*.1,skp.y))/2.+.5;//[0.0~1.0]
	vec4 col2 = col*(mix(1.5,1.3,skn*sun)-cosT*.2);//almost C_REF in ESBE1G
	vec4 col3 = mix(col*1.1,vec4(1.),smoothstep(3.+abs(wPos.y)*.3,0.,abs(wPos.z))*sun*weather*smoothstep(0.,.7,cosT));

	vec4 diffuse = mix(col,mix(col2,col3,smoothstep(.5,.9,n)),smoothstep(0.,.5,n));
	return mix(col,diffuse,max(.4,cosT));
}


void main()
{
#ifdef BYPASS_PIXEL_SHADER
	gl_FragColor = vec4(0, 0, 0, 0);
	return;
#else

#if USE_TEXEL_AA
	HM vec4 diffuse = texture2D_AA(TEXTURE_0, uv0);
#else
	HM vec4 diffuse = texture2D(TEXTURE_0, uv0);
#endif

#ifdef SEASONS_FAR
	diffuse.a = 1.0;
#endif

#if USE_ALPHA_TEST
	#ifdef ALPHA_TO_COVERAGE
	#define ALPHA_THRESHOLD 0.05
	#else
	#define ALPHA_THRESHOLD 0.6
	#endif
	if(diffuse.a < ALPHA_THRESHOLD)discard;
	//if(color.a==0. && !(gl_FrontFacing))discard;
#endif

vec4 inColor = color;

#if defined(BLEND)
	diffuse.a *= inColor.a;
#endif

#if !defined(ALWAYS_LIT)
	diffuse *= texture2D( TEXTURE_1, uv1 );
#endif

#ifndef SEASONS
	#if !USE_ALPHA_TEST && !defined(BLEND)
		diffuse.a = inColor.a;
	#endif

	diffuse.rgb *= inColor.rgb;
#else
	vec2 uv = inColor.xy;
	diffuse.rgb *= mix(vec3(1.0,1.0,1.0), texture2D( TEXTURE_2, uv).rgb*2.0, inColor.b);
	diffuse.rgb *= inColor.aaa;
	diffuse.a = 1.0;
#endif

//DATABASE
#ifdef FOG
	float weather = smoothstep(0.8,1.0,FOG_CONTROL.y);
#else
	float weather = 1.0;
#endif
vec2 daylight = texture2D(TEXTURE_1,vec2(0.,1.)).rr;
daylight.x *= weather;
float sunlight = smoothstep(0.865,0.875,uv1.y);
float indoor = smoothstep(1.0,0.5,uv1.y);
float dusk = min(smoothstep(0.4,0.55,daylight.y),smoothstep(0.8,0.65,daylight.y));
float uw = step(FOG_CONTROL.x,.0001);

//ESBE_tonemap	see http://filmicworlds.com/blog/filmic-tonemapping-operators/
//1が標準,小…暗,大…明
vec3 ambient = mix(mix(mix(/*雨*/vec3(0.8,0.82,1.0),mix(mix(/*夜*/vec3(0.7,0.72,0.8),/*昼*/vec3(1.57,1.56,1.5),daylight.y),/*日没*/vec3(1.6,1.25,0.8),dusk),weather),/*水*/vec3(1.),wf),/*屋内*/vec3(1.2,1.1,1.0),indoor);
if(bool(uw))ambient = FOG_COLOR.rgb+.7;
diffuse.rgb = tonemap(diffuse.rgb,ambient);

//ESBE_light
#ifndef BLEND
	#define dpow(x) x*x//光源の減衰の調整
	diffuse.rgb += max(uv1.x-.5,0.)*(1.-dpow(diffuse.rgb))*mix(1.,indoor*.7+.3,daylight.x)*
	vec3(1.0,0.65,0.3);//光源RGB torch color
#endif

//ESBEwater
#ifdef FANCY
	if(wf+uw>.5)diffuse = water(diffuse,weather,1.-uw,TIME);
#endif

//ESBE_shadow
float ao = 1.;
if(color.r==color.g && color.g==color.b)ao = smoothstep(.48*daylight.y,.52*daylight.y,color.g);

diffuse.rgb *= 1.-mix(/*影の濃さ*/0.5,0.0,min(sunlight,ao))*(1.-uv1.x)*daylight.x;
#ifdef FANCY//FLAT_SHADING
	diffuse.rgb *= mix(1.0,flat_sh(dusk),smoothstep(.7,.95,uv1.y)*min(1.25-uv1.x,1.)*daylight.x);
#endif

#ifdef FOG
	diffuse.rgb = mix( diffuse.rgb, FOG_COLOR.rgb, fog );
#endif

#ifdef DEBUG
	vec2 subdisp = gl_FragCoord.xy/1000.;
	if(subdisp.x<1. && subdisp.y<1.){
		vec3 subback = vec3(1);
		if(subdisp.x>0. && subdisp.x<=.2 && subdisp.y<=daylight.y)subback.rgb=vec3(1,.7,0);
		if(subdisp.x>.2 && subdisp.x<=.4 && subdisp.y<=weather)subback.rgb=vec3(0,.5,1);
		if(subdisp.x>.4 && subdisp.x<=.6 && subdisp.y<=dusk)subback.rgb=vec3(1,0,0);
		if(subdisp.x>.6 && subdisp.x<=.8 && subdisp.y<=FOG_COLOR.g)subback.rgb=vec3(.5,1.,.5);
		if(subdisp.x>.8 && subdisp.x<=1. && subdisp.y<=FOG_CONTROL.x)subback.rgb=vec3(.5,.5,.5);
		diffuse = mix(diffuse,vec4(subback,1),.5);
		vec3 tone = tonemap(subdisp.xxx,ambient);
		if(subdisp.y<=tone.r+.005 && subdisp.y>=tone.r-.005)diffuse.rgb=vec3(1,0,0);
		if(subdisp.y<=tone.g+.005 && subdisp.y>=tone.g-.005)diffuse.rgb=vec3(0,1,0);
		if(subdisp.y<=tone.b+.005 && subdisp.y>=tone.b-.005)diffuse.rgb=vec3(0,0,1);
	}
#endif

	gl_FragColor = diffuse;

#endif // BYPASS_PIXEL_SHADER
}

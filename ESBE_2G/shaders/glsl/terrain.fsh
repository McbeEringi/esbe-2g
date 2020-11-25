// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "fragmentVersionCentroid.h"

#if __VERSION__ >= 300
	#define USE_NORMAL
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

#include "util.h"
#include "snoise.h"
uniform HM float TOTAL_REAL_WORLD_TIME;
uniform vec4 FOG_COLOR;
uniform vec2 FOG_CONTROL;

LAYOUT_BINDING(0) uniform sampler2D TEXTURE_0;
LAYOUT_BINDING(1) uniform sampler2D TEXTURE_1;
LAYOUT_BINDING(2) uniform sampler2D TEXTURE_2;

vec3 curve(vec3 x){
	const float A = 0.50;
	const float B = 0.10;
	const float C = 0.40;
	const float D = 0.65;
	const float E = 0.05;
	const float F = 0.20;
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

vec3 tonemap(vec3 col, vec3 gamma){
	const float saturation = 1.2;
	//const float exposure = 1.0;
	col = pow(col,1./gamma);
	float luma = dot(col, vec3(0.298912, 0.586611, 0.114478));
	col = curve((col-luma)*saturation+luma);
	return col/curve(vec3(1/*1./exposure*/));
}

vec4 water(vec4 col,float weather,float uw,vec3 tex1){
	HM float time = TOTAL_REAL_WORLD_TIME; vec3 p = cPos;
	float sun = smoothstep(.5,.9,uv1.y);
	vec3 T = normalize(abs(wPos)); float cosT = length(T.xz);
	p.xz = p.xz*vec2(1.0,0.4)/*縦横比*/+smoothstep(0.,8.,abs(p.y-8.))*.5;
	float n = (snoise(p.xz-time*.5)+snoise(vec2(p.x-time,(p.z+time)*.5)))+2.;//[0.~4.]

	vec4 diffuse = mix(col,col*mix(1.5,1.3,T.y*uw),pow(1.-abs(n-2.)*.5,bool(uw)?1.5:2.5));
	if(bool(uw)){//new C_REF
		highp vec2 skp = (wPos.xz+n*4./*波の高さ*/*wPos.xz/max(length(wPos.xz),.5))*cosT*.1;
		skp.x -= time*.05;
		vec2 ssreff = mix(vec2(.7,.7),vec2(.8,.6),clamp(FOG_COLOR.r-FOG_COLOR.g,0.,.4)*2.5);
		vec4 skc = mix(mix(col,FOG_COLOR,cosT*.8),vec4(mix(tex1,FOG_COLOR.rgb,cosT*.7),1),smoothstep(0.,1.,snoise(skp)));
		float s_ref = sun*weather*smoothstep(.7,0.,T.y)*mix(.3,1.,smoothstep(1.5,4.,n))*.9;
		skc = mix(skc,vec4(1),smoothstep(3.+abs(wPos.y)*.3,0.,abs(wPos.z))*s_ref);
		diffuse = mix(diffuse,skc,cosT*sun);
	}
	return mix(diffuse,col,min(.7,T.y));
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
	#define ALPHA_THRESHOLD 0.52
	#endif
	if(diffuse.a < ALPHA_THRESHOLD)discard;
#endif

vec4 inColor = color;
#ifdef BLEND
	diffuse.a *= inColor.a;
#endif

vec4 tex1 = texture2D(TEXTURE_1,uv1);
#ifndef ALWAYS_LIT
	diffuse *= tex1;
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
float weather =
#ifdef FOG
	smoothstep(.7,.96,FOG_CONTROL.y);
#else
	1.;
#endif
vec2 daylight = texture2D(TEXTURE_1,vec2(0.,1.)).rr;
daylight.x *= weather;
float sunlight = smoothstep(0.865,0.875,uv1.y);
float indoor = smoothstep(1.0,0.5,uv1.y);
float dusk = min(smoothstep(0.4,0.55,daylight.y),smoothstep(0.8,0.65,daylight.y));
float uw = step(FOG_CONTROL.x,0.);
float nether = FOG_CONTROL.x/FOG_CONTROL.y;nether=step(.1,nether)-step(.12,nether);
//float nv = step(.9,texture2D(TEXTURE_1,vec2(0)).r);

//ESBE_tonemap	see http://filmicworlds.com/blog/filmic-tonemapping-operators/
//1が標準,小…暗,大…明
vec3 ambient = mix(mix(mix(/*雨*/vec3(0.8,0.82,1.0),mix(mix(/*夜*/vec3(0.7,0.72,0.8),/*昼*/vec3(1.57,1.56,1.5),daylight.y),/*日没*/vec3(1.6,1.25,0.8),dusk),weather),/*水*/vec3(1.),wf),/*屋内*/vec3(1.2,1.1,1.0),indoor);
if(uw+nether>.5)ambient = FOG_COLOR.rgb/dot(FOG_COLOR.rgb,vec3(0.298912, 0.586611, 0.114478))*.1+.9;//fogcolor based tonemap(Nether&Underwater)
diffuse.rgb = tonemap(diffuse.rgb,ambient);

//ESBE_light
#ifndef BLEND
	#define dpow(x) x*x//光源の減衰の調整
	diffuse.rgb += max(uv1.x-.5,0.)*(1.-dpow(diffuse.rgb))*mix(1.,indoor*.7+.3,daylight.x)*
	vec3(1.0,0.65,0.3);//光源RGB torch color
#endif

//ESBEwater
#ifdef FANCY
	#ifdef USE_NORMAL
		vec3 n = normalize(cross(dFdx(cPos),dFdy(cPos)));
	#endif
	if(wf+uw>.5){
		diffuse = water(diffuse,weather,1.-uw,tex1.rgb);
		#ifdef USE_NORMAL
			float w_r = 1.-dot(normalize(-wPos),n);
			diffuse.a = mix(diffuse.a,1.,.02+.98*w_r*w_r*w_r*w_r*w_r);
		#endif
	}
#endif

//ESBE_shadow
float ao = 1.;
if(color.r==color.g && color.g==color.b)ao = smoothstep(.48*daylight.y,.52*daylight.y,color.g);
diffuse.rgb *= 1.-mix(/*影の濃さ*/0.5,0.0,min(sunlight,ao))*(1.-uv1.x)*daylight.x;
#if defined(FANCY) && defined(USE_NORMAL)//FLAT_SHADING
	float fl_s = min(1.,dot(n,vec3(0.,.8,.6))*.45+.64);
	fl_s = mix(fl_s,max(dot(n,vec3(.9,.44,0.)),dot(n,vec3(-.9,.44,0.)))*1.3+.2,dusk);
	diffuse.rgb *= mix(1.0,fl_s,smoothstep(.7,.95,uv1.y)*min(1.25-uv1.x,1.)*daylight.x);
#endif

//ESBE_sun_ref (unused)
//vec4(1)…色, vec3(1)…座標
/*#ifdef BLEND
if(diffuse.a!=0.){
	vec3 N = normalize(cross(dFdx(cPos),dFdy(cPos)));
	diffuse = mix(diffuse,vec4(1),.8*smoothstep(.9,1.,dot(normalize(vec3(1)),reflect(normalize(wPos),N))));
	diffuse = mix(diffuse,(FOG_COLOR+vec4(ambient,1))*.5,.7*clamp(1.-dot(normalize(-wPos),N),0.,1.));}
#endif*/

#ifdef FOG
	diffuse.rgb = mix( diffuse.rgb, FOG_COLOR.rgb, fog );
#endif

//#define DEBUG//デバッグ画面
#ifdef DEBUG
	HM vec2 subdisp = gl_FragCoord.xy/1024.;
	if(subdisp.x<1. && subdisp.y<1.){
		vec3 subback = vec3(1);
		#define sdif(X,W,Y,C) if(subdisp.x>X && subdisp.x<=X+W && subdisp.y<=Y)subback.rgb=C;
		sdif(0.,1.,.5,vec3(.5))
		sdif(0.,.2,daylight.y,vec3(1,.7,0))
		sdif(.2,.2,weather,vec3(.5,.5,1))
		sdif(.4,.1,dusk,vec3(1.,.5,.2))
		sdif(.5,.1,clamp(FOG_COLOR.r-FOG_COLOR.g,0.,.4)*2.5,vec3(1.,.5,.2))
		//fcol
		sdif(.6,.05,FOG_COLOR.r,vec3(1,.5,.5))sdif(.65,.05,FOG_COLOR.g,vec3(.5,1,.5))
		sdif(.7,.05,FOG_COLOR.b,vec3(.5,.5,1))sdif(.75,.05,FOG_COLOR.a,vec3(.7))
		//fctr
		sdif(.8,.1,FOG_CONTROL.x,vec3(1,.5,.5))sdif(.9,.1,FOG_CONTROL.y,vec3(.5,1,.5))
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

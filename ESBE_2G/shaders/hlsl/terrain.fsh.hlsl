#include "ShaderConstants.fxh"
#include "util.fxh"
#include "snoise.fxh"

struct PS_Input
{
	float4 position : SV_Position;
	float3 cPos : chunkedPos;
	float3 wPos : worldPos;
	float wf : WaterFlag;

#ifndef BYPASS_PIXEL_SHADER
	lpfloat4 color : COLOR;
	snorm float2 uv0 : TEXCOORD_0_FB_MSAA;
	snorm float2 uv1 : TEXCOORD_1_FB_MSAA;
#endif

#ifdef FOG
	float fog : fog_a;
#endif
};

struct PS_Output
{
	float4 color : SV_Target;
};

float3 curve(float3 x){
	static const float A = 0.50;
	static const float B = 0.10;
	static const float C = 0.40;
	static const float D = 0.65;
	static const float E = 0.05;
	static const float F = 0.20;
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

float3 tonemap(float3 col, float3 gamma){
	static const float saturation = 1.2;
	//static const float exposure = 1.0;
	col = pow(col,1./gamma);
	float luma = dot(col, float3(0.298912, 0.586611, 0.114478));
	col = curve((col-luma)*saturation+luma);
	return col/curve(float3(1./*1./exposure*/,0.,0.)).r;
}
float4 water(float4 col,float3 p,float3 wPos,float weather,float uw,float sun,float3 tex1){
	sun = smoothstep(.5,.9,sun);
	float3 T = normalize(abs(wPos)); float cosT = length(T.xz);
	p.xz = p.xz*float2(1.0,0.4)+smoothstep(0.,8.,abs(p.y-8.))*.5;
	float n = (snoise(p.xz-TOTAL_REAL_WORLD_TIME*.5)+snoise(float2(p.x-TOTAL_REAL_WORLD_TIME,(p.z+TOTAL_REAL_WORLD_TIME)*.5)))+2.;//[0.~4.]

	float4 diffuse = lerp(col,col*lerp(1.5,1.3,T.y*uw),pow(1.-abs(n-2.)*.5,bool(uw)?1.5:2.5));
	if(bool(uw)){//new C_REF
		float2 skp = (wPos.xz+n*4.*wPos.xz/max(length(wPos.xz),.5))*cosT*.1;
		skp.x -= TOTAL_REAL_WORLD_TIME*.05;
		float2 ssreff = lerp(float2(.7,.7),float2(.8,.6),clamp(FOG_COLOR.r-FOG_COLOR.g,0.,.4)*2.5);
		float4 skc = lerp(lerp(col,FOG_COLOR,cosT*ssreff.x),float4(lerp(tex1,FOG_COLOR.rgb,cosT*ssreff.y),1),smoothstep(0.,1.,snoise(skp)));
		float s_ref = sun*weather*smoothstep(.7,0.,T.y)*lerp(.3,1.,smoothstep(1.5,4.,n))*.9;
		skc = lerp(skc,1,smoothstep(3.+abs(wPos.y)*.3,0.,abs(wPos.z))*s_ref);
		diffuse = lerp(diffuse,skc,cosT*sun);
	}
	return lerp(diffuse,col,min(.7,T.y));
}


ROOT_SIGNATURE
void main(in PS_Input PSInput, out PS_Output PSOutput)
{
#ifdef BYPASS_PIXEL_SHADER
		PSOutput.color = float4(0.0f, 0.0f, 0.0f, 0.0f);
		return;
#else

#if USE_TEXEL_AA
	float4 diffuse = texture2D_AA(TEXTURE_0, TextureSampler0, PSInput.uv0 );
#else
	float4 diffuse = TEXTURE_0.Sample(TextureSampler0, PSInput.uv0);
#endif

#ifdef SEASONS_FAR
	diffuse.a = 1.0f;
#endif

#if USE_ALPHA_TEST
	#ifdef ALPHA_TO_COVERAGE
		#define ALPHA_THRESHOLD 0.05
	#else
		#define ALPHA_THRESHOLD 0.52
	#endif
	if(diffuse.a < ALPHA_THRESHOLD)discard;
#endif

#ifdef BLEND
	diffuse.a *= PSInput.color.a;
#endif

float4 tex1 = TEXTURE_1.Sample(TextureSampler1, PSInput.uv1);
#ifndef ALWAYS_LIT
	diffuse *= tex1;
#endif

#ifndef SEASONS
	#if !USE_ALPHA_TEST && !defined(BLEND)
		diffuse.a = PSInput.color.a;
	#endif

	diffuse.rgb *= PSInput.color.rgb;
#else
	float2 uv = PSInput.color.xy;
	diffuse.rgb *= lerp(1.0f, TEXTURE_2.Sample(TextureSampler2, uv).rgb*2.0f, PSInput.color.b);
	diffuse.rgb *= PSInput.color.aaa;
	diffuse.a = 1.0f;
#endif

//DATABASE
float weather =
#ifdef FOG
	smoothstep(.7,.96,FOG_CONTROL.y);
#else
	1.;
#endif
float2 daylight = TEXTURE_1.Sample(TextureSampler1,float2(0.,1.)).rr;
daylight.x *= weather;
float sunlight = smoothstep(0.865,0.875,PSInput.uv1.y);
float indoor = smoothstep(1.0,0.5,PSInput.uv1.y);
float dusk = min(smoothstep(0.4,0.55,daylight.y),smoothstep(0.8,0.65,daylight.y));
float uw = step(FOG_CONTROL.x,0.);
float nether = FOG_CONTROL.x/FOG_CONTROL.y;nether=step(.1,nether)-step(.12,nether);

//ESBE_tonemap	see http://filmicworlds.com/blog/filmic-tonemapping-operators/
//1が標準,小…暗,大…明
float3 ambient = lerp(lerp(lerp(/*雨*/float3(0.8,0.82,1.0),lerp(lerp(/*夜*/float3(0.7,0.72,0.8),/*昼*/float3(1.57,1.56,1.5),daylight.y),/*日没*/float3(1.6,1.25,0.8),dusk),weather),/*水*/float3(1.,1.,1.),PSInput.wf),/*屋内*/float3(1.2,1.1,1.0),indoor);
if(uw+nether>.5)ambient = FOG_COLOR.rgb/dot(FOG_COLOR.rgb,float3(0.298912, 0.586611, 0.114478))*.1+.9;//fogcolor based tonemap(Nether&Underwater)
diffuse.rgb = tonemap(diffuse.rgb,ambient);

//ESBE_light
#ifndef BLEND
	#define dpow(x) x*x//光源の減衰の調整
	diffuse.rgb += max(PSInput.uv1.x-.5,0.)*(1.-dpow(diffuse.rgb))*lerp(1.,indoor*.7+.3,daylight.x)*
	float3(1.0,0.65,0.3);//光源RGB
#endif

//ESBEwater
#ifdef FANCY
	float3 n = normalize(cross(ddx(-PSInput.cPos),ddy(PSInput.cPos)));
	if(PSInput.wf+uw>.5){
		diffuse = water(diffuse,PSInput.cPos,PSInput.wPos,weather,1.-uw,PSInput.uv1.y,tex1.rgb);
		float w_r = 1.-dot(normalize(-PSInput.wPos),n);
		diffuse.a = lerp(diffuse.a,1.,.02+.98*w_r*w_r*w_r*w_r*w_r);
	}
#endif

//ESBE_shadow
float ao = 1.;
if(PSInput.color.r==PSInput.color.g && PSInput.color.g==PSInput.color.b)ao = smoothstep(.48*daylight.y,.52*daylight.y,PSInput.color.g);
diffuse.rgb *= 1.-lerp(/*影の濃さ*/0.5,0.0,min(sunlight,ao))*(1.-PSInput.uv1.x)*daylight.x;
#ifdef FANCY//FLAT_SHADING
	float fl_s = min(1.,dot(n,float3(0.,.8,.6))*.45+.64);
	fl_s = lerp(fl_s,max(dot(n,float3(.9,.44,0.)),dot(n,float3(-.9,.44,0.)))*1.3+.2,dusk);
	diffuse.rgb *= lerp(1.,fl_s,smoothstep(.7,.95,PSInput.uv1.y)*min(1.25-PSInput.uv1.x,1.)*daylight.x);
#endif

#ifdef FOG
	diffuse.rgb = lerp( diffuse.rgb, FOG_COLOR.rgb, PSInput.fog );
#endif

	PSOutput.color = diffuse;

#ifdef VR_MODE
	// On Rift, the transition from 0 brightness to the lowest 8 bit value is abrupt, so clamp to
	// the lowest 8 bit value.
	PSOutput.color = max(PSOutput.color, 1 / 255.0f);
#endif

#endif // BYPASS_PIXEL_SHADER
}

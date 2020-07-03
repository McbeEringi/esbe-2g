#include "ShaderConstants.fxh"

struct VS_Input {
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD_0;
	float2 uv1 : TEXCOORD_1;
#ifdef INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
};


struct PS_Input {
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
#ifdef GEOMETRY_INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
#ifdef VERTEXSHADER_INSTANCEDSTEREO
	uint renTarget_id : SV_RenderTargetArrayIndex;
#endif
};


static const float rA = 1.0;
static const float rB = 1.0;
static const float3 UNIT_Y = float3(0, 1, 0);
static const float DIST_DESATURATION = 56.0 / 255.0; //WARNING this value is also hardcoded in the water color, don'tchange

float hash11(float p){
	p = frac(p * .1031);
	p *= p + 33.33;
	return frac((p + p) * p);
}

float random(float p){
	p = p/3.0+TOTAL_REAL_WORLD_TIME;
	return lerp(hash11(floor(p)),hash11(floor(p+1.0)),smoothstep(0.0,1.0,frac(p)))*2.0;
}


ROOT_SIGNATURE
void main(in VS_Input VSInput, out PS_Input PSInput)
{
PSInput.wf = 0.;
#ifndef BYPASS_PIXEL_SHADER
	PSInput.uv0 = VSInput.uv0;
	PSInput.uv1 = VSInput.uv1;
	PSInput.color = VSInput.color;
#endif
/////waves
float3 p = float3(VSInput.position.x==16.?0.:VSInput.position.x,abs(VSInput.position.y-8.),VSInput.position.z==16.?0.:VSInput.position.z);
float wav = sin(TOTAL_REAL_WORLD_TIME*3.5+2.*p.x+2.*p.z+p.y);
float rand = random(p.x+p.y+p.z);

#ifdef AS_ENTITY_RENDERER
	#ifdef INSTANCEDSTEREO
		int i = VSInput.instanceID;
		PSInput.position = mul(WORLDVIEWPROJ_STEREO[i], float4(VSInput.position, 1));
	#else
		PSInput.position = mul(WORLDVIEWPROJ, float4(VSInput.position, 1));
	#endif
	float3 worldPos = PSInput.position;
#else
	float3 worldPos = (VSInput.position.xyz * CHUNK_ORIGIN_AND_SCALE.w) + CHUNK_ORIGIN_AND_SCALE.xyz;

	/////waves
	if(VSInput.color.a < 0.95 && VSInput.color.a >0.05 && VSInput.color.g > VSInput.color.r)worldPos.y += wav*.05*frac(VSInput.position.y)*rand*clamp(1.-length(worldPos.xyz)/FAR_CHUNKS_DISTANCE,0.,1.);

	// Transform to view space before projection instead of all at once to avoid floating point errors
	// Not required for entities because they are already offset by camera translation before rendering
	// World position here is calculated above and can get huge
	#ifdef INSTANCEDSTEREO
		int i = VSInput.instanceID;
		PSInput.position = mul(WORLDVIEW_STEREO[i], float4(worldPos, 1 ));
		PSInput.position = mul(PROJ_STEREO[i], PSInput.position);
	#else
		PSInput.position = mul(WORLDVIEW, float4( worldPos, 1 ));
		PSInput.position = mul(PROJ, PSInput.position);
	#endif
#endif
PSInput.cPos = VSInput.position.xyz;
PSInput.wPos = worldPos.xyz;

#ifdef GEOMETRY_INSTANCEDSTEREO
		PSInput.instanceID = VSInput.instanceID;
#endif
#ifdef VERTEXSHADER_INSTANCEDSTEREO
		PSInput.renTarget_id = VSInput.instanceID;
#endif

///// find distance from the camera
float3 relPos = -worldPos;
float cameraDepth = length(relPos);

///// apply fog
#ifdef FOG
	float len = cameraDepth / RENDER_DISTANCE;
#ifdef ALLOW_FADE
	len += RENDER_CHUNK_FOG_ALPHA.r;
#endif
	PSInput.fog = clamp((len - FOG_CONTROL.x) / (FOG_CONTROL.y - FOG_CONTROL.x), 0.0, 1.0);
	if(FOG_CONTROL.x<.3)
		if(.01<FOG_CONTROL.x)PSInput.position.xy += wav*PSInput.fog*.15
			#ifdef FANCY
				*(rand*.5+.5)
			#endif
			;else PSInput.position.x += wav*PSInput.fog*.1
			#ifdef FANCY
				*rand
			#endif
			;
#endif

///// leaves
#ifdef ALPHA_TEST
	float3 frp = frac(VSInput.position.xyz);
	if((PSInput.color.g != PSInput.color.b && PSInput.color.r < PSInput.color.g+PSInput.color.b)||(frp.y==.9375&&(frp.x==0.||frp.z==0.)))PSInput.position.x += wav*.016*rand*PROJ[0].x;
#endif

///// esbe water detection
#ifndef SEASONS
	if(VSInput.color.a < 0.95 && VSInput.color.a > 0.05) {
		PSInput.wf = 1.;
		float cameraDist = cameraDepth / FAR_CHUNKS_DISTANCE;
		#ifdef FANCY
			cameraDist *= cameraDist;
		#endif
		float alphaFadeOut = clamp(cameraDist, 0.0, 1.0);
		PSInput.color.a = lerp(VSInput.color.a*.6, 1.5, alphaFadeOut);
	}
#endif
}

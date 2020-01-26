#include "ShaderConstants.fxh"

struct VS_Input
{
	float3 position : POSITION;
	float2 uv : TEXCOORD_0;
#ifdef INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
};


struct PS_Input
{
	float4 position : SV_Position;
	float2 uv : TEXCOORD_0;
	float2 uv_ : uv_;
	float2 pos : pos;
	float4 lf : lensflare;
#ifdef GEOMETRY_INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
#ifdef VERTEXSHADER_INSTANCEDSTEREO
	uint renTarget_id : SV_RenderTargetArrayIndex;
#endif
};

ROOT_SIGNATURE
void main(in VS_Input VSInput, out PS_Input PSInput)
{
	PSInput.uv = VSInput.uv;
	float4 p = float4(VSInput.position*float3(10.,1.,10.),1);
#ifdef INSTANCEDSTEREO
	int i = VSInput.instanceID;
	PSInput.position = mul( WORLDVIEWPROJ_STEREO[i], p);
#else
	PSInput.position = mul(WORLDVIEWPROJ, p);
#endif
#ifdef GEOMETRY_INSTANCEDSTEREO
	PSInput.instanceID = VSInput.instanceID;
#endif
#ifdef VERTEXSHADER_INSTANCEDSTEREO
	PSInput.renTarget_id = VSInput.instanceID;
#endif
PSInput.uv_ = VSInput.uv;
PSInput.pos = mul(float2x2(.8,-.6,.6,.8),p.xz);
PSInput.lf = float4(mul(float2x2(.8,-.6,.6,.8),p.xz),mul(WORLDVIEWPROJ, p).xy);
}

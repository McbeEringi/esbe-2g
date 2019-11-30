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
	float4 fsh : fsh;
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
	float4 pos = float4(VSInput.position*float3(10.,1.,10.),1);
#ifdef INSTANCEDSTEREO
	int i = VSInput.instanceID;
	PSInput.position = mul( WORLDVIEWPROJ_STEREO[i], pos);
#else
	PSInput.position = mul(WORLDVIEWPROJ, pos);
#endif
#ifdef GEOMETRY_INSTANCEDSTEREO
	PSInput.instanceID = VSInput.instanceID;
#endif
#ifdef VERTEXSHADER_INSTANCEDSTEREO
	PSInput.renTarget_id = VSInput.instanceID;
#endif
PSInput.fsh = float4(mul(pos.xz,float2x2(.8,.6,-.6,.8)),VSInput.uv);
}

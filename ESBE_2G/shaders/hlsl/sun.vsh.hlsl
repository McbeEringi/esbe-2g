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
	float2 pos : pos;
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
#ifdef INSTANCEDSTEREO
	int i = VSInput.instanceID;
	PSInput.position = mul( WORLDVIEWPROJ_STEREO[i], float4( VSInput.position, 1 ) );
#else
	PSInput.position = mul(WORLDVIEWPROJ, float4(VSInput.position, 1));
#endif
#ifdef GEOMETRY_INSTANCEDSTEREO
	PSInput.instanceID = VSInput.instanceID;
#endif
#ifdef VERTEXSHADER_INSTANCEDSTEREO
	PSInput.renTarget_id = VSInput.instanceID;
#endif
PSInput.pos = mul(VSInput.position.xz,float2x2(.8,.6,-.6,.8));
}

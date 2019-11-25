#include "ShaderConstants.fxh"
#include "snoise.fxh"

struct PS_Input
{
	float4 position : SV_Position;
	float2 uv : TEXCOORD_0_FB_MSAA;
	float2 pos : pos;
};

struct PS_Output
{
	float4 color : SV_Target;
};

ROOT_SIGNATURE
void main(in PS_Input PSInput, out PS_Output PSOutput)
{
	float2 p = PSInput.pos;
	float l = length(p);
	float sun = max(cos(min(l*10.,1.58)),.5-l);
	float mp = (sin(TIME)+1.)*3.1415;//((step(.25,PSInput.uv.x)+step(.5,PSInput.uv.x)+step(.75,PSInput.uv.x))*.25+step(.5,PSInput.uv.y))*3.1415;//[0~2pi]
	float r =.15;//月半径 ~0.5
	float3 n = normalize(float3(p,sqrt(r*r-p.x*p.x-p.y*p.y)));
	float moon = dot(-float3(sin(mp),0.,cos(mp)),n);
	moon = smoothstep(-r,0.,moon)*(moon*.2+.8)*smoothstep(r,r-r*.1,l);
	moon *= 1.-smoothstep(1.5,0.,snoise(p+n.xy+5.)*.5+snoise((p+n.xy)*3.)*.25+.75)*.15;
	moon = max(moon,cos(l*3.14)*sin(mp*.5)*.6);//拡散光

	PSOutput.color = float4(1.,.95,.81,1.)*lerp(moon,sun,step(.5,TEXTURE_0.Sample(TextureSampler0,float2(.5,.5)).r));
}

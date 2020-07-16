#include "ShaderConstants.fxh"
#include "snoise.fxh"

struct PS_Input
{
	float4 position : SV_Position;
	float4 fog : FOG;
	float2 pos : POS;
};

struct PS_Output
{
	float4 color : SV_Target;
};

float fBM(int octaves, float lowerBound, float upperBound, float2 st) {
	float value = 0.0;
	float amplitude = 0.5;
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


ROOT_SIGNATURE
void main(in PS_Input PSInput, out PS_Output PSOutput)
{
	//DATABASE
	float day = smoothstep(0.15,0.25,FOG_COLOR.g);
	float weather = smoothstep(0.8,1.0,FOG_CONTROL.y);
	float ss = clamp(FOG_COLOR.r-FOG_COLOR.g,0.,.5)*2.;
	bool uw = FOG_CONTROL.x==0.;

	float3 top_col = lerp(lerp(float3(0.0,0.0,0.1),float3(-0.1,0.0,0.1),day),float3(0.5,0.5,0.5),ss*.5)*weather;
	float3 hor_col = lerp(lerp(float3(0.0,0.1,0.2),float3(0.2,0.1,-0.05),day),float3(0.7,0.7,0.7),ss*.5)*weather;

	float4 col = float4(lerp(CURRENT_COLOR.rgb+top_col,FOG_COLOR.rgb+hor_col,smoothstep(0.,.4,PSInput.fog)),1.);

		//AURORA
		float aflag = (1.-day)*weather;
		if(aflag > 0.){
			float2 apos = float2(PSInput.pos.x-TOTAL_REAL_WORLD_TIME*.004,PSInput.pos.y*10.);
			apos.y += sin(PSInput.pos.x*20.+TOTAL_REAL_WORLD_TIME*.1)*.15;
			float3 ac = lerp(/*オーロラ色1*/float3(0.,.8,.4),/*オーロラ色2*/float3(.4,.2,.8),sin(apos.x+apos.y+TOTAL_REAL_WORLD_TIME*.01)*.5+.5);
			float am = fBM(4,.5,1.,apos);
			col.rgb += ac*am*smoothstep(.5,0.,length(PSInput.pos))*aflag;
		}

		//CLOUDS
		float3 cc = lerp(/*雨*/lerp(.2,.9,day),lerp(lerp(/*夜*/float3(.1,.18,.38),/*昼*/float3(.97,.96,.90),day),/*日没*/float3(.97,.72,.38),ss),weather);
		float lb = lerp(.1,.5,weather);
		float cm = fBM(uw?4:6,lb,.8,PSInput.pos*3.-TOTAL_REAL_WORLD_TIME*.002);
		if(cm>0.){
			float br = fBM(uw?2:4,lb,.9,PSInput.pos*2.6-TOTAL_REAL_WORLD_TIME*.002);
			cc *= lerp(1.03,.8,br*(1.-ss*.7));
		}
		col.rgb = lerp(col.rgb,cc,cm);

	PSOutput.color =lerp(col,FOG_COLOR,PSInput.fog);
}

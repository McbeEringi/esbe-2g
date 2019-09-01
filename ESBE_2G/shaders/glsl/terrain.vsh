// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "vertexVersionCentroid.h"
#if __VERSION__ >= 300
	#ifndef BYPASS_PIXEL_SHADER
		_centroid out vec2 uv0;
		_centroid out vec2 uv1;
	#endif
#else
	#ifndef BYPASS_PIXEL_SHADER
		varying vec2 uv0;
		varying vec2 uv1;
	#endif
#endif

#ifndef BYPASS_PIXEL_SHADER
	varying vec4 color;
#endif

#ifdef FOG
	varying float fog;
#endif

#ifdef GL_FRAGMENT_PRECISION_HIGH
	varying highp vec3 cPos;
#else
	varying mediump vec3 cPos;
#endif
varying POS3 wPos;
varying float wf;

#include "uniformWorldConstants.h"
#include "uniformPerFrameConstants.h"
#include "uniformShaderConstants.h"
#include "uniformRenderChunkConstants.h"

attribute POS4 POSITION;
attribute vec4 COLOR;
attribute vec2 TEXCOORD_0;
attribute vec2 TEXCOORD_1;

const float rA = 1.0;
const float rB = 1.0;
const vec3 UNIT_Y = vec3(0,1,0);
const float DIST_DESATURATION = 56.0 / 255.0; //WARNING this value is also hardcoded in the water color, don'tchange

highp float hash11(highp float p){
	highp vec3 p3  = vec3(fract(p * 0.1031));
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

highp float random(highp float p){
	p = p/3.0+TIME;
	return mix(hash11(floor(p)),hash11(ceil(p)),smoothstep(0.0,1.0,fract(p)))*2.0;
}

void main()
{
		wf = 0.;
		POS4 worldPos;
#ifdef AS_ENTITY_RENDERER
		POS4 pos = WORLDVIEWPROJ * POSITION;
		worldPos = pos;
#else
		worldPos.xyz = (POSITION.xyz * CHUNK_ORIGIN_AND_SCALE.w) + CHUNK_ORIGIN_AND_SCALE.xyz;
		worldPos.w = 1.0;

		// Transform to view space before projection instead of all at once to avoid floating point errors
		// Not required for entities because they are already offset by camera translation before rendering
		// World position here is calculated above and can get huge
		POS4 pos = WORLDVIEW * worldPos;
		pos = PROJ * pos;
#endif
		gl_Position = pos;
		cPos = POSITION.xyz;
		wPos = worldPos.xyz;

#ifndef BYPASS_PIXEL_SHADER
		uv0 = TEXCOORD_0;
		uv1 = TEXCOORD_1;
	color = COLOR;
#endif

///// find distance from the camera
	#ifdef FANCY
		vec3 relPos = -worldPos.xyz;
		float cameraDepth = length(relPos);
	#else
		float cameraDepth = pos.z;
	#endif

///// apply fog
#ifdef FOG
	float len = cameraDepth / RENDER_DISTANCE;
	#ifdef ALLOW_FADE
		len += RENDER_CHUNK_FOG_ALPHA;
	#endif
	fog = clamp((len - FOG_CONTROL.x) / (FOG_CONTROL.y - FOG_CONTROL.x), 0.0, 1.0);
#endif

///// waves
highp float hTime = TIME;
#ifdef ALPHA_TEST
	if(color.g != color.b && color.r < color.g+color.b){
		POS3 lp = POSITION.xyz;
		lp.y = abs(lp.y-8.);
		gl_Position.x += sin(hTime*3.5+2.*lp.x+2.*lp.z+lp.y)*.015*random(lp.x+lp.y+lp.z);
	}
#endif

///// blended layer (mostly water) magic
#ifndef ALPHA_TEST
	if(color.a < 0.95 && color.a > 0.05 && color.g > color.r) {
		#ifdef FANCY	/////enhance water
			float cameraDist = pow(cameraDepth / FAR_CHUNKS_DISTANCE,2.);
			wf = 1.;
		#else
			// Completely insane, but if I don't have these two lines in here, the water doesn't render on a Nexus 6
			vec4 surfColor = vec4(color.rgb, 1.0);
			color = surfColor;

			vec3 relPos = -worldPos.xyz;
			float camDist = length(relPos);
			float cameraDist = camDist / FAR_CHUNKS_DISTANCE;
		#endif //FANCY

		float alphaFadeOut = clamp(cameraDist, 0.0, 1.0);
		color.a = mix(color.a*.7, 1.5, alphaFadeOut);

		/////waves
		POS3 wp = worldPos.xyz + VIEW_POS;
		gl_Position.y += sin(hTime*3.5+2.*wp.x+2.*wp.z+wp.y)*.05*fract(POSITION.y)*random(wp.x+wp.y+wp.z)*(1.-alphaFadeOut);
	}
	if(bool(step(FOG_CONTROL.x,.0001))){
		POS3 uwp = worldPos.xyz + VIEW_POS;
		gl_Position.x += sin(hTime*3.5+2.*uwp.x+2.*uwp.z+uwp.y)*.02;
	}
#endif

#ifndef BYPASS_PIXEL_SHADER
	#ifndef FOG
		// If the FOG_COLOR isn't used, the reflection on NVN fails to compute the correct size of the constant buffer as the uniform will also be gone from the reflection data
		color.rgb += FOG_COLOR.rgb * 0.000001;
	#endif
#endif
}

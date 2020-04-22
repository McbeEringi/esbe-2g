// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#if __VERSION__ >= 300
	#define attribute in
	#define varying out
#endif

uniform highp mat4 WORLDVIEWPROJ;
attribute highp vec4 POSITION;
varying highp vec3 pos;

void main(){
	gl_Position = WORLDVIEWPROJ * POSITION;
	pos = POSITION.xyz;
}

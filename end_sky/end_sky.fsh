// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#if __VERSION__ >= 300
	#define varying in
	out vec4 FragColor;
	#define gl_FragColor FragColor
#endif

varying highp vec3 pos;

void main(){
	gl_FragColor = vec4(fract(pos),1);
}

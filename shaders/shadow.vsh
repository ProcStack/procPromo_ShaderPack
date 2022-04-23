#version 120

#define OVERWORLD

#define VSH

//#include "/programs/gbuffers_shadow.glsl"

#extension GL_EXT_gpu_shader4 : enable

#include "/utils/shadowCommon.glsl"

varying vec2 texcoord;


void main() {

  vec4 position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
	gl_Position = BiasShadowProjection(  position );
	gl_Position.z /= 3.0;


	texcoord = gl_MultiTexCoord0.xy;
}
#version 120

#define OVERWORLD

#define VSH

//#include "/programs/gbuffers_shadow.glsl"

#extension GL_EXT_gpu_shader4 : enable

#include "/shaders.settings"
#include "/programs/utils/shadowCommon.glsl"

attribute vec4 mc_Entity;

varying vec2 texcoord;
varying float vIsLeaves;


void main() {

  vec4 position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
	gl_Position = BiasShadowProjection(  position );
	gl_Position.z /= 3.0;


	texcoord = gl_MultiTexCoord0.xy;
  
  vIsLeaves=0.0;
  
  // Leaves
  if (mc_Entity.x == 810 && SolidLeaves){
    vIsLeaves = 1.0;
  }
}
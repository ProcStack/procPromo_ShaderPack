#version 120

#define OVERWORLD

#define VSH

//#include "/programs/gbuffers_shadow.glsl"

#extension GL_EXT_gpu_shader4 : enable

#include "/shaders.settings"
#include "/programs/utils/shadowCommon.glsl"

uniform vec3 cameraPosition;

attribute vec4 mc_Entity;

varying vec2 texcoord;
varying vec3 vShadowPos;
varying float vIsLeaves;


void main() {

  //vec4 posOffset = vec4(-fract(cameraPosition*.5-.5) * vec3(1.0,0.0,1.0),0.0);
  vec4 posOffset = vec4( fitShadowOffset( cameraPosition ), 0.0);
  
  //vec4 position = ftransform();
  //vec4 position = gl_ProjectionMatrix * gl_ModelViewMatrix * (gl_Vertex + posOffset);
  vec4 position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
	gl_Position = biasShadowPos( position );
  vShadowPos = gl_Position.xyz;


	texcoord = gl_MultiTexCoord0.xy;
  
  vIsLeaves=0.0;
  
  // Leaves
  if (mc_Entity.x == 810 && SolidLeaves){
    vIsLeaves = 1.0;
  }
  
}
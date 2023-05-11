#version 120

#define OVERWORLD

#define FSH

#include "/shaders.settings"
//#include "/programs/gbuffers_shadow.glsl"

uniform sampler2D tex;

varying vec2 texcoord;
//varying vec4 color;
varying vec3 vShadowPos;
varying float vIsLeaves;


void main() {

  vec4 shadowCd = texture2D(tex,texcoord.xy);// * color;

  shadowCd.a= min(1.0, shadowCd.a+vIsLeaves);

  #if ( DebugView == 2 )
    shadowCd.b= length( vShadowPos );
  #endif
  
	gl_FragData[0] = shadowCd;
}

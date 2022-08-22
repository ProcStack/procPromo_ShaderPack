// Modified from Chocapic13's HighPerformance Toaster shader pack
//  (I'm still learning this shadow stuffs)

#ifdef VSH

#extension GL_EXT_gpu_shader4 : enable

#include "utils/shadowCommon.glsl"

attribute vec4 mc_Entity;

varying vec2 texcoord;
varying float vAlphaMult;

//varying vec4 color;

void main() {

  vec4 position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
	gl_Position = BiasShadowProjection(  position );
	gl_Position.z /= 3.0;


	texcoord = gl_MultiTexCoord0.xy;
	//color = gl_Color;
  
  
  vAlphaMult=1.0;
  if (mc_Entity.x == 801){
    float crossDot = dot( 
    vAlphaMult=clamp( (vCrossBlockCull+.5)*10.0, 0.0, 1.0 );
  }
  vAlphaMult=0.0;
  
}

#endif

#ifdef FSH

uniform sampler2D tex;

varying vec2 texcoord;
//varying vec4 color;
varying float vAlphaMult;

void main() {

  vec4 shadowCd = texture2D(tex,texcoord.xy);// * color;

  shadowCd.a*=step(.5, vAlphaMult);

  //shadowCd.rgb*=.0;

	gl_FragData[0] = shadowCd;
}

#endif

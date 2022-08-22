#version 120

#define OVERWORLD

#define FSH

//#include "/programs/gbuffers_shadow.glsl"

uniform sampler2D tex;

varying vec2 texcoord;
//varying vec4 color;
varying float vIsLeaves;

void main() {

  vec4 shadowCd = texture2D(tex,texcoord.xy);// * color;

  shadowCd.a= min(1.0, shadowCd.a+vIsLeaves);

	gl_FragData[0] = shadowCd;
}

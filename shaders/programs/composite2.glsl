// GBuffer - Composite #2 GLSL
// Written by Kevin Edzenga, ProcStack; 2022-2023
//
// Glow Color down res pass; 30% res

#ifdef VSH
varying vec2 texcoord;

void main() {
  gl_Position = ftransform();
  texcoord = gl_MultiTexCoord0.xy;
}

#endif

#ifdef FSH

/* RENDERTARGETS: 6 */

#include "/shaders.settings"
//#include "utils/texSampler.glsl"

uniform sampler2D colortex8;
uniform sampler2D gaux2;
uniform vec2 texelSize;

varying vec2 texcoord;


const int boxSamplesCount = 8;
const vec2 boxSamples[8] = vec2[8](
                              vec2( -1.0, -1.0 ),
                              vec2( -1.0, 0.0 ),
                              vec2( -1.0, 1.0 ),

                              vec2( 0.0, -1.0 ),
                              vec2( 0.0, 1.0 ),

                              vec2( 1.0, -1.0 ),
                              vec2( 1.0, 0.0 ),
                              vec2( 1.0, 1.0 )
                            );


vec3 directionBlurSample(vec3 sampleCd, sampler2D tx, vec2 uv, vec2 texelRes, int steps){
  vec2 curUV;
  vec2 curId;
  float curUVDist=0.0;
  vec3 curCd;
  vec3 curMix;
  float dist=0.0;
  float invDist=0.0;
  for( int x=0; x<steps; ++x){
    dist = float(x+1)/float(steps+1);
    invDist = (1.0-dist)*.5;//*dist;
    
    curUV =  uv + vec2( -1.0, -1.0 )*texelRes*dist ;
    curCd = texture2D(tx, curUV).rgb;
    sampleCd += curCd*invDist;
    curUV =  uv + vec2( 1.0, 1.0 )*texelRes*dist ;
    curCd = texture2D(tx, curUV).rgb;
    sampleCd += curCd*invDist;
  }
  return sampleCd;
}

void main() {
  vec2 uv = texcoord*.4;
  vec4 sampleCd = texture2D(gaux2, uv);
  //float sCdMax = max(sampleCd.r,max(sampleCd.g,sampleCd.b));
  float sCdMax = (sampleCd.r+sampleCd.g+sampleCd.b)*0.5773502691896258;// .33333;
  float reachDist = sampleCd.a;

  reachDist *= GLOW_PERC2 * GLOW_REACH * GlowBrightness;//*2.0;
  //sampleCdAlpha = min(1.0, sampleCdAlpha+max(0.0, GlowBrightness-1.0)*.1);

  int reachSteps = 7 + BaseQuality*6 ;
  float texScalar = 17.0-reachDist*4.0;
  vec2 texelRes = vec2( texelSize.x * texScalar * reachDist, 0.0 );
  
  vec3 baseBloomCd = directionBlurSample(sampleCd.rgb, gaux2, uv, texelRes, reachSteps)*sampleCd.a;

  gl_FragData[0] = vec4(baseBloomCd, 1.0);
}

#endif



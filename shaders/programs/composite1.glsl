// GBuffer - Composite #1 GLSL
// Written by Kevin Edzenga, ProcStack; 2022-2023
//
// Glow Color down res pass; 40% res
//   Output - colortex8

#ifdef VSH

varying vec2 texcoord;

void main() {
  gl_Position = ftransform();
  texcoord = gl_MultiTexCoord0.xy;
}

#endif

#ifdef FSH
/* RENDERTARGETS: 5 */

#ifndef GLOW_REACH
  #define GLOW_REACH 1.0
#endif

#ifndef GLOW_PERC
  #define GLOW_PERC 1.0
#endif

#include "/shaders.settings"
#include "utils/mathFuncs.glsl"

uniform sampler2D colortex1; // Depth Pass
uniform sampler2D colortex6;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex16;
uniform sampler2D gaux4;
uniform vec2 texelSize;

varying vec2 texcoord;

const int diagSamplesCount = 4;
const vec2 diagSamples[4] = vec2[4](
                              vec2( -1.0, -1.0 ),
                              vec2( -1.0, 1.0 ),

                              vec2( 1.0, -1.0 ),
                              vec2( 1.0, 1.0 )
                            );


vec3 boxBlurSampleHSV( sampler2D tx, vec2 uv, vec2 texelRes){
  vec3 sampleCd = texture2D(tx, uv).rgb;
  
  vec2 curUV;
  vec2 curId;
  float curUVDist=0.0;
  vec3 curCd;
  vec3 curMix;
  float delta=0.0;
  for( int x=0; x<diagSamplesCount; ++x){
    curUV =  uv + diagSamples[x]*texelRes*sampleCd.z ;
    
    curCd = texture2D(tx, curUV).rgb;
    sampleCd = mix(sampleCd, max( sampleCd, curCd), curCd.z*.5);
  }
  return sampleCd;
}

void main() {
  vec3 sampleCd = texture2D(colortex6, texcoord).rgb;
  float sampleDepth = texture2D(colortex1, texcoord).x;

  float depthInf = GLOW_PERC * GLOW_REACH * GlowBrightness*2.0;

  float glowBrightness = sampleCd.b;// * sampleCd.b;
  
  vec3 baseBloomCd = boxBlurSampleHSV(colortex6, texcoord, texelSize*20.0*glowBrightness*sampleDepth*depthInf);
  //baseBloomCd = max(baseBloomCd, boxBlurSampleHSV(colortex6, texcoord, texelSize*15.0*sampleDepth*depthInf));
  baseBloomCd.b *= GLOW_PERC;
  baseBloomCd = hsv2rgb(baseBloomCd);

  gl_FragData[0] = vec4(baseBloomCd, 1.0);//sampleDepth*.9+.1);
}

#endif




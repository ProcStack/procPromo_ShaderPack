
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

#include "utils/mathFuncs.glsl"

uniform sampler2D colortex1; // Depth Pass
uniform sampler2D colortex6;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex16;
uniform sampler2D gaux4;
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


vec3 boxBlurSampleHSV( sampler2D tx, vec2 uv, vec2 texelRes){
  vec3 sampleCd = texture2D(tx, uv).rgb;
  
  vec2 curUV;
  vec2 curId;
  float curUVDist=0.0;
  vec3 curCd;
  vec3 curMix;
  float delta=0.0;
  for( int x=0; x<boxSamplesCount; ++x){
    curUV =  uv + boxSamples[x]*texelRes*sampleCd.z ;
		
    curCd = texture2D(tx, curUV).rgb;
    sampleCd = mix(sampleCd, max( sampleCd, curCd), curCd.z*.5);
  }
  return sampleCd;
}

void main() {
  vec3 sampleCd = texture2D(colortex6, texcoord).rgb;
  float sampleDepth = texture2D(colortex1, texcoord).x;

  sampleDepth*=GLOW_PERC;
  sampleDepth*=GLOW_REACH;

  float glowBrightness = sampleCd.b * sampleCd.b;
  
	vec3 baseBloomCd = boxBlurSampleHSV(colortex6, texcoord, texelSize*10.0*sampleDepth);
	baseBloomCd = max(baseBloomCd, boxBlurSampleHSV(colortex6, texcoord, texelSize*15.0*sampleDepth));
  baseBloomCd.b *= GLOW_PERC;
  baseBloomCd = hsv2rgb(baseBloomCd);

	gl_FragData[0] = vec4(baseBloomCd, 1.0);//sampleDepth*.9+.1);
}

#endif




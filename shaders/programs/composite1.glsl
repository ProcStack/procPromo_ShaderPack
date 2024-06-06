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
// target - gaux2


#include "/shaders.settings"
#include "utils/mathFuncs.glsl"

uniform sampler2D colortex1;  // Bind 1; Depth Pass
uniform sampler2D colortex6; // Bind 9
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
  vec3 curCd;
	float curInf;
  vec3 brightestCd = sampleCd.rgb;
  for( int x=0; x<diagSamplesCount; ++x){
	
    curUV =  uv + diagSamples[x]*texelRes*sampleCd.z ;
    
    curCd = texture2D(tx, curUV).rgb;
		
		brightestCd = mix( brightestCd, curCd.rgb, step(brightestCd.z, curCd.z) );

    sampleCd.z += curCd.z*.5;

  }
	
	return vec3( brightestCd.rg, sampleCd.b ) ;
}

void main() {
  vec4 sampleCd = texture2D(colortex6, texcoord);
  float sampleDepth = 1.0+(1.0-texture2D(colortex1, texcoord).x);

  float depthInf = ( 1.0 + GLOW_PERC1 * GLOW_REACH ) * GlowBrightness;

  float glowBrightness = sampleCd.b;
  float reachInf = depthInf + sampleDepth*GLOW_REACH;
	
  vec3 baseBloomCd = boxBlurSampleHSV(colortex6, texcoord, texelSize * reachInf );
	
  //baseBloomCd.b *= GLOW_PERC1;
	
	vec4 outCd = vec4(vec3(0.0),1.0);
  outCd.rgb = hsv2rgb(baseBloomCd.rgb);
	outCd.a = max(glowBrightness, length(sampleCd.rgb));

  gl_FragData[0] = outCd;
}

#endif




// GBuffer - Composite #3 GLSL
//   Written by Kevin Edzenga, ProcStack; 2022-2023
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

/* RENDERTARGETS: 7 */
// target - gaux4

#include "/shaders.settings"
//#include "utils/texSampler.glsl"

uniform sampler2D gaux2; // Bind 8
uniform sampler2D gaux3; // Bind 9
uniform vec2 texelSize;

varying vec2 texcoord;

vec3 directionBlurSample(vec3 sampleCd, sampler2D tx, vec2 uv, vec2 texelRes, int steps){
  vec2 curUV;
  vec3 curCd;
  float dist=0.0;
  float invDist=0.0;
  for( int x=0; x<steps; ++x){
    dist = float(x+1)/float(steps+1);
    invDist = (1.0-dist);
		invDist*=invDist;
    
    curUV =  uv + vec2( -1.0, -1.0 )*texelRes*dist ;
    curCd = texture2D(tx, curUV).rgb;
    //sampleCd += curCd*invDist;
    sampleCd = max(sampleCd.rgb, curCd*invDist);
		
    curUV =  uv + vec2( 1.0, 1.0 )*texelRes*dist ;
    curCd = texture2D(tx, curUV).rgb;
    //sampleCd += curCd*invDist;
    sampleCd = max(sampleCd.rgb, curCd*invDist);
  }
  return sampleCd;
}

void main() {
  vec2 uv = texcoord*.3;
  vec4 sampleCd = texture2D(gaux3, uv);
  float sampleCdAlpha = texture2D(gaux2, texcoord*.4).a;//*.5+.5;

  float reachDist = 1.0+0.40*(sampleCdAlpha*.5+.5);
  reachDist = 1.5-sampleCdAlpha*.5;

  reachDist*=GLOW_PERC3 * GlowBrightness;//*2.0;
  //sampleCdAlpha = min(1.0, sampleCdAlpha+max(0.0, GlowBrightness-1.0));
  
  int reachSteps = 7 + BaseQuality*6 ;
  float texScalar = 13.0-reachDist*4.0;
  vec2 texelRes = vec2(0.0,texelSize.x*texScalar*reachDist);
  
  
  vec3 baseBloomCd = directionBlurSample(sampleCd.rgb, gaux3, uv, texelRes, reachSteps);
	
  gl_FragData[0] = vec4( baseBloomCd.rgb, 1.0 );
}
#endif



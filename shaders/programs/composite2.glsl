// GBuffer - Composite #2 GLSL
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

/* RENDERTARGETS: 6 */
// target - gaux3

#include "/shaders.settings"
//#include "utils/texSampler.glsl"

uniform sampler2D gaux2; // Bind 8
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
  vec2 uv = texcoord*.4;
  vec4 sampleCd = texture2D(gaux2, uv);
	
  float reachDist = 1.5-sampleCd.a*.5;

  reachDist *= Glow_Perc2 * Glow_Reach * GlowBrightness;//*2.0;

  int reachSteps = 7 + BaseQuality*6 ;
  float texScalar = 13.0-reachDist*4.0;
  vec2 texelRes = vec2( texelSize.x * texScalar * reachDist, 0.0 );
  
  vec3 baseBloomCd = directionBlurSample(sampleCd.rgb, gaux2, uv, texelRes, reachSteps);

	
  gl_FragData[0] = vec4( baseBloomCd.rgb, 1.0 );
}

#endif



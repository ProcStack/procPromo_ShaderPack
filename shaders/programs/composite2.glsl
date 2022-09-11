
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

#ifndef GLOW_REACH
  #define GLOW_REACH 1.0
#endif

#ifndef GLOW_PERC
  #define GLOW_PERC 1.0
#endif

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
    sampleCd += curCd*invDist*.5;
    curUV =  uv + vec2( 1.0, 1.0 )*texelRes*dist ;
    curCd = texture2D(tx, curUV).rgb;
    sampleCd += curCd*invDist*.5;
  }
  return sampleCd;
}

void main() {
  vec2 uv = texcoord*.4;
  vec4 sampleCd = texture2D(gaux2, uv);
  //float sCdMax = max(sampleCd.r,max(sampleCd.g,sampleCd.b));
  float sCdMax = (sampleCd.r+sampleCd.g+sampleCd.b)*.33333;
  float reachDist = sampleCd.a;

  reachDist*=GLOW_PERC;
  reachDist*=GLOW_REACH;

  
	vec3 baseBloomCd = directionBlurSample(sampleCd.rgb, gaux2, uv, vec2(texelSize.x*20.0*reachDist,0.0), 15)*sampleCd.a;

	gl_FragData[0] = vec4(baseBloomCd, 1.0);
}

#endif



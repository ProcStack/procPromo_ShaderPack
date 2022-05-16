
// Spectral Glowing Entities Outline

#ifdef VSH

varying vec2 texcoord;

void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;
}

#endif

#ifdef FSH
/* RENDERTARGETS: 9 */

/* COLORTEX9FORMAT:RGBA16 */
/*
const int colortex6Format = RGBA16F;
const int colortex9Format = RGBA16F;
*/

#include "/shaders.settings"
#include "utils/mathFuncs.glsl"

uniform sampler2D colortex1;
uniform sampler2D colortex9;
uniform vec2 texelSize;
uniform vec2 far;

varying vec2 texcoord;


// -- -- -- -- -- -- -- -- -- -- --
// -- Spectral Box Blur Sampler  -- --
// -- -- -- -- -- -- -- -- -- -- -- -- --

void runDepthSpectral( vec4 inCd, float blend, float refSpectral,  float dataDepth, inout vec3 dataRGB, inout float depthDelta, inout float spectralDelta ){
  dataRGB = mix( dataRGB, hsv2rgb(vec3(inCd.r, 0.5, 0.5)), blend );
  depthDelta = max(abs( inCd.g - dataDepth), depthDelta );
  spectralDelta = max( abs(inCd.a - refSpectral), spectralDelta );
  return;
}

void spectralSample( sampler2D tex, vec2 uv, vec2 reachMult, float blend, float refSpectral, vec3 dataCd,
                      inout vec3 dataRGB, inout float depthDelta, inout float spectralDelta ){

  vec2 curUVOffset;
  vec4 curCd;
  
  float maxSpectralDelta = 0.0;
  float maxDepthDelta = 0.0;
  
  
  curUVOffset = reachMult * vec2( -1.0, -1.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  runDepthSpectral( curCd, blend, refSpectral, dataCd.b, dataRGB, depthDelta, spectralDelta );
  
  curUVOffset = reachMult * vec2( -1.0, 0.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  runDepthSpectral( curCd, blend, refSpectral, dataCd.b, dataRGB, depthDelta, spectralDelta );
  
  curUVOffset = reachMult * vec2( -1.0, 1.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  runDepthSpectral( curCd, blend, refSpectral, dataCd.b, dataRGB, depthDelta, spectralDelta );
  
  
  curUVOffset = reachMult * vec2( 0.0, -1.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  runDepthSpectral( curCd, blend, refSpectral, dataCd.b, dataRGB, depthDelta, spectralDelta );
  
  curUVOffset = reachMult * vec2( 0.0, 1.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  runDepthSpectral( curCd, blend, refSpectral, dataCd.b, dataRGB, depthDelta, spectralDelta );
  
  
  curUVOffset = reachMult * vec2( 1.0, -1.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  runDepthSpectral( curCd, blend, refSpectral, dataCd.b, dataRGB, depthDelta, spectralDelta );
  
  curUVOffset = reachMult * vec2( 1.0, 0.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  runDepthSpectral( curCd, blend, refSpectral, dataCd.b, dataRGB, depthDelta, spectralDelta );
  
  curUVOffset = reachMult * vec2( 1.0, 1.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  runDepthSpectral( curCd, blend, refSpectral, dataCd.b, dataRGB, depthDelta, spectralDelta );
  
  depthDelta*=refSpectral;
  
  return;
}



void main() {

	vec4 dataCdBase = texture2D(colortex9, texcoord);

  //float dataSpec = dataCdBase.b;
  float dataSpec = dataCdBase.a;
  vec3 dataRGB = hsv2rgb( vec3(dataCdBase.r, .50, dataCdBase.b) );
  
  float dataDepth = max(0.0, (1.0-dataCdBase.g*1.0) )*dataSpec;
  dataDepth = biasToOne(dataDepth)+.3;
  

  float levelBlend = .1;
  
  vec3 localCdBase = dataRGB;
  float localDepthDelta = 0.0;
  float localSpectralDelta = 0.0;
  spectralSample( colortex9, texcoord, texelSize*2.0*dataDepth, levelBlend,
                  dataSpec, dataCdBase.rgb,
                  localCdBase, localDepthDelta, localSpectralDelta);
  

  vec3 midCdBase = dataRGB;
  float midDepthDelta = 0.0;
  float midSpectralDelta = 0.0;
  spectralSample( colortex9, texcoord, texelSize * vec2(5.0,4.0)*dataDepth,
                  levelBlend, dataSpec, dataCdBase.rgb,
                  midCdBase, midDepthDelta, midSpectralDelta);
                                      
  vec3 farCdBase = dataRGB;
  float farDepthDelta = 0.0;
  float farSpectralDelta = 0.0;
  spectralSample( colortex9, texcoord, texelSize * vec2(7.0,9.0)*dataDepth,
                  levelBlend, dataSpec, dataCdBase.rgb,
                  farCdBase, farDepthDelta, farSpectralDelta);


  float layerDepthMixer = max(localDepthDelta, max( midDepthDelta, farDepthDelta ) )  * dataSpec;
  float layerSpectralMixer = max(localSpectralDelta, max( midSpectralDelta, farSpectralDelta ) )  * dataSpec;


  vec3 boxBlurCd = dataCdBase.rgb;
  boxBlurCd.b = dataCdBase.b;

  
  boxBlurCd.x=mix(1.0, dataCdBase.b, dataSpec);
  boxBlurCd.y=dataDepth;
  boxBlurCd.z=localSpectralDelta;
  //vec2 depthEffGlowBase = texture2D(colortex1, texcoord).rg;
  
  
	gl_FragData[0] = vec4( boxBlurCd, 1.0 );
  
  
  
  
}


#endif



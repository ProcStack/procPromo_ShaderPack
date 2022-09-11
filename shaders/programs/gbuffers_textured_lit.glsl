// Particles fallbacks


#ifdef VSH
varying vec4 texcoord;
varying vec4 color;
varying vec4 lmcoord;

attribute vec4 mc_Entity;

uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec2 texelSize;

varying vec3 normal;
  
void main() {

	vec4 position =  gl_ModelViewMatrix * gl_Vertex;
  position = gl_ProjectionMatrix * position;
  
	gl_Position = position;

	color = gl_Color;

	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	
  float NdotU = gl_Normal.y*(0.17*15.5/255.)+(0.83*15.5/255.);
  lmcoord.zw = gl_MultiTexCoord1.xy*vec2(15.5/255.0,NdotU)+0.5;
  
  normal = normalize(gl_NormalMatrix * gl_Normal);

	gl_FogFragCoord = gl_Position.z;
}
#endif

#ifdef FSH
/* RENDERTARGETS: 0,1,2,6 */

/* --
const int gcolorFormat = RGBA8;
const int gdepthFormat = RGBA16;
const int gnormalFormat = RGB10_A2;
 -- */
 
#include "utils/mathFuncs.glsl"

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform vec2 texelSize;

 
varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform int fogMode;

varying vec3 normal;


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


vec4 boxBlurSample( sampler2D tx, vec2 uv, vec2 texelRes){
  vec4 sampleCd = texture2D(tx, uv);
  
  vec2 curUV;
  vec4 curCd;
  for( int x=0; x<boxSamplesCount; ++x){
    curUV =  uv + boxSamples[x]*texelRes ;
		
    curCd = texture2D(tx, curUV);
    sampleCd = mix( sampleCd, curCd, (sampleCd.a*curCd.a)*.5);
  }
  return sampleCd;
}



void main() {

  vec4 outCd = texture2D(texture, texcoord.st) * texture2D(lightmap, lmcoord.st) * color;
  //float glowInf = texture2D(colortex5, texcoord.st).x;

  
  // Glow Pass Logic
  vec2 screenSpace = (gl_FragCoord.xy/gl_FragCoord.z);
  screenSpace = (screenSpace*texelSize)-.5;
  float screenDewarp = length(screenSpace)*.5;
  float depth = min(1.0, max(0.0, gl_FragCoord.w-screenDewarp));
  float outCdMin = max(outCd.r, max( outCd.g, outCd.b ) );
  vec3 glowCd = outCd.rgb;

  vec3 glowHSV = rgb2hsv(glowCd);
  glowHSV.z *= (max(0.0,outCdMin-.4)*.20)*(depth);//*glowInf;//*.5+.5);
  
	gl_FragData[0] = outCd;
    gl_FragData[1] = vec4(vec3( min(.9999,gl_FragCoord.w) ), 1.0);
	gl_FragData[2] = vec4( normal*.5+.5, 1.0 );
	gl_FragData[3] = vec4( glowHSV, 1.0 );
		
}
#endif

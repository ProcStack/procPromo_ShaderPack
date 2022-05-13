
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

varying vec3 vNormal;
varying vec3 vLocalNormal;
  
void main() {

	vec4 position =  gl_ModelViewMatrix * gl_Vertex;
  position = gl_ProjectionMatrix * position;
  
	gl_Position = position;

	color = gl_Color;

	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
  
  vNormal = normalize(gl_NormalMatrix * gl_Normal);
  vLocalNormal = gl_Normal;

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
uniform sampler2D noisetex; // Custom Texture; textures/SoftNoise_1k.jpg
uniform vec2 texelSize;
uniform int worldTime;
uniform vec3 cameraPosition;
uniform vec3 upPosition;

 
varying vec4 color;
varying vec4 texcoord;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform int fogMode;

varying vec3 vNormal;
varying vec3 vLocalNormal;


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

  float timeOffset = worldTime/24000.0;
  vec4 outCd = texture2D(texture, fract(texcoord.st-vec2(timeOffset*50.,timeOffset*20.)) );
  outCd.rgb -= vec3(abs(vLocalNormal.y)*.1);
  
  // Glow Pass Logic
  vec2 screenSpace = (gl_FragCoord.xy/gl_FragCoord.z);
  screenSpace = (screenSpace*texelSize)-.5;
  float screenDewarp = length(screenSpace)*.5;
  float depth = min(1.0, max(0.0, gl_FragCoord.w-screenDewarp));
  float outCdMin = max(outCd.r, max( outCd.g, outCd.b ) );
  vec3 glowCd = outCd.rgb;

  vec3 glowHSV = rgb2hsv(glowCd);
  glowHSV.z *= step(.7,outCdMin)*.1*(depth*.5+.5);

	gl_FragData[0] = outCd;
	//gl_FragData[1] = vec4(vec3(gl_FragCoord.w), 1.0);
	gl_FragData[2] = vec4( vNormal*.5+.5, 1.0 );
	gl_FragData[3] = vec4( glowHSV, 1.0 );
		
}
#endif

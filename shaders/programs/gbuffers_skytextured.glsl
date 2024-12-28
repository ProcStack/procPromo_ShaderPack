// GBuffer - Sky Textured GLSL
// Written by Kevin Edzenga, ProcStack; 2022-2023
//

#ifdef VSH

uniform sampler2D gcolor;
uniform mat4 gbufferModelView;
uniform int renderStage;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int moonPhase;
uniform int worldTime;

uniform vec3 fogColor;
uniform vec3 skyColor;

varying vec4 vTexcoord;
varying vec4 vColor;
varying vec4 vPos;
varying vec3 vGlowEdgeCd;
varying vec2 vFittedUV;
varying float vDfLenMult;
varying float vWorldTime;
varying vec3 vSkyUV;

void main() {

  vec4 position = gl_ModelViewMatrix * gl_Vertex;
  vPos=position;

  vSkyUV = gl_Vertex.xyz;
  
	// Fit 'worldTime' from 0-24000 -> 0-1; Scale x30
	//   worldTime * 0.00004166666 * 30.0 == worldTime * 0.00125
	//vWorldTime = float(worldTime)*0.00125;
	vWorldTime = float(worldTime)*0.00025;


  gl_Position = gl_ProjectionMatrix * position;

  float moonPhaseMult = (1.0-abs(((mod(moonPhase+3,8))-3))*.25)*.7+.3;

  vec3 modelPos = gbufferModelView[3].xyz;
  
  float isSun = step( .5, dot( normalize(sunPosition), normalize(position.xyz) ) );

  
  vColor = gl_Color;
  
  vTexcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
  
  // Read color of the sun at the sun body's edge pixel
  //   Provides a tone to the smooth outer glow from the fragment pass below
  //     Only works with vanilla textures...
  //     No clue what texture packs will look like
  //     I should add a toggle button in settings...



  if (renderStage == MC_RENDER_STAGE_SUN) {
    vGlowEdgeCd = texture2D(gcolor, vec2(0.59375)).rgb; // .5+.0625+.03125
    vFittedUV = vTexcoord.st;
    vDfLenMult = .45;
  }
  if (renderStage == MC_RENDER_STAGE_MOON) {
    vGlowEdgeCd = fogColor*moonPhaseMult;
    vFittedUV = gl_MultiTexCoord0.xy*vec2(4.0,2.0);
    vDfLenMult = .3;
  }
  
  
  gl_FogFragCoord = gl_Position.z;
}
#endif

#ifdef FSH
/* RENDERTARGETS: 0,6 */

#include "/shaders.settings"
#include "utils/mathFuncs.glsl"

uniform sampler2D gcolor;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform sampler2D noisetex; // Custom Texture; textures/SoftNoise_1k.jpg

varying vec4 vPos;
varying vec4 vColor;
varying vec4 vTexcoord;
varying vec3 vGlowEdgeCd;
varying vec2 vFittedUV;
varying float vDfLenMult;
varying float vWorldTime;
varying vec3 vSkyUV;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;
uniform vec3 fogColor;


void main() {
  
  
  vec2 uv = vTexcoord.st;
  vec4 outCd = vec4(0.0);
  
  
#ifdef OVERWORLD
  vec2 fituv = fract(vFittedUV);

  vec4 baseCd = texture2D(gcolor, uv) * vColor;
  outCd = baseCd;
  //float glowVal =  (1.0 - biasToOne( min(1.0, length(fituv-.5)) ))*.5;

  float bodyThresh = .125;
  float uvbase = max( abs(fituv.x-.5), abs(fituv.y-.5) );
  float sunBody = step(bodyThresh,uvbase);
  
  float dfShift = .05;
  float dfMult = 2.;
  vec2 uvshift = abs(fituv-.5)-dfShift;

  float dfLen = 1.0-min(1.0, length(max(vec2(0.0),uvshift)*dfMult)); // 0-1 dist to center

  dfLen = (dfLen*dfLen)*vDfLenMult;
  vec3 sunCd = mix( outCd.rgb, vGlowEdgeCd * dfLen, sunBody);
  
  outCd.rgb = sunCd;//mix( outCd.rgb, vec3(sunCd), step(fituv.x,.5) );
#elif defined(NETHER)
  vec4 baseCd = texture2D(gcolor, uv) * vColor;
  outCd = baseCd;
  //float glowVal =  (1.0 - biasToOne( min(1.0, length(fituv-.5)) ))*.5;
#elif defined(THE_END)
  float skyDotZ = dot(normalize(vSkyUV), vec3(0.0,0.0,1.0))*.5+.5;
  float skyDotY = dot(normalize(vSkyUV), vec3(0.0,1.0,0.0));
	vec3 noiseX = texture( noisetex, fract(vec2(skyDotY,skyDotZ) + vec2(.75,1.75)*vWorldTime)).rgb;

  uv = fract( vTexcoord.st*.2 + noiseX.xy*.1 )*(1.0-(noiseX.z*.5));
  noiseX.z = (noiseX.z*.5+.5);
  vec4 baseCd = texture2D(gcolor, uv) * vColor * noiseX.z * (skyDotY*.4+.3);
  uv += noiseX.xy + vTexcoord.st*.1;
  vec4 mixCd = texture2D(gcolor, uv) * vColor * noiseX.z * min(1.0,skyDotY*.5+.7);
  outCd = mix( baseCd, mixCd, noiseX.x);
  //float glowVal =  (1.0 - biasToOne( min(1.0, length(fituv-.5)) ))*.5;
#else
  vec4 baseCd = texture2D(gcolor, uv) * vColor;
  outCd = baseCd;
  //float glowVal =  (1.0 - biasToOne( min(1.0, length(fituv-.5)) ))*.5;
#endif


  #if ( DebugView == 4 )
    float debugBlender = step( .0, vPos.x);
    outCd = mix( baseCd, outCd, debugBlender);
  #endif
  
  gl_FragData[0] = outCd;
  gl_FragData[1] = vec4(vec3(0.0),1.0);

}
#endif


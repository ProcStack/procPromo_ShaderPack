
#ifdef VSH
varying vec4 texcoord;
varying vec4 color;
varying vec4 lmcoord;
varying vec4 vPos;
varying vec4 vLocalPos;
varying vec3 vNormal;

varying vec3 sunVecNorm;
varying vec3 upVecNorm;
varying float dayNight;

attribute vec4 mc_Entity;

uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 sunPosition;
uniform vec3 upPosition;

void main() {


	sunVecNorm = normalize(sunPosition);
	upVecNorm = normalize(upPosition);
	dayNight = dot(sunVecNorm,upVecNorm);

	vNormal = normalize(gl_NormalMatrix * gl_Normal);


	vec4 position = gl_ModelViewMatrix * gl_Vertex;
  vLocalPos = position;
  gl_Position = gl_ProjectionMatrix * position;
	vPos = gl_Vertex;

	color = gl_Color;

	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

	gl_FogFragCoord = gl_Position.z;
}
#endif

#ifdef FSH
/* RENDERTARGETS: 0,1,2,6 */

#define gbuffers_clouds
/* --
const int gcolorFormat = RGBA8;
const int gdepthFormat = RGBA16;
const int gnormalFormat = RGB10_A2;
 -- */
 
#include "utils/mathFuncs.glsl"

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform float rainStrength;
uniform int moonPhase;

uniform float near;
uniform float far;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 vPos;
varying vec4 vLocalPos;
varying vec3 vNormal;
varying vec3 cameraPosition;

varying vec3 sunVecNorm;
varying vec3 upVecNorm;
varying float dayNight;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform int fogMode;
uniform vec3 fogColor;

void main() {

  float depth = min(1.0,gl_FragCoord.w*250.0);

  float toUp = dot(vNormal, upVecNorm);
  float toUpFitted = toUp*.05+1.0;
  float toSunMoon = dot(vNormal, sunVecNorm);
  float toSunMoonFitted = abs(toSunMoon*.6+.4)*.4+.6;
  
  float sunRainToneMult = mix( 1.5, .4, rainStrength/15.);
  float moonRainToneMult = mix( 1.2, .4, rainStrength/15.);
  
  vec3 awayFromSunCd = vec3( .85, .9, .97 )*sunRainToneMult;
  vec3 towardSunCd = vec3( 1.0, .93, .97 )*sunRainToneMult;
  float toSunMoonBias = toSunMoon*.5+.5;
  toSunMoonBias *= toSunMoonBias;
  vec3 cloudDayTint = mix( awayFromSunCd, towardSunCd, toSunMoonBias);
  
  
  vec3 awayFromMoonCd = vec3( .25, .3, .5 )*moonRainToneMult;
  vec3 towardMoonCd = vec3( .5, .6, .85 )*moonRainToneMult;
  vec3 cloudNightTint = mix( towardMoonCd, awayFromMoonCd, toSunMoonBias);

  vec4 outCd = texture2D(texture, texcoord.st);
  outCd.rgb *= mix( cloudNightTint, cloudDayTint, dayNight*.5+.5);
  outCd.rgb *= vec3(toUpFitted);
  outCd.rgb *= vec3(mix(.7, toSunMoonFitted, depth));
  
  // Rain Darkening
  float rainStrFit = rainStrength;
  float rainStrFitInverse = 1.0-rainStrFit;
  float rainStrFitInverseFit = rainStrFitInverse*.7+.3;
  outCd.rgb = mix( outCd.rgb, length(color.rgb)*vec3(.5), rainStrFit);
  
  
  
  float distMix = min(1.0,gl_FragCoord.w*2.0);
  outCd.rgb = mix( outCd.rgb*mix(fogColor, vec3(1,1,1), distMix*.55+.45), outCd.rgb, distMix );

  // Sun Glow Mult / Moon Phase Glow Mult
  float sunGlowMult = .65*rainStrFitInverseFit;
  float moonPhaseMult = (1+mod(moonPhase+3,8))*.25;
  moonPhaseMult = min(1.0,moonPhaseMult) - max(0.0, moonPhaseMult-1.0);
  moonPhaseMult = (moonPhaseMult*.4+.1);

  // Add glow around sun / moon
  vec3 camToPos = normalize( vLocalPos.xyz - cameraPosition);
  float sunMoonGlow = dot(camToPos, sunVecNorm);
  // Sun Glow Logic
  float sunGlow = sunMoonGlow*max(0.0,abs(sunMoonGlow)-.3);
  sunGlow = max(0.0,sunGlow)*sunGlowMult;
  // Moon Glow Logic
  float moonGlow = sunMoonGlow*max(0.0,abs(sunMoonGlow)-.8);
  moonGlow = max(0.0,-moonGlow)*moonPhaseMult;
  sunMoonGlow = mix( moonGlow, sunGlow, clamp(dayNight+.5,0.0,1.0));
  //sunMoonGlow = sunMoonGlow*sunMoonGlow * rainStrFitInverseFit;
  outCd.rgb += vec3( sunMoonGlow*.8 );
  
  // Opacity Logic
  outCd.a *= color.a*.5+.5;
  
  vec3 glowHSV = rgb2hsv(outCd.rgb*(.07+sunMoonGlow*.1)*rainStrFitInverseFit);
  glowHSV.z *= outCd.a*.2*(depth*.9+.1);
  glowHSV.z *= glowHSV.z*.5+.5;
  float glowReach = 1.0-depth*.5+.5;

  vec3 toNorm = upVecNorm * ((1.0-rainStrFit)*2.0-1.0);
  toNorm=normalize(toNorm)*.5+.5;

	gl_FragData[0] = outCd;
  gl_FragData[1] = vec4(vec3( min(.9999,gl_FragCoord.w) ), 1.0);
  gl_FragData[2] = vec4(mix(vNormal,upVecNorm,.5)*.5+.5, 1.0);
  gl_FragData[2] = vec4(toNorm, 1.0);
  gl_FragData[3] = vec4(glowHSV, glowReach);
    
}

#endif

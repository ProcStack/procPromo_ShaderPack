// GBuffer - Clouds GLSL
// Written by Kevin Edzenga, ProcStack; 2022-2023
//

#ifdef VSH


#include "utils/shadowCommon.glsl"

uniform float frameTimeCounter;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 sunPosition;
uniform float sunAngle;
uniform vec3 upPosition;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat3 normalMatrix;

attribute vec4 mc_Entity;
attribute vec3 vaNormal;

varying vec4 texcoord;
varying vec4 color;
varying vec4 lmcoord;
varying vec4 vPos;
varying vec4 vLocalPos;
varying vec3 vNormal;
varying vec3 vSunWorldPos;
varying vec3 vSunPos;
varying vec3 vWorldPos;
varying vec3 vFogSkyBlends;

varying vec3 sunVecNorm;
varying vec3 upVecNorm;
varying float dayNight;

varying vec4 shadowPos;

#define PI 3.1415926535897932384626433832795
#define TAU (2.0 * PI)

void main() {

  sunVecNorm = normalize(sunPosition);
  upVecNorm = normalize(upPosition);
  dayNight = dot(sunVecNorm,upVecNorm);

  vNormal = normalize(gl_NormalMatrix * gl_Normal);

  vec4 position = gl_ModelViewMatrix * gl_Vertex;
  vLocalPos = position;
  vWorldPos = gl_Vertex.xyz;
  gl_Position = gl_ProjectionMatrix * position;
  vPos = gl_Vertex;

  color = gl_Color;

  shadowPos = position;
	
	// -- -- --

	vSunWorldPos = (gbufferModelView * vec4(sunPosition,1.0)).xyz;
  vSunPos = normalize(vec3(cos(sunAngle*TAU), sin(sunAngle*TAU),0.0));

	// -- -- --

  float midDayCheck = step( abs(sunAngle - 0.5), .25); // Is it after midday / midnight ?
  float sunSetRiseCheck = step( .5, sunAngle ); // Is it after sunset / sunrise ?
  const float fadeScalar = 2.5;
  float fadeIns = sunAngle*4.0+.5;
  vFogSkyBlends = vec3( 0.0 );

  float fadeOutMorning =  max( 0.0, 1.0 - max(0.0,fadeIns-4.0) * fadeScalar);// * step( 3.0, fadeIns );


  vFogSkyBlends.x = min( 1.0, max( 0.0, vSunPos.y ) * fadeScalar * fadeOutMorning );

  vFogSkyBlends.y = min( 1.0, step( .25, sunAngle) * step( sunAngle, .75) * fadeOutMorning );
  vFogSkyBlends.z = min( 1.0, max( 0.0, -vSunPos.y ) * fadeScalar * fadeOutMorning );


  // -- -- -- -- -- -- -- --
  

  texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

  lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

  gl_FogFragCoord = gl_Position.z;
}
#endif

// -- -- -- -- -- -- -- -- -- --
// -- -- -- -- -- -- -- -- -- --
// -- -- -- -- -- -- -- -- -- --

#ifdef FSH
/* RENDERTARGETS: 0,1,2,6 */

#define gbuffers_clouds
/* --
const int gcolorFormat = RGBA8;
const int gdepthFormat = RGBA16;
const int gnormalFormat = RGB10_A2;
 -- */
 
#include "/shaders.settings"
#include "utils/mathFuncs.glsl"
#include "utils/shadowCommon.glsl"
#include "utils/texSamplers.glsl"

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;

uniform sampler2D gcolor;
uniform sampler2D lightmap;
uniform float rainStrength;
uniform int moonPhase;
uniform vec3 shadowLightPosition;


uniform float near;
uniform float far;

uniform int fogMode;
uniform vec3 fogColor;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 vPos;
varying vec4 vLocalPos;
varying vec3 vNormal;
varying vec3 vSunWorldPos;
varying vec3 vSunPos;
varying vec3 vWorldPos;
varying vec3 vFogSkyBlends;

varying vec4 shadowPos;

varying vec3 sunVecNorm;
varying vec3 upVecNorm;
varying float dayNight;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

const float Fifteenth = 1.0/15.0;

// Time of day Fog Colors
const vec3 fogColorMorning = vec3(0.7647058823529411, 0.7372549019607844, 0.7176470588235294);
const vec3 fogColorAnitMorning = vec3(0.34, 0.34215686274509803, 0.6511764705882353);
const vec3 fogColorDay = vec3(0.7254901960784313, 0.8274509803921568, 1.0);
//const vec3 fogColorEvening = vec3(0.7764705882352941, 0.5137254901960784, 0.34901960784313724);
const vec3 fogColorEvening = vec3(0.892156862745098, 0.42823529411764707, 0.28137254901960785);
const vec3 fogColorAntiEvening = vec3(0.4519607843137255, 0.37254901960784315, 0.7819607843137255);
const vec3 fogColorNight = vec3(0.0392156862745098, 0.043137254901960784, 0.0784313725490196);

// Time of day Sky Colors
const vec3 skyColorMorning = vec3(0.7647058823529411, 0.7372549019607844, 0.7176470588235294);
const vec3 skyColorAnitMorning = vec3(0.34, 0.34215686274509803, 0.6511764705882353);
const vec3 skyColorDay = vec3(0.47058823529411764, 0.6549019607843137, 1.0);
const vec3 skyColorEvening = vec3(0.3411764705882353, 0.47843137254901963, 0.7294117647058823);
const vec3 skyColorAntiEvening = vec3(0.4519607843137255, 0.37254901960784315, 0.7819607843137255);
const vec3 skyColorNight = vec3(0.0, 0.0, 0.0);

void main() {

  float depth = min(1.0,gl_FragCoord.w*250.0);
	
	float toSun = dot( sunVecNorm, normalize(vLocalPos.xyz) );

  float toUp = dot(vNormal, upVecNorm);
  float toUpFitted = toUp*.05+1.0;
  float dayNightBlend = dayNight*.5+.5;
  float toSunMoon = dot(vNormal, sunVecNorm);
  float toSunMoonFitted = abs(toSunMoon*.6+.4)*.4+.6;
  
  float rainMix = rainStrength * Fifteenth;
  float sunRainToneMult = mix( 1.5, .4, rainMix);
  float moonRainToneMult = mix( 1.2, .4, rainMix);
  
  vec3 awayFromSunCd = vec3( .85, .9, .97 )*sunRainToneMult;
  vec3 towardSunCd = vec3( 1.0, .93, .97 )*sunRainToneMult;
  float toSunMoonBias = toSunMoon*.5+.5;
  toSunMoonBias *= toSunMoonBias;
  vec3 cloudDayTint = mix( awayFromSunCd, towardSunCd, toSunMoonBias);
  
  
  vec3 awayFromMoonCd = vec3( .25, .3, .5 )*moonRainToneMult;
  vec3 towardMoonCd = vec3( .5, .6, .85 )*moonRainToneMult;
  vec3 cloudNightTint = mix( towardMoonCd, awayFromMoonCd, toSunMoonBias);

  //vec4 baseCd = vec4( texture2D(gcolor, texcoord.st).rgb, color.a );
  //baseCd.rgb = vec3(1.0); // I have no clue, things keep acting odd
  vec4 baseCd = vec4( 1.0, 1.0, 1.0, color.a ); // I have no clue, things keep acting odd
  vec4 outCd = baseCd;
  outCd.rgb *= mix( cloudNightTint, cloudDayTint, dayNightBlend);
  outCd.rgb *= vec3(toUpFitted);
  outCd.rgb *= vec3(mix(.7, toSunMoonFitted, depth));
  
  
	// -- -- --

  float upDot = max(0.0, dot(normalize(vPos.xyz), gbufferModelView[1].xyz));
  //upDot = 1.0-(1.0-upDot)*(1.0-upDot);

  float halfUpDot = upDot*.5;
  
  float toSunMoonDot = clamp( dot( vSunPos, normalize(vWorldPos) ) * .5 + .5, 0.0, 1.0);

  // Set morning or evening base color
  vec3 morningFogColors = mix( skyColorAnitMorning, fogColorMorning, toSunMoonDot );
  vec3 morningSkyColors = mix( skyColorAnitMorning, skyColorMorning, toSunMoonDot );
  vec3 eveningFogColors = mix( skyColorAntiEvening, fogColorEvening, toSunMoonDot );
  vec3 eveningSkyColors = mix( skyColorAntiEvening, skyColorEvening, toSunMoonDot );
  vec3 morningColors = mix( morningFogColors, morningSkyColors, upDot );
  vec3 eveningColors = mix( eveningFogColors, eveningSkyColors, upDot );
  
  vec3 timeOfDayTint =  mix( morningColors, eveningColors, vFogSkyBlends.y );

	
  // Set day color
  vec3 dayColors = mix( fogColorDay, skyColorDay, halfUpDot );
  timeOfDayTint = mix( timeOfDayTint, dayColors, vFogSkyBlends.x );

  // Set night color
  vec3 nightColors = mix( fogColorNight, skyColorNight, halfUpDot );
  timeOfDayTint = mix( timeOfDayTint, nightColors, vFogSkyBlends.z );

  outCd.rgb = mix( outCd.rgb, timeOfDayTint, dayNightBlend*.5 );


	// -- -- --

  // Rain Darkening
  float rainStrFit = rainStrength;
  float rainStrFitInverse = 1.0-rainStrFit;
  float rainStrFitInverseFit = rainStrFitInverse*.7+.3;
  outCd.rgb = mix( outCd.rgb, length(color.rgb)*vec3(.5), rainStrFit);
  
	// -- -- --

  // Distant fade out of horizon clouds
  float distantClouds = min(1.0, length(vPos.xz)*.001);
  distantClouds = 1.0 - (distantClouds*(distantClouds*.5+.5));

	// -- -- --
  
  float distMix = min(1.0,gl_FragCoord.w*5.0);
  outCd.rgb = mix( outCd.rgb*mix(fogColor, vec3(1,1,1), distMix*.55+.45), outCd.rgb, distMix );

  // Sun Glow Mult / Moon Phase Glow Mult
  float sunGlowMult = .65*rainStrFitInverseFit;
  float moonPhaseMult = (1+mod(moonPhase+3,8))*.25;
  moonPhaseMult = min(1.0,moonPhaseMult) - max(0.0, moonPhaseMult-1.0);

  
	// -- -- --
	
	// Set colors during Sunset/rise and Moonrise/set
	
	float antiBlend = biasToOne( toSun*.5+.5 );
	
	// Sunset / Anti-Sunset
	vec3 sunsetCd = vec3( 0.733, 0.682, 0.647 );
	vec3 antiSunsetCd = vec3( 0.58, 0.522, 0.631 );
	sunsetCd = mix( antiSunsetCd, sunsetCd, antiBlend );
	
	// Moonrise / Anti-Moonrise
	vec3 moonriseCd = vec3( 0.592, 0.647, 0.82 );
	vec3 antiMoonriseCd = vec3( 0.2, 0.239, 0.361 );
	moonriseCd = mix( antiMoonriseCd, moonriseCd, (1.0-antiBlend)*moonPhaseMult );
	
	// --
	
	// The sunset / moonrise color influence
	float riseSetInf = min(1.0,abs(dayNight)*4.0);
	riseSetInf = 1.0 - riseSetInf*(riseSetInf*.5+.5);
	
	// The cross over from sunset colors to moonrise colors
	float sunMoonCdBlend = clamp( (dayNight+.1)*6.2, 0.0, 1.0 );
	
	vec3 setRiseCd = mix( moonriseCd, sunsetCd, sunMoonCdBlend );
	outCd.rgb = mix( outCd.rgb, setRiseCd, riseSetInf );
	
	// -- 
	
  // Add glow around sun
	float sunGlowFit = (rainStrFitInverse*.6+.05);
  outCd.rgb += vec3( min(1.0,-log(pow(toSun*-.5+.5,(0.20+rainStrFit)*riseSetInf))) * sunGlowFit );
	
  // Add glow around moon
	//   moonPhaseMultFit multiplied number is glow's reach from moon
	//   moonPhaseMultFit added number is glow base influence around moon
	float moonPhaseMultFit = moonPhaseMult*.35+.05;
  outCd.rgb += vec3( max( 0.0, moonPhaseMultFit - clamp( -log(pow(toSun*-.5+.5,6.0-moonPhaseMult*3.0)), 0.0,1.0)) * sunGlowFit );
	
	
	// -- -- --
	
	
  // Opacity Logic
  #ifdef IS_IRIS
    float alphaDistFit = .75;
    float alphaOffset = 0.5;
  #else
    float alphaDistFit = .375;
    float alphaOffset = 0.25;
  #endif
  outCd.a *= min( 1.0, color.a * max(0.0,1.0-distMix*distMix*30.0) * alphaDistFit * distantClouds + alphaOffset );
  
  vec3 glowHSV = rgb2hsv(outCd.rgb*(.07+toSun*.2 + toSun*toSun*toSun*.05)*rainStrFitInverseFit);
  glowHSV.z *= outCd.a*(glowHSV.z*.5+.5) *(depth*2.0+.2) * distantClouds;
  float glowReach = ((1.0-depth*.5)+.5)*.5;

  vec3 toNorm = upVecNorm * ((1.0-rainStrFit)*2.0-1.0);
  toNorm=normalize(toNorm)*.5+.5;

  // -- -- --
  
  float shadowDist = 0.0;
  float diffuseSun = 1.0;
  float shadowAvg = 1.0;
#ifdef OVERWORLD

#if ShadowSampleCount > 0
/*
  vec4 shadowProjPos = shadowPos;
  float distort = radialBias(shadowPos.xy);
  vec2 spCoord = shadowProjPos.xy / distort;

  
  vec3 localShadowOffset = shadowPosOffset;
  //localShadowOffset.z *= min(1.0,outDepth*20.0+.7)*.1+.9;
  
  vec3 projectedShadowPosition = vec3(spCoord, shadowProjPos.z) * shadowPosMult + localShadowOffset;
  
  shadowAvg=shadow2D(shadow, projectedShadowPosition).x;
  */
  
#if ShadowSampleCount > 1

  // Modded for multi sampling the shadow
  // TODO : Functionize this rolled up for loop dooky
  /*
  vec2 posOffset;
  float reachMult = 1.5 - (min(1.0,outDepth*20.0)*.5);
  
  for( int x=0; x<axisSamplesCount; ++x){
    posOffset = axisSamples[x]*.0007*reachMult;
    projectedShadowPosition = vec3(spCoord+posOffset, shadowProjPos.z) * shadowPosMult + localShadowOffset;
  
    shadowAvg = mix( shadowAvg, shadow2D(shadow, projectedShadowPosition).x, .25);
    
    
  #if ShadowSampleCount > 2
    posOffset = crossSamples[x]*.0005*reachMult;
    projectedShadowPosition = vec3(spCoord+posOffset, shadowProjPos.z) * shadowPosMult + localShadowOffset;
  
    shadowAvg = mix( shadowAvg, shadow2D(shadow, projectedShadowPosition).x, .2);
  #endif
    
  }
  */

#endif
  /*
  float sunMoonShadowInf = clamp( (abs(dot(sunVecNorm, vNormal))-.04)*1.5, 0.0, 1.0 );
  //float sunMoonShadowInf = min(1.0, max(0.0, abs(dot(sunVecNorm, vNormal))+.50)*1.0);
  float shadowDepthInf = clamp( (depth*40.0), 0.0, 1.0 );

  
  shadowAvg = shadowAvg + min(1.0, (length(vLocalPos.xz)*.0025)*1.5);
  
  float shadowSurfaceInf = step(0.1,dot(normalize(shadowLightPosition), vNormal) + abs(vWorldNormal.z));
  
  //diffuseSun *= mix( 1.0, shadowAvg, sunMoonShadowInf * shadowDepthInf );
  diffuseSun *= mix( 1.0, shadowAvg, shadowSurfaceInf * shadowDepthInf );
*/
#endif
#endif
  
  // -- -- --

  outCd.rgb = mix( outCd.rgb, vec3( luma(color.rgb) ), rainStrFit);
  

  #if ( DebugView == 4 )
    float debugBlender = step( .0, vLocalPos.x);
    outCd = mix( baseCd*color, outCd, debugBlender);
  #endif
  

  gl_FragData[0] = outCd;
  gl_FragData[1] = vec4(vec3( min(.9999,gl_FragCoord.w) ), 1.0);
  //gl_FragData[2] = vec4(mix(vNormal,upVecNorm,.5)*.5+.15, 1.0);
  gl_FragData[2] = vec4(toNorm, 1.0);
  gl_FragData[3] = vec4(glowHSV, glowReach);
    
}

#endif

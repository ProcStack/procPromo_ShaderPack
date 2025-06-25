// GBuffer - Sky Basic GLSL
// Written by Kevin Edzenga, ProcStack; 2022-2023
//

#ifdef VSH
#include "/shaders.settings"

uniform int renderStage;
uniform float sunAngle;

attribute vec4 mc_Entity;

varying vec4 texcoord;
varying vec4 vPos;
varying vec3 vSunPos;
varying vec3 vWorldPos;
varying vec4 vColor;
varying vec3 vFogSkyBlends;
varying vec3 vNormal;


#define PI 3.1415926535897932384626433832795
#define TAU (2.0 * PI)

void main() {

  // Star Fading Logic
  //   Shift `sunAngle` from worldTime 0 at 6:00 to worldTime 0 at 12:00
  //     World Time 12000 would be 18:00
  //   Add .75 instead of subtracting .25 for positive fract morning hours
  float dayNight = 1.0-abs(fract(sunAngle+.75)-.5) * 2.0;
  dayNight = min(1.0, max(0.0,dayNight-.4) * 5.0);

  vNormal = normalize(gl_NormalMatrix * gl_Normal);
  
  vec4 position = gl_ModelViewMatrix * gl_Vertex;
  vPos = position;

  gl_Position = gl_ProjectionMatrix * position;

  vWorldPos = gl_Vertex.xyz;
  vColor = gl_Color;

  texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
  

  vSunPos = normalize(vec3(cos(sunAngle*TAU), sin(sunAngle*TAU),0.0));

  float midDayCheck = step( abs(sunAngle - 0.5), .25); // Is it after midday / midnight ?
  float sunSetRiseCheck = step( .5, sunAngle ); // Is it after sunset / sunrise ?
  const float fadeScalar = 2.5;
  float fadeIns = sunAngle*4.0+.5;
  vFogSkyBlends = vec3( 0.0 );

  float fadeOutMorning =  max( 0.0, 1.0 - max(0.0,fadeIns-4.0) * fadeScalar);// * step( 3.0, fadeIns );


  vFogSkyBlends.x = min( 1.0, max( 0.0, vSunPos.y ) * fadeScalar * fadeOutMorning );

  vFogSkyBlends.y = min( 1.0, step( .25, sunAngle) * step( sunAngle, .75) * fadeOutMorning );
  vFogSkyBlends.z = min( 1.0, max( 0.0, -vSunPos.y ) * fadeScalar * fadeOutMorning );

  //vFogSkyBlends.x = vFogSkyBlends.x * vFogSkyBlends.x;
  //vFogSkyBlends.y = 1.0 - (1.0-vFogSkyBlends.y)*(1.0-vFogSkyBlends.y);
  //vFogSkyBlends.z = vFogSkyBlends.z * vFogSkyBlends.z;
  
  gl_FogFragCoord = gl_Position.z;
}
#endif

#ifdef FSH
/* RENDERTARGETS: 0,1,6 */

#include "/shaders.settings"
#include "utils/mathFuncs.glsl"
#include "utils/stylization.glsl"

uniform sampler2D gcolor;
uniform sampler2D lightmap;
uniform float rainStrength;
uniform float dayNight;
uniform int renderStage;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;

uniform float viewHeight;
uniform float viewWidth;

varying vec4 texcoord;
varying vec4 vPos;
varying vec3 vSunPos;
varying vec3 vWorldPos;
varying vec4 vColor;
varying vec3 vFogSkyBlends;
varying vec3 vNormal;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform int fogMode;


// Time of day Fog Colors
const vec3 fogColorMorning = vec3(0.7647058823529411, 0.7372549019607844, 0.7176470588235294);
const vec3 fogColorAnitMorning = vec3(0.34, 0.34215686274509803, 0.6511764705882353);
const vec3 fogColorDay = vec3(0.7254901960784313, 0.8274509803921568, 1.0);
//const vec3 fogColorEvening = vec3(0.7764705882352941, 0.5137254901960784, 0.34901960784313724);
const vec3 fogColorEvening = vec3(0.792156862745098, 0.38823529411764707, 0.23137254901960785);
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
  
  vec4 outCd = vColor;
  
  vec4 basePos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight)*2.0 - 1.0, 1.0, 1.0);
  vec4 pos = gbufferProjectionInverse * basePos;
  //pos = gbufferModelView * vPos;
  
  float upDot = max(0.0, dot(normalize(pos.xyz), gbufferModelView[1].xyz));
  upDot = 1.0-(1.0-upDot)*(1.0-upDot);

  float skyGrey = getSkyGrey(skyColor.rgb);
  vec3 skyCd = mix( skyColor.rgb, vec3(skyGrey), rainStrength);
  vec3 fogCd = mix( fogColor, vec3(skyGrey*.65), rainStrength);

  outCd.rgb = mix(fogCd, skyCd, upDot);
  
  #if ( DebugView == 4 )
    float debugBlender = step( .0, basePos.x);
    outCd.rgb = mix( skyColor, outCd.rgb, debugBlender);
  #endif
    //outCd.rgb=skyCd.xyz;


  float toSunMoonDot = dot( vSunPos, normalize(vWorldPos) ) * .5 + .5 ;

  // Set morning or evening base color
  vec3 morningFogColors = mix( skyColorAnitMorning, fogColorMorning, toSunMoonDot );
  vec3 morningSkyColors = mix( skyColorAnitMorning, fogColorMorning, toSunMoonDot );
  vec3 eveningFogColors = mix( skyColorAntiEvening, fogColorEvening, toSunMoonDot );
  vec3 eveningSkyColors = mix( skyColorAntiEvening, fogColorEvening, toSunMoonDot );
  vec3 morningColors = mix( mix( morningFogColors, morningSkyColors, upDot ), vec3(skyGrey), rainStrength);
  vec3 eveningColors = mix( mix( eveningFogColors, eveningSkyColors, upDot ), vec3(skyGrey), rainStrength);
  
  outCd.rgb = mix( morningColors, eveningColors, vFogSkyBlends.y );

  // Set day color
  vec3 dayColors = mix( mix( fogColorDay, skyColorDay, upDot ), vec3(skyGrey), rainStrength);
  outCd.rgb = mix( outCd.rgb, dayColors, vFogSkyBlends.x );

  // Set night color
  vec3 nightColors = mix( mix( fogColorNight, skyColorNight, upDot ), vec3(skyGrey), rainStrength);
  outCd.rgb = mix( outCd.rgb, nightColors, vFogSkyBlends.z );
  
  
  // Get the stars back in
  if(renderStage == MC_RENDER_STAGE_STARS) {
    outCd.rgb = vec3(1.0,1.0,1.0);
    outCd.a = upDot*upDot*(1.0-vFogSkyBlends.x);
  }


  gl_FragData[0] = outCd;
  //gl_FragData[1] = vec4(vec3( 0.0 ), 1.0);
  gl_FragData[1] = vec4(vec3( min(.999999,gl_FragCoord.w) ), 1.0);
  //gl_FragData[2] = vec4(vNormal*.5+.5, 1.0);
  gl_FragData[1] = vec4(vec3(0.0),1.0);

}
#endif

// GBuffer - Entities GLSL
// Written by Kevin Edzenga, ProcStack; 2022-2023
//

#ifdef VSH


#define gbuffers_entities

uniform float frameTimeCounter;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;

uniform sampler2D gcolor;

uniform float viewWidth;
uniform float viewHeight;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;                      //xyz = tangent vector, w = handedness, added in 1.7.10

in vec3 at_velocity; // vertex offset to previous frame

varying vec2 texelSize;
varying vec2 texcoordmid;
varying vec4 texcoord;
varying vec4 vtexcoordam;
varying vec4 color;
varying vec4 lmcoord;

varying vec4 vPos;
varying vec4 vNormal;
varying vec3 vAvgColor;
varying float vAvgColorBlend;

void main() {

  vec4 position = gl_ModelViewMatrix * gl_Vertex;

  
  vPos = gl_ProjectionMatrix * position;
  gl_Position = vPos;
  
  vPos = gl_ModelViewMatrix * gl_Vertex;

  color = gl_Color;
  color.a=1.0;


  texelSize = vec2(1.0/64.0, 1.0/32.0);//vec2(1.0/viewWidth,1.0/viewWidth);
  texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

  lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

  gl_FogFragCoord = gl_Position.z;

  
  //vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
  vec2 midcoord = (gl_TextureMatrix[0] *  vec4(mc_midTexCoord.st,0.0,1.0)).st;
  texcoordmid=midcoord;
  vec2 texcoordminusmid = texcoord.xy-midcoord;
  vtexcoordam.pq = abs(texcoordminusmid)*2.0;
  vtexcoordam.st = min(texcoord.xy ,midcoord-texcoordminusmid);
  
  
  vNormal.xyz = normalize(gl_NormalMatrix * gl_Normal);
  vNormal.a = 0.02;
  
  //vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
  vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
  
  
  float avgBlend = .3;
  
  ivec2 txlOffset = ivec2(2);
  vec3 mixColor;
  vec4 tmpCd;
  float avgDiv = 0.0;
  tmpCd = texture2D(gcolor, midcoord);
    mixColor = tmpCd.rgb;
    avgDiv += tmpCd.a;
  tmpCd = textureOffset(gcolor, midcoord, ivec2(txlOffset.x, txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  tmpCd = textureOffset(gcolor, midcoord, ivec2(txlOffset.x, -txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  tmpCd = textureOffset(gcolor, midcoord, ivec2(-txlOffset.x, -txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  tmpCd = textureOffset(gcolor, midcoord, ivec2(-txlOffset.x, txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  
  vAvgColor = mixColor;
  
  // 
  vAvgColorBlend = 0.0;
  if (mc_Entity.x == 603){
    vAvgColorBlend = 0.5;
  }
  
  
  
}
#endif

#ifdef FSH


/* RENDERTARGETS: 0,1,2,7,6 */


/* --
const int gcolorFormat = RGBA8;
const int gdepthFormat = RGBA16; //it's to inacurrate otherwise
const int gnormalFormat = RGB10_A2;
 -- */

#include "/shaders.settings"
#include "utils/mathFuncs.glsl"
#include "utils/texSamplers.glsl"

uniform sampler2D gcolor;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform int fogMode;
uniform vec3 sunPosition;
uniform vec4 spriteBounds; 
uniform vec4 entityColor;
uniform float rainStrength;


varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

varying vec2 texelSize;
varying vec2 texcoordmid;
varying vec4 vtexcoordam;

varying vec4 vPos;
varying vec4 vNormal;
varying vec3 vAvgColor;
varying float vAvgColorBlend;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;



void main() {

  vec2 tuv = texcoord.st;
  vec4 baseCd = texture2D(gcolor, tuv);
  vec4 txCd = baseCd;
  float avgDelta = 0.0;
  vec2 screenSpace = (gl_FragCoord.xy/gl_FragCoord.z);
  screenSpace = (screenSpace*texelSize)-.5;

  //diffuseSampleXYZFetch( gcolor, tuv, texcoordmid, texelSize*1.0, DetailBlurring, baseCd, txCd, avgDelta);
  diffuseSampleXYZ( gcolor, tuv, vtexcoordam, texelSize*2.0, DetailBlurring, baseCd, txCd, avgDelta);
  //txCd = diffuseNoLimit( gcolor, tuv, vec2(0.10) );
  
  vec2 luv = lmcoord.st;
  vec4 lightCd = texture2D(lightmap, luv);
  
  vec4 outCd = txCd * color;
  baseCd *= color;
  
  float avgColorBlender = max(0.0, dot(outCd.rgb,(txCd.rgb)));
  float cdComp=1.0-abs(min(1.0,maxComponent(baseCd.rgb)*1.0)-.5)*2.0;
  avgColorBlender = clamp( (avgColorBlender-.85)*1.75+.25, 0.0, 1.0 )*cdComp;
  //avgColorBlender = min(1.0, avgColorBlender-(baseCd.r*baseCd.g*baseCd.b)*2.0);
  outCd.rgb =  mix( baseCd.rgb, outCd.rgb, avgColorBlender );
  
  float highlights = dot(normalize(sunPosition),vNormal.xyz);
  highlights = (highlights-.5)*0.3;

  float outDepth = min(.9999,gl_FragCoord.w);
  float outEffectGlow = 0.0;
  
  #if ( DebugView == 4 )
    float debugBlender = step( .0, vPos.x );
    outCd = mix( baseCd, outCd, debugBlender);
  #endif
  float entityCd = maxComponent(entityColor.rgb);
  lightCd = vec4( lightCd.r );// * (1.0+rainStrength*.2));
  outCd.rgb = mix( outCd.rgb*lightCd.rgb, entityColor.rgb, entityCd);  
//outCd.rgb=vec3(avgColorBlender);// * color.rgb);
  gl_FragData[0] = outCd;
  gl_FragData[1] = vec4(outDepth, outEffectGlow, 0.0, 1.0);
  gl_FragData[2] = vec4(vNormal.xyz*.5+.5,1.0);
  gl_FragData[3] = vec4( 1.0, 1.0, 0.0,1.0);
  gl_FragData[4] = vec4(vec3(0.0),1.0);


}
#endif

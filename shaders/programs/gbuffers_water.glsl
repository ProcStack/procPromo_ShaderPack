// GBuffer - Water GLSL
// Written by Kevin Edzenga, ProcStack; 2022-2024
//


#ifdef VSH
#define gbuffers_water

uniform sampler2D gcolor;
uniform float frameTimeCounter;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;

uniform float viewWidth;
uniform float viewHeight;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;                      //xyz = tangent vector, w = handedness, added in 1.7.10

in vec3 at_velocity; // vertex offset to previous frame

varying vec2 texelSize;
varying vec4 texcoord;
varying vec4 color;
varying vec4 lmcoord;
varying vec4 lmtexcoord;
varying vec2 texmidcoord;

varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec2 vtexcoord;

varying float vTextureInf;
varying float vTextureGlow;
varying float vMinAlpha;

varying vec4 vPos;
varying vec4 normal;
varying mat3 tbnMatrix;

void main() {

  vec4 position = gl_ModelViewMatrix * gl_Vertex;

  
  vPos = gl_ProjectionMatrix * position;
  gl_Position = vPos;
  
  vPos = gl_ModelViewMatrix * gl_Vertex;

  color = gl_Color;


  texelSize = vec2(1.0/viewWidth,1.0/viewHeight);
  texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
  texcoord =  gl_MultiTexCoord0;

  lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

  float NdotU = gl_Normal.y*(0.17*15.5/255.)+(0.83*15.5/255.);
#ifdef SEPARATE_AO
  lmtexcoord.zw = gl_MultiTexCoord1.xy*vec2(15.5/255.0,NdotU*gl_Color.a)+0.5;
#else
  lmtexcoord.zw = gl_MultiTexCoord1.xy*vec2(15.5/255.0,NdotU)+0.5;
#endif

  gl_FogFragCoord = gl_Position.z;


  
  vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
  vec2 texcoordminusmid = texcoord.xy-midcoord;
  texmidcoord = midcoord;
  vtexcoordam.pq = abs(texcoordminusmid)*3.0;
  vtexcoordam.st = min(texcoord.xy ,midcoord-texcoordminusmid);
  vtexcoord = sign(texcoordminusmid)*0.5+0.5;
  
  
  
  normal.xyz = normalize(gl_NormalMatrix * gl_Normal);
  normal.a = 0.02;
  
  //vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
  vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;

  
  vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
  vec3 binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
  tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
           tangent.y, binormal.y, normal.y,
           tangent.z, binormal.z, normal.z);
  
  
  //vTextureInf = step(.1,texcoord.y)*.2+.05;
  vTextureInf = 1.0;
  vTextureGlow = 0.0;
  vMinAlpha = 0.0;
  

  //vec2 txlquart = texelSize*8.0;
  vec2 txlquart = texelSize*4.0;
  vec4 avgCd;
  float avgValue;

  // Lava
  //if (mc_Entity.x == 701){
    //color.rgb=avgCd;
  //}
  // Flowing Lava
  if (mc_Entity.x == 702){
    avgCd = texture2D(gcolor, mc_midTexCoord.st);
    avgCd += texture2D(gcolor, mc_midTexCoord.st+txlquart);
    avgCd += texture2D(gcolor, mc_midTexCoord.st+vec2(txlquart.x, -txlquart.y));
    avgCd += texture2D(gcolor, mc_midTexCoord.st-txlquart);
    avgCd += texture2D(gcolor, mc_midTexCoord.st+vec2(-txlquart.x, txlquart.y));
    avgCd *= .5;
    //color.rgb *= vec3(.3,.3,.5)*avgCd;
  
    color *= avgCd;//*.3+.7;
    vTextureInf = 0.0;
  }
  
  // Water
  if (mc_Entity.x == 703){
    avgCd = texture2D(gcolor, mc_midTexCoord.st);
    avgCd += texture2D(gcolor, mc_midTexCoord.st+txlquart);
    avgCd *= .5;
    //color.rgb=vec3(.35,.35,.85);
    color = color*avgCd;
    vTextureInf = 0.0;
  }
  // Flowing Water
  if (mc_Entity.x == 704){
    avgCd = texture2D(gcolor, mc_midTexCoord.st);
    //avgCd += texture2D(gcolor, mc_midTexCoord.st+txlquart).x;
    //avgCd += texture2D(gcolor, mc_midTexCoord.st+vec2(txlquart.x, -txlquart.y)).x;
    //avgCd += texture2D(gcolor, mc_midTexCoord.st-txlquart).x;
    //avgCd += texture2D(gcolor, mc_midTexCoord.st+vec2(-txlquart.x, txlquart.y)).x;
    //avgCd *= .2;
    //color.rgb *= vec3(.3,.3,.5)*avgCd;
    
    color *= avgCd*.3+.7;
    vTextureInf = 0.0;
  }
  
  // Nether Portal
  if (mc_Entity.x == 705){
    vTextureGlow = 0.5;
    avgCd = texture2D(gcolor, mc_midTexCoord.st);
    color*=avgCd*.5+.5;
    vMinAlpha = .5;
  }
  
}
#endif

#ifdef FSH
/* DRAWBUFFERS:0126 */

#define gbuffers_water

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
uniform sampler2D gaux1; // Dynamic Lighting
uniform sampler2D normals;
uniform int fogMode;
uniform vec3 sunPosition;
uniform float aspectRatio;

uniform vec3 fogColor;
uniform int isEyeInWater;

//#include "utils/sampler.glsl"

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 lmtexcoord;

varying vec2 texelSize;
varying vec2 texmidcoord;
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec2 vtexcoord;

varying float vTextureInf;
varying float vTextureGlow;
varying float vMinAlpha;

varying vec4 vPos;
varying vec4 normal;
varying mat3 tbnMatrix;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;


void main() {

  vec2 tuv = texcoord.st;
  //vec4 txCd = diffuseSample( gcolor, tuv, texelSize, 0.0 );
  //vec4 txCd = diffuseSample( gcolor, tuv, vtexcoordam, texelSize-.0005, 1.0 );
  vec4 txCd = diffuseNoLimit( gcolor, tuv, texelSize*0.50 );
  vec4 baseCd =  texture2D(gcolor, tuv);// 
  
  vec2 luv = lmcoord.st;
  float lightVal = texture2D(lightmap, luv).r;
  
  vec4 outCd = color;// * vec4(vec3(lightVal),1.0);
  outCd*= mix(vec4(1.0),txCd,vTextureInf);//+0.5;
  

  float depth = min(1.0, max(0.0, gl_FragCoord.w));
  //outCd.rgb = mix( fogColor, outCd.rgb, smoothstep(.0,.01,depth) );
  outCd.rgb = mix( fogColor*vec3(.8,.8,.9), outCd.rgb, min(1.0,depth*80.0)*.8+.2 ) * lightVal;




    float distMix = min(1.0,gl_FragCoord.w);
    float waterLavaSnow = float(isEyeInWater);
    if( isEyeInWater == 1 ){ // Water
      float smoothDepth=min(1.0, smoothstep(.01,.30,depth));
      outCd.rgb *= fogColor*lightVal* ( 1.3-(1.0-smoothDepth)*.5 );
    }else if( isEyeInWater >= 2 ){ // Lava
      outCd.rgb = mix( outCd.rgb, fogColor, (1.0-distMix*.1) );
    }
    
    outCd.a = max( vMinAlpha, outCd.a+(1.0-depth*depth*depth)*.2 );
    
    vec3 glowCd = outCd.rgb*outCd.rgb;
    vec3 glowHSV = rgb2hsv(glowCd);
    //glowHSV.z *= (depthBias*.5+.2);
    glowHSV.z *= (depth*.2+.8) * .5;// * lightLuma;
    glowHSV.y *= 1.52;// * lightLuma;

#ifdef NETHER
    glowHSV.z *= vTextureGlow;
#else
    glowHSV.z *= vTextureGlow*.7;
#endif


    if( WorldColor ){ // Greyscale
      outCd.rgb = vec3( luma(color.rgb) * lightVal );
    }
		
		
  #if ( DebugView == 2 )
    vec2 screenSpace = (vPos.xy/vPos.z)  * vec2(aspectRatio);
		//outCd.a *= step(0.5, screenSpace.x)*.75+.25;
  #elif ( DebugView == 4 )
    float debugBlender = step( .0, vPos.x);
    outCd = mix( baseCd*vec4(color.rgb,1.0)*lightVal, outCd, debugBlender);
  #endif
  
    gl_FragData[0] = outCd;
    gl_FragData[1] = vec4(vec3( min(.9999,gl_FragCoord.w) ), 1.0);
    gl_FragData[2] = vec4(normal.xyz*.5+.5,1.0);
    gl_FragData[3] = vec4(glowHSV,1.0);

}

#endif

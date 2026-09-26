// GBuffer - Hands GLSL
// Written by Kevin Edzenga, ProcStack; 2022-2023
//

#ifdef VSH

#define gbuffers_hand

#include "/shaders.settings"

uniform float frameTimeCounter;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform int heldItemId;
uniform int heldItemId2;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

uniform int blockEntityId;
uniform int entityId;

uniform vec3 sunPosition;

uniform float viewWidth;
uniform float viewHeight;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

varying vec2 texelSize;
varying vec4 texcoord;
varying vec4 color;
varying vec4 lmcoord;
varying vec2 texmidcoord;

varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec2 vtexcoord;
varying float vTexColorOnly;


varying float vWhichHandItem; // 0 = left; 1 = right
varying float vLeftGlowPerc;
varying float vRightGlowPerc;
varying float vGlowPerc;

varying vec4 vPos;
varying vec4 normal;

void main() {


  vec4 position = gl_ModelViewMatrix * gl_Vertex;
  float center = position.x;

  float isWhichHand = step( 0.0, center ); // Right to init
  float isLeftHand = step( 0.0, center );
  float isRightHand = step( center, 0.0 ); 
  float leftGlow = (heldBlockLightValue2/15.);//*isLeftHand;
  float rightGlow = (heldBlockLightValue/15.);//*isRightHand;

  //float posScalarDir = heldItemId==111 ? -1.0 : 1.0;
  float posScalarDir = -1.0;// -(step( -0.0, center )*2.0-1.0);
  

// Move hands inward and angle toward camera
//   Needed for filming usable vertical content...
//     Either I hide it or leave it on a branch...
#if HandPosScalar < 1.0

  float handAngle = 0.95; // radians; .35 = ~20 degrees
  float sideRotation = -handAngle * posScalarDir * (1.0-HandPosScalar);
  float rotationCos = cos(sideRotation);
  float rotationSin = sin(sideRotation);

  mat3 yRotation = mat3(
    rotationCos, 0.0, -rotationSin,
    0.0,         1.0,  0.0,
    rotationSin, 0.0,  rotationCos
  );

  // Move hand "near" center, rotate, move back to original position
  float handScalarComp = (1.0-HandPosScalar)*posScalarDir;
  vPos = vec4( yRotation * vec3(gl_Vertex.x+handScalarComp, gl_Vertex.yz), gl_Vertex.w );
  vPos.x -= handScalarComp*0.75;
  vPos.z -= handScalarComp*handScalarComp*handScalarComp*posScalarDir*.5; // Depth


#else
  vPos =  gl_Vertex;
#endif

  gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * vPos;


  // -- -- --
  
  color = gl_Color;


  texelSize = vec2(1.0/viewWidth,1.0/viewHeight);
  texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

  lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

  gl_FogFragCoord = gl_Position.z;


  
  vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
  vec2 texcoordminusmid = texcoord.xy-midcoord;
  texmidcoord = midcoord;
  vtexcoordam.pq = abs(texcoordminusmid)*2.0;
  vtexcoordam.st = min(texcoord.xy ,midcoord-texcoordminusmid);
  vtexcoord = sign(texcoordminusmid)*0.5+0.5;
  
  
  normal.xyz = normalize(gl_NormalMatrix * gl_Normal);
  normal.a = 0.02;
  


  //vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
  vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
           

  float curGlowPerc=0.0;
  if( heldItemId == 14 ){
    curGlowPerc = 1. ;
  }
  if( heldItemId == 15  ){
    curGlowPerc = .95 ;
  }
  if( heldItemId == 16  ){
    curGlowPerc = .35 ;
  }
  if( heldItemId == 17  ){
    curGlowPerc = 3.5 ;
  }
  vRightGlowPerc = rightGlow*curGlowPerc;
  
  curGlowPerc=0.0;
  if( heldItemId2 == 14 ){
    curGlowPerc = 1. ;
    isWhichHand=1.0-isWhichHand;
  }
  if( heldItemId2 == 15 ){
    curGlowPerc = .95 ;
    isWhichHand=1.0-isWhichHand;
  }
  if( heldItemId2 == 16 ){
    curGlowPerc = .35 ;
    isWhichHand=1.0-isWhichHand;
  }
  if( heldItemId2 == 17 ){
    curGlowPerc = 3.5 ;
    isWhichHand=1.0-isWhichHand;
  }
  vLeftGlowPerc = leftGlow*curGlowPerc;
  vGlowPerc = max( vLeftGlowPerc, vRightGlowPerc );
  vWhichHandItem = isWhichHand;
  
  
  // Items that shouldn't have additional effects
  vTexColorOnly = float( mc_Entity.x == 605  );
  vTexColorOnly = float( entityId );
  vTexColorOnly = float( blockEntityId );
}
#endif

#ifdef FSH
/* RENDERTARGETS: 0,1,2,7,6 */

#define gbuffers_hand

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
uniform sampler2DShadow shadow;
uniform sampler2D normals;
uniform vec3 fogColor;
uniform int fogMode;
uniform vec3 sunPosition;
uniform int isEyeInWater;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

varying vec2 texelSize;
varying vec2 texmidcoord;
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec2 vtexcoord;

varying float vWhichHandItem; // 0 = left; 1 = right
varying float vLeftGlowPerc;
varying float vRightGlowPerc;
varying float vGlowPerc;
varying float vBlurPerc;

varying float vTexColorOnly;

varying vec4 vPos;
varying vec4 normal;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;




void main() {

  vec2 tuv = texcoord.st;
  
  
  
  //vec4 txCd = diffuseSampleNoLimit( gcolor, tuv, texelSize );
  //vec4 txCd = diffuseNoLimit( gcolor, tuv, texelSize );
  vec4 txCd = diffuseNoLimit( gcolor, tuv, vec2(0.001) );
  float glowInf = 0.0;
  
  vec2 luv = lmcoord.st;
  vec4 lightCd = texture2D(lightmap, luv);
  
  vec4 outCd = txCd * lightCd * color;
  
  
  float surfaceShading = 1.0-abs(dot(normalize(-vPos.xyz*vec3(1.0,.91,1.0)),normal.xyz));
  surfaceShading *= dot(normalize(sunPosition),normal.xyz)*.2;
  surfaceShading *= max(0.0,dot( normalize(sunPosition), vec3(0.0,0.0,-1.0)));
  outCd.rgb += vec3( surfaceShading*.2 );
  


    // TODO : Update isEyeInWater to not be ifs
    float distMix = min(1.0,gl_FragCoord.w);
    vec3 fogCg = vec3(fogColor.rbg)*.2+.7;
    if( isEyeInWater == 1 ){ // Water
      outCd.rgb *= mix( outCd.rgb, outCd.rgb*mix(fogColor, vec3(1,1,1),distMix*.7+.3), (1.0-distMix) );
    }else if( isEyeInWater == 2 ){ // Lava
      outCd.rgb *= fogCg;//mix( outCd.rgb, fogColor, (1.0-distMix) );
    //}else if( isEyeInWater == 3 ){ // Snow
    //  outCd.rgb *= fogCg;
    }

  //vec3 cdDeltas = vec3( outCd.r-max(outCd.g,outCd.b), outCd.g-max(outCd.r,outCd.b), outCd.b-max(outCd.r,outCd.g) );
  float cdDeltaSub = .9;
  vec3 cdDeltas = vec3( outCd.r-max(outCd.g,outCd.b)*cdDeltaSub, outCd.g-max(outCd.r,outCd.b)*cdDeltaSub, outCd.b-max(outCd.r,outCd.g)*cdDeltaSub );
  float glowMult = max(length(outCd.rgb)*.4, max( cdDeltas.r, max(cdDeltas.g, cdDeltas.b))*2.0);
  


  if( vTexColorOnly > .5 ){
    outCd = txCd * lightCd * color;
  }
  vec3 glowHSV = rgb2hsv(outCd.rgb);
  glowHSV.z *= glowInf*glowInf*.7;//glowVal;

  #if ( DebugView == 4 )
    vec4 baseCd = texture2D( gcolor, tuv );
    float debugBlender = step( .0, vPos.x);
    outCd = mix( outCd, baseCd, debugBlender);
  #endif
  


  gl_FragData[0] = outCd;
  gl_FragData[1] = vec4(vec3( min(1.0,gl_FragCoord.w)-.0001 ), 1.0);
  gl_FragData[2] = vec4(normal.xyz*.5+.5,1.0);
  gl_FragData[3] = vec4(1.0,min(.999999,gl_FragCoord.w)+.5,0.0,1.0);//glowVal);
  gl_FragData[4] = vec4(glowHSV,1.0);//glowVal);

  /*
    gl_FragData[0].rgb = mix(gl_FragData[0].rgb, gl_Fog.color.rgb, clamp((gl_FogFragCoord - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0));
  */
}

#endif

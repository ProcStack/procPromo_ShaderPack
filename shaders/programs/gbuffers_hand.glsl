
#ifdef VSH

#define gbuffers_hand

uniform float frameTimeCounter;
uniform int heldItemId;
uniform int heldItemId2;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

uniform vec3 sunPosition;
uniform vec3 cameraPosition;

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
varying vec2 texmidcoord;

varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec2 vtexcoord;
varying float vTexColorOnly;

varying float sunDot;

varying float vWhichHandItem; // 0 = left; 1 = right
varying float vLeftGlowPerc;
varying float vRightGlowPerc;
varying float vGlowPerc;

varying vec4 vPos;
varying vec4 normal;
varying mat3 tbnMatrix;

void main() {

	vec4 position = gl_ModelViewMatrix * gl_Vertex;

  
  vPos = gl_ProjectionMatrix * position;
	gl_Position = vPos;

  vPos = position;
  
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
  sunDot = dot( normal.xyz, normalize(sunPosition) );
  sunDot = dot( normal.xyz, normalize(localSunPos) );
  sunDot = dot( (gbufferModelViewInverse*gl_Vertex).xyz, normalize(vec3(1.0,0.,0.) ));

  
	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
	vec3 binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
					 tangent.y, binormal.y, normal.y,
					 tangent.z, binormal.z, normal.z);
           
  float isWhichHand = step( 0.0, position.x ); // Right to init
  float isLeftHand = step( 0.0, position.x );
  float isRightHand = step( position.x, 0.0 ); 
  float leftGlow = (heldBlockLightValue2/15.);//*isLeftHand;
  float rightGlow = (heldBlockLightValue/15.);//*isRightHand;

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
  vTexColorOnly = float( heldItemId == 118 || heldItemId2 == 118 );
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

#include "utils/mathFuncs.glsl"
#include "utils/texSamplers.glsl"

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2DShadow shadow;
uniform sampler2D normals;
uniform int fogMode;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
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

varying float vTexColorOnly;

varying float sunDot;

varying vec4 vPos;
varying vec4 normal;
varying mat3 tbnMatrix;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;




void main() {

  vec2 tuv = texcoord.st;
  //vec4 txCd = diffuseSampleNoLimit( texture, tuv, texelSize );
  vec4 txCd = diffuseNoLimit( texture, tuv, vec2(0.001) );
  float glowInf = 0.0;
  
  vec2 luv = lmcoord.st;
  vec4 lightCd = texture2D(lightmap, luv);
  
  vec4 outCd = txCd * lightCd * color;
  
  
  vec3 normalCd = texture2D(normals, tuv).rgb*2.0-1.0;
  normalCd = normalize( normalCd*tbnMatrix );
  float surfaceShading = 1.0-abs(dot(normalize(-vPos.xyz*vec3(1.0,.91,1.0)),normal.xyz));
  surfaceShading *= dot(normalize(sunPosition),normalCd)*.2;
  surfaceShading *= max(0.0,dot( normalize(sunPosition), vec3(0.0,0.0,-1.0)));
  outCd.rgb += vec3( surfaceShading*.2 );
  
  //outCd.rgb = vec3( dot( normalize(sunPosition), normalize(reflect(normalize(-vPos.xyz),normalCd) )) );// * -highlights;
  //outCd.rgb = vec3( dot( normalize(sunPosition), dot(normalize(-vPos.xyz),normal.xyz) ) );
  //outCd.rgb = vec3( dot(normalize(vPos.xyz),normal.xyz) );
  //outCd.rgb = vec3( dot(normalize(vPos.xyz-cameraPosition),normal.xyz) );


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

	gl_FragData[0] = outCd;
  gl_FragData[1] = vec4(vec3( min(.999999,gl_FragCoord.w) ), 1.0);
	gl_FragData[2] = vec4(normalCd.xyz*.5+.5,1.0);
	gl_FragData[3] = vec4(1.0,min(.999999,gl_FragCoord.w),0.0,1.0);//glowVal);
	gl_FragData[4] = vec4(glowHSV,1.0);//glowVal);

	/*if (fogMode == GL_EXP) {
		gl_FragData[0].rgb = mix(gl_FragData[0].rgb, gl_Fog.color.rgb, 1.0 - clamp(exp(-gl_Fog.density * gl_FogFragCoord), 0.0, 1.0));
	} else if (fogMode == GL_LINEAR) {
		gl_FragData[0].rgb = mix(gl_FragData[0].rgb, gl_Fog.color.rgb, clamp((gl_FogFragCoord - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0));
	}*/
  
}

#endif

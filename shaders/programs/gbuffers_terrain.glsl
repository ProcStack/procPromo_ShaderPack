// GBuffer - Terrain GLSL
//   Main hub of most things Minecraft
// Written by Kevin Edzenga, ProcStack; 2022-2024
//

#extension GL_ARB_explicit_attrib_location : enable

#ifdef VSH

#include "utils/shadowCommon.glsl"
const float eyeBrightnessHalflife = 4.0f;

#define SEPARATE_AO

#define ONE_TILE 0.015625
#define THREE_TILES 0.046875

#define PI 3.14159265358979323
#include "/shaders.settings"

uniform sampler2D gcolor;
uniform vec3 sunVec;
uniform int moonPhase;
uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 upPosition;
uniform vec3 cameraPosition;
uniform float far;

uniform mat3 normalMatrix;

uniform int blockEntityId;
uniform vec2 texelSize;
uniform vec3 chunkOffset;

uniform int worldTime;

uniform float dayNight;
uniform ivec2 eyeBrightnessSmooth;
uniform float eyeBrightnessFit;
uniform vec3 shadowLightPosition;

in vec3 mc_Entity;
in vec2 mc_midTexCoord;
in vec3 vaPosition;
in vec3 vaNormal;
in vec4 vaColor;
in vec4 at_tangent; 
in vec2 vaUV0; // texture
in ivec2 vaUV2; // lightmap

//in vec3 at_velocity; // vertex offset to previous frame                

// Glow Pass outs --
out float blockFogInfluence;
out float txGlowThreshold;
// -- -- -- -- -- -- -- --

out vec2 texcoord;
out vec2 texcoordmid;
out vec2 lmcoord;
out vec2 texmidcoord;

out vec4 vtexcoordam; // .st for add, .pq for mul


#ifdef OVERWORLD
  out float skyBrightnessMult;
  out float dayNightMult;
  out float sunPhaseMult;
	out vec4 shadowPos;
#endif


out vec4 vPos;
out vec3 vLocalPos;
out vec4 vWorldPos;
out vec3 vNormal;
out float vNormalSunDot;

out vec4 vColor;
out vec4 vAvgColor;
out float vCrossBlockCull;

out float vAlphaMult;
out float vAlphaRemove;

out vec3 vCamViewVec;
out vec3 vWorldNormal;
out vec3 vAnimFogNormal;

out float vDetailBlurringMult;
out float vMultiTexelMap;

out float vKeepBack;
out float vIsLava;
out float vCdGlow;
out float vDepthAvgColorInf;
out float vFinalCompare;
out float vColorOnly;
out float vDeltaPow;
out float vDeltaMult;


// Having some issues with Iris
//   Putting light texture matrix for compatability
const mat4 LIGHT_TEXTURE_MATRIX = mat4(vec4(0.00390625, 0.0, 0.0, 0.0), vec4(0.0, 0.00390625, 0.0, 0.0), vec4(0.0, 0.0, 0.00390625, 0.0), vec4(0.03125, 0.03125, 0.03125, 1.0));

void main() {
  vec3 normal = normalMatrix * vaNormal;
  vec3 basePos = vaPosition + chunkOffset ;
  vec3 position = mat3(gbufferModelView) * basePos + gbufferModelView[3].xyz;
  vWorldNormal = vaNormal;
  vNormal = normalize(normal);
  vNormalSunDot = dot(normalize(shadowLightPosition), vNormal);
  vAnimFogNormal = normalMatrix*vec3(1.0,0.0,0.0);
  
  vCamViewVec =  normalize((mat3(gbufferModelView) * normalize(vec3(-1.0,0.0,.0)))*vec3(1.0,0.0,1.0));
  
  // -- -- -- -- -- -- -- --

  vLocalPos = basePos;
  vWorldPos = gbufferProjection * vec4(position,1.0);
  gl_Position = ftransform();

  vPos = vec4(position,1.0);
  
  vColor = vaColor;
            
  texcoord = vaUV0;
  
  vec2 midcoord = mc_midTexCoord;
  texcoordmid=midcoord;
  vec2 texelhalfbound = texelSize*16.0;
  
  // -- -- --
  
  float avgBlend = .95;
  
  ivec2 txlOffset = ivec2(2);
  vec3 mixColor;
  vec4 tmpCd;
  float avgDiv = 0.0;
  tmpCd = texture2D(gcolor, midcoord);
    mixColor = tmpCd.rgb;
    avgDiv += tmpCd.a;
  #if (BaseQuality > 1)
  tmpCd = textureOffset(gcolor, midcoord, ivec2(-txlOffset.x, txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  tmpCd = textureOffset(gcolor, midcoord, ivec2(txlOffset.x, -txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  #if (BaseQuality == 2)
  tmpCd = textureOffset(gcolor, midcoord, ivec2(-txlOffset.x, -txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  tmpCd = textureOffset(gcolor, midcoord, ivec2(-txlOffset.x, txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  #endif
  #endif
  //mixColor = mix( vec3(length(vColor.rgb)), mixColor, step(.1, length(mixColor)) );
  mixColor = mix( vec3(vColor.rgb), mixColor, step(.1, mixColor.r+mixColor.g+mixColor.b) );

  vAvgColor = vec4( mixColor, vColor.a); // 1.0);


  lmcoord = vaUV0;//vec2(vaUV2);

  lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

  // Get atlas shift & limits for detail blurring
  vec2 texcoordminusmid = texcoord.xy-midcoord;
  texmidcoord = midcoord;
  vtexcoordam.pq = abs(texcoordminusmid)*2.0;
  vtexcoordam.st = min(texcoord.xy ,midcoord-texcoordminusmid);


  // -- -- -- -- -- -- -- --
	
	
#ifdef OVERWORLD
  
  // Shadow Prep --
	// Invert vert  modelVert positions 
  float depth = min(1.0, length(position.xyz)*.1 );
  vec3 shadowPosition = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;
  //shadowPosition = basePos.xyz;
  
  //float shadowPushAmmount =  (depth*.5 + 0.9-abs(dayNight)*0.85) ;
  float shadowPushAmmount =  (depth*.5 + .010 ) ;
  shadowPushAmmount *=  min( 1.0, max(abs(vWorldNormal.x), max(vWorldNormal.y, abs(vWorldNormal.z) )));
  //shadowPushAmmount *= (1.0-skyBrightnessMult*.5) );
  vec3 shadowPush = vWorldNormal*shadowPushAmmount ;
  
  shadowPos.xyz = mat3(shadowModelView) * (shadowPosition.xyz+shadowPush) + shadowModelView[3].xyz;
  vec3 shadowProjDiag = diagonal3(shadowProjection);
  shadowPos.xyz = (shadowProjDiag * shadowPos.xyz + shadowProjection[3].xyz);
  shadowPos.w = 1.0;

  #if ( DebugView == 3 ) // Debug Vision : Shadow Debug
		// Verts push out on the left side of the screen
    //   Showing how far its sampling for the shadow base value
    position = mat3(gbufferModelView) * (shadowPosition.xyz+shadowPush*clamp(1.0-position.x,0.0,1.0)) + gbufferModelView[3].xyz;
  #endif


	// Sun Moon Influence
	skyBrightnessMult = 1.0;
	dayNightMult = 0.0;
	sunPhaseMult = 1.0;

	// Sky Influence
	//   TODO : Move to 
	//skyBrightnessMult=eyeBrightnessSmooth.y * 0.004166666666666666; //  1.0/240.0
	skyBrightnessMult=eyeBrightnessFit;
	
	// Sun Influence
	sunPhaseMult = 1.0-max(0.0,dayNight);
	//sunPhaseMult = 1.0-(sunPhaseMult*sunPhaseMult*sunPhaseMult);
	
	
	// Moon Influence
	float moonPhaseMult = min(1.0,float(mod(moonPhase+4,8))*.125);
	//moonPhaseMult = moonPhaseMult;// - max(0.0, moonPhaseMult-0.50)*2.0;
	moonPhaseMult = moonPhaseMult*.18 + .018; // Moon's shadowing multiplier

	dayNightMult = mix( 1.0, moonPhaseMult, sunPhaseMult);
  
#endif
  
  
  //gl_Position = toClipSpace3(gbufferProjection, position);
  //gl_Position = ftransform();
  //gl_Position = gbufferProjection * vec4( position, 1.0);
  
  
  
  // -- -- -- -- -- -- -- --
  
  
  
  vAlphaMult=1.0;
  vIsLava=0.0;
  vCdGlow=0.0;
  vCrossBlockCull=0.0;
  vColorOnly=0.0;
  vFinalCompare = mc_Entity.x == 811 ? 0.0 : 1.0;
  vFinalCompare = mc_Entity.x == 901 ? 0.0 : vFinalCompare;
  vKeepBack = mc_Entity.x == 301 ? 1.0 : 0.0;

  blockFogInfluence = 1.0;
  if (mc_Entity.x == 803){
    blockFogInfluence = 1.;
  }
  
  txGlowThreshold = 1.0; // Off
  if (mc_Entity.x == 804){
    txGlowThreshold = 1.00;//.7;
    blockFogInfluence = 1.0;
  }

  // Single plane cross blocks;
  //   Grass, flowers, etc.
  //vCamViewVec=vec3(0.0);
    /*
  if (mc_Entity.x == 801){
  
    //vCrossBlockCull = abs(dot(vec3(vWorldNormal.x, 0.0, vWorldNormal.z),normalize(vec3(vPos.x, 0.0, vPos.z)) ));
    vCrossBlockCull = abs(dot(vec3(vWorldNormal.x, 0.0, vWorldNormal.z),normalize(vec3(1.0, 0.0, 1.0)) ));
    //vCrossBlockCull = abs( dot( normalize(vLocalPos.xyz), normalize(vec3(1.0, 0.0, 1.0)) ) );
    vCrossBlockCull = abs( dot( normalize(vec3(vWorldNormal.x, 0.0, vWorldNormal.z)), normalize(vec3(vLocalPos.x, 0.0, vLocalPos.z)) ) );
    //vCrossBlockCull =  dot( normalize(vLocalPos.xyz), normalize(vec3(1.0, 0.0, 1.0)) )*.5+.5;
    
    //vAlphaMult=clamp( (vCrossBlockCull+.5)*10.0, 0.0, 1.0 );
    //vAlphaMult=step(.5, vCrossBlockCull);
    
    float alphaStep = abs(vCrossBlockCull-.5)-.2;

    vCrossBlockCull=step( .0, alphaStep );
    float blerg = abs(dot(vec3(vWorldNormal.x, 0.0, vWorldNormal.z),vec3(0.707107,0.0,0.707107) ));
    blerg = step(.5, abs(dot(vec3(vCamViewVec.x, 0.0, vCamViewVec.z),vec3(0.707107,0.0,0.707107) )) );
    //blerg = normalize(vec3(vPos.x, 0.0, vPos.z));
    //blerg = dot( normalize((cameraPosition - gbufferModelView[3].xyz)*vec3(1.0,0.0,1.0)), vec3(0.707107,0.0,0.707107) );
    //vCrossBlockCull=blerg;
    //vCamViewVec = normalize( basePos.xyz );
    //vCamViewVec = normalize((gbufferProjection[3].xyz)*vec3(1.0,0.0,1.0));
  vec3 crossNorm = abs(normalize((vWorldNormal.xyz)*vec3(1.0,0.0,1.0)));
  //vCamViewVec = normalize((vCamViewVec.xyz)*vec3(1.0,0.0,1.0));
  //vCamViewVec = vec3( abs(dot(vCamViewVec,crossNorm)) );
  //  vCamViewVec = vec3( abs(dot(vCamViewVec,crossNorm)) );
    vCamViewVec = vec3( abs(dot(vCamViewVec,crossNorm)) );
    vCamViewVec = cross(vCamViewVec,crossNorm);
    vCamViewVec = vec3( abs(dot( cross(vCamViewVec,crossNorm), vec3(0.707107,0.0,0.707107) )) );
    //vCamViewVec = vec3( step(.5, abs(dot(vec3(vNormal.x, 0.0, vCamViewVec.z),vec3(0.707107,0.0,0.707107) )) ) );
    
//    normalMatrix * vaNormal;
    vCamViewVec = vec3( dot( normalMatrix* vaNormal, vaNormal ) );
    //vCrossBlockCull=step( .5, vCrossBlockCull );
    
    
    
  //position = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;
    
    vCamViewVec = mat3(gbufferModelViewInverse) * vec3(0.0,0.0,1.0) + gbufferModelViewInverse[3].xyz;
    vCamViewVec = inverse(normalMatrix) * normalize( vCamViewVec*vec3(1.0,0.0,1.0) );
    vec4 refPos = (gbufferProjectionInverse * gbufferModelViewInverse * basePos)*.5;

    vec3 crossRefVec = normalize( ( vWorldPos.xyz, refPos.xyz )*vec3(1.0,0.0,1.0) );
    vec3 wNormRefVec = normalize( vWorldNormal*vec3(1.0,0.0,1.0) );
    //vCrossBlockCull = 1.0-abs(dot( crossRefVec, wNormRefVec ));
    //vCamViewVec = vec3( step( vCrossBlockCull, .5 ) );
    vCamViewVec = mat3(gbufferModelViewInverse) * vaNormal;
    vCamViewVec = mat3(gbufferProjection) * vaNormal;
    //vCamViewVec = vaNormal;
    //vAlphaMult=vCrossBlockCull;
  }
  */
  
  // Leaves
  vAlphaRemove = 0.0;
  if((mc_Entity.x == 810 || mc_Entity.x == 8101) && SolidLeaves ){
    vAvgColor = mc_Entity.x == 810 ? vColor * (vAvgColor.g*.5+.5) : vAvgColor;
    vColor = mc_Entity.x == 8101 ? vAvgColor : vColor;
    
    
    vAlphaRemove = 1.0;
    //shadowPos.w = -2.0;
  }


  // General Alt Texture Reads
  vDepthAvgColorInf = 1.0;


  if( mc_Entity.x == 801 ||  mc_Entity.x == 811  || mc_Entity.x == 8014 ){
    vColorOnly = mc_Entity.x == 801 ? 0.85 : 0.0;
    //vColorOnly = mc_Entity.x == 811 ? vColor.b*.5 : vColorOnly;
    vAvgColor*=vColor;
    vDepthAvgColorInf=vColor.r;
  }

  if( mc_Entity.x == 802 ){
    vAvgColor*=vColor;
    vDepthAvgColorInf=0.0;
  }
  // Slab & Stairs with detail blending UV issues
  //if( mc_Entity.x == 812 ){
  //}
  
  // Ore Detail Blending Mitigation
  vDeltaPow=1.8;
  vDeltaMult=3.0;
  if( mc_Entity.x == 8012 ){
    vDeltaPow=.80;
  }
  if( mc_Entity.x == 8013 ){
    vDeltaPow=0.90;
		vAvgColor+=vec4(0.1,0.1,0.12,0.0);
  }
  if( mc_Entity.x == 9011 ){
    vDeltaPow=4.0;
    vDeltaMult=1.10;
  }

  
  
  
  // Lava
  if( mc_Entity.x == 701 ){
    vIsLava=0.85;
    vCdGlow=.08;
#ifdef NETHER
    vCdGlow=.1;
    vIsLava=0.7;
#endif
    vColor.rgb = mix( vAvgColor.rgb, texture2D(gcolor, midcoord).rgb, .5 );
  }
  // Flowing Lava
  if( mc_Entity.x == 702 ){
    vIsLava=0.85;
    vCdGlow=0.15;
#ifdef NETHER
    vIsLava=0.75;
    vCdGlow=0.095;
#endif
    vColor.rgb = mix( vAvgColor.rgb, texture2D(gcolor, midcoord).rgb, .5 );
  }
  
  // Fire / Soul Fire
  if( mc_Entity.x == 707 ){
    vCdGlow=0.02;
    vColor+=vColor*.15;
#ifdef NETHER
    vCdGlow=0.012;
#endif
    //vAvgColor = vec4( .8, .6, .0, 1.0 );
    
    //vDepthAvgColorInf =  0.0;
  }
  // End Rod, Soul Lantern, Glowstone, Redstone Lamp, Sea Lantern, Shroomlight, Magma Block
  if( mc_Entity.x == 805 ){
    vCdGlow=0.025;
#ifdef NETHER
    vCdGlow=0.03;
#endif
    //vDepthAvgColorInf = 0.20;
  }
  if( mc_Entity.x == 8051 ){
    vCdGlow=0.015;
#ifdef NETHER
    vCdGlow=0.035;
#endif
    //vDepthAvgColorInf = 0.20;
  }
  
  if( mc_Entity.x == 8052 ){
    vCdGlow=0.01;
    vAvgColor = vColor;
  }

  // Amethyst Block
  if (mc_Entity.x == 909){
    vCdGlow = 0.1;
    vAvgColor.rgb = vec3(.35,.15,.7);
    //vColor.rgb = mix( vAvgColor.rgb, texture2D(gcolor, midcoord).rgb, .7 );
  }
  // Amethyst Clusters
  if (mc_Entity.x == 910){
    vCdGlow = 0.1;
    //vColor.rgb = vAvgColor.rgb;//mix( vAvgColor.rgb, texture2D(gcolor, midcoord).rgb, .5 );
  }

}

#endif




/* */
/* */
/* */



#ifdef FSH


#define gbuffers_terrain

/* RENDERTARGETS: 0,1,2,7,6,9 */
layout(Location = 0) out vec4 outCd;
layout(Location = 1) out vec4 outDepthGlow;
layout(Location = 2) out vec4 outNormal;
layout(Location = 3) out vec4 outLighting;
layout(Location = 4) out vec4 outGlow;
layout(Location = 5) out vec4 outNull;


/* --
const int gcolorFormat = RGBA8;
const int gdepthFormat = RGBA16;
const int gnormalFormat = RGB10_A2;
 -- */

#include "/shaders.settings"
#include "utils/shadowCommon.glsl"
#include "utils/mathFuncs.glsl"
#include "utils/texSamplers.glsl"



uniform sampler2D gcolor;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D noisetex; // Custom Texture; textures/SoftNoise_1k.jpg
uniform int fogMode;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform vec3 sunVec;
uniform vec3 cameraPosition;
uniform int isEyeInWater;
uniform float BiomeTemp;
uniform float nightVision;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;


uniform float viewWidth;
uniform float viewHeight;

uniform float near;
uniform float far;
uniform sampler2D gaux1;
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform int shadowQuality;

uniform vec2 texelSize;
uniform float aspectRatio;

uniform int worldTime;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

// To Implement
//uniform float wetness;  //rainStrength smoothed with wetnessHalfLife or drynessHalfLife
//uniform int fogMode;
//fogMode==GL_LINEAR
//fogMode==GL_EXP
//fogMode==GL_EXP2
uniform float fogStart;
uniform float fogEnd;
//uniform int fogShape;
uniform float fogDensity;
//uniform int heldBlockLightValue;
//uniform int heldBlockLightValue2;
uniform float rainStrength;


uniform vec3 upPosition;

// Glow Pass Varyings --
in float blockFogInfluence;
in float txGlowThreshold;
// -- -- -- -- -- -- -- --

in vec4 vColor;
in vec2 texcoord;
in vec2 texcoordmid;
in vec2 lmcoord;

in vec2 texmidcoord;
in vec4 vtexcoordam; // .st for add, .pq for mul


#ifdef OVERWORLD
  in float skyBrightnessMult;
  in float dayNightMult;
  in float sunPhaseMult;
	in vec4 shadowPos;
#endif

uniform vec3 shadowLightPosition;
uniform float dayNight;
uniform float sunMoonShadowInf;

in float vAlphaMult;
in float vAlphaRemove;
in float vColorOnly;

in vec3 vCamViewVec;
in vec4 vPos;
in vec3 vLocalPos;
in vec4 vWorldPos;
in vec3 vNormal;
in vec3 vWorldNormal;
in float vNormalSunDot;
in vec3 vAnimFogNormal;

in vec4 vAvgColor;
in float vCrossBlockCull;

in float vKeepBack;
in float vIsLava;
in float vCdGlow;
in float vDepthAvgColorInf;
in float vFinalCompare;
in float vDeltaPow;
in float vDeltaMult;

void main() {
  
    vec2 tuv = texcoord;
		vec4 baseTxCd=texture2D(gcolor, tuv);
		
		// TODO : Remove need for 'txCd' variable
    vec4 txCd=vec4(1.0,1.0,0.0,1.0);

    vec2 screenSpace = (vPos.xy/vPos.z)  * vec2(aspectRatio);

    vec2 luv = lmcoord;
    float outDepth = min(.9999,gl_FragCoord.w);
    float isLava = vIsLava;
    vec4 avgShading = vAvgColor;
    float avgDelta = 0.0;

    // -- -- -- -- -- -- --
    
    vec4 baseCd=baseTxCd;
		
		
		// Alpha Test
		baseTxCd.a = max(baseTxCd.a, vAlphaRemove) * vColor.a ;

    #if( DebugView == 4 )
      baseTxCd.a = mix(baseTxCd.a, 1.0, step(screenSpace.x,.0)*vAlphaRemove);
    #else
      baseTxCd.a = mix(baseTxCd.a, 1.0, vAlphaRemove) * vAlphaMult;
    #endif
		
    if ( baseTxCd.a < .02 ){
      discard;
    }
		
	
    // -- -- -- -- -- -- --
    
		// Texture Sampler
    
    // TODO : There's gotta be a better way to do this...
    //          - There is, just gotta change it over
    if ( DetailBlurring > 0.0 ){
      //txCd = diffuseSample( gcolor, tuv, vtexcoordam, texelSize, DetailBlurring*2.0 );
      
      // Split Screen "Blur Comparison" Debug View
      #if ( DebugView == 1 )
        float debugDetailBlurring = clamp((screenSpace.y/(aspectRatio*.8))*.5+.5,0.0,1.0)*2.0;
        //debugDetailBlurring *= debugDetailBlurring;
        debugDetailBlurring = mix( DetailBlurring, debugDetailBlurring, step(screenSpace.x,0.75));
        diffuseSampleXYZ( gcolor, tuv, vtexcoordam, texelSize, debugDetailBlurring, baseCd, txCd, avgDelta );
      #else
        //diffuseSampleXYZ( gcolor, tuv, vtexcoordam, texelSize, DetailBlurring, baseCd, txCd, avgDelta);
        diffuseSampleXYZFetch( gcolor, tuv, texcoordmid, texelSize, DetailBlurring, baseCd, txCd, avgDelta);
      #endif
      
    }else{
      txCd = texture2D(gcolor, tuv);
    }

    

    
    
    
    // Default Minecraft Lighting
    vec4 lightLumaCd = texture2D(lightmap, luv);//*.9+.1;
    float lightLumaBase = lightLumaCd.r;//*.9+.1;
    
    txCd.rgb = mix(baseCd.rgb, txCd.rgb, avgDelta);
    
    txCd.rgb = mix(txCd.rgb, vColor.rgb, vAlphaRemove);
    
    
    
    float glowInf = 0.0;
    vec3 glowCd = vec3(0,0,0);
    glowCd = txCd.rgb*vCdGlow;// * max(0.0, luma(txCd.rgb));
    glowInf = max(0.0, maxComponent(txCd.rgb)*1.5-0.9)*vCdGlow;
    
    
    // Screen Space UVing and Depth
    // TODO : Its a block game.... move the screen space stuff to vert stage
    //          Vert interpolation is good enough
    float screenDewarp = length(screenSpace)*0.7071067811865475; //  1 / length(vec2(1.0,1.0))
    screenDewarp*=screenDewarp*.7+.3;
    float depth = min(1.0, max(0.0, gl_FragCoord.w+glowInf));
    float depthBias = biasToOne(depth, 7.5);
    float depthDetailing = clamp(1.035-depthBias, 0.0, 1.0);

    // Side by side of active blurring and no blurring
    //   Other shader effects still applied though
    #if ( DebugView == 1 )
      txCd = mix( texture2D(gcolor, tuv), txCd, step(0.0, screenSpace.x+.75) );
    #endif

  // -- -- -- -- -- -- -- --
  
    // Use Light Map Data
    //float lightLuma = clamp((lightLumaBase-.265) * 1.360544217687075, 0.0, 1.0); // lightCd.r;
    float lightLuma = shiftBlackLevels( lightLumaBase ); // lightCd.r;

    vec3 lightCd = vec3(lightLuma);
    
  // -- -- -- -- -- -- -- --

    outCd = vec4(txCd.rgb,1.0) * vec4(vColor.rgb,1.0);

    vec3 outCdAvgRef = outCd.rgb;
    vec3 cdToAvgDelta = outCdAvgRef.rgb - txCd.rgb; // Strong color changes, ie birch black bark markings
    float cdToAvgBlender = min(1.0, addComponents( cdToAvgDelta ));
    //outCd.rgb = mix( outCd.rgb, txCd.rgb, max(0.0,cdToAvgBlender-depthBias*.5)*vFinalCompare );
    
    float avgColorBlender = min(1.0, pow(length(txCd.rgb-vAvgColor.rgb),vDeltaPow+lightLuma*.75)*vDeltaMult*depthBias);
    outCd.rgb =  mix( vAvgColor.rgb, outCd.rgb, avgColorBlender );


    // -- -- -- -- -- -- -- -- -- -- -- --
    // -- Apply Shading To Base Color - -- --
    // -- -- -- -- -- -- -- -- -- -- -- -- -- --
    float avgColorMix = depthDetailing*vDepthAvgColorInf;
    avgColorMix = min(1.0, avgColorMix + vAlphaRemove + vIsLava*3.0);
    outCd = mix( vec4(outCd.rgb,1.0),  vec4(avgShading.rgb,1.0), min(1.0,avgColorMix+vColorOnly));


  // -- -- -- -- -- -- -- --
  // Based on shadow lookup from Chocapic13's HighPerformance Toaster
  //
  float shadowDist = 0.0;
  float diffuseSun = 1.0;
  float shadowAvg = 1.0;
  vec4 shadowCd = vec4(0.0);
  float shadowDepth = 0.0;
  
  float toCamNormalDot = dot(normalize(-vPos.xyz*vec3(1.3,1.35,1.3)),vNormal)+.2;
  float surfaceShading = 9.0-abs(toCamNormalDot);

  float fogColorBlend = 1.0;
  
  
    // -- -- -- -- -- -- -- -- -- -- -- --
    // -- Shadow Sampling & Influence - -- --
    // -- -- -- -- -- -- -- -- -- -- -- -- -- --
#ifdef OVERWORLD
#if ShadowSampleCount > 0

  //vec4 shadowProjOffset = vec4( fitShadowOffset( cameraPosition ), 0.0);

  vec3 localShadowOffset = shadowPosOffset;
  localShadowOffset.z *= (skyBrightnessMult*.5+.5);
  //localShadowOffset.z *= min(1.0,outDepth*20.0+.7)*.1+.9;
  localShadowOffset.z = 0.5 - min( 1.0, (shadowThreshBase + shadowThreshDist*(1.0-depthBias)) * shadowThreshold );
  
  vec4 shadowPosLocal = shadowPos;
  //shadowPosLocal.xy += vCamViewVec.xz;
  
// Implement --	
//  vWorldNormal.y*(1.0-shadowData.b)

	// 
  shadowPosLocal = distortShadowShift( shadowPosLocal );
  vec3 projectedShadowPosition = shadowPosLocal.xyz * shadowPosMult + localShadowOffset;
  
	// Get base shadow value
  float shadowBase=shadow2D(shadowtex0, projectedShadowPosition).x; 
	shadowAvg = shadowBase ;
	
	// Get base shadow source block color
  shadowCd=texture2D(shadowcolor0, projectedShadowPosition.xy); 
	
	// Get shadow source distance
	// Delta of frag shadow distance * shadowDistBiasMult
	vec3 shadowData = texture2D(shadowcolor1, projectedShadowPosition.xy).rgg;
	shadowData.b = ( shadowData.g - length(shadowPosLocal.xyz) ) * shadowDistBiasMult;
	
	shadowCd.rgb = mix( vec3(0.0), shadowCd.rgb, shadowData.r ); 
	
  shadowDepth = min(10.0,  shadowData.b + .50 )*4.0;




#if ShadowSampleCount == 2
  vec2 posOffset;
  //float reachMult = shadowDepth;// - (min(1.0,outDepth*20.0)*.5);
  float reachMult = max(0.0, shadowDepth - (min(1.0,outDepth*20.0)*.5));
  
  for( int x=0; x<axisSamplesCount; ++x){
    posOffset = axisSamples[x]*reachMult*.00038828125*skyBrightnessMult;
    projectedShadowPosition = vec3(shadowPosLocal.xy+posOffset,shadowPosLocal.z) * shadowPosMult + localShadowOffset;
  
    shadowAvg = mix( shadowAvg, shadow2D(shadowtex0, projectedShadowPosition).x, .25);
		
    posOffset = axisSamples[x]*reachMult*.00038828125*skyBrightnessMult;
    projectedShadowPosition = vec3(shadowPosLocal.xy+posOffset,shadowPosLocal.z) * shadowPosMult + localShadowOffset;
  
    shadowAvg = mix( shadowAvg, shadow2D(shadowtex0, projectedShadowPosition).x, .25);
  }
#elif ShadowSampleCount > 2
  vec2 posOffset;
  float reachMult = shadowDepth;// - (min(1.0,outDepth*20.0)*.5);
  //float reachMult = max(0.0, shadowDepth - (min(1.0,outDepth*20.0)*.5));
  
  for( int x=0; x<axisSamplesCount; ++x){
		// Box Diagnals
    posOffset = boxSamples[x]*reachMult*.00038828125;
    projectedShadowPosition = vec3(shadowPosLocal.xy+posOffset,shadowPosLocal.z) * shadowPosMult + localShadowOffset;
    shadowAvg = mix( shadowAvg, shadow2D(shadowtex0, projectedShadowPosition).x, .35);
		
		// Box Axes
    posOffset = boxSamples[x+4]*reachMult*.00028828125;
    projectedShadowPosition = vec3(shadowPosLocal.xy+posOffset,shadowPosLocal.z) * shadowPosMult + localShadowOffset;
    shadowAvg = mix( shadowAvg, shadow2D(shadowtex0, projectedShadowPosition).x, .35);
  }
#endif

  
  float shadowDepthInf = clamp( (depth*distancDarkenMult), 0.0, 1.0 );
  shadowDepthInf *= shadowDepthInf;
	
	// Verts not facing the sun should never have non-1.0 shadow values
	//shadowCd.rgb = mix( vec3(1.0), shadowCd.rgb, min(1.0,step(-.01,vNormalSunDot)*shadowDepthInf));
	shadowCd.rgb = mix( vec3(1.0), shadowCd.rgb, step(-.01,vNormalSunDot));

  // Distance Rolloff
  shadowAvg = shadowAvg + min(1.0, (length(vLocalPos.xz)*.0025)*1.5);
  
	// Tighten Shadow, reducing aliasing, sharper shadows
	//shadowAvg = clamp((shadowAvg*1.2),0.0,1.0);
  
  float shadowInfFit = 0.025;
  float shadowInfFitInv = 40.0;// 1.0/shadowInfFit;
  //float shadowSurfaceInf = step(-0.005,dot(normalize(shadowLightPosition), vNormal));
  float shadowSurfaceInf = min(1.0, max(0.0,(shadowInfFit-(-dot(normalize(shadowLightPosition), vNormal)))*shadowInfFitInv )*1.5);
  
  
  // -- -- --
  //  Distance influence of surface shading --
  shadowAvg = mix( (shadowAvg*shadowSurfaceInf), min(shadowAvg,shadowSurfaceInf), shadowAvg)*skyBrightnessMult * (1-rainStrength) * dayNightMult;
  //shadowAvg = mix( (shadowAvg*shadowSurfaceInf), min(shadowAvg,shadowSurfaceInf), shadowAvg)*skyBrightnessMult * dayNightMult;
  // -- -- --
  // TODO : Needed?  Depth based shadowings
  //diffuseSun *= mix( 0.0, shadowAvg, sunMoonShadowInf * shadowDepthInf * shadowSurfaceInf );
  //diffuseSun *= mix( shadowDepthInf, shadowAvg, sunMoonShadowInf * shadowSurfaceInf );
  //diffuseSun *= mix( max(0.0,shadowDepthInf-rainStrength), shadowAvg, sunMoonShadowInf * shadowSurfaceInf );
  diffuseSun *= mix( max(0.0,shadowDepthInf-rainStrength), shadowAvg, sunMoonShadowInf  );

#endif


  // -- -- -- -- -- -- -- --
  // -- Lighting & Diffuse - --
  // -- -- -- -- -- -- -- -- -- --
    
  // Mute Shadows during Rain
  diffuseSun = mix( diffuseSun, 0.50, rainStrength);          
  
  lightCd = max( lightCd, diffuseSun);
	// Mix translucent color
	lightCd = mix( lightCd, lightCd*(shadowCd.rgb*.5+.85), clamp(shadowData.r*(1.0-shadowBase)
	                                      //* max(0.0,shadowDepthInf*2.0-1.0)
																				- shadowData.b*2.0, 0.0, 1.0) );
	lightLuma = min( maxComponent(lightCd), lightLuma );

  // Strength of final shadow
  outCd.rgb *= mix(max(vec3(shadowAvg),lightCd*.7), vec3(1.0),shadowAvg);
	//outCd.rgb = mix(lightCd*shadowAvg, outCd.rgb, shadowCd.a);
	

  fogColorBlend = skyBrightnessMult;
  
  lightCd = mix( lightCd, max(lightCd, vec3(shadowAvg)), shadowAvg) ;
  


  surfaceShading *= mix( dayNightMult, vNormalSunDot, sunMoonShadowInf*.5+.5 );
    
#endif
    
  // -- -- -- -- -- -- --
  // -- Fake Fresnel - -- --
  // -- -- -- -- -- -- -- -- --
    float dotToCam = dot(vNormal,normalize(vec3(screenSpace*(1.0-depthBias*.5),1.0)));
    outCd*=mix(1.0, dotToCam*.3+.7, vIsLava*.5);
    
    
  // Apply Black Level Shift from User Settings
  //   Since those set to 0 would be rather low,
  //     Default is to run black shift with no check.
    lightCd = shiftBlackLevels( lightCd );
    surfaceShading = max( surfaceShading, lightCd.r );
    surfaceShading = shiftBlackLevels( surfaceShading );
    
  // -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
  // -- 'Specular' Roll-Off; Radial Highlights -- --
  // -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    
    depthDetailing = max(0.0, min(1.0,(1.0-(depthBias+(vCdGlow*1.0)))*distantVibrance) ); 
    //surfaceShading = 1.0-(1.0-surfaceShading)*.4;
    
    outCd.rgb += outCd.rgb * depthBias * surfaceShading * depthDetailing  *fogColor; // -.2;

  // -- -- -- -- -- -- 


  // -- -- -- -- -- -- -- -- --
  // -- Lighting influence - -- --
  // -- -- -- -- -- -- -- -- -- -- --
    //outCd.rgb *=  lightCd.rgb + glowInf;// + vCdGlow;

  // Used for correcting blended colors post environment influences
  // This shouldn't be needed, but blocks like Grass or Birch Log/Wood are persnickety
    //vec3 avgCdRef = vAvgColor.rgb * (lightCd.rgb + glowInf + vCdGlow);

  // -- -- -- -- -- -- --
  // -- Fog Coloring - -- --
  // -- -- -- -- -- -- -- -- --
    vec3 toFogColor = mix( skyColor*.5+outCd.rgb*.5, fogColor, depth);
    toFogColor = mix( vec3(1.0), toFogColor, fogColorBlend);

  // -- -- -- -- -- -- --
  // -- Night Vision - -- --
  // -- -- -- -- -- -- -- -- --
  // TODO : Rework Night Vision & Darkness
    toFogColor = mix(toFogColor, vec3(1.0), nightVision);
    

    // TODO : Move whats possible to vert
    float waterLavaSnow = float(isEyeInWater);
    if( isEyeInWater == 1 ){ // Water
      float smoothDepth=min(1.0, smoothstep(.01,.1,depth));
      //outCd.rgb *=  1.0+lightLuma+glowInf;
      outCd.rgb *=  toFogColor*(.8+lightLuma*lightLuma*.3);//+.5;
    }else if( isEyeInWater > 1 ){ // Lava
      depthBias = depthBias*.1; // depth;
      depth *= .5;
      
      outCd.rgb = mix( outCd.rgb, toFogColor, (1.0-outDepth*.01) );
    //}else if( isEyeInWater == 3 ){ // Snow
      //outCd.rgb = mix( outCd.rgb, toFogColor, (1.0-outDepth*.1) );
    }else{
      float fogFit = min(1.0,depth*100.0)*.8+.2;
      outCd.rgb = mix( (outCd.rgb*.5+.5)*toFogColor, outCd.rgb, fogFit+glowInf );
    }

    
    
// -- -- -- -- -- -- -- -- -- -- 
// End Logic; Animated Fog  - -- --
// -- -- -- -- -- -- -- -- -- -- -- --

// TODO : MOVE TO POST PROCESSING ... ya dingus

    
#ifdef THE_END
    
      float depthEnd = max(0.0, min(1.0, outDepth*6.0-screenDewarp*.025));
      depthEnd = depthEnd*.4+.6;
      //depthEnd = 1.0-(1.0-depthEnd)*(1.0-depthEnd);
      
  // Fit lighting 0-1
      float lightShift=.47441;
      float lightShiftMult=1.9026237181072698; // 1.0/(1.0-lightShift)
      float lightInf = min(1.0, (max((lightCd.r-.35)*1.2,lightLumaBase)-lightShift)*lightShiftMult + depthEnd*.4);
      
      vec3 endFogCd = fogColor+vec3(.3,.25,.3);
      float timeOffset = (float(worldTime)*0.00004166666)*(30.0);
      vec3 worldPos = (abs(cameraPosition+vLocalPos.xyz)*vec3(.09,.06,.05)*.01);
      worldPos = ( worldPos+texture2D( noisetex, fract(worldPos.xz+worldPos.yy)).rgb );

  // RGB Depth Based Noise for final influence
      vec3 noiseX = texture2D( noisetex, worldPos.xy*depthEnd + (timeOffset*vec2(.1,.5))).rgb;
      //vec3 noiseZ = texture2D( noisetex, fract(worldPos.yz+noiseX.rg*.1 + vec2(timeOffset) )).rgb;
      
      float noiseInf = min(1.0, (depthEnd+max(0.0,(lightInf*depthEnd-.4)+glowInf*.8))*depthEnd );
      
      outCd.rgb *= mix(  mix((noiseX*endFogCd*lightCd),endFogCd,noiseInf+depthEnd*.3), vec3(lightInf), noiseInf );
      //outCd.rgb=lightCd.rgb;//vAvgColor.rgb*lightInf;
      //outCd.rgb=noiseX;//vAvgColor.rgb*lightInf;
      
#endif
    
    
    //if( glowMultVertColor > 0.0 ){
      //float outCdMin = min(outCd.r, min( outCd.g, outCd.b ) );
      float outCdMin = max(outCd.r, max( outCd.g, outCd.b ) );
      //float outCdMin = max(txCd.r, max( txCd.g, txCd.b ) );
      glowCd = addToGlowPass(glowCd, mix(txCd.rgb,outCd.rgb,.5)*step(txGlowThreshold,outCdMin)*(depth*.8+.2));
    //}
    
    
    
    glowInf += (luma(outCd.rgb)+vIsLava)*vCdGlow;

#ifdef NETHER
    //outCd.rgb *= mix( outCd.rgb+outCd.rgb*vec3(1.6,1.3,1.2), vec3(1.0), (depthBias)*.4+.4);
    //outCd.rgb = mix( fogColor*(lightCd+.5), outCd.rgb*lightCd, smoothstep(.015, .35, depthBias+glowInf*.5));
    outCd.rgb = mix( fogColor*(lightCd+.5), outCd.rgb*lightCd, lightCd.r);
    outCd.rgb *= mix(1.0, toCamNormalDot, depth*.7+.3);
#else
    // Block Surface Rolloff
    outCd.rgb *= mix(toFogColor.rgb, vec3(toCamNormalDot*.45+.55), min(1.0,depth*.5+.5+lightCd.r));
#endif


    
    
#ifdef OVERWORLD
// -- -- -- -- -- -- -- -- -- -- -- -- -- --
// Biome & Snow Glow when in a Cold Biome - -- --
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    float frozenSnowGlow = 1.0-smoothstep(.0,.2,BiomeTemp);
    glowCd = addToGlowPass(glowCd, outCd.rgb*frozenSnowGlow*.5*(1.0-sunPhaseMult)*max(0.06,-sunMoonShadowInf)*max(0.0,(1.0-depth*3.0)));

    outCd.rgb *= 1.0+frozenSnowGlow*max(0.06,-sunMoonShadowInf*.1)*(1.0-rainStrength);//*skyBrightnessMult;
    
    
// -- -- -- -- -- -- -- -- -- -- -- 
// Outdoors vs Caving Lighting - -- --
// -- -- -- -- -- -- -- -- -- -- -- -- --
// Brighten blocks when going spelunking
// TODO: Promote control to Shader Options
    float skyBrightMultFit = min(1.0, 1.0-skyBrightnessMult*.1*(1.0-frozenSnowGlow) );
    outCd.rgb *= skyBrightMultFit;
      
    outCd.rgb*=mix(vec3(1.0), lightCd.rgb, min(1.0,  sunPhaseMult*skyBrightnessMult));
    
#endif
    
    glowCd += outCd.rgb+(outCd.rgb+.1)*glowInf;

    vec3 glowHSV = rgb2hsv(glowCd);
    glowHSV.z *= glowInf * (depthBias*.6+.5) * GlowBrightness;


#ifdef NETHER
    outCd.rgb = clamp( outCd.rgb*(1.0+0.2*lightCd), vec3(0.0), vec3(1.0));
#else
    glowHSV.z *= .7+vIsLava*.5;
#endif

    outCd.rgb*=1.0+glowHSV.z;


    // -- -- -- -- -- -- -- -- -- -- 
    // -- Lava & Powda Snow Fog - -- --
    // -- -- -- -- -- -- -- -- -- -- -- --
    float lavaSnowFogInf = 1.0-min(1.0, max(0.0,waterLavaSnow-1.0) );
    glowHSV.z *= lavaSnowFogInf;
    outCd.rgb = mix( fogColor.rgb, outCd.rgb, lavaSnowFogInf);

    
    // -- -- -- -- -- -- -- -- -- -- -- -- --
    // -- Texture Overides from Settings - -- --
    // -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    if( WorldColor ){ // Greyscale
      outCd.rgb = luma(vAvgColor.rgb) * vec3(mix(lightCd.r*.9, 1.0, shadowAvg));
      glowHSV.y = 0.0;
      glowHSV.z *= 0.80;
    }
    
    float outEffectGlow = 0.0;
    
    
		// TODO : Dupelicate? Or actually doing something?
    //outCd.a*=vAlphaMult;
    
    
    vec3 outCdHSV = rgb2hsv(outCd.rgb);
    vec3 avgCdHSV = rgb2hsv(vAvgColor.rgb);
    outCd.rgb = hsv2rgb( vec3(mix(avgCdHSV.r,outCdHSV.r,vFinalCompare*step(.25,luma(vAvgColor.rgb))), outCdHSV.gb) );
    
// Boost bright colors morso
    boostPeaks(outCd.rgb);
    
   
   
    if( GlowBrightness>0.0 ){
      float ambientGlow = length(outCd.rgb) * (1.1 + GlowBrightness*.15) * .5;
      ambientGlow = ambientGlow*ambientGlow;
      glowHSV.z = min( glowHSV.z, ambientGlow ) * vCdGlow;
    }
  
    #if ( DebugView == 1 )
      outCd.rgb=mix( outCd.rgb, vec3((screenSpace.y/(aspectRatio*.8))*.5+.5), step(abs(screenSpace.x+.75), .05));
      outCd.rgb = mix( outCd.rgb, vec3(1.0,0.0,0.0), step( 0.5, abs(outCd.r-.5)));
      
      //DetailBlurring 0.0-2.0
      float shifter=1.0-(screenSpace.x*.68-.51);
      outCd.rgb = mix( outCd.rgb, vec3(step(shifter, DetailBlurring*.5)), step(0.0,screenSpace.x-0.75)*step(1.15,screenSpace.y));
      
      outCd.rgb=mix( outCd.rgb, vec3(0.0), step(abs(screenSpace.x-0.75), .0012));
    #elif ( DebugView == 3 )
      outCd.rgb=mix(outCd.rgb, vec3(lightCd), step(0.0,screenSpace.x));
    #endif
    
    
    
    #if ( DebugView == 4 )
      vec4 debugCd = texture2D(gcolor, tuv);
      vec4 debugLightCd = texture2D(lightmap, luv);
      
      float debugBlender = step( .0, screenSpace.x);
      float debugFogInf = min(1.0,depth*2.0);
      
      debugFogInf=clamp(((1.0-gl_FragCoord.w)-.997)*800.0+screenDewarp*.2,0.0,1.0);
      debugCd.rgb = mix( debugCd.rgb, fogColor, debugFogInf);
  
      //debugCd = debugCd * debugLightCd * vec4(vColor.rgb*(1.0-debugBlender)+(debugBlender),1.0) * vColor.aaaa;
      debugCd = debugCd * debugLightCd * vColor * vColor.aaaa;
      outCd = mix( outCd, debugCd, debugBlender);
    #endif
		
//	outCd.rgb=vec3(  clamp((shadowAvg*2.0)-0.5,0.0,1.0) );
//	outCd.rgb=vec3(  clamp((shadowAvg*1.4)-0.1,0.0,1.0) );
	//outCd.rgb=vec3(  shadowData.r * shadowAvg );
	//outCd.rgb=vec3(  lightCd );
	//outCd.rgb=vec3(  shadowDepth );
	//outCd.rgb=vec3(  shadowData.r*(1.0-shadowBase) );
	//outCd.rgb=vec3(  shadowData.ggg );
	//outCd.rgb=vec3(  shadowAvg );
	//outCd.rgb=vec3(  shadowData.b );
	//outCd.rgb=vec3(  vWorldNormal );
	
    outCd = outCd;
    outDepthGlow = vec4(outDepth, outEffectGlow, 0.0, 1.0);
    outNormal = vec4(vNormal*.5+.5, 1.0);
    // [ Sun/Moon Strength, Light Map, Spectral Glow ]
    outLighting = vec4( lightLumaBase, lightLumaBase, 0.0, 1.0);
    outGlow = vec4( glowHSV, 1.0);
    outNull = vec4( 0.0);

  //}
}


#endif

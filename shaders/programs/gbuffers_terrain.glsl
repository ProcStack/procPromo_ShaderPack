
#ifdef VSH

#include "utils/shadowCommon.glsl"
const float eyeBrightnessHalflife = 4.0f;

#define SEPARATE_AO

#define ONE_TILE 0.015625
#define THREE_TILES 0.046875

#define PI 3.14159265358979323
#include "/shaders.settings"

uniform sampler2D texture;
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

uniform int blockEntityId;
uniform vec2 texelSize;

uniform int worldTime;

uniform float dayNight;
uniform ivec2 eyeBrightnessSmooth;
uniform float eyeBrightnessFit;
uniform vec3 shadowLightPosition;

attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;
attribute vec4 at_tangent; 

// Doesn't run on gl 1.20
//in vec3 at_velocity; // vertex offset to previous frame
in vec4 vaColor;                                color (r, g, b, a)                          1.17+
//in vec2 vaUV0;                                  texture (u, v)                              1.17+
//in ivec2 vaUV1;                                 overlay (u, v)                              1.17+
//in ivec2 vaUV2;                                 lightmap (u, v)                             1.17+
//in vec3 vaNormal;                               normal (x, y, z)                            1.17+

// Glow Pass Varyings --
varying float blockFogInfluence;
varying float txGlowThreshold;
// -- -- -- -- -- -- -- --

varying vec4 texcoord;
varying vec2 texcoordmid;
varying vec4 lmcoord;
varying vec2 texmidcoord;

varying vec4 vtexcoordam; // .st for add, .pq for mul


varying float sunDot;

#ifdef OVERWORLD
  varying float skyBrightnessMult;
  varying float dayNightMult;
  varying float sunPhaseMult;
#endif

varying vec4 shadowPos;
varying vec3 shadowOffset;

varying vec4 vPos;
varying vec4 vLocalPos;
varying vec4 vWorldPos;
varying vec3 vModelPos;
varying vec3 vNormal;
varying float vNormalSunDot;

varying vec4 vColor;
varying vec4 vAvgColor;
varying float vCrossBlockCull;

varying float vAlphaMult;
varying float vAlphaRemove;

varying vec3 vCamViewVec;
varying vec4 camDir;
varying vec3 vWorldNormal;
varying vec3 vAnimFogNormal;

varying float vDetailBluringMult;
varying float vMultiTexelMap;

varying float vIsLava;
varying float vCdGlow;
varying float vDepthAvgColorInf;
varying float vFinalCompare;
varying float vColorOnly;
varying float vDeltaPow;
varying float vDeltaMult;



void main() {
	vec3 normal = gl_NormalMatrix * gl_Normal;
	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
  vWorldNormal = gl_Normal;
  vNormal = normalize(normal);
  vNormalSunDot = dot(normalize(shadowLightPosition), vNormal);
  vAnimFogNormal = gl_NormalMatrix*vec3(1.0,0.0,0.0);
  
  vModelPos = gl_Vertex.xyz;//(gl_ProjectionMatrix * gl_ModelViewMatrix * vec4(0.0,0.0,0.0,1.0)).xyz;
  vModelPos = gl_ModelViewMatrix[3].xyz;//(gl_ProjectionMatrix * gl_ModelViewMatrix * vec4(0.0,0.0,0.0,1.0)).xyz;
  vModelPos = (gl_ModelViewMatrix * vec4(0.0,0.0,0.0,1.0)).xyz;
  
  vCamViewVec =  normalize((mat3(gl_ModelViewMatrix) * normalize(vec3(-1.0,0.0,.0)))*vec3(1.0,0.0,1.0));
  
  // -- -- -- -- -- -- -- --

  vLocalPos = gl_Vertex;
  vWorldPos = gl_ProjectionMatrix * gl_Vertex;
	gl_Position = vWorldPos;

  vPos = vec4(position,1.0);
  
	vColor = gl_Color;


  vec4 textureUV = gl_MultiTexCoord0;

                                 
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	//texcoord = gl_MultiTexCoord0;
  

	vec2 midcoord = (gl_TextureMatrix[0] *  vec4(mc_midTexCoord,0.0,1.0)).st;
  texcoordmid=midcoord;
  vec2 texelhalfbound = texelSize*16.0;
  
  // -- -- --
  
  float avgBlend = .95;
  
  ivec2 txlOffset = ivec2(2);
  vec3 mixColor;
  vec4 tmpCd;
  float avgDiv = 0.0;
  tmpCd = texture2D(texture, midcoord);
    mixColor = tmpCd.rgb;
    avgDiv += tmpCd.a;
  #if (BaseQuality > 1)
  tmpCd = textureOffset(texture, midcoord, ivec2(-txlOffset.x, txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  tmpCd = textureOffset(texture, midcoord, ivec2(txlOffset.x, -txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  #if (BaseQuality == 2)
  tmpCd = textureOffset(texture, midcoord, ivec2(-txlOffset.x, -txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  tmpCd = textureOffset(texture, midcoord, ivec2(-txlOffset.x, txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  #endif
  #endif
  //mixColor = mix( vec3(length(vColor.rgb)), mixColor, step(.1, length(mixColor)) );
  mixColor = mix( vec3(vColor.rgb), mixColor, step(.1, mixColor.r+mixColor.g+mixColor.b) );

  vAvgColor = vec4( mixColor, vColor.a); // 1.0);


	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

	gl_FogFragCoord = gl_Position.z;


	
	vec2 texcoordminusmid = texcoord.xy-midcoord;
  texmidcoord = midcoord;
	vtexcoordam.pq = abs(texcoordminusmid)*2.0;
	vtexcoordam.st = min(texcoord.xy ,midcoord-texcoordminusmid);


  // -- -- -- -- -- -- -- --
  
#ifdef OVERWORLD
  
  // Shadow Prep
  float depth = min(1.0, length(position.xyz)*.01 );
  vec3 shadowPosition = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;
  //shadowPosition = gl_Vertex.xyz;
  
  
  //float shadowPushAmmount = .02+depth*0.50;
      //+(gl_Vertex.y+cameraPosition.y)*.0;
      //max(0.0,.8-abs(dot(sunVec, normal))))*(.10);//normal));
  //shadowPushAmmount = (shadowPosition.z*0.01);
  //shadowPushAmmount = max( abs(vWorldNormal.z), vWorldNormal.y)*0.2;
  
  //float shadowPushAmmount =  (depth*.5 + 0.9-abs(dayNight)*0.85) ;
  float shadowPushAmmount =  (depth*.5 + .010 ) ;
  shadowPushAmmount *=  min( 1.0, max(abs(vWorldNormal.x), max( vWorldNormal.y, abs(vWorldNormal.z) )));//+(1.0-skyBrightnessMult*.5) );
  vec3 shadowPush = gl_Normal*shadowPushAmmount ;
  
  //shadowPush = (vNormal*shadowPushAmmount) ;
  shadowPos.xyz = mat3(shadowModelView) * (shadowPosition.xyz+shadowPush) + shadowModelView[3].xyz;
  vec3 shadowProjDiag = diagonal3(shadowProjection);
  shadowPos.xyz = (shadowProjDiag * shadowPos.xyz + shadowProjection[3].xyz);// * (skyBrightnessMult*.5+.5);
  //shadowPos = biasShadowAxis( shadowPos );

  #if ( DebugView == 3 )
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
    moonPhaseMult = moonPhaseMult - max(0.0, moonPhaseMult-0.50)*2.0;
    //moonPhaseMult = moonPhaseMult*.18 + .018; // Moon's shadowing multiplier

    dayNightMult = mix( 1.0, moonPhaseMult, sunPhaseMult);
  
#endif
  
  
	gl_Position = toClipSpace3(position);
  
	
	
  // -- -- -- -- -- -- -- --
	
	
	
  vAlphaMult=1.0;
  vIsLava=0.0;
  vCdGlow=0.0;
  vCrossBlockCull=0.0;
  vColorOnly=0.0;
  vFinalCompare = mc_Entity.x == 811 ? 0.0 : 1.0;
  vFinalCompare = mc_Entity.x == 901 ? 0.0 : vFinalCompare;

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
    //blerg = dot( normalize((cameraPosition - gl_ModelViewMatrix[3].xyz)*vec3(1.0,0.0,1.0)), vec3(0.707107,0.0,0.707107) );
    //vCrossBlockCull=blerg;
    //vCamViewVec = normalize( gl_Vertex.xyz );
    //vCamViewVec = normalize((gbufferProjection[3].xyz)*vec3(1.0,0.0,1.0));
  vec3 crossNorm = abs(normalize((vWorldNormal.xyz)*vec3(1.0,0.0,1.0)));
  //vCamViewVec = normalize((vCamViewVec.xyz)*vec3(1.0,0.0,1.0));
  //vCamViewVec = vec3( abs(dot(vCamViewVec,crossNorm)) );
  //  vCamViewVec = vec3( abs(dot(vCamViewVec,crossNorm)) );
    vCamViewVec = vec3( abs(dot(vCamViewVec,crossNorm)) );
    vCamViewVec = cross(vCamViewVec,crossNorm);
    vCamViewVec = vec3( abs(dot( cross(vCamViewVec,crossNorm), vec3(0.707107,0.0,0.707107) )) );
    //vCamViewVec = vec3( step(.5, abs(dot(vec3(vNormal.x, 0.0, vCamViewVec.z),vec3(0.707107,0.0,0.707107) )) ) );
    
//    gl_NormalMatrix * gl_Normal;
    vCamViewVec = vec3( dot( gl_NormalMatrix* gl_Normal, gl_Normal ) );
    //vCrossBlockCull=step( .5, vCrossBlockCull );
    
    
    
  //position = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;
    
    vCamViewVec = mat3(gbufferModelViewInverse) * vec3(0.0,0.0,1.0) + gbufferModelViewInverse[3].xyz;
    vCamViewVec = inverse(gl_NormalMatrix) * normalize( vCamViewVec*vec3(1.0,0.0,1.0) );
    vec4 refPos = (gbufferProjectionInverse * gbufferModelViewInverse * gl_Vertex)*.5;

    vec3 crossRefVec = normalize( ( vWorldPos.xyz, refPos.xyz )*vec3(1.0,0.0,1.0) );
    vec3 wNormRefVec = normalize( vWorldNormal*vec3(1.0,0.0,1.0) );
    //vCrossBlockCull = 1.0-abs(dot( crossRefVec, wNormRefVec ));
    //vCamViewVec = vec3( step( vCrossBlockCull, .5 ) );
    vCamViewVec = mat3(gbufferModelViewInverse) * gl_Normal;
    vCamViewVec = mat3(gbufferProjection) * gl_Normal;
    //vCamViewVec = gl_Normal;
    //vAlphaMult=vCrossBlockCull;
  }
  */
  
  // Leaves
  vAlphaRemove = 0.0;
  if((mc_Entity.x == 810 || mc_Entity.x == 8101) && SolidLeaves ){
    vAvgColor = mc_Entity.x == 810 ? vColor * (vAvgColor.g*.5+.5) : vAvgColor;
    vColor = mc_Entity.x == 8101 ? vAvgColor : vColor;
    
    
    vAlphaRemove = 1.0;
    shadowPos.w = -2.0;
  }


  // General Alt Texture Reads
  texcoord.zw = texcoord.st;
  vDepthAvgColorInf = 1.0;


  if( mc_Entity.x == 801 ||  mc_Entity.x == 811 || mc_Entity.x == 8013 ){
    texcoord.zw = texcoord.st;
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
	vDeltaPow=3.2;
	vDeltaMult=3.0;
  if( mc_Entity.x == 8012 ){
		vDeltaPow=.80;
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
    vCdGlow=.2;
    vIsLava=0.7;
#endif
    vColor.rgb = mix( vAvgColor.rgb, texture2D(texture, midcoord).rgb, .5 );
  }
  // Flowing Lava
  if( mc_Entity.x == 702 ){
    vIsLava=0.85;
    vCdGlow=0.15;
#ifdef NETHER
    vIsLava=0.7;
    vCdGlow=.2;
#endif
    vColor.rgb = mix( vAvgColor.rgb, texture2D(texture, midcoord).rgb, .5 );
  }
  
  // Fire / Soul Fire
  if( mc_Entity.x == 707 ){
    vCdGlow=0.015;
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
    texcoord.zw = texcoord.st;
    vCdGlow = 0.1;
    vAvgColor.rgb = vec3(.35,.15,.7);
    //vColor.rgb = mix( vAvgColor.rgb, texture2D(texture, midcoord).rgb, .7 );
  }
  // Amethyst Clusters
  if (mc_Entity.x == 910){
    texcoord.zw = texcoord.st;
    vCdGlow = 0.1;
    //vColor.rgb = vAvgColor.rgb;//mix( vAvgColor.rgb, texture2D(texture, midcoord).rgb, .5 );
  }
  


}

#endif




/* */
/* */
/* */



#ifdef FSH


/* RENDERTARGETS: 0,1,2,7,6,9 */

#define gbuffers_terrain
/* --
const int gcolorFormat = RGBA8;
const int gdepthFormat = RGBA16;
const int gnormalFormat = RGB10_A2;
 -- */

#include "/shaders.settings"
#include "utils/shadowCommon.glsl"
#include "utils/mathFuncs.glsl"
#include "utils/texSamplers.glsl"



uniform sampler2D texture;
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
uniform sampler2DShadow shadow;
uniform sampler2D shadowcolor0;
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
varying float blockFogInfluence;
varying float txGlowThreshold;
// -- -- -- -- -- -- -- --

varying vec4 vColor;
varying vec4 texcoord;
varying vec2 texcoordmid;
varying vec4 lmcoord;

varying vec2 texmidcoord;
varying vec4 vtexcoordam; // .st for add, .pq for mul


varying float sunDot;

#ifdef OVERWORLD
  varying float skyBrightnessMult;
  varying float dayNightMult;
  varying float sunPhaseMult;
#endif

uniform vec3 shadowLightPosition;
uniform float dayNight;
uniform float sunMoonShadowInf;

varying vec4 shadowPos;
varying vec3 shadowOffset;
varying float vAlphaMult;
varying float vAlphaRemove;
varying float vColorOnly;

varying vec3 vCamViewVec;
varying vec4 camDir;
varying vec4 vPos;
varying vec4 vLocalPos;
varying vec4 vWorldPos;
varying vec3 vModelPos;
varying vec3 vNormal;
varying vec3 vWorldNormal;
varying float vNormalSunDot;
varying vec3 vAnimFogNormal;

varying vec4 vAvgColor;
varying float vCrossBlockCull;

varying float vIsLava;
varying float vCdGlow;
varying float vDepthAvgColorInf;
varying float vFinalCompare;
varying float vDeltaPow;
varying float vDeltaMult;

void main() {
  
    vec2 tuv = texcoord.st;

    vec2 screenSpace = (vPos.xy/vPos.z)  * vec2(aspectRatio);

    vec2 luv = lmcoord.st;

    float outDepth = min(.9999,gl_FragCoord.w);


    float isLava = vIsLava;
    vec4 avgShading = vAvgColor;
    float avgDelta = 0.0;

    // -- -- -- -- -- -- --
    
    vec4 baseCd=vAvgColor;//vec4(1.0,1.0,0.0,1.0);
    baseCd=baseCd = texture2D(texture, tuv);
    
		vec4 txCd=vec4(1.0,1.0,0.0,1.0);
		
		
		
    // TODO : There's gotta be a better way to do this...
    //          - There is, just gotta change it over
    if ( DetailBluring > 0.0 ){
      //txCd = diffuseSample( texture, tuv, vtexcoordam, texelSize, DetailBluring*2.0 );
      
      // Split Screen "Blur Comparison" Debug View
      #if ( DebugView == 1 )
        float debugDetailBluring = clamp((screenSpace.y/(aspectRatio*.8))*.5+.5,0.0,1.0)*2.0;
        //debugDetailBluring *= debugDetailBluring;
        debugDetailBluring = mix( DetailBluring, debugDetailBluring, step(screenSpace.x,0.75));
        diffuseSampleXYZ( texture, tuv, vtexcoordam, texelSize, debugDetailBluring, baseCd, txCd, avgDelta );
      #else
        //diffuseSampleXYZ( texture, tuv, vtexcoordam, texelSize, DetailBluring, baseCd, txCd, avgDelta);
        diffuseSampleXYZFetch( texture, tuv, texcoordmid, texelSize, DetailBluring, baseCd, txCd, avgDelta);
      #endif
      
    }else{
      txCd = texture2D(texture, tuv);
    }

    

		
		float discardMult = vAlphaMult;
		#if ( DebugView == 4 )
			txCd.a = mix(txCd.a, 1.0, step(screenSpace.x,.0)*vAlphaRemove);
			discardMult=1.0;
		#else
			txCd.a = mix(txCd.a, 1.0, vAlphaRemove);
		#endif
    if (txCd.a * discardMult < .2){
      discard;
    }
    
		
    // Default Minecraft Lighting
    float lightLumaBase = texture2D(lightmap, luv).r;//*.9+.1;
		
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
    float depthBias = biasToOne(depth, 10.5);
    float depthDetailing = clamp(1.035-depthBias, 0.0, 1.0);

    // Side by side of active bluring and no bluring
    //   Other shader effects still applied though
    #if ( DebugView == 1 )
      txCd = mix( texture2D(texture, tuv), txCd, step(0.0, screenSpace.x+.75) );
    #endif

  // -- -- -- -- -- -- -- --
	
		// Use Light Map Data
    //float lightLuma = clamp((lightLumaBase-.265) * 1.360544217687075, 0.0, 1.0); // lightCd.r;
    float lightLuma = shiftBlackLevels( lightLumaBase ); // lightCd.r;

    vec3 lightCd = vec3(lightLuma);
		
  // -- -- -- -- -- -- -- --

    vec4 outCd = vec4(txCd.rgb,1.0) * vec4(vColor.rgb,1.0);

    vec3 outCdAvgRef = outCd.rgb;
    vec3 cdToAvgDelta = outCdAvgRef.rgb - txCd.rgb; // Strong color changes, ie birch black bark markings
    float cdToAvgBlender = min(1.0, addComponents( cdToAvgDelta ));
    //outCd.rgb = mix( outCd.rgb, txCd.rgb, max(0.0,cdToAvgBlender-depthBias*.5)*vFinalCompare );
    
    float avgColorBlender = min(1.0, pow(length(txCd.rgb-vAvgColor.rgb),vDeltaPow)*vDeltaMult*depthBias);
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
  
  float toCamNormalDot = dot(normalize(-vPos.xyz*vec3(1.3,1.35,1.3)),vNormal);
  float surfaceShading = 9.0-abs(toCamNormalDot);

	float fogColorBlend = 1.0;
	
	
#ifdef OVERWORLD


#if ShadowSampleCount > 0

  //vec4 shadowProjOffset = vec4( fitShadowOffset( cameraPosition ), 0.0);

  vec3 localShadowOffset = shadowPosOffset;
	//localShadowOffset.z *= (skyBrightnessMult*.5+.5);
  //localShadowOffset.z *= min(1.0,outDepth*20.0+.7)*.1+.9;
  
  vec4 shadowPosLocal = shadowPos;
  //shadowPosLocal.xy += camDir.xz;
  
  shadowPosLocal = biasShadowShift( shadowPosLocal );
  vec3 projectedShadowPosition = shadowPosLocal.xyz * shadowPosMult + localShadowOffset;
  
  shadowAvg=shadow2D(shadow, projectedShadowPosition).x;
  
  
#if ShadowSampleCount > 1

  // Modded for multi sampling the shadow
  // TODO : Functionize this rolled up for loop dooky
  
  vec2 posOffset;
  float reachMult = 1.5 - (min(1.0,outDepth*20.0)*.5);
  
  for( int x=0; x<axisSamplesCount; ++x){
    //posOffset = axisSamples[x]*reachMult*skyBrightnessMult*.00058828125;
    posOffset = axisSamples[x]*reachMult*.00058828125*skyBrightnessMult;
    projectedShadowPosition = vec3(shadowPosLocal.xy+posOffset,shadowPosLocal.z) * shadowPosMult + localShadowOffset;
  
    shadowAvg = mix( shadowAvg, shadow2D(shadow, projectedShadowPosition).x, .25);
    //shadowAvg = ( shadowAvg * shadow2D(shadow, projectedShadowPosition).x );
    
    
  #if ShadowSampleCount > 2
    //posOffset = crossSamples[x]*reachMult*skyBrightnessMult*.0008;
    //posOffset = crossSamples[x]*reachMult*skyBrightnessMult*.00038828125;
    posOffset = crossSamples[x]*reachMult*.00038828125;
    projectedShadowPosition = vec3(shadowPosLocal.xy+posOffset,shadowPosLocal.z) * shadowPosMult + localShadowOffset;
  
    shadowAvg = mix( shadowAvg, shadow2D(shadow, projectedShadowPosition).x, .35);
    //shadowAvg = ( shadowAvg * shadow2D(shadow, projectedShadowPosition).x );
  #endif
    
  }
  

#endif
  
  //float sunMoonShadowInf = clamp( (abs(vNormalSunDot)-.04)*1.5, 0.0, 1.0 );
  //float sunMoonShadowInf = min(1.0, max(0.0, abs(vNormalSunDot)+.50)*1.0);
  float shadowDepthInf = clamp( (depth*distancDarkenMult), 0.0, 1.0 );
  shadowDepthInf *= shadowDepthInf;

  
  shadowAvg = shadowAvg + min(1.0, (length(vLocalPos.xz)*.0025)*1.5);
  
  
  float shadowInfFit = 0.025;
  float shadowInfFitInv = 40.0;// 1.0/shadowInfFit;
  //float shadowSurfaceInf = step(-0.005,dot(normalize(shadowLightPosition), vNormal));
  float shadowSurfaceInf = min(1.0, max(0.0,(shadowInfFit-(-dot(normalize(shadowLightPosition), vNormal)))*shadowInfFitInv )*1.5);
  //shadowSurfaceInf = clamp(shadowSurfaceInf * max(0.0,1.0-(1.0-abs(dayNight))*10000.0) + abs(vWorldNormal.z), 0.0, 1.0)*step(-.8,vWorldNormal.y);
  
  //shadowSurfaceInf = min(1.0, shadowSurfaceInf + min(1.0, (length(vLocalPos.xz)*.0025)*1.5) );
  
  // -- -- --
  //  Distance influence of surface shading --
  shadowAvg = mix( (shadowAvg*shadowSurfaceInf), min(shadowAvg,shadowSurfaceInf), shadowAvg)*skyBrightnessMult * (1-rainStrength);
  // -- -- --
  // TODO : Needed?  Depth based shadowings
  diffuseSun *= mix( 0.0, shadowAvg, sunMoonShadowInf * shadowDepthInf * shadowSurfaceInf * dayNightMult );

  
#endif
  // -- -- -- -- -- -- -- --
  // -- Lighting & Diffuse - --
  // -- -- -- -- -- -- -- -- -- --
    
	// Mute Shadows during Rain
	diffuseSun = mix( diffuseSun, 0.50, rainStrength);          
	
	lightCd = max( lightCd, diffuseSun);
	//lightCd = max(lightCd,vec3(diffuseSun) );//vec3( mix(  max(diffuseSun,lightLumaBase), diffuseSun*lightLumaBase,  skyBrightnessMult ) );
	//lightCd = vec3( mix(  max(diffuseSun,lightLumaBase), diffuseSun*lightLumaBase,  dayNightMult*skyBrightnessMult ) );
	
	// Strength of final shadow
	//outCd.rgb *= vec3(mix(max(shadowAvg,lightCd.r), 1.0,shadowAvg));
	//outCd.rgb *= vec3(mix(lightCd.r, 1.0,shadowAvg));
	outCd.rgb *= vec3(mix(max(shadowAvg,lightCd.r*.8), 1.0,shadowAvg));

	fogColorBlend = skyBrightnessMult;
	
	//lightCd = mix( vec3(shadowAvg), lightCd, 1.0-shadowAvg);// * dayNightMult;
	//lightCd = max( vec3(shadowAvg*dayNightMult), lightCd) ;
	lightCd = mix( lightCd.rrr, max(lightCd.rrr, vec3(shadowAvg)*dayNightMult), shadowAvg) ;
	//lightCd = mix( lightCd.rrr*shadowAvg, max(lightCd.rrr, vec3(shadowAvg)*dayNightMult), shadowAvg) ;
	


	surfaceShading *= mix( dayNightMult, vNormalSunDot, dayNight*.5+.5 );
    
#endif
    
		// Add Fake Fresnel To Blocks
		float dotToCam = dot(vNormal,normalize(vec3(screenSpace*(1.0-depthBias),1.0)));
		outCd*=mix(1.0, dotToCam*.35+.65, vIsLava*.5);
		
		
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
    //outCd.rgb *=  lightCd.rrr + glowInf;// + vCdGlow;

    // Used for correcting blended colors post environment influences
    // This shouldn't be needed, but blocks like Grass or Birch Log/Wood are persnickety
    //vec3 avgCdRef = vAvgColor.rgb * (lightCd.rrr + glowInf + vCdGlow);

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
      outCd.rgb *=  1.0+lightLuma*1.2;//+.5;
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
			
			float lightShift=.47441;
			float lightShiftMult=1.9026237181072698; // 1.0/(1.0-lightShift)
      float lightInf = min(1.0, (max((lightCd.r-.35)*1.2,lightLumaBase)-lightShift)*lightShiftMult + depthEnd*.4);
      
      vec3 endFogCd = fogColor+vec3(.3,.25,.3);
      float timeOffset = (float(worldTime)*0.00004166666)*(30.0);
      vec3 worldPos = (abs(cameraPosition+vLocalPos.xyz)*vec3(.09,.06,.05)*.01);
      worldPos = ( worldPos+texture2D( noisetex, fract(worldPos.xz+worldPos.yy)).rgb );

      vec3 noiseX = texture2D( noisetex, worldPos.xy*depthEnd + (timeOffset*vec2(.1,.5))).rgb;
      vec3 noiseZ = texture2D( noisetex, fract(worldPos.yz+noiseX.rg*.1 + vec2(timeOffset) )).rgb;
      
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
    
    
    

#ifdef NETHER
    //outCd.rgb *= mix( outCd.rgb+outCd.rgb*vec3(1.6,1.3,1.2), vec3(1.0), (depthBias)*.4+.4);
    outCd.rgb = mix( fogColor*(lightCd+.5), outCd.rgb*lightCd, smoothstep(.015, .35, depthBias+glowInf*.5));
    outCd.rgb *= mix(1.0, toCamNormalDot, depth*.7+.3);
#else
    outCd.rgb *= mix(toFogColor.rgb, vec3(toCamNormalDot*.5+.5), min(1.0,depth*.7+.3+lightCd.r));
#endif


    
    
    glowInf += (luma(outCd.rgb)+vIsLava)*vCdGlow;
#ifdef OVERWORLD
    // -- -- -- -- -- -- -- -- -- -- -- -- -- --
    // Biome & Snow Glow when in a Cold Biome - -- --
    // -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    float frozenSnowGlow = 1.0-smoothstep(.0,.2,BiomeTemp);
    glowCd = addToGlowPass(glowCd, outCd.rgb*frozenSnowGlow*.5*(1.0-sunPhaseMult)*max(0.06,-dayNight)*max(0.0,(1.0-depth*3.0)));
    //float cdBrightness = min(1.0,max(0.0,dot(txCd.rgb,vec3(1.0))));
    //cdBrightness *= cdBrightness;
    //outCd.rgb *= 1.0+cdBrightness*frozenSnowGlow*3.5*max(0.06,-dayNight*.1)*(1.0-rainStrength);
    outCd.rgb *= 1.0+frozenSnowGlow*max(0.06,-dayNight*.1)*(1.0-rainStrength);//*skyBrightnessMult;
    
    
    // -- -- -- -- -- -- -- -- -- -- -- 
    // Outdoors vs Caving Lighting - -- --
    // -- -- -- -- -- -- -- -- -- -- -- -- --
    // Brighten blocks when going spelunking
    // TODO: Promote control to Shader Options
    float skyBrightMultFit = min(1.0, 1.0-skyBrightnessMult*.1*(1.0-frozenSnowGlow) );
    outCd.rgb *= skyBrightMultFit;
		
// Check this for shadow infulences--    
    outCd.rgb*=mix(vec3(1.0), lightCd.rgb, min(1.0,  sunPhaseMult*skyBrightnessMult));
    
#endif
    
    
    glowCd += outCd.rgb+(outCd.rgb+.1)*glowInf;



    vec3 glowHSV = rgb2hsv(glowCd);
    glowHSV.z *= glowInf * (depthBias*.6+.5) * GlowBrightness;// * .05;// * lightLuma;


#ifdef NETHER
    outCd.rgb = clamp( outCd.rgb+outCd.rgb*lightCd*min(1.0,vIsLava), vec3(0.0), vec3(1.0));//*glowInf;
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
    
    outCd.a*=vAlphaMult;
    
    
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
      
      //DetailBluring 0.0-2.0
      float shifter=1.0-(screenSpace.x*.68-.51);
      outCd.rgb = mix( outCd.rgb, vec3(step(shifter, DetailBluring*.5)), step(0.0,screenSpace.x-0.75)*step(1.15,screenSpace.y));
      
      outCd.rgb=mix( outCd.rgb, vec3(0.0), step(abs(screenSpace.x-0.75), .0012));
    #elif ( DebugView == 3 )
      outCd.rgb=mix(outCd.rgb, vec3(lightCd), step(0.0,screenSpace.x));
    #endif
    
    
    
		#if ( DebugView == 4 )
			vec4 debugCd = texture2D(texture, tuv);
			vec4 debugLightCd = texture2D(lightmap, luv);
			
			float debugBlender = step( .0, screenSpace.x);
			float debugFogInf = min(1.0,depth*2.0);
			
			debugFogInf=clamp(((1.0-gl_FragCoord.w)-.997)*800.0+screenDewarp*.2,0.0,1.0);
			debugCd.rgb = mix( debugCd.rgb, fogColor, debugFogInf);
  
			//debugCd = debugCd * debugLightCd * vec4(vColor.rgb*(1.0-debugBlender)+(debugBlender),1.0) * vColor.aaaa;
			debugCd = debugCd * debugLightCd * vColor * vColor.aaaa;
      outCd = mix( outCd, debugCd, debugBlender);
    #endif
		//outCd.rgb=vec3(float(eyeBrightness.x)*(1.0/15.0));
		//outCd.rgb=vec3(step(15.00/16.0,lightLumaBase));

    gl_FragData[0] = outCd;
    gl_FragData[1] = vec4(outDepth, outEffectGlow, 0.0, 1.0);
    gl_FragData[2] = vec4(vNormal*.5+.5, 1.0);
    // [ Sun/Moon Strength, Light Map, Spectral Glow ]
    gl_FragData[3] = vec4( lightLumaBase, lightLumaBase, 0.0, 1.0);
    gl_FragData[4] = vec4( glowHSV, 1.0);
    gl_FragData[5] = vec4( 0.0);

	//}
}


#endif

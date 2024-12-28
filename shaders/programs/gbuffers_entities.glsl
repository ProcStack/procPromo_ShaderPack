// GBuffer - Entities GLSL
// Written by Kevin Edzenga, ProcStack; 2022-2023
//

#ifdef VSH


#define gbuffers_entities

#include "/shaders.settings"
#include "utils/shadowCommon.glsl"

uniform float frameTimeCounter;
uniform mat3 normalMatrix;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;

uniform int blockEntityId;
uniform int entityId;


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
varying vec3 vLocalPos;
varying vec3 vNormal;
varying float vNormalSunDot;
varying vec3 vAvgColor;
varying float vAvgColorBlend;


#ifdef OVERWORLD
	// Sun Moon Influence
	uniform mat4 shadowModelView;
	uniform mat4 shadowProjection;

	uniform float dayNight;
	uniform int moonPhase;
	uniform ivec2 eyeBrightnessSmooth;
	uniform float eyeBrightnessFit;
	uniform vec3 shadowLightPosition;

	
	varying float skyBrightnessMult;
	varying float dayNightMult;
	varying float sunPhaseMult;
	varying vec4 shadowPos;
#endif



void main() {

  vec4 position = gl_ModelViewMatrix * gl_Vertex;
	vLocalPos = position.xyz;
  
  vPos = gl_ProjectionMatrix * position;
  gl_Position = vPos;
  
  vPos = gl_ModelViewMatrix * gl_Vertex;

  vNormal = normalize(gl_NormalMatrix * gl_Normal);

  color = gl_Color;
  //color.a=1.0;


  texelSize = vec2(1.0/64.0, 1.0/32.0);//vec2(1.0/viewWidth,1.0/viewWidth);
  texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

  lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

  gl_FogFragCoord = gl_Position.z;



#ifdef OVERWORLD
  
  vNormalSunDot = dot(normalize(shadowLightPosition), vNormal);
	
  // Shadow Prep --
	// Invert vert  modelVert positions 
  float depth = min(1.5, length(position.xyz)*.015 );
  vec3 shadowPosition = mat3(gbufferModelViewInverse) * position.xyz + gbufferModelViewInverse[3].xyz;

  vec3 shadowNormal = mat3(shadowProjection) * mat3(shadowModelView) * gl_Normal;
  float shadowPushAmmount =  (depth*.5 + .00010 ) ;
	float sNormRef = max(abs(shadowNormal.x), abs(shadowNormal.z) );
	
	// `+ (0.75-depth*.55)` is scalping fixes
	sNormRef = max( -shadowNormal.y*depth, sNormRef + (0.75+depth*.55) );
  shadowPushAmmount *= sNormRef;
  vec3 shadowPush = shadowNormal*shadowPushAmmount ;
  
  shadowPos.xyz = mat3(shadowModelView) * (shadowPosition.xyz+shadowPush) + shadowModelView[3].xyz;
  vec3 shadowProjDiag = diagonal3(shadowProjection);
  shadowPos.xyz = (shadowProjDiag * shadowPos.xyz + shadowProjection[3].xyz);
  shadowPos.w = 1.0;

  #if ( DebugView == 3 ) // Debug Vision : Shadow Debug
		// Verts push out on the left side of the screen
    //   Showing how far its sampling for the shadow base value
    position.xyz = mat3(gbufferModelView) * (shadowPosition.xyz+shadowPush*clamp(1.0-position.x,0.0,1.0)) + gbufferModelView[3].xyz;
  #endif


	// Sun Moon Influence
	skyBrightnessMult = 1.0;
	dayNightMult = 0.0;
	sunPhaseMult = 1.0;

	// Sky Influence
	skyBrightnessMult=eyeBrightnessFit;
	
	// Sun Influence
	sunPhaseMult = max(0.0,1.0-max(0.0,dayNight)*2.0);
	
	// Moon Influence
	float moonPhaseMult = min(1.0,float(mod(moonPhase+4,8))*.125);
	moonPhaseMult = moonPhaseMult*.18 + .018; // Moon's shadowing multiplier

	dayNightMult = mix( 1.0, moonPhaseMult, sunPhaseMult);
  
#endif


  //vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
  vec2 midcoord = (gl_TextureMatrix[0] *  vec4(mc_midTexCoord.st,0.0,1.0)).st;
  texcoordmid=midcoord;
  vec2 texcoordminusmid = texcoord.xy-midcoord;
  vtexcoordam.pq = abs(texcoordminusmid)*2.0;
  vtexcoordam.st = min(texcoord.xy ,midcoord-texcoordminusmid);
  
  
  vNormal = normalize(gl_NormalMatrix * gl_Normal);
  
  //vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
  vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
  
  
  float avgBlend = .5;
  
  ivec2 txlOffset = ivec2(2);
  vec3 mixColor;
  vec4 tmpCd;
  float avgDiv = 0.0;
  tmpCd = color*texture2D(gcolor, midcoord);
    mixColor = tmpCd.rgb;
    avgDiv += tmpCd.a;
  tmpCd = color*textureOffset(gcolor, midcoord, ivec2(txlOffset.x, txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  tmpCd = color*textureOffset(gcolor, midcoord, ivec2(txlOffset.x, -txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  tmpCd = color*textureOffset(gcolor, midcoord, ivec2(-txlOffset.x, -txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  tmpCd = color*textureOffset(gcolor, midcoord, ivec2(-txlOffset.x, txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  
  vAvgColor = mixColor;
  
  // 
  vAvgColorBlend = 0.0;
  if(mc_Entity.x == 603){
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
#include "utils/shadowCommon.glsl"
#include "utils/mathFuncs.glsl"
#include "utils/texSamplers.glsl"

uniform sampler2D gcolor;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform int fogMode;
uniform vec3 sunPosition;
uniform vec4 spriteBounds; 
uniform vec4 entityColor;
uniform vec3 fogColor;

uniform int blockEntityId;
uniform int entityId;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

varying vec2 texelSize;
varying vec2 texcoordmid;
varying vec4 vtexcoordam;

varying vec4 vPos;
varying vec3 vNormal;
varying float vNormalSunDot;
varying vec3 vAvgColor;
varying float vAvgColorBlend;


#ifdef OVERWORLD
	// Sun Moon Influence
	uniform sampler2DShadow shadowtex0;
	uniform sampler2D shadowcolor0;
	uniform sampler2D shadowcolor1;
	uniform float rainStrength;
	uniform float sunMoonShadowInf;
	uniform vec3 shadowLightPosition;
	
	varying vec3 vLocalPos;
	varying float skyBrightnessMult;
	varying float dayNightMult;
	varying float sunPhaseMult;
	varying vec4 shadowPos;
#endif

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;



void main() {

  vec2 tuv = texcoord.st;
  vec4 baseCd = texture2D(gcolor, tuv);
  vec4 txCd = baseCd;
  float avgDelta = 0.0;
  //vec2 screenSpace = (gl_FragCoord.xy/gl_FragCoord.z);
  //screenSpace = (screenSpace*texelSize)-.5;

  //diffuseSampleXYZFetch( gcolor, tuv, texcoordmid, texelSize*1.0, 0.0, DetailBlurring, baseCd, txCd, avgDelta);
  diffuseSampleXYZ( gcolor, tuv, vtexcoordam, texelSize*2.0, 0.0, DetailBlurring, baseCd, txCd, avgDelta);
  //txCd = diffuseNoLimit( gcolor, tuv, vec2(0.10) );
  
  vec2 luv = lmcoord.st;
  vec4 lightBaseCd = texture2D(lightmap, luv);
  vec3 lightCd = lightBaseCd.rgb*.85+.15;
  
  vec4 outCd = txCd * color;
  baseCd *= color;
  
  float avgColorBlender = max(0.0, dot(outCd.rgb,(txCd.rgb)));
  float cdComp=1.0-abs(min(1.0,maxComponent(baseCd.rgb)*1.0)-.5)*2.0;
  avgColorBlender = clamp( (avgColorBlender-.85)*1.75+.25, 0.0, 1.0 )*cdComp;
  //avgColorBlender = min(1.0, avgColorBlender-(baseCd.r*baseCd.g*baseCd.b)*2.0);
  outCd.rgb =  mix( baseCd.rgb, outCd.rgb, avgColorBlender );
  
  float highlights = dot(normalize(sunPosition),vNormal);
  highlights = (highlights-.5)*0.3;

  float outEffectGlow = 0.0;
  
  

  float depth = min(0.999999, gl_FragCoord.w);
	float depthBias = biasToOne(depth, 10.5);
	float depthFog = min(1.0, depth*2.5 );


	float lightLumaBase = biasToOne( lightCd.r );




  // -- -- -- -- -- -- -- --
  // Based on shadow lookup from Chocapic13's HighPerformance Toaster
  //
  float shadowDist = 0.0;
  float diffuseSun = 1.0;
  float shadowAvg = 1.0;
  vec4 shadowCd = vec4(0.0);
  float reachMult = 0.0;
  
  float toCamNormalDot = dot(normalize(-vPos.xyz*vec3(1.3,1.35,1.3)),vNormal)+.2;
  float surfaceShading = 9.0-abs(toCamNormalDot);

  float fogColorBlend = 1.0;
	
	float ambBrightness = 3.0;
  
    // -- -- -- -- -- -- -- -- -- -- -- --
    // -- Shadow Sampling & Influence - -- --
    // -- -- -- -- -- -- -- -- -- -- -- -- -- --
#ifdef OVERWORLD

		float lightLuma = shiftBlackLevels( lightLumaBase ); // lightCd.r;
		
		ambBrightness = 1.0;

#if ShadowSampleCount > 0

// localShadowOffset is distance offset from surface to sample shadow
  vec3 localShadowOffset = shadowPosOffset_Entity;
  localShadowOffset.z *= (skyBrightnessMult*.5+.5);
  //localShadowOffset.z = 0.5 - min( 1.0, (shadowThreshBase_Entity + shadowThreshDist*(2.0-depthBias)) * shadowThreshold_Entity );
  localShadowOffset.z = 0.5 - min( 1.0, (shadowThreshBase_Entity) * shadowThreshold_Entity );

  
  vec4 shadowPosLocal = shadowPos;

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
	
  reachMult = min(10.0,  shadowData.b + .50 )*0.55;




#if ShadowSampleCount == 2
  vec2 posOffset;
  //float reachMult = reachMult;// - (min(1.0,depth*20.0)*.5);
  reachMult = max(0.0, reachMult - (min(1.0,depth*20.0)*.5));
  
  for( int x=0; x<axisSamplesCount; ++x){
    posOffset = axisSamples[x]*reachMult*shadowMapTexelSize*skyBrightnessMult;
    projectedShadowPosition = vec3(shadowPosLocal.xy+posOffset,shadowPosLocal.z) * shadowPosMult + localShadowOffset;
  
    //shadowAvg = mix( shadowAvg, shadow2D(shadowtex0, projectedShadowPosition).x, boxSampleFit);
    shadowAvg = max( shadowAvg, shadow2D(shadowtex0, projectedShadowPosition).x);
  }
#elif ShadowSampleCount == 3
  vec2 posOffset;
  
  for( int x=0; x<boxSamplesCount; ++x){
    posOffset = boxSamples[x]*reachMult*shadowMapTexelSize;
    projectedShadowPosition = vec3(shadowPosLocal.xy+posOffset,shadowPosLocal.z) * shadowPosMult + localShadowOffset;
    //shadowAvg = mix( shadowAvg, shadow2D(shadowtex0, projectedShadowPosition).x, boxSampleFit);
    shadowAvg = max( shadowAvg, shadow2D(shadowtex0, projectedShadowPosition).x);
  }
#elif ShadowSampleCount > 3
  vec2 posOffset;
  
  for( int x=0; x<boxSamplesCount; ++x){
    posOffset = boxSamples[x]*reachMult*shadowMapTexelSize;
    projectedShadowPosition = vec3(shadowPosLocal.xy+posOffset,shadowPosLocal.z) * shadowPosMult + localShadowOffset;
    //shadowAvg = mix( shadowAvg, shadow2D(shadowtex0, projectedShadowPosition).x, boxSampleFit);
    shadowAvg = max( shadowAvg, shadow2D(shadowtex0, projectedShadowPosition).x);
  }
#endif




  
  float shadowDepthInf = clamp( (depth*distancDarkenMult), 0.0, 1.0 );
  shadowDepthInf *= shadowDepthInf;
	
	// Verts not facing the sun should never have non-1.0 shadow values
	shadowCd.rgb = mix( vec3(1.0), shadowCd.rgb, min(1.0,step(-.01,vNormalSunDot)*shadowDepthInf));

  // Distance Rolloff
  shadowAvg = shadowAvg + min(1.0, (length(vLocalPos.xz)*.005)*1.5);
  
  float shadowInfFit = 0.025;
  float shadowInfFitInv = 40.0;// 1.0/shadowInfFit;
  //float shadowSurfaceInf = min(1.0, max(0.0,(shadowInfFit-(-dot(normalize(shadowLightPosition), vNormal)))*shadowInfFitInv )*1.5);
  float shadowSurfaceInf = min(1.0, max(0.0,shadowInfFit*shadowInfFitInv )*1.5);
  
  
  // -- -- --
  //  Distance influence of surface shading --
  shadowAvg = mix( (shadowAvg*shadowSurfaceInf), min(shadowAvg,shadowSurfaceInf), shadowAvg)*skyBrightnessMult * (1-rainStrength) * dayNightMult *.5+.5;
  // -- -- --
  diffuseSun *= mix( max(0.0,shadowDepthInf-rainStrength), shadowAvg, sunMoonShadowInf * shadowSurfaceInf );

#endif


  // -- -- -- -- -- -- -- --
  // -- Lighting & Diffuse - --
  // -- -- -- -- -- -- -- -- -- --
    
  // Mute Shadows during Rain
  diffuseSun = mix( diffuseSun, 0.50, rainStrength);          
  
  //lightCd = max( lightCd, diffuseSun);
	// Mix translucent color
	lightCd = mix( lightCd, shadowCd.rgb,
									clamp(shadowData.r*(1.0-shadowBase)
									//* max(0.0,shadowDepthInf*2.0-1.0)
									- shadowData.b*2.0, 0.0, 1.0) );
	lightLuma = min( maxComponent(lightCd), lightLuma );

  // Strength of final shadow
  //outCd.rgb *= mix(max(vec3(shadowAvg),lightCd), vec3(1.0),shadowAvg);
  //outCd.rgb *= mix(max(vec3(shadowAvg),lightCd), vec3(1.0),shadowAvg);
	//outCd.rgb = mix(lightCd*shadowAvg, outCd.rgb, shadowCd.a);
	

  fogColorBlend = skyBrightnessMult;
  
  lightCd = min(vec3(min(1.0,lightLumaBase)), mix( lightCd*(.8+(1.0-skyBrightnessMult)*.2)+shadowData.r*.3*max(0.0,vNormalSunDot), max(lightCd, vec3(shadowAvg)), shadowAvg) );
	lightCd = mix( vec3(lightLumaBase), lightCd.rgb, skyBrightnessMult);

	// Kill Shadow
	//lightCd = vec3(1.0);

  surfaceShading *= mix( dayNightMult, max(0.0,vNormalSunDot), sunMoonShadowInf*.5+.5 );
    
  // Apply Black Level Shift from User Settings
  //   Since those set to 0 would be rather low,
  //     Default is to run black shift with no check.
    lightCd = shiftBlackLevels( lightCd );
    surfaceShading = max( surfaceShading, lightCd.r );
    surfaceShading = shiftBlackLevels( surfaceShading );
    
    outCd.rgb *= max(vec3(0.0),lightCd.xyz-.335)*1.25; // -.2;

#else
  // Nether and End
  outCd.rgb *= lightBaseCd.rgb;
#endif


	float fogLuma = luma(fogColor);
	outCd.rgb = mix( outCd.rgb*(max(vec3(fogColor*ambBrightness), fogColor.rgb)*.5+.5), outCd.rgb, depthFog );

	
  #if ( DebugView == 4 )
    float debugBlender = step( .0, vPos.x );
    outCd = mix( baseCd, outCd, debugBlender);
  #endif
	
  float entityCd = maxComponent(entityColor.rgb);
  lightCd = vec3( lightCd.r );// * (1.0+rainStrength*.2));
  outCd.rgb = mix( outCd.rgb*lightCd.rgb, entityColor.rgb, entityCd);  
	
  gl_FragData[0] = outCd;
  gl_FragData[1] = vec4(depth, outEffectGlow, 0.0, 1.0);
  gl_FragData[2] = vec4(vNormal.xyz*.5+.5,1.0);
  gl_FragData[3] = vec4( 1.0, 1.0, 0.0,1.0);
  gl_FragData[4] = vec4(vec3(0.0),1.0);


}
#endif

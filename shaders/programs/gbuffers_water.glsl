// GBuffer - Water GLSL
// Written by Kevin Edzenga, ProcStack; 2022-2024
//


#ifdef VSH
#define gbuffers_water

#include "/shaders.settings"
#include "utils/shadowCommon.glsl"

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

varying float vKeepBack;
varying vec4 vPos;
varying vec3 vLocalPos;
varying vec4 vNormal;
varying float vNormalSunDot;
varying mat3 tbnMatrix;



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

  
  vPos = gl_ProjectionMatrix * position;
  gl_Position = vPos;
  
  vPos = gl_ModelViewMatrix * gl_Vertex;
	vLocalPos = gl_Vertex.xyz;

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
  
  
  
  vNormal.xyz = normalize(gl_NormalMatrix * gl_Normal);
  vNormal.a = 0.02;
  
  //vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
  vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;

  
  vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
  vec3 binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
  tbnMatrix = mat3(tangent.x, binormal.x, vNormal.x,
           tangent.y, binormal.y, vNormal.y,
           tangent.z, binormal.z, vNormal.z);
  
  
	
	
	
  vKeepBack = mc_Entity.x == 301 ? 1.0 : -dot(normalize(vLocalPos.xyz),gl_Normal.xyz);

#ifdef OVERWORLD
  
  vNormalSunDot = dot(normalize(shadowLightPosition), vNormal.xyz);
	
  // Shadow Prep --
	// Invert vert  modelVert positions 
  float depth = min(1.5, length(position.xyz)*.015 );
  vec3 shadowPosition = mat3(gbufferModelViewInverse) * position.xyz + gbufferModelViewInverse[3].xyz;

  vec3 shadowNormal = gl_Normal;
  float shadowPushAmmount =  (depth*.5 + .0010 ) ;
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
  
  // Water
  if (mc_Entity.x == 703){
    avgCd = texture2D(gcolor, mc_midTexCoord.st);
    avgCd += texture2D(gcolor, mc_midTexCoord.st+txlquart);
    avgCd *= .5;
    //color.rgb=vec3(.35,.35,.85);
    color = color*avgCd;
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
#include "utils/shadowCommon.glsl"
#include "utils/mathFuncs.glsl"
#include "utils/texSamplers.glsl"

uniform sampler2D gcolor;
uniform sampler2D lightmap;
uniform sampler2D gaux1; // Dynamic Lighting
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

varying float vKeepBack;
varying vec4 vPos;
varying vec4 vNormal;
varying float vNormalSunDot;
varying mat3 tbnMatrix;

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
  //vec4 txCd = diffuseSample( gcolor, tuv, texelSize, 0.0 );
  //vec4 txCd = diffuseSample( gcolor, tuv, vtexcoordam, texelSize-.0005, 1.0 );
  vec4 txCd = diffuseNoLimit( gcolor, tuv, texelSize*0.50 );
  vec4 baseCd =  texture2D(gcolor, tuv);// 
  
	if ( vKeepBack < 0.0 ){
		discard;
	}
	
  vec2 luv = lmcoord.st;
  vec4 lightVal = texture2D(lightmap, luv);
  
  vec4 outCd = color;// * vec4(vec3(lightVal),1.0);
  outCd*= mix(vec4(1.0),txCd,vTextureInf);//+0.5;
  
	vec2 screenSpace = (vPos.xy/vPos.z)  * vec2(aspectRatio);

  float depth = min(1.0, max(0.0, gl_FragCoord.w));
	float depthBias = biasToOne(depth, 10.5);
  //outCd.rgb = mix( fogColor, outCd.rgb, smoothstep(.0,.01,depth) );
  outCd.rgb = mix( fogColor*vec3(.8,.8,.9), outCd.rgb, min(1.0,depth*80.0)*.8+.2 ) * lightVal.rgb;


	float lightLumaBase = biasToOne( lightVal.r );




  // -- -- -- -- -- -- -- --
  // Based on shadow lookup from Chocapic13's HighPerformance Toaster
  //
  float shadowDist = 0.0;
  float diffuseSun = 1.0;
  float shadowAvg = 1.0;
  vec4 shadowCd = vec4(0.0);
  float reachMult = 0.0;
  
  float toCamNormalDot = dot(normalize(-vPos.xyz*vec3(1.3,1.35,1.3)),vNormal.xyz)+.2;
  float surfaceShading = 9.0-abs(toCamNormalDot);

  float fogColorBlend = 1.0;
  
    // -- -- -- -- -- -- -- -- -- -- -- --
    // -- Shadow Sampling & Influence - -- --
    // -- -- -- -- -- -- -- -- -- -- -- -- -- --
#ifdef OVERWORLD
		float lightLuma = shiftBlackLevels( lightLumaBase ); // lightCd.r;
    vec3 lightCd = vec3(lightLuma);
    
#if ShadowSampleCount > 0

  vec3 localShadowOffset = shadowPosOffset;
  localShadowOffset.z *= (skyBrightnessMult*.5+.5);
  localShadowOffset.z = 0.5 - min( 1.0, (shadowThreshBase + shadowThreshDist*(2.0-depthBias)) * shadowThreshold );
  
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
  
    shadowAvg = mix( shadowAvg, shadow2D(shadowtex0, projectedShadowPosition).x, axisSamplesFit);
  }
#elif ShadowSampleCount == 3
  vec2 posOffset;
  
  for( int x=0; x<boxSamplesCount; ++x){
    posOffset = boxSamples[x]*reachMult*shadowMapTexelSize;
    projectedShadowPosition = vec3(shadowPosLocal.xy+posOffset,shadowPosLocal.z) * shadowPosMult + localShadowOffset;
    shadowAvg = mix( shadowAvg, shadow2D(shadowtex0, projectedShadowPosition).x, boxSampleFit);
  }
#elif ShadowSampleCount > 3
  vec2 posOffset;
  
  for( int x=0; x<boxSamplesCount; ++x){
    posOffset = boxSamples[x]*reachMult*shadowMapTexelSize;
    projectedShadowPosition = vec3(shadowPosLocal.xy+posOffset,shadowPosLocal.z) * shadowPosMult + localShadowOffset;
    shadowAvg = mix( shadowAvg, shadow2D(shadowtex0, projectedShadowPosition).x, boxSampleFit);
  }
#endif

  
  float shadowDepthInf = clamp( (depth*distancDarkenMult), 0.0, 1.0 );
  shadowDepthInf *= shadowDepthInf;
	
	// Verts not facing the sun should never have non-1.0 shadow values
	shadowCd.rgb = mix( vec3(1.0), shadowCd.rgb, min(1.0,step(-.01,vNormalSunDot)*shadowDepthInf));

  // Distance Rolloff
  shadowAvg = shadowAvg + min(1.0, (length(vLocalPos.xz)*.0025)*1.5);
  
  float shadowInfFit = 0.025;
  float shadowInfFitInv = 40.0;// 1.0/shadowInfFit;
  float shadowSurfaceInf = min(1.0, max(0.0,(shadowInfFit-(-dot(normalize(shadowLightPosition), vNormal.xyz)))*shadowInfFitInv )*1.5);
  
  
  // -- -- --
  //  Distance influence of surface shading --
  shadowAvg = mix( (shadowAvg*shadowSurfaceInf), min(shadowAvg,shadowSurfaceInf), shadowAvg)*skyBrightnessMult * (1-rainStrength) * dayNightMult;
  // -- -- --
  diffuseSun *= mix( max(0.0,shadowDepthInf-rainStrength), shadowAvg, sunMoonShadowInf * shadowSurfaceInf );

#endif


  // -- -- -- -- -- -- -- --
  // -- Lighting & Diffuse - --
  // -- -- -- -- -- -- -- -- -- --
    
  // Mute Shadows during Rain
  diffuseSun = mix( diffuseSun, 0.50, rainStrength);          
  
  lightCd = max( lightCd, diffuseSun);
	// Mix translucent color
	lightCd = mix( lightCd, shadowCd.rgb, clamp(shadowData.r*(1.0-shadowBase)
	                                      //* max(0.0,shadowDepthInf*2.0-1.0)
																				- shadowData.b*2.0, 0.0, 1.0) );
	lightLuma = min( maxComponent(lightCd), lightLuma );

  // Strength of final shadow
  outCd.rgb *= mix(max(vec3(shadowAvg),lightCd*.7), vec3(1.0),shadowAvg);
	//outCd.rgb = mix(lightCd*shadowAvg, outCd.rgb, shadowCd.a);
	

  fogColorBlend = skyBrightnessMult;
  
  lightCd = mix( lightCd, max(lightCd, vec3(shadowAvg)), shadowAvg) ;
  


  surfaceShading *= mix( dayNightMult, vNormalSunDot, sunMoonShadowInf*.5+.5 );
    
  // Apply Black Level Shift from User Settings
  //   Since those set to 0 would be rather low,
  //     Default is to run black shift with no check.
    lightCd = shiftBlackLevels( lightCd );
    surfaceShading = max( surfaceShading, lightCd.r );
    surfaceShading = shiftBlackLevels( surfaceShading );
    
  // -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
  // -- 'Specular' Roll-Off; Radial Highlights -- --
  // -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
    
    
    //outCd.rgb += outCd.rgb * depthBias * surfaceShading *fogColor; // -.2;
    outCd.rgb *= lightCd.xyz; // -.2;
#endif







    float distMix = min(1.0,gl_FragCoord.w);
    float waterLavaSnow = float(isEyeInWater);
    if( isEyeInWater == 1 ){ // Water
      float smoothDepth=min(1.0, smoothstep(.01,.30,depth));
      outCd.rgb *= lightVal.xyz * fogColor * ( 1.3-(1.0-smoothDepth)*.5 );
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
      outCd.rgb = vec3( luma(color.rgb) * lightVal.xyz );
    }
		
		
  #if ( DebugView == 4 )
    float debugBlender = step( .0, vPos.x);
    outCd = mix( baseCd*vec4(color.rgb,1.0)*lightVal.xyz, outCd, debugBlender);
  #endif

    gl_FragData[0] = outCd;
    gl_FragData[1] = vec4(vec3( min(.9999,gl_FragCoord.w) ), 1.0);
    gl_FragData[2] = vec4(vNormal.xyz*.5+.5,1.0);
    gl_FragData[3] = vec4(glowHSV,1.0);

}

#endif

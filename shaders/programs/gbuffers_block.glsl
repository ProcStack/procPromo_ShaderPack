// GBuffer - Block Entities GLSL
// Written by Kevin Edzenga, ProcStack; 2022-2023
//

#ifdef VSH

#define ONE_TILE 0.015625
#define THREE_TILES 0.046875

#include "/shaders.settings"
#include "utils/shadowCommon.glsl"

uniform sampler2D gcolor;
uniform vec3 sunVec;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform int blockEntityId;

uniform vec2 texelSize;

uniform float viewWidth;
uniform float viewHeight;

uniform float frameTimeCounter;

attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;
in vec3 at_velocity; // vertex offset to previous frame

// -- -- -- -- -- -- -- --

varying vec4 lmtexcoord;
varying vec4 texcoord;
varying vec2 texcoordmid;
varying vec4 texcoordminmax;
varying vec4 color;
varying vec4 avgColor;
varying vec4 lmcoord;
varying vec2 texmidcoord;

varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec2 vtexcoord;

varying vec4 vPos;
varying vec4 vLocalPos;
varying vec3 vNormal;
varying vec3 vScreenUV;
varying vec2 vTexelSize;

varying vec3 sunVecNorm;
varying vec3 vWorldNormal;
varying vec3 vAnimFogNormal;

varying float vAlphaMult;

varying float vDetailBlurringMult;
varying float vAltTextureMap;
varying float vGlowMultiplier;

varying float vBlendPerc;
varying float vChestBlender;
varying float vColorOnly;
varying float vWorldTime;

#ifdef OVERWORLD
	// Sun Moon Influence
	uniform mat4 shadowModelView;
	uniform mat4 shadowProjection;

	uniform float dayNight;
	uniform int moonPhase;
	uniform ivec2 eyeBrightnessSmooth;
	uniform float eyeBrightnessFit;
	uniform vec3 shadowLightPosition;

	
	varying float vNormalSunDot;
	varying float skyBrightnessMult;
	varying float dayNightMult;
	varying float sunPhaseMult;
	varying vec4 shadowPos;
#endif



// == Chocapic13's HighPerformance Toaster; Shadow-space helpers ==
//      If it aint broke, don't fix it
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition),-viewSpacePosition.z);
}


void main() {
  vec3 normal = gl_NormalMatrix * gl_Normal;
  vec3 position = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
  lmtexcoord.xy = gl_MultiTexCoord0.xy;
  vWorldNormal = mat3(gbufferModelViewInverse) * gl_Normal;
  vAnimFogNormal = gl_NormalMatrix*vec3(1.0,0.0,0.0);
	vWorldTime = sin(frameTimeCounter*.01);

  // -- -- -- -- -- -- -- --
  
  
  sunVecNorm = normalize(sunPosition);

  vPos = gl_ProjectionMatrix * gl_Vertex;
  vPos = ftransform();
  gl_Position = vPos;

  vLocalPos = vec4(position,1.0);
  vPos = vec4(position.xyz,1.0);
  //vPos = gbufferProjectionInverse * gbufferModelViewInverse * gl_Vertex;

  vNormal = normalize(normal);

#ifdef OVERWORLD
  
  vNormalSunDot = dot(normalize(shadowLightPosition), vNormal.xyz);
	
  // Shadow Prep --
	// Invert vert  modelVert positions 
  float depth = min(1.5, length(position.xyz)*.015 );
  vec3 shadowPosition = mat3(gbufferModelViewInverse) * position.xyz + gbufferModelViewInverse[3].xyz;

  vec3 shadowNormal = mat3(shadowProjection) * mat3(shadowModelView) * gl_Normal;
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










  
  vScreenUV = mat3(gbufferModelViewInverse) * gl_Normal;
  
  color = gl_Color;


  vec4 textureUV = gl_MultiTexCoord0;



  vTexelSize = vec2(1.0/viewWidth,1.0/viewHeight);
  texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;


  vec2 midcoord = (gl_TextureMatrix[0] *  vec4(mc_midTexCoord,0.0,1.0)).st;
texcoordmid=midcoord;
  vec2 texelhalfbound = texelSize*16.0;
  texcoordminmax = vec4( midcoord-texelhalfbound, midcoord+texelhalfbound );
  
  
  vec2 txlquart = texelSize*8.0;
  avgColor = texture2D(gcolor, mc_midTexCoord);
  avgColor += texture2D(gcolor, mc_midTexCoord+txlquart);
  avgColor += texture2D(gcolor, mc_midTexCoord+vec2(txlquart.x, -txlquart.y));
  avgColor += texture2D(gcolor, mc_midTexCoord-txlquart);
  avgColor += texture2D(gcolor, mc_midTexCoord+vec2(-txlquart.x, txlquart.y));
  avgColor *= .2;

/*
  vec2 txlquart = texelSize*8.0;
  float avgDiv=0;
  vec4 curAvgCd = texture2D(gcolor, mc_midTexCoord);
  avgDiv = curAvgCd.a;
  avgColor = curAvgCd;
  curAvgCd += texture2D(gcolor, mc_midTexCoord+txlquart);
  avgDiv += curAvgCd.a;
  avgColor += curAvgCd;
  curAvgCd += texture2D(gcolor, mc_midTexCoord+vec2(txlquart.x, -txlquart.y));
  avgDiv += curAvgCd.a;
  avgColor += curAvgCd;
  curAvgCd += texture2D(gcolor, mc_midTexCoord-txlquart);
  avgDiv += curAvgCd.a;
  avgColor += curAvgCd;
  curAvgCd += texture2D(gcolor, mc_midTexCoord+vec2(-txlquart.x, txlquart.y));
  avgDiv += curAvgCd.a;
  avgColor += curAvgCd;
  avgColor *= 1.0/avgDiv;
*/  

  lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

  gl_FogFragCoord = gl_Position.z;

  
  vec2 texcoordminusmid = texcoord.xy-midcoord;
  texmidcoord = midcoord;
  vtexcoordam.pq = abs(texcoordminusmid)*2.0;
  vtexcoordam.st = min(texcoord.xy ,midcoord-texcoordminusmid);
  vtexcoord = sign(texcoordminusmid)*0.5+0.5;
  
  

  #ifdef SEPARATE_AO
    color.rgb = gl_Color.rgb;
  #else
    color.rgb = gl_Color.rgb*gl_Color.a;
  #endif
  
  vAlphaMult=1.0;
  vBlendPerc=1.0;
  vChestBlender=0.0;
  vColorOnly=0.0;


  // General Alt Texture Reads
  vAltTextureMap=1.0;
  vGlowMultiplier=1.0;
  vec2 prevTexcoord = texcoord.zw;
  texcoord.zw = texcoord.st;
  if( mc_Entity.x == 901 || mc_Entity.x == 801 ){
    texcoord.zw = texcoord.st;
    vColorOnly=.001;
    //color.rgb=vec3(1.0);
    vAltTextureMap = 0.0;
  }else if( blockEntityId == 902 ){ // Chests / Trapped Chests
    vColorOnly = 1.0;
    avgColor.rgb = vec3(0.6235294117647059, 0.4352941176470588, 0.1372549019607843)*.9;
    vChestBlender = 0.75;
  }else if( blockEntityId == 910 ){ // Copper Chests
    vColorOnly = 0.5;
    avgColor = vec4(0.5333333333333333, 0.3098039215686275, 0.2313725490196078, 1.0)*2.;
    vBlendPerc = 0.5;
  }else if( blockEntityId == 911 ){ // Exposed Copper Chests
    vColorOnly = 0.5;
    avgColor = vec4(0.3882352941176471, 0.3098039215686275, 0.2431372549019608, 1.0)*2.5;
    vBlendPerc = 0.5;
  }else if( blockEntityId == 912 ){ // Weathered Copper Chests
    vColorOnly = 0.5;
    avgColor = vec4(0.2666666666666667, 0.4392156862745098, 0.3058823529411765, 1.0)*2.5;
    vBlendPerc = 0.5;
  }else if( blockEntityId == 913 ){ // Oxidized Copper Chests
    vColorOnly = 0.5;
    avgColor = vec4(0.2352941176470588, 0.4745098039215686, 0.3882352941176471, 1.0)*2.;
    vBlendPerc = 0.5;
  }
  
}

#endif




/* */
/* */
/* */



#ifdef FSH
/* RENDERTARGETS: 0,1,2,7,6 */

#define gbuffers_terrain
/* --
const int gcolorFormat = RGBA8;
const int gdepthFormat = RGBA16;
const int gnormalFormat = RGB10_A2;
 -- */


#include "/shaders.settings"
#include "utils/mathFuncs.glsl"
#include "utils/shadowCommon.glsl"
#include "utils/texSamplers.glsl"



uniform sampler2D gcolor;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D noisetex; // Custom Texture; textures/SoftNoise_1k.jpg
uniform int fogMode;
uniform vec3 fogColor;
uniform vec3 sunPosition;
uniform int blockEntityId;
uniform int isEyeInWater;
uniform float BiomeTemp;
uniform int moonPhase;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform float near;
uniform float far;
uniform sampler2D gaux1;
uniform sampler2DShadow shadow;

uniform vec2 texelSize;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;


// To Implement
uniform vec4 spriteBounds;
//uniform float wetness;  //rainStrength smoothed with wetnessHalfLife or drynessHalfLife
//uniform int fogMode;
//uniform float fogStart;
//uniform float fogEnd;
//uniform int fogShape;
//uniform float fogDensity;
//uniform int heldBlockLightValue;
//uniform int heldBlockLightValue2;


uniform vec3 upPosition;

// -- -- -- -- -- -- -- --

varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 avgColor;
varying vec4 texcoord;
varying vec2 texcoordmid;
varying vec4 texcoordminmax;
varying vec4 lmcoord;

varying vec2 texmidcoord;
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec2 vtexcoord;

varying vec4 vPos;
varying vec4 vLocalPos;
varying vec3 vNormal;
varying vec3 vScreenUV;
varying vec3 vWorldNormal;
varying vec3 vAnimFogNormal;

varying vec3 sunVecNorm;
varying float vAlphaMult;
varying float vAltTextureMap;
varying float vGlowMultiplier;

varying float vBlendPerc;
varying float vChestBlender;
varying float vColorOnly;
varying float vWorldTime;

#ifdef OVERWORLD
	// Sun Moon Influence
	uniform sampler2DShadow shadowtex0;
	uniform sampler2D shadowcolor0;
	uniform sampler2D shadowcolor1;
	uniform float rainStrength;
	uniform float sunMoonShadowInf;
	uniform vec3 shadowLightPosition;
	
	varying float vNormalSunDot;
	varying float skyBrightnessMult;
	varying float dayNightMult;
	varying float sunPhaseMult;
	varying vec4 shadowPos;
#endif

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;


void main() {
    
    float colorValue =  rgb2hsv(color.rgb).z;
    float blockShading = color.a * (sin( colorValue*PI*.5 )*.5+.5);
    
    vec3 diffuseLight = vec3(0.0);

    
	
    vec2 tuv = texcoord.st;
    if( vAltTextureMap > .5 ){
      tuv = texcoord.zw;
    }
    vec2 luv = lmcoord.st;

    float glowInf = 0.0;
    vec3 glowCd = vec3(0,0,0);


    // -- -- -- -- -- -- --
    
    vec4 txCd;
    if( DetailBlurring > 0 ){
        txCd = diffuseSample( gcolor, tuv, vtexcoordam, texelSize, DetailBlurring * 2.0 * vBlendPerc );
        //txCd = diffuseNoLimit( gcolor, tuv, texelSize*vec2(3.75,2.1)*DetailBlurring );
    }else{
      txCd = texture2D(gcolor, tuv);
    }

  #if ( DebugView == 4 )
    float debugDiscard = step( .0, vPos.x);
    if (txCd.a < .2 && debugDiscard==0.0){
      discard;
    }
  #endif
  
    float depth = min(1.0, max(0.0, gl_FragCoord.w));
    float depthBias = biasToOne(depth, 4.5);
    
    
    vec4 lightBaseCd = texture2D(lightmap, luv);
		float lightLumaBase = biasToOne( lightBaseCd.r );
    vec3 lightCd = lightBaseCd.rgb; //(lightBaseCd.rgb*.7+.3);//*(fogColor*.5+.5);
    lightCd.rgb *= LightWhiteLevel;
    vec4 outCd = txCd * vec4(lightCd,1.0) * vec4(color.rgb,1.0);
    float avgBlender = vColorOnly * clamp(1.0-(1.0-dot(txCd.rgb, avgColor.rgb)*.75)*1.5, 0.0, 1.0);
  if( blockEntityId == 902 ){ // Chests / Trapped Chests; Non-Branching
    //chestAvgBlender = max( 1.0-max(dot(normalize(txCd.rgb), normalize(avgColor.rgb))-.65, 0.0)*5.0, 0.0 );
    float chestAvgBlender = max( 1.0 - abs(dot(normalize(txCd.rgb), normalize(avgColor.rgb))-1.0)*20.0, 0.0 );
    avgBlender = mix( avgBlender, chestAvgBlender, vChestBlender );
  }
    outCd.rgb = mix( outCd.rgb, avgColor.rgb * color.rgb, avgBlender );

#ifdef OVERWORLD
    vec4 blockLumVal =  vec4(lightCd,1.0);
#endif
#ifdef NETHER
    vec4 blockLumVal =  vec4(fogColor*.4+.4,1);
#endif
#ifdef THE_END
    vec4 blockLumVal =  vec4(1,1,1,1);
#endif







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

  
  float shadowDepthInf = clamp( (depth*Distance_DarkenMult), 0.0, 1.0 );
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
  
  //lightCd = max( lightCd, diffuseSun);
	// Mix translucent color
	lightCd = mix( lightCd, shadowCd.rgb, clamp(shadowData.r*(1.0-shadowBase)
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
  outCd.rgb*=lightCd;


  surfaceShading *= mix( dayNightMult, max(0.0,vNormalSunDot), sunMoonShadowInf*.5+.5 );
    
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
    outCd.rgb *= lightCd.xyz*1.1; // -.2;
#endif



  
  float glowValueMult = 1.0;
  
  if(blockEntityId == 706){
    //outCd.rgb = vNormal.xyz;
    
    // Screen Space UVing
    vec2 screenSpace = (gl_FragCoord.xy);
    screenSpace = (screenSpace*texelSize)-.5;
    
    float dotToCam = dot( vNormal, normalize(vPos.xyz))*.3;
    
    vec2 uvProj = screenSpace.yx;
    //uvProj *= (1.0-depthBias)*.1+.8 ;
    uvProj.x += dotToCam;
    
    float ftime = vWorldTime;
    float pxVal = uvProj.x*-100.0;
    float pyVal = fract(uvProj.y*3.0+ftime*50.);
    float uvShift = sin( pxVal + pyVal + uvProj.y*ftime*0.1  );
    uvShift *= abs(uvShift);
    uvProj.x += uvShift*.02*screenSpace.y;
    uvProj += vec2(ftime*5.1,ftime*5.1);
    uvProj.y+=cos( (uvProj.x+uvProj.y) *ftime*2.2+sin(uvProj.y*ftime*6.7)*.35);
    uvProj = fract(uvProj);
    
    
    outCd = texture2D(gcolor, uvProj);
    glowValueMult = outCd.r*.4;
    outCd = outCd * color ;
    glowCd += outCd.rgb*glowValueMult;
  }


  vec3 glowHSV = rgb2hsv(glowCd);
  //glowHSV.z *= glowInf * (depthBias*.5+.2) * GlowBrightness;
  //glowHSV.z *= glowInf * (depth*.2+.8) * GlowBrightness * .5;// * lightLuma;
  glowHSV.z *= vGlowMultiplier * glowValueMult;

  #if ( DebugView == 4 )
    float debugBlender = step( vPos.x, .0 );
    float debugCdMult=color.r*color.g*color.b;
    debugCdMult = step(.998, debugCdMult);
    outCd = mix( outCd, (texture2D(gcolor, tuv)*debugCdMult+(1.0-debugCdMult)) * lightBaseCd * color, debugBlender);
  #endif
	
    //outCd.rgb = vec3( avgBlender );
    gl_FragData[0] = outCd;
    gl_FragData[1] = vec4(vec3( min(.999,gl_FragCoord.w) ), 1.0);
    gl_FragData[2] = vec4(vNormal*.5+.5, 1.0);
    //gl_FragData[3] = vec4(vec3(blockShading), 1.0);
    gl_FragData[3] = vec4(diffuseLight, 1.0);
    gl_FragData[4] = vec4( glowHSV, 1.0);

    
}

#endif


#ifdef VSH

#include "/utils/shadowCommon.glsl"
const float eyeBrightnessHalflife = 4.0f;

#define SEPARATE_AO

#define ONE_TILE 0.015625
#define THREE_TILES 0.046875

#include "/shaders.settings"

uniform sampler2D texture;
uniform vec3 sunVec;
uniform vec4 lightCol;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 cameraPosition;

uniform int blockEntityId;
uniform vec2 texelSize;

uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform int worldTime;

attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;
attribute vec4 at_tangent; 
in vec3 at_velocity; // vertex offset to previous frame

// Glow Pass Varyings --
varying float blockFogInfluence;
varying float txGlowThreshold;
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

varying float sunInfMult;    
varying float sunDot;

varying vec4 vPos;
varying vec4 vLocalPos;
varying vec3 vNormal;
varying vec2 vTexelSize;

varying vec3 sunVecNorm;
varying vec3 upVecNorm;
varying float dayNight;
varying vec4 shadowPos;
varying vec3 shadowOffset;
varying vec3 vWorldNormal;
varying vec3 vAnimFogNormal;

varying float vAlphaMult;

varying float vDetailBluringMult;
varying float vMultiTexelMap;

varying float vAltTextureMap;
varying float vGlowMultiplier;

varying float vColorOnly;
varying float vIsLava;
varying float vLightingMult;

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(gl_ProjectionMatrix, viewSpacePosition),-viewSpacePosition.z);
}


void main() {
	vec3 normal = gl_NormalMatrix * gl_Normal;
	vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
	lmtexcoord.xy = gl_MultiTexCoord0.xy;
  vWorldNormal = gl_Normal;
  vAnimFogNormal = gl_NormalMatrix*vec3(1.0,0.0,0.0);
  // -- -- -- -- -- -- -- --
  
  
	sunVecNorm = normalize(sunPosition);
	upVecNorm = normalize(upPosition);
	dayNight = dot(sunVecNorm,upVecNorm);

vLocalPos = gl_Vertex;
  vPos = gl_ProjectionMatrix * gl_Vertex;
	gl_Position = vPos;

  vPos = vec4(position,1.0);
  
	color = gl_Color;


  vec4 textureUV = gl_MultiTexCoord0;



  vTexelSize = vec2(1.0/viewWidth,1.0/viewHeight);                                   
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;


	vec2 midcoord = (gl_TextureMatrix[0] *  vec4(mc_midTexCoord,0.0,1.0)).st;
texcoordmid=midcoord;
  vec2 texelhalfbound = texelSize*16.0;
  texcoordminmax = vec4( midcoord-texelhalfbound, midcoord+texelhalfbound );
  
  
  vec2 txlquart = texelSize*8.0;
    avgColor = texture2D(texture, mc_midTexCoord);
    avgColor += texture2D(texture, mc_midTexCoord+txlquart);
    avgColor += texture2D(texture, mc_midTexCoord+vec2(txlquart.x, -txlquart.y));
    avgColor += texture2D(texture, mc_midTexCoord-txlquart);
    avgColor += texture2D(texture, mc_midTexCoord+vec2(-txlquart.x, txlquart.y));
    avgColor *= .2;

/*
  vec2 txlquart = texelSize*8.0;
  float avgDiv=0;
  vec4 curAvgCd = texture2D(texture, mc_midTexCoord);
  avgDiv = curAvgCd.a;
  avgColor = curAvgCd;
  curAvgCd += texture2D(texture, mc_midTexCoord+txlquart);
  avgDiv += curAvgCd.a;
  avgColor += curAvgCd;
  curAvgCd += texture2D(texture, mc_midTexCoord+vec2(txlquart.x, -txlquart.y));
  avgDiv += curAvgCd.a;
  avgColor += curAvgCd;
  curAvgCd += texture2D(texture, mc_midTexCoord-txlquart);
  avgDiv += curAvgCd.a;
  avgColor += curAvgCd;
  curAvgCd += texture2D(texture, mc_midTexCoord+vec2(-txlquart.x, txlquart.y));
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
  
  
  vNormal = normalize(normal);
  
  //vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
  vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
  sunDot = dot( vNormal, normalize(sunPosition) );
  sunDot = dot( vNormal, normalize(localSunPos) );
  sunDot = dot( (gbufferModelViewInverse*gl_Vertex).xyz, normalize(vec3(1.0,0.,0.) ));

  
           
           
  // -- -- -- -- -- -- -- --



	float NdotU = gl_Normal.y*(0.17*15.5/255.)+(0.83*15.5/255.);
  #ifdef SEPARATE_AO
	lmtexcoord.zw = gl_MultiTexCoord1.xy*vec2(15.5/255.0,NdotU*gl_Color.a)+0.5;
  #else
  lmtexcoord.zw = gl_MultiTexCoord1.xy*vec2(15.5/255.0,NdotU)+0.5;
  #endif

	gl_Position = toClipSpace3(position);
	float diffuseSun = clamp(  (dot(normal,sunVec)*.8+.2)  *lightCol.a,0.0,1.0);


	shadowPos.x = 1e30;
	//skip shadow position calculations if far away
	//normal based rejection is useless in vertex shader
	//if (gl_Position.z < shadowDistance + 28.0){
  
		position = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;
    
    float wtMult = (worldTime*.1);//*.01+1.;
    float rotVal = 0;
    vec4 posVal = vec4( -.5, 0, 0, 1 );
    
    // rotVal = 90*3.14159265358979323/180;
    rotVal = -1.5707963267948966;
    //rotVal = wtMult;
    /*mat4 xRotMat = mat4( 
                vec4( 1, 0, 0, 0 ),
                vec4( 0, cos(rotVal), -sin(rotVal), 0 ),
                vec4( 0, sin(rotVal), cos(rotVal), 0 ),
                posVal
              );
    mat4 yRotMat = mat4( 
                vec4( cos(rotVal), 0, sin(rotVal), 0 ),
                vec4( 0, 1, 0, 0 ),
                vec4( -sin(rotVal), 0, cos(rotVal), 0 ),
                posVal
              );
    mat4 zRotMat = mat4( 
                vec4( cos(rotVal), -sin(rotVal), 0, 0 ),
                vec4( sin(rotVal), cos(rotVal), 0, 0 ),
                vec4( 0, 0, 1, 0 ),
                posVal
              );*/

  
		shadowPos.xyz = mat3(shadowModelView) * position.xyz + shadowModelView[3].xyz;
		//vec3 rainingShadowPos = mat3(yRotMat) * position.xyz + yRotMat[3].xyz;
		//vec3 rainingShadowPos =  mat3(xRotMat) * position.xyz + xRotMat[3].xyz;
		//vec3 rainingShadowPos =  mat3(zRotMat) * zRotMat[3].xyz;
		//vec3 rainingShadowPos =  mat3(xRotMat) * position.xyz + xRotMat[3].xyz;
    
    //shadowPos.xy = mix( shadowPos.xy, rainingShadowPos.xy, clamp(position.z+2,0,1) );
    
    
    vec3 shadowProjDiag = diagonal3(shadowProjection);
    float spdLength = length( shadowProjDiag );
    vec3 projRot = (shadowProjDiag);
    projRot.x = cos( shadowProjDiag.x+wtMult ) + sin( shadowProjDiag.z+wtMult );
    projRot.z = cos( shadowProjDiag.z+wtMult ) + sin( shadowProjDiag.x+wtMult );
    //projRot = normalize(projRot)*spdLength;
    projRot = shadowProjDiag;
		shadowPos.xyz = projRot * shadowPos.xyz + shadowProjection[3].xyz;
    
	//}



  // -- -- -- -- -- -- -- --
  // Shadow Prep

  //shadowPos.xyz = mat3(shadowModelView) * position.xyz + shadowModelView[3].xyz;
  //vec3 shadowProjDiag = diagonal3(shadowProjection);
  //shadowPos.xyz = shadowProjDiag * shadowPos.xyz + shadowProjection[3].xyz;


  // -- -- -- -- -- -- -- --
  
  
  vAlphaMult=1.0;
  vColorOnly=0.0;

  blockFogInfluence = 1.0;
  if (mc_Entity.x == 803){
    blockFogInfluence = 0.2;
  }
  
  txGlowThreshold = 1.0; // Off
  if (mc_Entity.x == 804){
    txGlowThreshold = .7;
    blockFogInfluence = 0.6;
  }
                                                    
                                                     
                            
   
  
  
  // Leaves
  if (mc_Entity.x == 810 && SolidLeaves){
    //shadowPos.w = -2.0;
    //diffuseSun = diffuseSun*0.35+0.4;
    //color.rgb *= 1.1;
    vAlphaMult=0.0;
    vColorOnly=.001;
    vAltTextureMap=1.0;
    //vColorOnly=.0;
  }
  








  // General Alt Texture Reads
  vAltTextureMap=1.0;
  vGlowMultiplier=1.0;
  vec2 prevTexcoord = texcoord.zw;
  texcoord.zw = texcoord.st;
  if (mc_Entity.x == 901 || mc_Entity.x == 801){

    texcoord.zw = texcoord.st;
    vColorOnly=.001;
    //color.rgb=vec3(1.0);
    vAltTextureMap = 0.0;

  }
  
  
  // Lava
  vIsLava=0.0;
  if (mc_Entity.x == 701){
    vIsLava=1.0;
    vColorOnly=1.10;
    //vColorOnly=1.30;
    color.rgb = mix( avgColor.rgb, texture2D(texture, midcoord).rgb, .5 );
  }
  if (mc_Entity.x == 702){
    vIsLava=1.0;
    //vColorOnly=0.10;
    //vColorOnly=1.30;
    color.rgb = avgColor.rgb;//mix( avgColor.rgb, texture2D(texture, midcoord).rgb, .5 );
  }

  // Amethyst Block
  vLightingMult=1.0;
  if (mc_Entity.x == 909){
    texcoord.zw = texcoord.st;
    vColorOnly=0.50;
    vLightingMult = 1.2;
    avgColor.rgb = vec3(.35,.15,.7);
    //color.rgb = mix( avgColor.rgb, texture2D(texture, midcoord).rgb, .7 );
  }
  // Amethyst Clusters
  if (mc_Entity.x == 910){
    texcoord.zw = texcoord.st;
    //vColorOnly=0.100;
    vLightingMult = 1.2;
    //color.rgb = avgColor.rgb;//mix( avgColor.rgb, texture2D(texture, midcoord).rgb, .5 );
  }
  

  //color.a = diffuseSun * gl_MultiTexCoord1.y;
  sunInfMult = diffuseSun * gl_MultiTexCoord1.y;
//color.a=1.0;//
                                                                              
  //color = mix( gl_Color, color, eyeBrightnessSmooth.y/240.0);
  //color = gl_Color;

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
#include "/utils/shadowCommon.glsl"
#include "/utils/mathFuncs.glsl"
#include "/utils/texSamplers.glsl"



uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D colortex4; // Minecraft Vanilla Texture Atlas
uniform sampler2D colortex5; // Minecraft Vanilla Glow Atlas
uniform sampler2D noisetex; // Custom Texture; textures/SoftNoise_1k.jpg
uniform int fogMode;
uniform vec3 fogColor;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
uniform int isEyeInWater;
uniform float BiomeTemp;
uniform int moonPhase;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform float near;
uniform float far;
uniform sampler2D gaux1;
uniform sampler2DShadow shadow;
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;

uniform vec4 lightCol;
uniform vec2 texelSize;

uniform int worldTime;
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
uniform float rainStrength;


uniform vec3 upPosition;

// Glow Pass Varyings --
varying float blockFogInfluence;
varying float txGlowThreshold;
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

varying float sunInfMult;
varying float sunDot;

varying vec4 vPos;
varying vec4 vLocalPos;
varying vec3 vNormal;
varying vec3 vWorldNormal;
varying vec3 vAnimFogNormal;

varying vec3 sunVecNorm;
varying vec3 upVecNorm;
varying float dayNight;
varying vec4 shadowPos;
varying vec3 shadowOffset;
varying float vAlphaMult;
varying float vAltTextureMap;
varying float vGlowMultiplier;

varying float vColorOnly;
varying float vIsLava;
varying float vLightingMult;



// Sildurs
//faster and actually more precise than pow 2.2
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;



void main() {
  

  // -- -- -- -- -- -- -- --
  // Modded shadow lookup Chocapic13's HighPerformance Toaster
  //  (I'm still learning this shadow stuffs)
  //
	gl_FragData[0] = texture2D(texture, lmtexcoord.xy);
  float shadowDist = 0.0;
  
	//if (gl_FragData[0].a > 0.0 ) {
		float diffuseSun = sunInfMult/255.;
#ifdef OVERWORLD
		if (color.a > 0.0001 && shadowPos.x < 1e10) {
      float distort = calcDistort(shadowPos.xy);
      vec2 spCoord = shadowPos.xy / distort;
      if (abs(spCoord.x) < 1.0-1.5/shadowMapResolution && abs(spCoord.y) < 1.0-1.5/shadowMapResolution) {
        float diffthresh = 0.0006*shadowDistance/45.;
        if (shadowPos.w > -1.0) diffthresh = 0.0004*512./shadowMapResolution*shadowDistance/45.*distort/diffuseSun;

        vec3 projectedShadowPosition = vec3(spCoord, shadowPos.z) * vec3(0.5,0.5,0.5/3.0) + vec3(0.5,0.5,0.5-diffthresh);
        
        float shadowAvg=shadow2D(shadow, projectedShadowPosition).x;
        
        for( int x=0; x<boxSamplesCount; ++x){
          projectedShadowPosition = vec3(spCoord+boxSamples[x]*.001, shadowPos.z) * vec3(0.5,0.5,0.5/3.0) + vec3(0.5,0.5,0.5-diffthresh);
        
          shadowAvg = mix( shadowAvg, shadow2D(shadow, projectedShadowPosition).x, .1);
        }
        for( int x=0; x<boxSamplesCount; ++x){
          projectedShadowPosition = vec3(spCoord+boxSamples[x]*.0015, shadowPos.z) * vec3(0.5,0.5,0.5/3.0) + vec3(0.5,0.5,0.5-diffthresh);
        
          shadowAvg = mix( shadowAvg, shadow2D(shadow, projectedShadowPosition).x, .05);
        }
        diffuseSun *= shadowAvg;
			}
		}
#endif


  // -- -- -- -- -- -- -- --
  // -- Lighting & Diffuse - --
  // -- -- -- -- -- -- -- -- -- --
    
    
    diffuseSun = smoothstep(.4,.8,diffuseSun); 
    // Mute Shadows during Rain
    diffuseSun = mix( diffuseSun*.6+.6, 1.0, rainStrength);
    
    //float blockShading = max( diffuseSun, (sin( color.a*PI*.5 )*.5+.5) );
    float blockShading = diffuseSun * (sin( color.a*PI*.5 )*.5+.5);
    
		vec3 lightmapcd = texture2D(gaux1,lmtexcoord.zw*texelSize).xyz;// *.5+.5;
		vec3 diffuseLight = mix(lightCol.rgb*.5+.5, vec3(1,1,1),.7) ;
		diffuseLight *= max(lightmapcd, vec3(blockShading) ) ;
    
    
    vec2 tuv = texcoord.st;
    if( vAltTextureMap > .5 ){
      tuv = texcoord.zw;
    }
    vec2 luv = lmcoord.st;

    float glowInf = texture2D(colortex5, tuv).x;
    vec3 glowCd = vec3(0,0,0);


    // -- -- -- -- -- -- --
    
    vec4 txCd;
    // Why was #if breaking?????
    //   Future me; asign to variable first
    if( DetailBluring > 0 ){
      // Block's pre-modified, no need to blur again
      if(vColorOnly>.0){
        txCd = texture2D( colortex4, tuv);//diffuseSampleNoLimit( texture, tuv, texelSize* DetailBluring*(1.0-vIsLava));
      }else{
        txCd = diffuseSample( texture, tuv, vtexcoordam, texelSize, DetailBluring*2.0 );
        //txCd = diffuseNoLimit( texture, tuv, texelSize*vec2(3.75,2.1)*DetailBluring );
      }
      //txCd = texture2D(texture, tuv);
    }else{
      txCd = texture2D(texture, tuv);
    }

      //txCd = texture2D(colortex4, texcoord.zw* vec2( .25, .25 )+vec2( 0.0, 0.546875 ));
      //txCd = diffuseNoLimit( texture, tuv, texelSize*DetailBluring*2.0 );
      //txCd = texture2D(texture, tuv);
    if (txCd.a < .2){
      discard;
    }
    
    // Screen Space UVing and Depth
    vec2 screenSpace = (gl_FragCoord.xy/gl_FragCoord.z);
    screenSpace = (screenSpace*texelSize)-.5;
    //float screenDewarp = length(screenSpace)*.5;
    float screenDewarp = length(screenSpace)*0.7071067811865476; //length(vec2(.5,.5))
    //float depth = min(1.0, max(0.0, gl_FragCoord.w-screenDewarp));
    float depth = min(1.0, max(0.0, gl_FragCoord.w));
    float depthBias = biasToOne(depth, 4.5);
    
    
    vec4 lightBaseCd = texture2D(lightmap, luv);
    vec3 lightCd = lightBaseCd.rgb;//*vLightingMult; //(lightBaseCd.rgb*.7+.3);//*(fogColor*.5+.5)*vLightingMult;
    lightCd.rgb *= LightingBrightness;
    //vec4 outCd = txCd * vec4(lightCd,1.0) * vec4(color.rgb,1.0);
    
#ifdef OVERWORLD
    vec4 blockLumVal =  vec4(lightCd,1.0);
#endif
#ifdef NETHER
    vec4 blockLumVal =  vec4(fogColor*.4+.4,1);
#endif
#ifdef THE_END
    vec4 blockLumVal =  vec4(1,1,1,1);
#endif

    float lightLuma = luma(blockLumVal.rgb);
    
    // Set base color
    vec4 outCd = vec4(txCd.rgb,1.0) * vec4(color.rgb,1.0);
    outCd = mix( vec4(outCd.rgb,1.0),  vec4(color.rgb,1.0), vColorOnly*(1.0-depthBias*.3));
    outCd = mix( outCd,  vec4(avgColor.rgb,1.0), vColorOnly*(1.0-depthBias*.3));



    
    
    //outCd.rgb = mix( avgColor.rgb*color.rgb, outCd.rgb, depthBias*.5+.5);
    
    // Sun/Moon Lighting
    float toCamNormalDot = dot(normalize(-vPos.xyz*vec3(1.0,.91,1.0)),vNormal);
    float surfaceShading = 1.0-abs(toCamNormalDot);

#ifdef OVERWORLD
    
    float sunPhaseMult = max(0.0,dot( sunVecNorm, upVecNorm));
    
    float skyBrightnessMult=eyeBrightnessSmooth.y*0.004166666666666666;//  1.0/240.0
    float moonPhaseMult = (1+mod(moonPhase+3,8))*.25;
    moonPhaseMult = min(1.0,moonPhaseMult) - max(0.0, moonPhaseMult-1.0);
    moonPhaseMult = (moonPhaseMult*.4+.1);
    
    diffuseLight *= mix( moonPhaseMult, 1.0, clamp(dayNight*2.0+.5, 0.0, 1.0) );

    surfaceShading *= mix( .55*moonPhaseMult, dot(sunVecNorm,vNormal)*.15+.05, dayNight*.5+.5 );
    surfaceShading *= sunPhaseMult;
    surfaceShading *= (1.0-rainStrength)*.5+.5;
#endif
    
    //outCd.rgb += mix(fogColor,vec3(lightLuma),gl_FragCoord.w) * surfaceShading;// -.2;

    // Nether Logic
#ifdef NETHER
    float colorRed = outCd.r;
    outCd.rgb = rgb2hsv(outCd.rgb);
    outCd.g = mix( outCd.g, min(1.0,outCd.g*1.4), min(1.0, abs(1.0-colorRed-.5)*20.0) );
    outCd.b = mix( outCd.b, min(1.0,outCd.b*1.3), min(1.0, abs(1.0-colorRed-.5)*20.0) );
    outCd.rgb = hsv2rgb(outCd.rgb);
#endif
    
    // Lighting influence
    outCd.rgb *=  lightLuma+glowInf;
  //outCd.rgb *= lightCd;

    // -- -- -- -- -- -- --
    
    // TODO : Update isEyeInWater to not be ifs
    float distMix = min(1.0,gl_FragCoord.w);
    float waterLavaSnow = float(isEyeInWater);
    if( isEyeInWater == 1 ){ // Water
      float smoothDepth=min(1.0, smoothstep(.01,.1,depth));
      outCd.rgb *=  1.0+lightLuma+glowInf;
      outCd.rgb = mix( outCd.rgb*(fogColor*.2+.8), outCd.rgb*fogColor*( 1.0-smoothDepth*.5 ), max(0.0,( 1.0-smoothDepth )-glowInf*5.0) );
    }else if( isEyeInWater > 1 ){ // Lava
      outCd.rgb = mix( outCd.rgb, fogColor, (1.0-distMix*.1) );
    //}else if( isEyeInWater == 3 ){ // Snow
      //outCd.rgb = mix( outCd.rgb, fogColor, (1.0-distMix*.1) );
    }else{
      outCd.rgb = mix( fogColor*vec3(.8,.8,.9), outCd.rgb, min(1.0,depth*80.0)*.8+.2+glowInf );
    }

    
    
// -- -- -- -- -- -- -- -- -- -- 
// End Logic; Animated Fog  - -- --
// -- -- -- -- -- -- -- -- -- -- -- --

#ifdef THE_END
      float depthEnd = min(1.0, gl_FragCoord.w*38.0-screenDewarp);
      float fogInf = min(1.0, gl_FragCoord.w*64.0-screenDewarp);
      fogInf *= fogInf;
    
      float lightMax = max( lightCd.r, max( lightCd.g, lightCd.b ) );
      //float facingMultOrig=clamp( dot(normalize(-gl_FragCoord.xyz), vNormal)*.7+.5, 0.0, 1.0);
      float facingMultOrig=clamp( dot(normalize(vLocalPos.xyz), vWorldNormal)*.7+.5, 0.0, 1.0);
      
      
      //vec2 rotUV = rotToUV(vAnimFogNormal);
      vec2 rotUV = rotToUV(vec3(-vLocalPos.x, -vAnimFogNormal.y, -vLocalPos.z));
      rotUV.y = (rotUV.y-.5)*.5+.5;
      screenSpace = (screenSpace)*(1.0-depthEnd)*.5;
      screenSpace = vec2( screenSpace.x, -screenSpace.y);
      screenSpace = fract( rotUV-screenSpace );
      float timeOffset = (worldTime*0.00004166666)*80.0;
      vec3 ssNoiseInit = texture2D( noisetex, fract(screenSpace)).rgb;
      vec3 ssNoiseCd = texture2D( noisetex, fract(screenSpace+(ssNoiseInit.rg-.5+timeOffset*.5)*.5+(ssNoiseInit.br-.5)*.2)).rgb;
      float fogNoise = ssNoiseCd.r*ssNoiseCd.g*ssNoiseCd.b;
      vec3 endFogCd = vec3(.75,.5,.75);
      endFogCd = mix( endFogCd*fogNoise + (ssNoiseCd-.3)*.7, endFogCd, depthEnd*.7+.3);
      
      float facingMult = mix( 1.0, facingMultOrig, max(0.0, (1.0-depthEnd*.5)-lightMax) );
      vec3 cdFogMix = outCd.rgb*mix( endFogCd*facingMult, vec3( facingMult ), min(1.0,fogInf+lightMax*.2));
      
      float cdMaxVal = max( txCd.r, max( txCd.g, txCd.b) );
      float txGlow = smoothstep(.35,.65, cdMaxVal)*3.0*(1.0-depthEnd*.7);
      cdFogMix = mix( outCd.rgb+outCd.rgb*txGlow, cdFogMix, blockFogInfluence*.45+.55);
      outCd.rgb = mix( outCd.rgb*endFogCd*(facingMult*.5+.5), cdFogMix, min(1.0,depthEnd*depthEnd+(1.0-blockFogInfluence)));
      glowCd = addToGlowPass(glowCd, outCd.rgb*txGlow*(1.0-blockFogInfluence)*(depthEnd));
      
      outCd.rgb *= min(1.0, dot(vWorldNormal,vec3(0,1,0))*.25+.75);
#endif
    
    /*
    vec3 worldPos = fract(abs(cameraPosition+vLocalPos.xyz)*.01);
    worldPos = fract( worldPos+texture2D( noisetex, worldPos.xz).rgb );
    vec3 noiseInit = texture2D( noisetex, tuv).rgb;
    //vec3 noiseAnim = texture2D( softnoisetex, fract(tuv+noiseInit.rg + noiseInit.br)).rgb;
    outCd.rgb = noiseInit;//sin( fract(worldPos.x*.1) * TAU);
    vec3 noiseX = texture2D( noisetex, worldPos.xy).rgb;
    vec3 noiseZ = texture2D( noisetex, fract(worldPos.zy+noiseX.rg)).rgb;
    vec3 noiseY = texture2D( noisetex, fract(worldPos.xz+noiseZ.br)).rgb;
    vec3 noiseCd = mix( noiseX, noiseZ, abs(vWorldNormal.x));
    noiseCd = mix( noiseCd, noiseY, abs(vWorldNormal.y));
    */
    
    // TODO : Why I turn this off?
    //if( glowMultVertColor > 0.0 ){
      //float outCdMin = min(outCd.r, min( outCd.g, outCd.b ) );
      //float outCdMin = max(outCd.r, max( outCd.g, outCd.b ) );
      //float outCdMin = max(txCd.r, max( txCd.g, txCd.b ) );
      //glowCd = addToGlowPass(glowCd, mix(txCd.rgb,outCd.rgb,.5)*step(txGlowThreshold,outCdMin)*(depth*.5+.5));
    //}
    
    
    
    // Texcoord fit to block
    //vec2 localUV = vec2(0.0);
    //localUV.x = (tuv.x-texcoordminmax.x) / (texcoordminmax.z-texcoordminmax.x);
    //localUV.y = (tuv.y-texcoordminmax.y) / (texcoordminmax.w-texcoordminmax.y);
    
    
// -- -- -- -- -- -- -- -- -- -- -- -- -- --
// Mightcraft Lighting, not Shadow Pass - -- --
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

  //outCd.rgb *= mix(diffuseLight.rgb, vec3(1.0), lightLuma);
#ifdef OVERWORLD
  //outCd.rgb *= 1.0+(lightBaseCd.rgb*.3-.5);
#endif

#ifdef NETHER
    outCd.rgb *= mix( outCd.rgb+outCd.rgb*vec3(1.6,1.3,1.2), vec3(1.0), (depthBias)*.4+.4);
    outCd.rgb = mix( fogColor, outCd.rgb*lightCd, smoothstep(.015, .45, depthBias+glowInf));
#else
    outCd.rgb *= mix(1.0, toCamNormalDot*.5+.5, depth*.7+.3);
#endif


    
    //outCd.rgb = mix( outCd.rgb,vec3( txCd.a,txCd.a,txCd.a), step(screenSpace.y,0.0));
    //outCd.rgb = mix( outCd.rgb, (texture2D(texture, tuv) * blockLumVal * vec4(color.rgb,1.0)).rgb, step(screenSpace.x,0.0));
    
    //blockShading = max( blockShading, lightLuma );// lightLuma is lightCd
    
    
// -- -- -- -- -- -- -- -- -- -- -- -- -- --
// Biome & Snow Glow when in a Cold Biome - -- --
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
#ifdef OVERWORLD
    // Snow glow when in a cold biome
    float frozenSnowGlow = 1.0-(0.0,smoothstep(.0,.2,BiomeTemp));
    glowCd = addToGlowPass(glowCd, outCd.rgb*frozenSnowGlow*.8*max(0.06,-dayNight)*max(0.0,(1.0-depth*3.0)));
    //float cdBrightness = min(1.0,max(0.0,dot(txCd.rgb,vec3(1.0))));
    //cdBrightness *= cdBrightness;
    //outCd.rgb *= 1.0+cdBrightness*frozenSnowGlow*3.5*max(0.06,-dayNight)*(1.0-rainStrength);
    outCd.rgb *= 1.0+frozenSnowGlow*3.5*max(0.06,-dayNight)*(1.0-rainStrength);
    outCd.rgb *= 1.0-rainStrength*.5;
    
    //float skyBrightMultFit = 1.5-skyBrightnessMult*.5*(1.0-frozenSnowGlow);
    //outCd.rgb *= skyBrightMultFit;
    outCd.rgb*=mix(vec3(1.0), diffuseLight, skyBrightnessMult*sunPhaseMult);
#endif
    
    

    //outCd.rgb *= skyBrightMultFit;
    
    glowCd = outCd.rgb;
    //glowCd += vec3(1.0-distMix);
    //glowCd *= skyBrightMultFit;


    vec3 glowHSV = rgb2hsv(glowCd);
    //glowHSV.z *= glowInf * (depthBias*.5+.2) * GlowBrightness;
    glowHSV.z *= glowInf * (depth*.2+.8) * GlowBrightness * .5;// * lightLuma;

#ifdef NETHER
    glowHSV.z *= vGlowMultiplier;
#else
    glowHSV.z *= vGlowMultiplier*.7;
#endif

    outCd.rgb+=glowHSV.z;


    float outDepth = min(.9999999,gl_FragCoord.w);
    
    gl_FragData[0] = outCd;
    gl_FragData[1] = vec4(vec3( outDepth ), 1.0);
    gl_FragData[2] = vec4(vNormal*.5+.5, 1.0);
    //gl_FragData[3] = vec4(vec3(diffuseSun, outDepth, 0.0), 1.0);
    gl_FragData[3] = vec4(vec3(blockShading, outDepth, 0.0), 1.0);
    //gl_FragData[3] = vec4(vec3(blockShading), 1.0);
    //gl_FragData[3] = vec4(diffuseLight, 1.0);
    //gl_FragData[3] = vec4(vec3(blockShading), 1.0);
    gl_FragData[4] = vec4( glowHSV, 1.0);

	//}
}


#endif


#ifdef VSH

#define ONE_TILE 0.015625
#define THREE_TILES 0.046875

#include "/shaders.settings"

uniform sampler2D texture;
uniform vec3 sunVec;
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
in vec3 at_velocity; // vertex offset to previous frame

// Glow Pass Varyings --
varying float blockFogInfluence;
varying float glowMultVertColor;
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
varying vec3 debug;

varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec2 vtexcoord;

varying float sunDot;

varying vec4 vPos;
varying vec4 vLocalPos;
varying vec3 vNormal;
varying vec3 vScreenUV;
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
	vec3 position = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
	lmtexcoord.xy = gl_MultiTexCoord0.xy;
  vWorldNormal = mat3(gbufferModelViewInverse) * gl_Normal;
  vAnimFogNormal = gl_NormalMatrix*vec3(1.0,0.0,0.0);
  // -- -- -- -- -- -- -- --
  
  
	sunVecNorm = normalize(sunPosition);
	upVecNorm = normalize(upPosition);
	dayNight = dot(sunVecNorm,upVecNorm);

  vPos = gl_ProjectionMatrix * gl_Vertex;
  vPos = ftransform();
	gl_Position = vPos;

  vLocalPos = vec4(position,1.0);
  vPos = vec4(position.xyz,1.0);
  //vPos = gbufferProjectionInverse * gbufferModelViewInverse * gl_Vertex;

  
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
	float diffuseSun = clamp(dot(normal,sunVec),0.0,1.0);


	shadowPos.x = 1e30;
	//skip shadow position calculations if far away
	//normal based rejection is useless in vertex shader
	//if (gl_Position.z < shadowDistance + 28.0){
  
		position = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;
    


  
		shadowPos.xyz = mat3(shadowModelView) * position.xyz + shadowModelView[3].xyz;

    
    vec3 shadowProjDiag = diagonal3(shadowProjection);
    float spdLength = length( shadowProjDiag );
		shadowPos.xyz = shadowProjDiag * shadowPos.xyz + shadowProjection[3].xyz;
    
	//}


  #ifdef SEPARATE_AO
    color.rgb = gl_Color.rgb;
  #else
    color.rgb = gl_Color.rgb*gl_Color.a;
  #endif

  // Left from Sildurs
  if (mc_Entity.x == 801){
    shadowPos.w = -2.0;
    diffuseSun = diffuseSun*0.35+0.4;
    color.rgb *= 1.1;
  }
  
  vAlphaMult=1.0;
  vColorOnly=0.0;

  
  blockFogInfluence = 1.0;
  glowMultVertColor=0.0;
  if (mc_Entity.x == 803){
    blockFogInfluence = 0.2;
    glowMultVertColor = 0.8;
  }
  
  txGlowThreshold = 1.0; // Off
  if (mc_Entity.x == 804){
    txGlowThreshold = .7;
    blockFogInfluence = 0.6;
  }
  
  
  // Leaves
  if (mc_Entity.x == 810 && SolidLeaves){
    shadowPos.w = -2.0;
    diffuseSun = diffuseSun*0.35+0.4;
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
  

  color.a = diffuseSun*gl_MultiTexCoord1.y;
color.a=1.0;//

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
#include "utils/mathFuncs.glsl"
#include "utils/texSamplers.glsl"
#include "utils/shadowCommon.glsl"



uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D noisetex; // Custom Texture; textures/SoftNoise_1k.jpg
uniform int fogMode;
uniform vec3 fogColor;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
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
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;

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
varying float glowMultVertColor;
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

varying float sunDot;

varying vec4 vPos;
varying vec4 vLocalPos;
varying vec3 vNormal;
varying vec3 vScreenUV;
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

varying vec3 debug;


// Sildurs
//faster and actually more precise than pow 2.2
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;


void main() {
	gl_FragData[0] = texture2D(texture, lmtexcoord.xy);
  float shadowDist = 0.0;
  vec4 shadowFull=vec4(0.0);
	//if (gl_FragData[0].a > 0.0 ) {
		float diffuseSun = color.a/255.;
#ifdef OVERWORLD
		if (color.a > 0.0001 && shadowPos.x < 1e10) {
			float distort = calcDistort(shadowPos.xy);
			vec2 spCoord = shadowPos.xy / distort;
			if (abs(spCoord.x) < 1.0-1.5/shadowMapResolution && abs(spCoord.y) < 1.0-1.5/shadowMapResolution) {
					float diffthresh = 0.0006*shadowDistance/45.;
					if (shadowPos.w > -1.0) diffthresh = 0.0004*2048./shadowMapResolution*shadowDistance/45.*distort/diffuseSun;

          vec3 projectedShadowPosition = vec3(spCoord, shadowPos.z) * vec3(0.5,0.5,0.5/3.0) + vec3(0.5,0.5,0.5-diffthresh);
          
          shadowFull = shadow2D(shadow, projectedShadowPosition);

          float shadowAvg=shadow2D(shadow, projectedShadowPosition).x;
          for( int x=0; x<boxSamplesCount; ++x){
            projectedShadowPosition = vec3(spCoord+boxSamples[x]*.001, shadowPos.z) * vec3(0.5,0.5,0.5/3.0) + vec3(0.5,0.5,0.5-diffthresh);
          
            shadowAvg = mix( shadowAvg, shadow2D(shadow, projectedShadowPosition).x, .1);
          }
          for( int x=0; x<boxSamplesCount; ++x){
            projectedShadowPosition = vec3(spCoord+boxSamples[x]*.0015, shadowPos.z) * vec3(0.5,0.5,0.5/3.0) + vec3(0.5,0.5,0.5-diffthresh);
          
            shadowAvg = mix( shadowAvg, shadow2D(shadow, projectedShadowPosition).x, .1);
          }
          diffuseSun *= shadowAvg;
			}
		}
#endif
    
    // Mute Shadows during Rain
    //diffuseSun = mix( diffuseSun*.8+.2, 1.0, rainStrength);
    
    
    float colorValue =  rgb2hsv(color.rgb).z;
    float blockShading = diffuseSun * (sin( colorValue*PI*.5 )*.5+.5);
    
		vec3 lightmapcd = texture2D(gaux1,lmtexcoord.zw*texelSize).xyz;
		vec3 diffuseLight = mix(lightmapcd, vec3(1,1,1),.7)*blockShading;// * lightmapcd;
    vec3 lightingHSV = rgb2hsv(diffuseLight);
    
    vec2 tuv = texcoord.st;
    if( vAltTextureMap > .5 ){
      tuv = texcoord.zw;
    }
    vec2 luv = lmcoord.st;

    float glowInf = 0.0;
    vec3 glowCd = vec3(0,0,0);


    // -- -- -- -- -- -- --
    
    vec4 txCd;
    // Why was #if breaking?????
    if( DetailBluring > 0 ){
        txCd = diffuseSample( texture, tuv, vtexcoordam, texelSize, DetailBluring*2.0 );
        //txCd = diffuseNoLimit( texture, tuv, texelSize*vec2(3.75,2.1)*DetailBluring );
    }else{
      txCd = texture2D(texture, tuv);
    }

    if (txCd.a < .2){
      discard;
    }
    
    float depth = min(1.0, max(0.0, gl_FragCoord.w));
    float depthBias = biasToOne(depth, 4.5);
    
    
    vec4 lightBaseCd = texture2D(lightmap, luv);
    vec3 lightCd = lightBaseCd.rgb; //(lightBaseCd.rgb*.7+.3);//*(fogColor*.5+.5)*vLightingMult;
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
    vec4 outCd = vec4(txCd.rgb,1.0) * color;
    outCd = mix( vec4(outCd.rgb,1.0),  vec4(color.rgb,1.0), vColorOnly*(1.0-depthBias*.3));
    outCd = mix( outCd,  vec4(avgColor.rgb,1.0), vColorOnly*(1.0-depthBias*.3));
    //outCd = mix( vec4(outCd.rgb,1.0),  vec4(outCd.rgb,1.0), vIsLava);
    
    // Sun/Moon Lighting
    //float toCamNormalDot = dot(normalize(-vLocalPos.xyz*vec3(1.0,.91,1.0)),vNormal);
    //float surfaceShading = 1.0-abs(toCamNormalDot);

#ifdef OVERWORLD
    
    float moonPhaseMult = (1+mod(moonPhase+3,8))*.25;
    moonPhaseMult = min(1.0,moonPhaseMult) - max(0.0, moonPhaseMult-1.0);
    moonPhaseMult = (moonPhaseMult*.4+.1);
    
    diffuseLight *= mix( moonPhaseMult, 1.0, clamp(dayNight*2.0+.5, 0.0, 1.0) );

    //surfaceShading *= mix( .55*moonPhaseMult, dot(sunVecNorm,vNormal)*.15+.05, dayNight*.5+.5 );
    //surfaceShading *= max(0.0,dot( sunVecNorm, upVecNorm));
    //surfaceShading *= (1.0-rainStrength)*.5+.5;
#endif
    
    //float envBrightness = eyeBrightnessSmooth.y/240.0;
    //outCd.rgb += mix(fogColor,vec3(lightLuma),gl_FragCoord.w) * surfaceShading *.5 ;
    
    
    // Lighting influence
    //outCd.rgb *=  lightLuma+glowInf;

    
    
  outCd.rgb *= lightCd;

    
    
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
      
      float pxVal = uvProj.x*-100.0;
      float pyVal = uvProj.y*10.0;
      uvProj.x += sin( pxVal + pyVal + worldTime*.1)*.007;
      uvProj += vec2(worldTime*.002,worldTime*.0015);
      uvProj = fract(uvProj);
      
      
      outCd = texture2D(texture, uvProj);
      glowValueMult = outCd.r*.4;
      outCd = outCd * color ;
      glowCd += outCd.rgb*glowValueMult;
    }


    vec3 glowHSV = rgb2hsv(glowCd);
    //glowHSV.z *= glowInf * (depthBias*.5+.2) * GlowBrightness;
    //glowHSV.z *= glowInf * (depth*.2+.8) * GlowBrightness * .5;// * lightLuma;
    glowHSV.z *= vGlowMultiplier * glowValueMult;


    gl_FragData[0] = outCd;
    gl_FragData[1] = vec4(vec3( min(.999,gl_FragCoord.w) ), 1.0);
    gl_FragData[2] = vec4(vNormal*.5+.5, 1.0);
    //gl_FragData[3] = vec4(vec3(blockShading), 1.0);
    gl_FragData[3] = vec4(diffuseLight, 1.0);
    gl_FragData[4] = vec4( glowHSV, 1.0);

    
}

#endif


// -- -- -- -- -- -- -- -- -- -- -- -- --
// -- Vertex Shader Compiler Directive -- --
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

#ifdef VSH

#define SEPARATE_AO

uniform sampler2D texture;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D shadowcolor0;

uniform float eyeBrightnessFit;
uniform vec3 shadowLightPosition;
uniform vec3 sunVec;
uniform vec3 sunPosition;
uniform float dayNight;
uniform int moonPhase;
uniform float moonPhaseFitted;

uniform float rainStrength;


attribute vec2 mc_midTexCoord;
attribute vec4 mc_Entity;
attribute vec2 vaUV0;                                 // texture (u, v)                              1.17+
attribute ivec2 vaUV1;                                // overlay (u, v)                              1.17+
attribute ivec2 vaUV2;                                // lightmap (u, v)                             1.17+
attribute vec3 vaNormal;                              // normal (x, y, z)                            1.17+             
attribute vec4 at_tangent;                            // xyz = tangent vector, w = handedness
attribute vec3 at_midBlock;                           // offset to block center in 1/64m units       Only for blocks

varying vec4 vPos;
varying vec4 vWorldPos;
varying vec2 vUv;
varying vec2 vLightUV;
varying vec4 vColor;
varying vec4 vAvgColor;
varying float vAvgColorBlend;
varying vec3 vNormal;
varying vec3 vWorldNormal;
varying vec3 vTangent;

varying vec2 vAtlasMid;
varying vec4 vAtlasFit; // .st for add, .pq for mul

#ifdef OVERWORLD
	varying float vRainInfluence;
	varying float vRainInfluenceFit;
  varying float skyBrightnessMult;
  varying float dayNightMult;
  varying float sunPhaseMult;
	
	varying float vShadowInf;
	varying float vShadowSurface;
	varying vec3 vShadowPos;
	
#endif



varying float vKeepAlpha;
varying float vKeepFrag;
varying float vGlowCdInf;
varying float vGlowCdMult;
varying float vBoostColor;





// -- -- --

#include "/shaders.settings"
#include "utils/mathFuncs.glsl"
#include "utils/texSamplers.glsl"
#include "utils/shadowCommon.glsl"
const float eyeBrightnessHalflife = 4.0f;

// -- -- --



void main() {

	vec4 position = gl_ModelViewMatrix * gl_Vertex;
	gl_Position = gl_ProjectionMatrix * position;
	vPos = gl_Position ;
	vWorldPos = gl_Vertex ;
  float depth = min( 1.0, length(gl_Vertex.xyz)*.007 );
	
	
  vNormal = normalize(gl_NormalMatrix * gl_Normal);
	vWorldNormal = gl_Normal;
  vTangent = at_tangent.xyz;
	
	vColor = gl_Color;

	vUv = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
  
	vLightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;


	vec2 midcoord = (gl_TextureMatrix[0] *  vec4(mc_midTexCoord,0.0,1.0)).xy;
	vec2 atlasFitRange = vUv-midcoord;
  vAtlasMid = midcoord;
	vAtlasFit.pq = abs(atlasFitRange)*2.0;
	vAtlasFit.st = min( vUv, midcoord-atlasFitRange );

	// -- -- --


	
#ifdef OVERWORLD

	// -- -- -- -- -- -- 
  // -- Specifics - -- --
	// -- -- -- -- -- -- -- --

	vRainInfluence = 1.0-rainStrength;
	vRainInfluenceFit = 1.0-rainStrength*.8;


	// -- -- --
	// -- -- -- -- -- -- -- --
  // -- Sun / Moon Prep - -- --
	// -- -- -- -- -- -- -- -- -- --
	
	// Sun Moon Influence
	skyBrightnessMult = 1.0;
	dayNightMult = 0.0;
	sunPhaseMult = 1.0;
  
	skyBrightnessMult=eyeBrightnessFit;
	
	// Sun Influence
	sunPhaseMult = max(0.0,dayNight);
	
	// Moon Influence
	float moonPhaseMult = moonPhaseFitted;
	//float moonPhaseMult = min(1.0,float(mod(moonPhase+4,8))*.125);
	//moonPhaseMult = moonPhaseMult - max(0.0, moonPhaseMult-0.50)*2.0;
	dayNightMult = mix( moonPhaseFitted, 1.0, sunPhaseMult);
	
	
	
#endif

	// -- -- --

	// -- -- -- -- -- --
  // -- Shadow Prep -- --
	// -- -- -- -- -- -- -- --
	
#ifdef OVERWORLD
	vec4 ssPos = toShadowSpace( position, depth, vWorldNormal, gbufferModelViewInverse, shadowProjection, shadowModelView );
	vShadowPos = ssPos.rgb;
	vShadowInf = (1.0 - ssPos.a*ssPos.a) * vRainInfluenceFit  ;
	//vShadowInf = abs( sunVec.x-vNormal.x );
	//vShadowInf =  step(0.0, sunVec.x-vWorldNormal.x );
	//vShadowInf =  abs( sunPosition.x-vNormal.x );
	//vShadowInf =  step(sunVec.z, vNormal.z );
	//vShadowInf = (normalize(gl_NormalMatrix * sunVec)).z;
	
	
	
  float shadowInfFit = 0.025;
  float shadowInfFitInv = 40.0;// 1.0/shadowInfFit;
  float shadowSurfaceInf = min(1.0, max(0.0,(shadowInfFit-(-dot(normalize(shadowLightPosition), vNormal)))*shadowInfFitInv )*1.5);
	
	vShadowSurface = shadowSurfaceInf*.5+.5;
	
	
#endif

	
	
	// -- -- --

	vec4 avgCd = atlasSampler( texture, midcoord, ivec2(5), .2455, vColor );
	
	//vColor = avgCd;
	vAvgColor = mix( vColor, avgCd, step( 2.9, vColor.x + vColor.y + vColor.z) );

	// -- -- --
	
	// Remove alpha from target blocks, only Leaves currently
	vAvgColor = ( SolidLeaves && mc_Entity.x == 101 ) ? vAvgColor*avgCd : vAvgColor;
	vKeepAlpha = ( SolidLeaves && (mc_Entity.x == 101 || mc_Entity.x == 102) ) ? 1.0 : 0.0;
	vKeepFrag = ( mc_Entity.x == 301 ) ? 1.0 : step( -0.10, dot( -normalize(vWorldPos.xyz), vWorldNormal ) );
	vBoostColor = 0.0 ;
	
	// -- -- --
	
	float avgColorBlender = vKeepAlpha;
	
	/*if( !SolidLeaves && (mc_Entity.x == 101 || mc_Entity.x == 102) ){
		vKeepFrag = 1.0;
	}*/
	
	// Lava & Flowing Lava
	if( mc_Entity.x == 701 || mc_Entity.x == 702 ){
		vBoostColor = .3;
		avgColorBlender = .8;
		vAvgColor = avgCd;
	}
	
	
	
	
	//vGlowCdInf = 1.0;
	//vGlowCdMult = 1.0;
	
	gl_FogFragCoord = gl_Position.z;

  /*
  
  // Lava
  if( mc_Entity.x == 701 ){
    vIsLava=.8;
#ifdef NETHER
    vCdGlow=.2;
#else
     vCdGlow=.05;
#endif
    vColor.rgb = mix( vAvgColor.rgb, texture2D(texture, midcoord).rgb, .5 );
  }
  // Flowing Lava
  if( mc_Entity.x == 702 ){
    vIsLava=0.9;
#ifdef NETHER
    vCdGlow=.5;
#else
    vCdGlow=0.25;
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
	
	*/
	
	
	avgColorBlender = max( avgColorBlender, clamp( gl_Position.z*avgCdDepthBlend, 0.0, 1.0 ) );
	vAvgColorBlend = avgColorBlender;
	
	
}
#endif


// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --


// -- -- -- -- -- -- -- -- -- -- -- -- -- --
// -- Fragment Shader Compiler Directive  -- --
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

#ifdef FSH

/* RENDERTARGETS: 0,2,8,1,7 */
//  0-gtexture  2-normals  8-tangents   1-Depth   7-colortex4 
//      Color    Normals     Tangents    Depth      GlowHSV

/* --
const int gcolorFormat = RGBA16;
const int gdepthFormat = R32F;
const int gnormalFormat = RGB16F;
const int colortex7Format = RGB16;
const int colortex8Format = RGB16f;
 -- */
 
uniform sampler2D texture;
uniform vec2 texelSize;
uniform float aspectRatio;

uniform sampler2D lightmap;
uniform sampler2DShadow shadow;
uniform sampler2D shadowcolor0;


uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform vec3 shadowLightPosition;

uniform float sunMoonShadowInf;

uniform float darknessFactor;
uniform float darknessLightFactor;

uniform vec3 fogColor;
uniform vec3 skyColor;

varying vec4 vPos;
varying vec4 vWorldPos;
varying vec2 vUv;
varying vec2 vLightUV;
varying vec4 vColor;
varying vec4 vAvgColor;
varying float vAvgColorBlend;
varying vec3 vNormal;
varying vec3 vWorldNormal;
varying vec3 vTangent;

varying vec2 vAtlasMid;
varying vec4 vAtlasFit; // .st for add, .pq for mul

#ifdef OVERWORLD
  varying float vRainInfluence;
  varying float vRainInfluenceFit;
  varying float skyBrightnessMult;
  varying float dayNightMult;
  varying float sunPhaseMult;
	varying float vShadowInf;
	varying float vShadowSurface;
	varying vec3 vShadowPos;
#endif


varying float vKeepAlpha;
varying float vKeepFrag;
varying float vGlowCdInf;
varying float vGlowCdMult;
varying float vBoostColor;

// -- -- --

#include "/shaders.settings"
#include "utils/mathFuncs.glsl"
#include "utils/texSamplers.glsl"
#include "utils/shadowCommon.glsl"

// -- -- --


void main() {
  vec2 tuv = vUv; // Texture Map UV
  vec2 luv = vLightUV ; // Light Map UV
	
	
	vec2 screenSpace = (vPos.xy/vPos.z)  * vec2(aspectRatio);
	
	// Texture Sampler
	vec4 baseTxCd=texture2D(texture, tuv);
	
	// Alpha Test
	baseTxCd.a = max(baseTxCd.a, vKeepAlpha) * vKeepFrag * vColor.a ;

	if( baseTxCd.a < .05 ){
		discard;
	}
	
	//vec4 txCd=baseTxCd;
	vec4 txCd=vec4(1.0,1.0,0.0,1.0);
	float avgDelta = 0.0;
	
	// TODO : There's gotta be a better way to do this...
	//          - There is, just gotta change it over
	if ( DetailBluring > 0.0 ){
		
		// Split Screen "Blur Comparison" Debug View
		#if ( DebugView == 1 )
			float debugDetailBluring = clamp((screenSpace.y/(aspectRatio*.8))*.5+.5,0.0,1.0)*2.0;
			debugDetailBluring = mix( DetailBluring, debugDetailBluring, step(screenSpace.x,0.75));
			//diffuseSampleXYZ( texture, tuv, vAtlasFit, texelSize, debugDetailBluring, baseTxCd, txCd, avgDelta );
			diffuseSampleXYZ( texture, tuv, vAtlasMid, texelSize, debugDetailBluring, baseTxCd, txCd, avgDelta );
		#else
			//diffuseSampleXYZ( texture, tuv, vAtlasFit, texelSize, DetailBluring, baseTxCd, txCd, avgDelta);
			diffuseSampleXYZFetch( texture, tuv, vAtlasMid, texelSize, DetailBluring, baseTxCd, txCd, avgDelta);
		#endif
	}
	//txCd.rgb = mix(vAvgColor.rgb, txCd.rgb, avgDelta);
	
	//avgDelta = clamp( avgDelta*1.750-.5, 0.0, 1.0 );
	//avgDelta =  avgDelta*0.750+0.25;
	
	//txCd.rgb = mix( txCd.rgb, vAvgColor.rgb*baseTxCd.rgb, avgDelta);
	txCd.rgb = mix( baseTxCd.rgb, vAvgColor.rgb*txCd.rgb,  avgDelta);
	
	// Blend sampled texture with block average color
	txCd.rgb = mix( txCd.rgb + (vAvgColor.rgb*vColor.rgb-txCd.rgb)*.5, vAvgColor.rgb, vAvgColorBlend );
	
	
	
	
	// Alpha Test
	//txCd.a = max(baseTxCd.a, vKeepAlpha) * vKeepFrag * vColor.a ;
	
	
  vec3 lightCdBase = texture2D(lightmap, luv).rgb;
	vec3 lightCdBaseFit = clamp((lightCdBase-.1) * 1.1, 0.0, 1.0);
	
  vec3 lightCd = lightCdBase;
	//float lightLuma = luma( lightCdBaseFit );
	float lightLuma = maxComponent( lightCdBaseFit );
	
	float lightLumaFit = max( 0.0, 1.0 - ( (1.0-lightLuma*lightWhiteClipMult) * lightBlackClipMult ) );

	
	float aoNative = biasToOne(vColor.a)*.45+.55;
	lightCd *= vec3(aoNative);
  
	
	// -- -- --
	
	// -- -- -- --
	// -- Depth -- --
	// -- -- -- -- -- --
	
	
  vec4 diffuse = vec4( txCd.rgb, txCd.a ) ;
	
	float depth = min(.9999,gl_FragCoord.w);
	depth = max(0.0,vPos.w);
  float depthFit = min( 1.0, depth*.004 );
	
	// -- -- --
	
	// -- -- -- -- -- -- -- -- --
	// -- Shadow Gather  -- -- -- --
	// -- -- -- -- -- -- -- -- -- -- --
	
#ifdef OVERWORLD
	float diffuseSun = 1.0;
	// Multi-Sample shadow map; Returns 0-1 Sun/Moon shadow only
  diffuseSun = gatherShadowSamples( shadow, vShadowPos, shadowPosOffset, depth );
	
	// Scale shadow influence based on distances from eye & surface normal
  diffuseSun = shadowPositionInfluence( diffuseSun, vWorldPos, vNormal, depth, shadowLightPosition );
	
	float shadowInf = vShadowInf;
	// Respectfully -
	//   Sun / Moon Phase Brightness,  Sun/Moon Angle To Horizon Inf,  Eye Brightness Fitted 0-1, Rain Influence
	diffuseSun *= dayNightMult * sunMoonShadowInf * skyBrightnessMult * vRainInfluence * shadowInf;
	//diffuseSun =    shadowInf;

	float inSunlight =  max(0.0, 1.0-(1.0-diffuseSun)*shadowInfluence*shadowInf) * vRainInfluenceFit;
	lightCd = lightCd * mix( max( lightCd, vec3(diffuseSun) ), vec3(inSunlight), sunPhaseMult*skyBrightnessMult ) ;
	//lightCd = vec3( skyBrightnessMult );
	
	vec4 shcd=texture2D(shadowcolor0, biasShadowShift(vShadowPos).xy*.5+.5 );
	//lightCd = length(1.0-shcd.rgb	)*.5*(dayNightMult*sunMoonShadowInf*skyBrightnessMult) + lightCd * shcd.rgb * vShadowSurface + vec3(1.0-vShadowSurface)*.3;// * shcd.a ;
	////lightCd =  length(1.0-shcd.rgb	)*.5 + lightCd * shcd.rgb * vShadowSurface + vec3(vShadowSurface*sunMoonShadowInf*dayNightMult)*.3;// * shcd.a ;////lightCd =  mix( fogColor, lightCd, shadowInf ) ; // Near, color;  Far, fog color
	//lightCd =  mix( lightCdBaseFit, max(min(vec3(1.0),max(vec3(0.0),lightCd-.35)*5.0),lightCd*lightCdBaseFit+(1.0-shadowInf))*vShadowSurface, skyBrightnessMult ) ;  // Yer inna cave there!
	lightCd =  mix( lightCd*lightCdBaseFit, lightCdBaseFit, inSunlight  ) ;  // Yer inna cave there!

	
#endif

	// Apply Lighting contributions to Diffuse color
	//lightCd = shiftBlackLevels( lightCd );
	diffuse.rgb = diffuse.rgb * shiftBlackLevels( lightCd );
	
	
	/*
#ifdef OVERWORLD
	diffuse.rgb *= min(vec3(1.0), max(vec3(lightCd.rrr), (1.0-(1.0-lightCd.rgb)*.5)*lightCd.rrr-.1)*1.65) ;
	diffuse.rgb *= max(lightCdBaseFit.rgb, vec3(diffuseSun) );
#elif defined NETHER
	//diffuse.rgb = min(vec3(1.0), max(vec3(0.0), (lightCd.rrr-.2)*1.65)) ;
	//diffuse.rgb = vec3( depthFit ) ;
	diffuse.rgb = mix( diffuse.rgb, vAvgColor.rgb*lightCdBaseFit, min(1.0,max(0.0, (lightCd.r+depthFit-.15))*1.5) ) ;
#endif
	*/
	
	diffuse.rgb = diffuse.rgb + diffuse.rgb*vBoostColor ;
	
	// -- -- --

	vec4 glowCd = vec4( max( vec3(0.0), 1.0-((1.0-diffuse.rgb) * vGlowCdMult) ), 1.0 );
	glowCd *= vGlowCdInf;
  vec3 glowHSV = rgb2hsv(glowCd.rgb);
	
	float darknessInf = depthFit * darknessFactor * ((20.0 + 10.0*darknessLightFactor*lightLuma) * (1.0-lightLuma*lightLuma) ) ;
	diffuse.rgb = diffuse.rgb - diffuse.rgb * darknessInf;

	
	gl_FragData[0] = diffuse; 
	gl_FragData[1] = vec4( vNormal, 1.0 ); 
	gl_FragData[2] = vec4( vTangent, 1.0 ); 
	gl_FragData[3] = vec4( depthFit,0.0,0.0, 1.0 );
	gl_FragData[4] = vec4( glowHSV, 1.0 );
}
#endif



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

uniform float eyeBrightnessFit;
uniform float dayNight;
uniform int moonPhase;

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
varying vec4 vTangent;

#ifdef OVERWORLD
	varying float vRainInfluence;
  varying float skyBrightnessMult;
  varying float dayNightMult;
  varying float sunPhaseMult;
#endif

varying float vShadowInf;
varying vec3 shadowPos;


varying float vKeepAlpha;
varying float vKeepFrag;
varying float vGlowCdInf;
varying float vGlowCdMult;





// -- -- --

#include "/shaders.settings"
#include "utils/mathFuncs.glsl"
#include "utils/texSamplers.glsl"
#include "utils/shadowCommon.glsl"

// -- -- --



void main() {

	vec4 position = gl_ModelViewMatrix * gl_Vertex;
	gl_Position = gl_ProjectionMatrix * position;
	vPos = gl_Position ;
	vWorldPos = gl_Vertex ;
  float depth = min( 1.0, length(gl_Vertex.xyz)*.007 );
	
	
  vNormal = normalize(gl_NormalMatrix * gl_Normal);
	vWorldNormal = gl_Normal;
  //vTangent = normalize(gl_NormalMatrix * at_tangent);
	
	vColor = gl_Color;

	vUv = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
  
	vLightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;


	vec2 midcoord = (gl_TextureMatrix[0] *  vec4(mc_midTexCoord,0.0,1.0)).xy;

	// -- -- --

	// -- -- -- -- -- -- 
  // -- Specifics - -- --
	// -- -- -- -- -- -- -- --

#ifdef OVERWORLD
	 vRainInfluence = 1.0 - rainStrength ;
#endif


	// -- -- --


	// -- -- -- -- -- -- -- --
  // -- Sun / Moon Prep - -- --
	// -- -- -- -- -- -- -- -- -- --
	
#ifdef OVERWORLD
	// Sun Moon Influence
	skyBrightnessMult = 1.0;
	dayNightMult = 0.0;
	sunPhaseMult = 1.0;
  
    skyBrightnessMult=eyeBrightnessFit;
    
    // Sun Influence
    sunPhaseMult = 1.0-max(0.0,dayNight);
    
    // Moon Influence
    float moonPhaseMult = min(1.0,float(mod(moonPhase+4,8))*.125);
    moonPhaseMult = moonPhaseMult - max(0.0, moonPhaseMult-0.50)*2.0;
    dayNightMult = mix( 1.0, moonPhaseMult, sunPhaseMult);
#endif

	// -- -- --

	// -- -- -- -- -- --
  // -- Shadow Prep -- --
	// -- -- -- -- -- -- -- --
	
#ifdef OVERWORLD
	vec4 ssPos = toShadowSpace( position, depth, vWorldNormal, gbufferModelViewInverse, shadowProjection, shadowModelView );
	shadowPos = ssPos.rgb;
	vShadowInf = ssPos.a;
#endif

	// -- -- --

	vec4 avgCd = atlasSampler( texture, midcoord, ivec2(6), .455, vColor );
	
	//vColor = avgCd;
	vAvgColor = mix( vColor, avgCd, step( 2.9, vColor.x + vColor.y + vColor.z) );

	// -- -- --
	
	// Remove alpha from target blocks, only Leaves currently
	vAvgColor = ( SolidLeaves && mc_Entity.x == 101 ) ? vAvgColor*avgCd : vAvgColor;
	vKeepAlpha = ( SolidLeaves && (mc_Entity.x == 101 || mc_Entity.x == 102) ) ? 1.0 : 0.0;
	vKeepFrag = ( mc_Entity.x == 301 ) ? 1.0 : step( 0.0, dot( -normalize(vWorldPos.xyz), vWorldNormal ) );
	vAvgColorBlend = vKeepAlpha;
	
	vGlowCdInf = 1.0;
	vGlowCdMult = 1.0;
	
	gl_FogFragCoord = gl_Position.z;
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
//  0-gtexture  2-normals  1-Depth   7-colortex4 
//      Color    Normals     Depth      GlowHSV

/* --
const int gcolorFormat = RGBA16;
const int gdepthFormat = R32F;
const int gnormalFormat = RGB16F;
const int colortex7Format = RGB16;
 -- */
 
uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2DShadow shadow;


uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform vec3 shadowLightPosition;

uniform float sunMoonShadowInf;

varying vec4 vPos;
varying vec4 vWorldPos;
varying vec2 vUv;
varying vec2 vLightUV;
varying vec4 vColor;
varying vec4 vAvgColor;
varying float vAvgColorBlend;
varying vec3 vNormal;
varying vec3 vWorldNormal;
varying vec4 vTangent;

#ifdef OVERWORLD
  varying float vRainInfluence;
  varying float skyBrightnessMult;
  varying float dayNightMult;
  varying float sunPhaseMult;
	varying float vShadowInf;
	varying vec3 shadowPos;
#endif


varying float vKeepAlpha;
varying float vKeepFrag;
varying float vGlowCdInf;
varying float vGlowCdMult;

// -- -- --

#include "/shaders.settings"
#include "utils/mathFuncs.glsl"
#include "utils/texSamplers.glsl"
#include "utils/shadowCommon.glsl"

// -- -- --


void main() {
  vec2 tuv = vUv; // Texture Map UV
  vec2 luv = vLightUV ; // Light Map UV
	
	vec3 normal = vNormal;
	vec3 tangent = vTangent.xyz;
	
	// Texture Sampler
	// ~~ Insert Texture Bluring by Pass ~~
  vec4 txCd = texture2D(texture, tuv);
  
	// Alpha Test
	txCd.a = max(txCd.a, vKeepAlpha) * vKeepFrag;
	if( txCd.a < .05 ){
		discard;
	}
	
	
	// Blend sampled texture with block average color
	txCd.rgb = mix( txCd.rgb * vColor.rgb, vAvgColor.rgb, vAvgColorBlend );
	
	
  vec3 lightCd = texture2D(lightmap, luv).rgb;
	lightCd = clamp((lightCd-.265) * 1.360544217687075, 0.0, 1.0);
	
	float aoNative = biasToOne(vColor.a)*.3+.7;
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
  diffuseSun = gatherShadowSamples( shadow, shadowPos, shadowPosOffset, depth );
	
	// Scale shadow influence based on distances from eye & surface normal
  diffuseSun = shadowPositionInfluence( diffuseSun, vWorldPos, normal, depth, shadowLightPosition );
	
	float shadowInf = 1.0-vShadowInf*vShadowInf;
	// Respectfully -
	//   Sun / Moon Phase Brightness,  Sun/Moon Angle To Horizon Inf,  Eye Brightness Fitted 0-1, Rain Influence
	diffuseSun *= dayNightMult * sunMoonShadowInf * skyBrightnessMult * vRainInfluence * shadowInf;

	float inSunlight =  1.0-(1.0-diffuseSun)*.4*shadowInf;
	lightCd = mix(  max( lightCd*inSunlight, vec3(diffuseSun) ), max( lightCd, vec3(diffuseSun) ) ,  diffuseSun*shadowInf  ) ;
#endif

	// Apply Lighting contributions to Diffuse color
	diffuse.rgb = diffuse.rgb * lightCd;
	
	
	// -- -- --

	
	vec4 glowCd = vec4( max( vec3(0.0), 1.0-((1.0-diffuse.rgb) * vGlowCdMult) ), 1.0 );
	glowCd *= vGlowCdInf;
  vec3 glowHSV = rgb2hsv(glowCd.rgb);

	gl_FragData[0] = diffuse; 
	gl_FragData[1] = vec4( normal, 1.0 ); 
	gl_FragData[2] = vec4( tangent, 1.0 ); 
	gl_FragData[3] = vec4( depthFit,0.0,0.0, 1.0 );
	gl_FragData[4] = vec4( glowHSV, 1.0 );
}
#endif



// -- -- -- -- -- -- -- -- -- -- -- -- --
// -- Vertex Shader Compiler Directive -- --
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

#ifdef VSH

#define SEPARATE_AO

uniform sampler2D texture;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

attribute vec2 mc_midTexCoord;
attribute vec4 mc_Entity;
attribute vec2 vaUV0;                                 // texture (u, v)                              1.17+
attribute ivec2 vaUV1;                                // overlay (u, v)                              1.17+
attribute ivec2 vaUV2;                                // lightmap (u, v)                             1.17+
attribute vec3 vaNormal;                              // normal (x, y, z)                            1.17+             
attribute vec4 at_tangent;                            // xyz = tangent vector, w = handedness
attribute vec3 at_midBlock;                           // offset to block center in 1/64m units       Only for blocks

varying vec4 vPos;
varying vec2 vUv;
varying vec2 vLightUV;
varying vec4 vColor;
varying vec4 vAvgColor;
varying float vAvgColorBlend;
varying vec3 vNormal;
varying vec4 vTangent;

varying float vKeepAlpha;
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
  vNormal = normalize(gl_NormalMatrix * gl_Normal);
  //vTangent = normalize(gl_NormalMatrix * at_tangent);
	
	vColor = gl_Color;

	vUv = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
  
	vLightUV = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;


	vec2 midcoord = (gl_TextureMatrix[0] *  vec4(mc_midTexCoord,0.0,1.0)).xy;


  #if (BaseQuality == 2)
	#endif
	vec4 avgCd = atlasSampler( texture, midcoord, ivec2(6), .455, vColor );
	
	//vColor = avgCd;
	vAvgColor = mix( vColor, avgCd, step( 2.9, vColor.x + vColor.y + vColor.z) );

	// -- -- --
	
	// Remove alpha from target blocks, only Leaves currently
	vAvgColor = ( mc_Entity.x == 101 && SolidLeaves ) ? vAvgColor*avgCd : vAvgColor;
	vKeepAlpha = ( (mc_Entity.x == 101 || mc_Entity.x == 102) && SolidLeaves ) ? 1.0 : 0.0;
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

/* RENDERTARGETS: 0,2,1,7 */
//  0-gtexture  2-normals  1-Depth   7-colortex4 
//      Color    Normals     Depth      GlowHSV

/* --
const int gcolorFormat = RGBA16;
const int gnormalFormat = RGB16;
const int colortex7Format = RGB16;
 -- */
 
uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec4 vPos;
varying vec2 vUv;
varying vec2 vLightUV;
varying vec4 vColor;
varying vec4 vAvgColor;
varying float vAvgColorBlend;
varying vec3 vNormal;
varying vec4 vTangent;

varying float vKeepAlpha;
varying float vGlowCdInf;
varying float vGlowCdMult;

// -- -- --

#include "/shaders.settings"
#include "utils/mathFuncs.glsl"
#include "utils/shadowCommon.glsl"

// -- -- --


void main() {
  vec2 tuv = vUv; // Texture Map UV
  vec2 luv = vLightUV ; // Light Map UV
	
	// Texture Sampler
	// ~~ Insert Texture Bluring by Pass ~~
  vec4 txCd = texture2D(texture, tuv);
  
	// Alpha Test
	txCd.a = max(txCd.a, vKeepAlpha);
	if( txCd.a < .05 ){
		discard;
	}
	
	
	// Blend sampled texture with block average color
	txCd.rgb = mix( txCd.rgb * vColor.rgb, vAvgColor.rgb, vAvgColorBlend );
	
	
  vec3 lightCd = texture2D(lightmap, luv).rgb;
	//lightCd = clamp((lightCd-.265) * 1.360544217687075, 0.0, 1.0);
	
	float aoNative = biasToOne(vColor.a)*.3+.7;
	lightCd *= vec3(aoNative);
  
	
	// -- -- --
	
	// -- -- -- -- -- -- -- -- --
	// -- Shadow Gather  -- -- -- --
	// -- -- -- -- -- -- -- -- -- -- --
	
	
	// -- -- --
	
  vec4 diffuse = vec4( txCd.rgb * lightCd, txCd.a ) ;
	vec3 normal = vNormal;
	float depth = min(.9999,gl_FragCoord.w);
	depth = min(.9999,vPos.w);
	
	vec4 glowCd = vec4( max( vec3(0.0), 1.0-((1.0-diffuse.rgb) * vGlowCdMult) ), 1.0 );
	glowCd *= vGlowCdInf;
  vec3 glowHSV = rgb2hsv(glowCd.rgb);
	
	gl_FragData[0] = diffuse; 
	gl_FragData[1] = vec4( normal, 1.0 ); 
	gl_FragData[2] = vec4( depth,0.0,0.0, 1.0 );
	gl_FragData[3] = vec4( glowHSV, 1.0 );
}
#endif


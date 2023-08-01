
// -- -- -- -- -- -- -- -- -- -- -- -- --
// -- Vertex Shader Compiler Directive -- --
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

#ifdef VSH

uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

attribute vec4 mc_Entity;

varying vec4 vUv;
varying vec4 vLightUV;
varying vec4 vColor;
varying vec3 vNormal;

// -- -- --

#include "/shaders.settings"
#include "utils/mathFuncs.glsl"
#include "utils/shadowCommon.glsl"

// -- -- --

void main() {

	vec4 position = gl_ModelViewMatrix * gl_Vertex;

	gl_Position = gl_ProjectionMatrix * position;

	vColor = gl_Color;

	vUv = gl_TextureMatrix[0] * gl_MultiTexCoord0;
  
	vLightUV = gl_TextureMatrix[0] * gl_MultiTexCoord1;
  
	//float NdotU = gl_Normal.y*(0.17*15.5/255.)+(0.83*15.5/255.);
  //vLightUV.zw = gl_MultiTexCoord1.xy*vec2(15.5/255.0,NdotU)+0.5;

  vNormal = normalize(gl_NormalMatrix * gl_Normal);
  
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
/* RENDERTARGETS: 0,2,7 */
//  0-gtexture     2-normals     7-colortex4 
//      Color    (Normals,Depth)    GlowHSV

/* --
const int gcolorFormat = RGBA16;
const int gnormalFormat = RGBA16;
const int colortex7Format = RGB10_A2;
 -- */
 
uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec4 vUv;
varying vec4 vLightUV;
varying vec4 vColor;
varying vec3 vNormal;


// -- -- --

#include "/shaders.settings"
#include "utils/mathFuncs.glsl"
#include "utils/shadowCommon.glsl"

// -- -- --

void main() {
  vec2 tuv = vUv.st;
  vec4 txCd = texture2D(texture, tuv);
  
	if( txCd.a < .05 ){
		discard;
	}
		
  vec2 luv = vLightUV.zw;
  vec4 lightCd = texture2D( lightmap, luv );
  
  vec4 outCd = txCd * lightCd * vColor ;
	
	gl_FragData[0] = outCd;
	gl_FragData[1] = vec4(vec3(0.0), 1.0);
	gl_FragData[2] = vec4(vec3(0.0), 1.0);
}
#endif


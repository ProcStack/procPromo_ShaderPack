
#ifdef VSH
#include "/shaders.settings"

uniform mat4 gbufferModelViewInverse;
varying vec4 texcoord;
varying vec4 color;
varying vec4 lmcoord;
varying vec3 vNormal;

attribute vec4 mc_Entity;


void main() {

	vNormal = normalize(gl_NormalMatrix * gl_Normal);
  
	vec4 position = gl_ModelViewMatrix * gl_Vertex;

	gl_Position = gl_ProjectionMatrix * position;

	color = gl_Vertex;//*step(1.0,(gl_Vertex.y+60.0)*.015);//*step(0.0, gl_Vertex.y);

	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	//texcoord = gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	
  float NdotU = gl_Normal.y*(0.17*15.5/255.)+(0.83*15.5/255.);
  lmcoord.zw = gl_MultiTexCoord1.xy*vec2(15.5/255.0,NdotU)+0.5;
  
	gl_FogFragCoord = gl_Position.z;
}
#endif

#ifdef FSH
/* RENDERTARGETS: 0,1,6 */

#include "utils/mathFuncs.glsl"

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform float rainStrength;
uniform float BiomeTemp;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;

uniform float viewHeight;
uniform float viewWidth;

varying vec4 color;
varying vec3 vNormal;
varying vec4 texcoord;
varying vec4 lmcoord;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform int fogMode;


void main() {
  
  //vec2 tuv = texcoord.st;
  //vec4 txCd = texture2D(texture, texcoord.st);
    
  vec4 outCd = color;
  vec2 luv = lmcoord.zw;
  vec4 lightCd = texture2D(lightmap, luv);
  
  vec4 pos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight)*2.0 - 1.0, 1.0, 1.0);
  pos = gbufferProjectionInverse * pos;
  
  float upDot = max(0.0, dot(normalize(pos.xyz), gbufferModelView[1].xyz));
  upDot = 1.0-(1.0-upDot)*(1.0-upDot);

  float skyGrey = min(luma(skyColor.rgb),.25)*1.4;
  vec3 skyCd = mix( skyColor.rgb, vec3(skyGrey), rainStrength);
  vec3 fogCd = mix( fogColor, vec3(skyGrey*.5), rainStrength);

  outCd.rgb = mix(fogCd, skyCd, upDot);

    
    
	gl_FragData[0] = outCd;
    //gl_FragData[1] = vec4(vec3( 0.0 ), 1.0);
    gl_FragData[1] = vec4(vec3( min(.999999,gl_FragCoord.w) ), 1.0);
  //gl_FragData[2] = vec4(vNormal*.5+.5, 1.0);
	gl_FragData[1] = vec4(vec3(0.0),1.0);

}
#endif

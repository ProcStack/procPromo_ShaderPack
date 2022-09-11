
#ifdef VSH
#include "/shaders.settings"

varying vec4 texcoord;
varying vec4 color;
varying vec4 lmcoord;
varying vec3 vNormal;

attribute vec4 mc_Entity;


void main() {

	vNormal = normalize(gl_NormalMatrix * gl_Normal);

	gl_Position = ftransform();

	color = gl_Color;

	//texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	//texcoord = gl_MultiTexCoord0;

	//lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	
  //float NdotU = gl_Normal.y*(0.17*15.5/255.)+(0.83*15.5/255.);
  //lmcoord.zw = gl_MultiTexCoord1.xy*vec2(15.5/255.0,NdotU)+0.5;
  
	//gl_FogFragCoord = gl_Position.z;
}
#endif

#ifdef FSH
/* RENDERTARGETS: 1,6 */
uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec4 color;
varying vec3 vNormal;
varying vec4 texcoord;
varying vec4 lmcoord;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform int fogMode;

void main() {
  
  //vec2 tuv = texcoord.st;
  vec4 txCd = texture2D(texture, texcoord.st);
    
  vec4 outCd = color;
  //vec2 luv = lmcoord.zw;
  //vec4 lightCd = texture2D(lightmap, luv);
  
  //outCd.rgb*=txCd.rgb;
  //outCd.rgb*=lightCd.rgb;
  
  outCd=txCd*color;
  outCd=color;
  
	gl_FragData[0] = color;
  //  gl_FragData[1] = vec4(vec3( min(.9999,gl_FragCoord.w) ), 1.0);
  //gl_FragData[2] = vec4(vNormal*.5+.5, 1.0);
	gl_FragData[1] = vec4(vec3(1.0),1.0);

}
#endif

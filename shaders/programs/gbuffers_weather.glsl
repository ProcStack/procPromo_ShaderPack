
#ifdef VSH
varying vec4 texcoord;
varying vec4 color;
varying vec4 lmtexcoord;

attribute vec4 mc_Entity;

uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

varying vec3 vNormal;

void main() {

	vec4 position = gl_ModelViewMatrix * gl_Vertex;

	gl_Position = gl_ProjectionMatrix * position;

	color = gl_Color;

	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
  
	lmtexcoord = gl_TextureMatrix[0] * gl_MultiTexCoord1;
  
	//float NdotU = gl_Normal.y*(0.17*15.5/255.)+(0.83*15.5/255.);
  //lmtexcoord.zw = gl_MultiTexCoord1.xy*vec2(15.5/255.0,NdotU)+0.5;

  vNormal = normalize(gl_NormalMatrix * gl_Normal);
  
	gl_FogFragCoord = gl_Position.z;
}
#endif

#ifdef FSH
/* RENDERTARGETS: 0,6 */

/* --
const int gcolorFormat = RGBA16;
const int gdepthFormat = RGBA16;
const int gnormalFormat = RGB10_A2;
 -- */
uniform sampler2D texture;
uniform sampler2D lightmap;

uniform int fogMode;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmtexcoord;

varying vec3 vNormal;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;


void main() {
  vec2 tuv = texcoord.st;
  vec4 txCd = texture2D(texture, tuv);
    
  vec4 outCd = color;
  vec2 luv = lmtexcoord.zw;
  vec4 lightCd = texture2D(lightmap, luv);
  
  // Minihud is Weather
  //   Weather is All!
  //outCd*=mix( vec4(1.0), txCd, step(.9999, color.a) );
  outCd.rgba*=txCd.rgba;
  outCd.rgb*=lightCd.rgb;
  
  
	gl_FragData[0] = outCd;
  //gl_FragData[1] = vec4(vec3( gl_FragCoord.w ), 1.0);
	//gl_FragData[2] = vec4(vNormal.xyz*.5+.5, 1.0);
	gl_FragData[2] = vec4(vec3(0.0), 1.0);
}
#endif



#ifdef VSH

uniform float frameTimeCounter;
uniform mat4 gbufferModelView;
uniform mat4 modelViewMatrixInverse;
uniform mat4 projectionMatrixInverse;


uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 sunVec;
uniform vec3 upPosition;
uniform vec3 cameraPosition;

varying vec4 texcoord;
varying vec4 color;
varying vec3 vPos;

void main() {

	vec4 position = gl_ModelViewMatrix * gl_Vertex;


	gl_Position = gl_ProjectionMatrix * position;


  /*
  vec3 toSun = sunPosition;
  toSun = (toSun-gl_Position.xyz);
  vec3 toMoon = moonPosition;
  toMoon = (toMoon-gl_Position.xyz);
  vPos = mix( toMoon, toSun, step(length(toMoon), length(toSun)) );
  //vPos = (vec4(sunPosition,1.0)-gl_Vertex), vPos
  vPos = (vec4(vPos,1.0)).xyz;// - gl_Vertex.xyz;
  */
  vPos = position.xyz;
  
	color = gl_Color;

	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

	gl_FogFragCoord = gl_Position.z;
}
#endif

#ifdef FSH
/* RENDERTARGETS: 0,6 */

#include "utils/mathFuncs.glsl"

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

varying vec4 color;
varying vec4 texcoord;
varying vec3 vPos;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;


void main() {
  
  vec2 uv = texcoord.st;
  
  vec4 outCd = texture2D(texture, uv) * color;
  
  float glowThresh = .85;
  float glowVal =  (1.0 - biasToOne( min(1.0, length(uv-.5)) ))*.5;
  
  
  float bodyThresh = .15;
  float uvbase = max( abs(uv.x-.5), abs(uv.y-.5) );
  float sunBody = step(bodyThresh,uvbase);
  //glowThresh*=sunBody;
  
  float mCd = max(outCd.r, max(outCd.g,outCd.b) );
  //outCd.rgb=mix( vec3(glowVal), outCd.rgb, step(glowThresh,mCd) );
  vec3 toSun = sunPosition-vPos;
  vec3 toMoon = moonPosition-vPos;
  vec3 sunMoonInf = vec3(1.0-min(length( mix( toMoon, toSun, step(length(toSun), length(toMoon)) ) )*.05, 1.0));
  
  //outCd.rgb=max( sunMoonInf, outCd.rgb );
  
	gl_FragData[0] = outCd;
	gl_FragData[1] = vec4(vec3(0.0),1.0);

}
#endif


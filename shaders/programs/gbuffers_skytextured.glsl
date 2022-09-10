
#ifdef VSH

uniform sampler2D texture;
uniform mat4 gbufferModelView;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int moonPhase;

uniform vec3 fogColor;
uniform vec3 skyColor;

varying vec4 vTexcoord;
varying vec4 vColor;
varying vec3 vPos;
varying vec3 vGlowEdgeCd;
varying vec2 vFittedUV;
varying float vDfLenMult;

void main() {

	vec4 position = gl_ModelViewMatrix * gl_Vertex;


	gl_Position = gl_ProjectionMatrix * position;


    float moonPhaseMult = (1.0-abs(((mod(moonPhase+3,8))-3))*.25)*.7+.3;
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
  vec3 modelPos = gbufferModelView[3].xyz;
  
  float isSun = step( .5, dot( normalize(sunPosition), normalize(position.xyz) ) );
  vPos = vec3( isSun );
  
	vColor = gl_Color;
  
	vTexcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
  
  // Read color of the sun at the sun body's edge pixel
  //   Provides a tone to the smooth outer glow from the fragment pass below
  //     Only works with vanilla textures...
  //     No clue what texture packs will look like
  //     I should add a toggle button in settings...
  vGlowEdgeCd = texture2D(texture, vec2(0.59375)).rgb; // .5+.0625+.03125
  vGlowEdgeCd = mix( fogColor*moonPhaseMult, vGlowEdgeCd, isSun ); // .5+.0625+.03125


  vFittedUV = mix( gl_MultiTexCoord0.xy*vec2(4.0,2.0), vTexcoord.st, isSun );
  
  vDfLenMult = mix( 3., .45, isSun );

	gl_FogFragCoord = gl_Position.z;
}
#endif

#ifdef FSH
/* RENDERTARGETS: 0,6 */

#include "utils/mathFuncs.glsl"

uniform sampler2D texture;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

varying vec4 vColor;
varying vec4 vTexcoord;
varying vec3 vPos;
varying vec3 vGlowEdgeCd;
varying vec2 vFittedUV;
varying float vDfLenMult;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;


void main() {
  
  vec2 uv = vTexcoord.st;
  vec2 fituv = fract(vFittedUV);
  
  vec4 outCd = texture2D(texture, uv) * vColor;
  
  //float glowVal =  (1.0 - biasToOne( min(1.0, length(fituv-.5)) ))*.5;
  
  
  float bodyThresh = .125;
  float uvbase = max( abs(fituv.x-.5), abs(fituv.y-.5) );
  float sunBody = step(bodyThresh,uvbase);
  
  float dfShift = .05;
  float dfMult = 2.;
  vec2 uvshift = abs(fituv-.5)-dfShift;

  float dfLen = 1.0-min(1.0, length(max(vec2(0.0),uvshift)*dfMult)); // 0-1 dist to center

  dfLen = (dfLen*dfLen)*vDfLenMult;
  vec3 sunCd = mix( outCd.rgb, vGlowEdgeCd * dfLen, sunBody);
  
  outCd.rgb = sunCd;//mix( outCd.rgb, vec3(sunCd), step(fituv.x,.5) );
  //outCd.rgb = mix( outCd.rgb, vec3(vPos), step(fituv.x,.5) );
  //outCd.rgb = vPos;
  
	gl_FragData[0] = outCd;
	gl_FragData[1] = vec4(vec3(0.0),1.0);

}
#endif


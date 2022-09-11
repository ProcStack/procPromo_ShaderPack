
#ifdef VSH
#include "/shaders.settings"

uniform int renderStage;
uniform float sunAngle;

varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 vColor;
varying vec3 vNormal;
varying float vAmbiance;
varying float vDayNight;

attribute vec4 mc_Entity;


void main() {

  // Star Fading Logic
  //   Shift `sunAngle` from worldTime 0 at 6:00 to worldTime 0 at 12:00
  //     World Time 12000 would be 18:00
  //   Add .75 instead of subtracting .25 for positive fract morning hours
	float dayNight = 1.0-abs(fract(sunAngle+.75)-.5) * 2.0;
  dayNight = min(1.0, max(0.0,dayNight-.4) * 5.0);

	vNormal = normalize(gl_NormalMatrix * gl_Normal);
  
	vec4 position = gl_ModelViewMatrix * gl_Vertex;

	gl_Position = gl_ProjectionMatrix * position;

	vColor = gl_Vertex;//*step(1.0,(gl_Vertex.y+60.0)*.015);//*step(0.0, gl_Vertex.y);

	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	
  float NdotU = gl_Normal.y*(0.17*15.5/255.)+(0.83*15.5/255.);
  lmcoord.zw = gl_MultiTexCoord1.xy*vec2(15.5/255.0,NdotU)+0.5;
  
  vAmbiance = 1.0;
  
  vDayNight = 1.0;
  if(renderStage == MC_RENDER_STAGE_STARS) {
    vAmbiance = 0.0;
    vColor = vec4(1.0);
    vDayNight = dayNight;
  }
  
	gl_FogFragCoord = gl_Position.z;
}
#endif

#ifdef FSH
/* RENDERTARGETS: 0,1,6 */

#include "utils/mathFuncs.glsl"

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform float rainStrength;
uniform float sunAngle;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;

uniform float viewHeight;
uniform float viewWidth;

varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 vColor;
varying vec3 vNormal;
varying float vAmbiance;
varying float vDayNight;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform int fogMode;


void main() {
  
  vec4 outCd = vColor;
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
  
  outCd.rgb = mix( vColor.rgb, outCd.rgb, vAmbiance );
  
  //outCd = texture2D(lightmap, texcoord.xy);
  outCd.a = vDayNight*upDot;
    
	gl_FragData[0] = outCd;
    //gl_FragData[1] = vec4(vec3( 0.0 ), 1.0);
    gl_FragData[1] = vec4(vec3( min(.999999,gl_FragCoord.w) ), 1.0);
  //gl_FragData[2] = vec4(vNormal*.5+.5, 1.0);
	gl_FragData[1] = vec4(vec3(0.0),1.0);

}
#endif

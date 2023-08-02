
// Screen Space Ambient Occlusion

#ifdef VSH

varying vec2 vUv;

void main() {
	gl_Position = ftransform();
	vUv = gl_MultiTexCoord0.xy;
}

#endif

#ifdef FSH
/* RENDERTARGETS: 7 */

/* COLORTEX9FORMAT:RGBA16 */
/*
const int colortex6Format = RGBA16F;
const int colortex9Format = RGBA16F;
*/

#include "/shaders.settings"
#include "utils/mathFuncs.glsl"

uniform sampler2D colortex0; // Diffuse Pass
uniform sampler2D colortex1; // Depth Pass
uniform sampler2D colortex2; // Normal Pass

uniform vec2 texelSize;
uniform vec2 far;

varying vec2 vUv;


void main() {

  
  vec4 outCd = texture2D(colortex0, vUv);
  //outCd = texture2D(colortex1, vUv);
  //outCd = texture2D(colortex2, vUv);
	gl_FragData[0] = outCd;
  
  
  
  
}


#endif



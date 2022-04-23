
#ifdef VSH
varying vec4 texcoord;
varying vec4 color;
varying vec4 lmcoord;

attribute vec4 mc_Entity;

uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec2 texelSize;

varying vec3 normal;
  
void main() {

	vec4 position = gl_ModelViewMatrix * gl_Vertex;

	gl_Position = gl_ProjectionMatrix * position;

	color = gl_Color;

	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
  
  normal = normalize(gl_NormalMatrix * gl_Normal);

	gl_FogFragCoord = gl_Position.z;
}
#endif

#ifdef FSH
/* RENDERTARGETS: 0,1,2,6 */
uniform sampler2D texture;

/* --
const int gcolorFormat = RGBA8;
const int gdepthFormat = RGBA16; //it's to inacurrate otherwise
const int gnormalFormat = RGB10_A2;
 -- */
 
varying vec4 color;
varying vec4 texcoord;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform int fogMode;

varying vec3 normal;

void main() {

  vec4 outCd = texture2D(texture, texcoord.st) * color;
  
	gl_FragData[0] = outCd;
    gl_FragData[1] = vec4(vec3( min(.9999,gl_FragCoord.w) ), 1.0);
	gl_FragData[2] = vec4( normal*.5+.5, 0.0 );
	gl_FragData[3] = vec4( vec3(0.0), 1.0 );
		
}
#endif

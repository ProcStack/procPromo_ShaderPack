
#ifdef VSH
#define gbuffers_entities

uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;
uniform float far;
uniform float near;

uniform float viewWidth;
uniform float viewHeight;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;                      //xyz = tangent vector, w = handedness, added in 1.7.10

in vec3 at_velocity; // vertex offset to previous frame

varying vec2 texelSize;
varying vec4 texcoord;
varying vec4 color;
varying vec4 vLightcoord;
varying vec2 texmidcoord;

varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec2 vtexcoord;

varying float sunDot;

varying vec4 vPos;
varying vec4 normal;
varying float vDepth;

void main() {

  vec3 toCamPos = gl_Vertex.xyz*.01;
	vec4 position = gl_ModelViewMatrix * vec4(toCamPos, 1.0) ;
  position.xyz = position.xyz+normalize(position.xyz)*near*2.50;

  vPos = gl_ProjectionMatrix * position;

	gl_Position = vPos;
  
  vDepth = clamp(length((gl_ModelViewMatrix * gl_Vertex).xyz)/far, 0.0, 1.0);

	color = gl_Color;


  texelSize = vec2(1.0/viewWidth,1.0/viewHeight);
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

	vLightcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

	gl_FogFragCoord = gl_Position.z;


	
	vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texcoordminusmid = texcoord.xy-midcoord;
  texmidcoord = midcoord;
	vtexcoordam.pq = abs(texcoordminusmid)*2.0;
	vtexcoordam.st = min(texcoord.xy ,midcoord-texcoordminusmid);
	vtexcoord = sign(texcoordminusmid)*0.5+0.5;
  
  
  normal.xyz = normalize(gl_NormalMatrix * gl_Normal);
	normal.a = 0.02;
  
  //vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
  vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
  sunDot = dot( normal.xyz, normalize(sunPosition) );
  sunDot = dot( normal.xyz, normalize(localSunPos) );
  sunDot = dot( (gbufferModelViewInverse*gl_Vertex).xyz, normalize(vec3(1.0,0.,0.) ));

  
	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
	vec3 binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);

  
}
#endif

#ifdef FSH
/* RENDERTARGETS: 0,1,2,7,6,9 */

#define gbuffers_entities

/* GAUX1FORMAT:RGB16_A2 */
/* GAUX3FORMAT:RGB16_A2 */

/* --
const int gcolorFormat = RGBA8;
const int gdepthFormat = RGBA16; //it's to inacurrate otherwise
const int gnormalFormat = RGB10_A2;
const int colortex9Format = RGBA16F;
 -- */

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D colortex7;
uniform int fogMode;
uniform float fogStart;
uniform float fogEnd;
uniform float far;

uniform vec3 sunPosition;
uniform vec4 spriteBounds; 
uniform float isGlowing;

//#include "utils/texSamplers.glsl"

varying vec4 color;
varying vec4 texcoord;
varying vec4 vLightcoord;

varying vec2 texelSize;
varying vec2 texmidcoord;
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec2 vtexcoord;

varying float sunDot;

varying vec4 vPos;
varying vec4 normal;
varying float vDepth;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// From Sildurs
//encode normal in two channel (xy),torch and material(z) and sky lightmap (w)
vec4 encode (vec3 n){
    float p = sqrt(n.z*8+8);
    return vec4(n.xy/p + 0.5,texcoord.z,texcoord.w);
}


const int boxSamplesCount = 8;
const vec2 boxSamples[8] = vec2[8](
                              vec2( -1.0, -1.0 ),
                              vec2( -1.0, 0.0 ),
                              vec2( -1.0, 1.0 ),

                              vec2( 0.0, -1.0 ),
                              vec2( 0.0, 1.0 ),

                              vec2( 1.0, -1.0 ),
                              vec2( 1.0, 0.0 ),
                              vec2( 1.0, 1.0 )
                            );


vec4 diffuseSampleLocal( sampler2D tx, vec2 uv, vec2 res, float thresh){
  vec4 sampleCd = texture2D(tx, uv);
  vec3 sampleHSV = rgb2hsv( sampleCd.rgb );
  
  vec2 curUV;
  vec2 curId;
  float curUVDist=0.0;
  vec4 curCd;
  vec3 curMix;
  vec3 curHSV;
  float delta=0.0;
  for( int x=0; x<boxSamplesCount; ++x){
    curUV =  uv + boxSamples[x]*res ;
    
		//curUV = fract(curUV)*vtexcoordam.pq+vtexcoordam.st;
		
    curCd = texture2D(tx, curUV);
    curHSV = rgb2hsv( curCd.rgb );
    curHSV = 1.0-abs( curHSV-sampleHSV );
    
    delta = max( 0.0, dot(sampleCd.rgb, curCd.rgb) );
    delta *= curHSV.r*curHSV.g*curHSV.b;
    delta *= delta * delta;//* smoothstep( .4, 1.0, delta);//*delta;
    delta *= sampleCd.a * curCd.a;
    //delta *= step( res.x*2.0, abs(curUV.x-uv.x) );
    //delta *= step( res.y*2.0, abs(curUV.y-uv.y) );
    delta = clamp( delta, 0.0, 1.0 );
    
    curMix = curCd.rgb;//mix(sampleCd.rgb, curCd.rgb, .5);
    curMix = mix(sampleCd.rgb, curCd.rgb, .5);
    sampleCd.rgb = mix( sampleCd.rgb, curMix, delta);
  }
  
  return sampleCd;
}


void main() {

  vec2 tuv = texcoord.st;
  //vec4 txCd = texture2D(texture, tuv);;
  vec4 txCd = diffuseSampleLocal( texture, tuv, texelSize, 0.0 );
  
  vec2 luv = vLightcoord.st;
  //vec4 lightCd = texture2D(lightmap, luv);
  
  vec4 outCd = txCd * color;//vec4(color.rgb,1.0);
  
  vec3 glowHSV = rgb2hsv(outCd.rgb);

  vec4 outData = vec4(0.0);
  float outDepth = min(.9999,gl_FragCoord.w);
  outDepth = vDepth;
  
  
  outData.x=glowHSV.x;
  outData.y=outDepth;
  outData.z=glowHSV.z;
  outData.w = outCd.a; // 1.0;

  glowHSV.z *= .0;
  float outEffectGlow = 0.0;
  
  
  
	gl_FragData[0] = outCd;
  gl_FragData[1] = vec4(outDepth, outEffectGlow, 0.0, 1.0);
	gl_FragData[2] = vec4(normal.xyz*.5+.5,1.0);
    // [ Sun/Moon Strength, Light Map, Spectral Glow ]
  gl_FragData[3] = outData;
	gl_FragData[4] = vec4(glowHSV,1.0);
  gl_FragData[5] = outData;

}

#endif

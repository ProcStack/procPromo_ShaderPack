
#ifdef VSH


#define gbuffers_entities

uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;

uniform sampler2D texture;

uniform float viewWidth;
uniform float viewHeight;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;                      //xyz = tangent vector, w = handedness, added in 1.7.10

in vec3 at_velocity; // vertex offset to previous frame

varying vec2 texelSize;
varying vec4 texcoord;
varying vec4 color;
varying vec4 lmcoord;

varying float sunDot;

varying vec4 vPos;
varying vec4 vNormal;
varying vec3 vAvgColor;
varying float vAvgColorBlend;

void main() {

	vec4 position = gl_ModelViewMatrix * gl_Vertex;

  
  vPos = gl_ProjectionMatrix * position;
	gl_Position = vPos;
  
  vPos = gl_ModelViewMatrix * gl_Vertex;

	color = gl_Color;
  color.a=1.0;


  texelSize = vec2(1.0/64.0, 1.0/32.0);//vec2(1.0/viewWidth,1.0/viewWidth);
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

	gl_FogFragCoord = gl_Position.z;

	
	vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texcoordminusmid = texcoord.xy-midcoord;
  
  
  vNormal.xyz = normalize(gl_NormalMatrix * gl_Normal);
	vNormal.a = 0.02;
  
  //vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
  vec3 localSunPos = (gbufferProjectionInverse * gbufferModelViewInverse * vec4(sunPosition,1.0) ).xyz;
  sunDot = dot( vNormal.xyz, normalize(sunPosition) );
  sunDot = dot( vNormal.xyz, normalize(localSunPos) );
  sunDot = dot( (gbufferModelViewInverse*gl_Vertex).xyz, normalize(vec3(1.0,0.,0.) ));

  
  
  float avgBlend = .3;
  
  ivec2 txlOffset = ivec2(2);
  vec3 mixColor;
  vec4 tmpCd;
  float avgDiv = 0.0;
  tmpCd = texture2D(texture, midcoord);
    mixColor = tmpCd.rgb;
    avgDiv += tmpCd.a;
  tmpCd = textureOffset(texture, midcoord, ivec2(txlOffset.x, txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  tmpCd = textureOffset(texture, midcoord, ivec2(txlOffset.x, -txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  tmpCd = textureOffset(texture, midcoord, ivec2(-txlOffset.x, -txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  tmpCd = textureOffset(texture, midcoord, ivec2(-txlOffset.x, txlOffset.y) );
    mixColor = mix( mixColor, tmpCd.rgb, avgBlend*tmpCd.a);
    avgDiv += tmpCd.a;
  
  vAvgColor = mixColor;
  
  // 
  vAvgColorBlend = 0.0;
  if (mc_Entity.x == 603){
    vAvgColorBlend = 0.5;
  }
  
  
  
}
#endif

#ifdef FSH


/* RENDERTARGETS: 0,1,2,7,6 */

//#include "shaders.settings"
#include "utils/mathFuncs.glsl"

/* --
const int gcolorFormat = RGBA8;
const int gdepthFormat = RGBA16; //it's to inacurrate otherwise
const int gnormalFormat = RGB10_A2;
 -- */

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform int fogMode;
uniform vec3 sunPosition;
uniform vec4 spriteBounds; 
uniform vec4 entityColor;
uniform float rainStrength;


varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

varying vec2 texelSize;

varying float sunDot;

varying vec4 vPos;
varying vec4 vNormal;
varying vec3 vAvgColor;
varying float vAvgColorBlend;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

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
		
    curCd = texture2D(tx, curUV);
    curHSV = rgb2hsv( curCd.rgb );
    curHSV = abs(sampleHSV-curHSV );
    curHSV.r = 1.0-min(1.0,curHSV.r*1.0);
    curHSV.g = mix( curHSV.g*curHSV.g, biasToOne(curHSV.g), step(.5,curHSV.g));
    curHSV.b = 1.0-max(0.0,curHSV.b-.3)*10.0;

    
    delta = max( 0.0, dot(normalize(sampleCd.rgb), normalize(curCd.rgb)) );
    delta = max(0.0, 1.0-length(sampleCd.rgb-curCd.rgb)*2.0);
    delta *= curHSV.r*curHSV.g*curHSV.b;
    delta = clamp( delta, 0.0, 1.0 );
    
    curMix = curCd.rgb;//mix(sampleCd.rgb, curCd.rgb, .5);
    //curMix = mix(sampleCd.rgb, curCd.rgb, .5);

    sampleCd.rgb = mix( sampleCd.rgb, curMix, delta);
  }
  
  return sampleCd;
}


void main() {

  vec2 tuv = texcoord.st;
  vec4 baseCd = texture2D(texture, tuv);;
  vec4 txCd = baseCd;//diffuseSampleLocal( texture, tuv, texelSize, 0.0 );
  
  vec2 luv = lmcoord.st;
  vec4 lightCd = texture2D(lightmap, luv);
  
  vec4 outCd = txCd;
  outCd.rgb *= lightCd.rgb * color.rgb;
  
  //outCd.rgb *= (1.0-rainStrength*.3);
  
  vec3 colorMix = min(vec3(1.0),entityColor.rgb*1.5);
  outCd.rgb = mix( outCd.rgb, color.rgb*colorMix, step(.2,entityColor.a)*(.5+entityColor.g*.3) );
  
  
  float highlights = dot(normalize(sunPosition),vNormal.xyz);
  highlights = (highlights-.5)*0.3;


  outCd.rgb = mix( outCd.rgb, vAvgColor*lightCd.rgb, vAvgColorBlend );

  float outDepth = min(.9999,gl_FragCoord.w);
  float outEffectGlow = 0.0;
  
	gl_FragData[0] = outCd;
  gl_FragData[1] = vec4(outDepth, outEffectGlow, 0.0, 1.0);
	gl_FragData[2] = vec4(vNormal.xyz*.5+.5,1.0);
	gl_FragData[3] = vec4( 1.0, 1.0, 0.0,1.0);
	gl_FragData[4] = vec4(vec3(0.0),1.0);

}
#endif

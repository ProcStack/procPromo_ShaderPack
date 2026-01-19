// GBuffer - Sky Textured GLSL
// Written by Kevin Edzenga, ProcStack; 2022-2023
//

#ifdef VSH

uniform sampler2D gtexture;
uniform mat4 gbufferModelView;
uniform int renderStage;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int moonPhase;
uniform int worldTime;
uniform float frameTimeCounter;

uniform vec3 fogtexture;
uniform vec3 skyColor;

attribute vec2 mc_midTexCoord;


varying vec4 vColor;
varying vec4 vPos;
varying vec3 vGlowEdgeCd;
varying float vDfLenMult;
varying float vWorldTime;
varying float isSun;
varying vec3 vSkyUV;
varying vec2 vTexCoord;

const vec3 sunInnerCd = vec3( 1.0, 1.0, 0.99607843137 );

void main() {

  vec4 position = gl_ModelViewMatrix * gl_Vertex;
  vPos=position;

  vSkyUV = gl_Vertex.xyz;
  
	// Fit 'worldTime' from 0-24000 -> 0-1; Scale x30
	//   worldTime * 0.00004166666 * 30.0 == worldTime * 0.00125
	//vWorldTime = float(worldTime)*0.00125;
	vWorldTime = float(worldTime)*0.00025;
	vWorldTime = frameTimeCounter*.01;


  gl_Position = gl_ProjectionMatrix * position;

  float moonPhaseMult = (1.0-abs(((mod(moonPhase+3,8))-3))*.25)*.7+.3;

  vec3 modelPos = gbufferModelView[3].xyz;
  
  isSun = step( .5, dot( normalize(sunPosition), normalize(position.xyz) ) );

  vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

  vColor = gl_Color;
  
  
  // Read color of the sun at the sun body's edge pixel
  //   Provides a tone to the smooth outer glow from the fragment pass below
  //     Only works with vanilla textures...
  //     No clue what texture packs will look like
  //     I should add a toggle button in settings...


  //vFittedUV = vTexCoord.st;
  /*if (renderStage == MC_RENDER_STAGE_SUN) {
    vGlowEdgeCd = texture2D(gtexture, vec2(0.59375)).rgb; // .5+.0625+.03125
    vDfLenMult = .45;
  }
  if (renderStage == MC_RENDER_STAGE_MOON) {
    vGlowEdgeCd = fogtexture*moonPhaseMult;
    vFittedUV = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy *vec2(4.0,2.0);
    vDfLenMult = .3;
  }*/
  
  // Iris is having some issues with MC_RENDER_STAGEs SUN and MOON
  if( isSun>.5 ){
    //vFittedUV = vTexCoord.st;
    //vGlowEdgeCd = texture2D(gtexture, vec2(0.49375)).rgb; // .5+.0625+.03125
    //vGlowEdgeCd = texture2D(gtexture, vec2(vMidCoord)).rgb; // .5+.0625+.03125
    vGlowEdgeCd = sunInnerCd; // .5+.0625+.03125
    vDfLenMult = .45;
  }else{
    //vFittedUV = vTexCoord.st*vec2(4.0,2.0) ;
    vGlowEdgeCd = fogtexture*moonPhaseMult;
    vDfLenMult = .3;
  }
  
  gl_FogFragCoord = gl_Position.z;
}
#endif

#ifdef FSH
/* RENDERTARGETS: 0,6 */

#include "/shaders.settings"
#include "utils/mathFuncs.glsl"

uniform sampler2D gtexture;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform sampler2D noisetex; // Custom Texture; textures/SoftNoise_1k.jpg
uniform int renderStage;
uniform float rainStrength;
uniform vec3 skyColor;

varying vec4 vPos;
varying vec4 vColor;
varying vec3 vGlowEdgeCd;
varying float vDfLenMult;
varying float vWorldTime;
varying float isSun;
varying vec3 vSkyUV;
varying vec2 vTexCoord;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;
uniform vec3 fogtexture;

// These don't work as Const in Iris, defines work just fine --
#define sunInnerCd vec3( 1.0, 1.0, 0.99607843137 )
#define sunOuterCd vec3( 0.9, 0.9, 0.1 )

// Sun settings -
#define bodyThresh 0.02 // Step(bodyThresh, deltaUVs)
#define outlineThresh 0.016 // Step(outlineThresh, deltaUVs)
#define dfMult 22.5 // Sun Aura Mutliplier

// -- -- --

void main() {

  vec2 uv = vTexCoord;
  vec4 outCd = vec4(0.0);
  
  float rainMix = rainStrength ;
  
#ifdef OVERWORLD
  vec2 fituv = uv;

  vec4 baseCd = texture2D(gtexture, uv) * vColor;
  //vec4 baseCd = texture2D(gtexture, uv) * vColor;
  outCd = texture2D(gtexture, uv) * vColor;
  //float glowVal =  (1.0 - biasToOne( min(1.0, length(fituv-.5)) ))*.5;


  //float bodyThresh = .2; // Last known working value
  //float uvbase = max( abs(fituv.x-.5), abs(fituv.y-.5) ); // Last known working
  float uvbase = max( abs(fituv.x-.7), abs(fituv.y-.4)*0.5 );  // Should be center, might be bug in iris? Need to check optifine
  float sunBody = step(bodyThresh,uvbase);
  float sunOutline = step(outlineThresh,uvbase);
  

  vec2 uvshift = max( vec2(0.0) , (abs( (fituv-vec2(.7,.4)) * vec2(1.0,.5) )-bodyThresh) );

  float dfLen = min(1.0, length(max(vec2(0.0),uvshift)*dfMult)); // 0-1 dist to center

  dfLen = max(0.0, (1.0-dfLen) * (1.0-dfLen*.65) ) * .2;
  //dfLen = (dfLen*dfLen)*vDfLenMult;
  //vec3 sunCd = mix( outCd.rgb, vGlowEdgeCd * dfLen, sunBody);
  vec3 sunCd = mix( sunInnerCd, sunOuterCd, sunOutline);
  sunCd = mix( sunCd, vGlowEdgeCd * dfLen, sunBody);
  
  outCd.rgb = sunCd;
  //outCd.rgb = mix( outCd.rgb, vec3(sunCd), step(fituv.x,.5) );


  outCd.rgb = mix( baseCd.rgb, outCd.rgb, isSun );


  // Clear sky Blue = 0xFF = 255/255 = 1.0
  // Rain sky Blue = 0x88 = 136/255 = 0.53333333333
  // Thunder sky Blue = 0x33 = 51/255 = 0.2 = 1.0/(1.0-.2) = 1.25
  float skyGreyInf =  (skyColor.b-.2)*1.25;
  outCd.a = mix( 1.0, skyGreyInf * skyGreyInf * (skyGreyInf*.5+.5) * isSun, rainMix );

#elif defined(NETHER)
  outCd = texture2D(gtexture, uv) * vColor;
  //float glowVal =  (1.0 - biasToOne( min(1.0, length(fituv-.5)) ))*.5;
#elif defined(THE_END)
  float skyDotZ = dot(normalize(vSkyUV), vec3(0.0,0.0,1.0))*.5+.5;
  float skyDotY = dot(normalize(vSkyUV), vec3(0.0,1.0,0.0));
	vec3 noiseX = texture( noisetex, fract(vec2(skyDotY,skyDotZ) + vec2(.75,1.75)*vWorldTime)).rgb;

  uv = fract( vTexCoord*.15 + noiseX.xy*.1 )*(1.0-(noiseX.z*.5));
  noiseX.z = (noiseX.z*.5+.5);
  vec4 baseCd = texture2D(gtexture, uv) * vColor * noiseX.z * (skyDotY*.4+.3);
  uv += noiseX.xy + vTexCoord*.1;
  vec4 mixCd = texture2D(gtexture, uv) * vColor * noiseX.z * min(1.0,skyDotY*.5+.7);
  //outCd = mix( baseCd, mixCd, noiseX.x);
  outCd.rgb *= 1.0-outCd.rgb*.5;
  //float glowVal =  (1.0 - biasToOne( min(1.0, length(fituv-.5)) ))*.5;
#endif


  #if ( DebugView == 4 )
    float debugBlender = step( .0, vPos.x);
    outCd = mix( baseCd, outCd, debugBlender);
  #endif



  //outCd.rgb = vec3( sunCd );
  //outCd.rgb = vec3( dfLen*9. );
  //outCd.rgb = mix( outCd.rgb, vec3(1.0,0.0,0.0), step(1.0, outCd.r) );
  //  //outCd.rgb = vec3( vColor.rgb*.1 );
  //outCd.rgb = vec3( isSun, 1.0-isSun, 0.0 );
  //outCd.rgb = vec3( vGlowEdgeCd * dfLen );
  outCd.a=1.0;

  //outCd.rgb = vec3(uvshift.xy,0.);
  //outCd.a =1.0;//skyGreyInf * skyGreyInf * (skyGreyInf*.5+.5) * isSun;
  gl_FragData[0] = outCd;
  gl_FragData[1] = vec4(vec3(0.0),1.0);

}
#endif


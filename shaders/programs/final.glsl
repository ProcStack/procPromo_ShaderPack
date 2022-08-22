/* -- -- -- -- -- --
  -Shadow Pass is not being used.
    Buffer currently has Sun Shadow written to it
    Should be block luminance;
      Transparent blocks included
   -- -- -- -- -- -- */


#ifdef VSH

uniform sampler2D gnormal;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;

uniform vec3 sunPosition;
uniform vec3 upPosition;

varying vec2 texcoord;
varying vec2 res;

varying vec3 sunVecNorm;
varying vec3 upVecNorm;
varying float dayNight;

void main() {
  
	sunVecNorm = normalize(sunPosition);
	upVecNorm = normalize(upPosition);
	dayNight = dot(sunVecNorm,upVecNorm);
  
	gl_Position = ftransform();
	texcoord = (gl_MultiTexCoord0).xy;
  
  res = vec2( 1.0/viewWidth, 1.0/viewHeight);
}
#endif

#ifdef FSH

/* --
const int gcolorFormat = RGBA8;
const int gdepthFormat = RGBA16;
const int gnormalFormat = RGB10_A2;
const float eyeBrightnessHalflife = 4.0f;
 -- */
 
#include "/shaders.settings"
#include "utils/mathFuncs.glsl"

uniform sampler2D colortex0; // Diffuse Pass
uniform sampler2D colortex1; // Depth Pass
uniform sampler2D colortex2; // Normal Pass


uniform sampler2D gaux1;
uniform sampler2D gaux2; // 40% Res Glow Pass
uniform sampler2D gaux3; // 20% Res Glow Pass
uniform sampler2D gaux4; // 20% Res Glow Pass
uniform sampler2D colortex9; // Known working from terrain gbuffer

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform vec3 sunPosition;
uniform int isEyeInWater;
uniform vec2 texelSize;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;
uniform vec3 fogColor;
uniform vec3 skyColor; 
uniform float rainStrength;
uniform int worldTime;
uniform float nightVision;


const float eyeBrightnessHalflife = 4.0f;
uniform ivec2 eyeBrightnessSmooth;

uniform float InTheEnd;

varying vec2 texcoord;

varying vec3 sunVecNorm;
varying vec3 upVecNorm;
varying float dayNight;
varying vec2 res;

  
// -- -- -- -- -- -- -- --
// -- Box Blur Sampler  -- --
// -- -- -- -- -- -- -- -- -- --
vec4 boxSample( sampler2D tex, vec2 uv, vec2 reachMult, float blend ){

  vec2 curUVOffset;
  vec4 curCd;
  
  vec4 blendCd = texture2D(tex, uv);
  
  curUVOffset = reachMult * vec2( -1.0, -1.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  blendCd = mix( blendCd, curCd, blend);
  curUVOffset = reachMult * vec2( -1.0, 0.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  blendCd = mix( blendCd, curCd, blend);
  curUVOffset = reachMult * vec2( -1.0, 1.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  blendCd = mix( blendCd, curCd, blend);
  
  curUVOffset = reachMult * vec2( 0.0, -1.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  blendCd = mix( blendCd, curCd, blend);
  curUVOffset = reachMult * vec2( 0.0, 1.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  blendCd = mix( blendCd, curCd, blend);
  
  curUVOffset = reachMult * vec2( 1.0, -1.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  blendCd = mix( blendCd, curCd, blend);
  curUVOffset = reachMult * vec2( 1.0, 0.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  blendCd = mix( blendCd, curCd, blend);
  curUVOffset = reachMult * vec2( 1.0, 1.0 );
  curCd = texture2D(tex, uv+curUVOffset);
  blendCd = mix( blendCd, curCd, blend);
  
  return blendCd;
}


// -- -- -- -- -- -- -- -- -- -- -- -- --
// -- Depth & Normal LookUp & Blending -- --
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
void edgeLookUp(  sampler2D txColor, sampler2D txDepth, sampler2D txNormal,
                  vec2 uv, vec2 uvOffset,
                  float depthRef, vec3 normalRef, float thresh,
                  inout float depthOut, inout vec3 avgNormal, inout float edgeOut ){

  vec2 uvDepthLimit = uv+uvOffset;//limitUVs(uv+uvOffset);
  vec2 uvNormalLimit = uv+uvOffset*1.5;//limitUVs(uv+uvOffset*1.5);
  float curDepth = texture2D(txDepth, uvDepthLimit).r;
  vec3 curNormal = texture2D(txNormal, uvNormalLimit).rgb*2.0-1.0;
  
  float curInf = step( abs(curDepth - depthRef), thresh );

  curDepth = ( abs(curDepth - depthRef)*3.0 );
  //curDepth *=curDepth;
  //curDepth = min(0.5, curDepth );
  curDepth = smoothstep(0.0, .65, curDepth );

  depthOut = max( depthOut, curDepth );
  
  //edgeOut = mix( max(edgeOut, step(0.075, depthOut)*.5 ), 1.0-abs(dot(normalRef, curNormal))*curInf, .125 );
  float curEdge = 1.0-abs(dot(normalRef, curNormal));
  edgeOut = mix( edgeOut, curEdge, .125*curInf );
  //curInf *= dot(avgNormal, curNormal)*.5+.5;
  
  
    
  //avgNormal = mix( avgNormal, curNormal, max(edgeOut, step(0.005, depthOut)*.5 ) );
  avgNormal = (mix( avgNormal, curNormal, .5*curInf ));
  
}


// -- -- -- -- -- -- -- -- -- -- -- -- --
// -- Sample Depth & Normals; 3x3 - -- -- --
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
void findEdges( sampler2D txColor, sampler2D txDepth, sampler2D txNormal,
                vec2 uv, vec2 txRes,
                float depthRef, vec3 normalRef, float thresh,
                inout vec3 avgNormal, inout float edgeInsidePerc, inout float edgeOutsidePerc ){
  
  float edgeOut = 0.0;
  float depthOut = 0.0;
  
  vec2 uvOffsetReach = txRes;
  
  vec2 curUVOffset;
  curUVOffset = uvOffsetReach * vec2( -1.0, -1.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,  depthOut,avgNormal,edgeOut );
  curUVOffset = uvOffsetReach * vec2( -1.0, 0.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,  depthOut,avgNormal,edgeOut );
  curUVOffset = uvOffsetReach * vec2( -1.0, 1.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,  depthOut,avgNormal,edgeOut );
  
  curUVOffset = uvOffsetReach * vec2( 0.0, -1.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,  depthOut,avgNormal,edgeOut );
  curUVOffset = uvOffsetReach * vec2( 0.0, 1.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,  depthOut,avgNormal,edgeOut );
  
  curUVOffset = uvOffsetReach * vec2( 1.0, -1.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,  depthOut,avgNormal,edgeOut );
  curUVOffset = uvOffsetReach * vec2( 1.0, 0.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,  depthOut,avgNormal,edgeOut );
  curUVOffset = uvOffsetReach * vec2( 1.0, 1.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,  depthOut,avgNormal,edgeOut );
  

  depthOut *= step(0.05, depthOut); 
  
  //edgeOut = max( edgeOut, depthOut );
  
  avgNormal = normalize(avgNormal);
  edgeInsidePerc = edgeOut;
  edgeOutsidePerc = depthOut;
}



// == == == == == == == == == == == == ==
// == MAIN VOID = == == == == == == == == ==
// == == == == == == == == == == == == == == ==
void main() {
  // -- -- -- -- -- -- -- -- -- -- --
  // -- Color, Depth, Normal,   -- -- --
  // --   Shadow, & Glow Reads  -- -- -- --
  // -- -- -- -- -- -- -- -- -- -- -- -- -- --
  vec2 uv = texcoord;
  vec4 baseCd = texture2D(colortex0, uv);
  vec4 outCd = baseCd;
  vec2 depthEffGlowBase = texture2D(colortex1, uv).rg;
  float depthBase = depthEffGlowBase.r;
  float effGlowBase = depthEffGlowBase.g;
  
  vec4 normalCd = texture2D(colortex2, uv);
  vec3 dataCd = texture2D(gaux1, uv).xyz;
  vec4 spectralDataCd = texture2D(colortex9, uv);

  
  
  // -- -- -- -- -- -- -- --
  // -- Glow Passes -- -- -- --
  // -- -- -- -- -- -- -- -- -- --
  vec3 blurMidCd = texture2D(gaux2, uv*.4).rgb;
  vec3 blurLowCd = texture2D(gaux3, uv*.3).rgb;
  
  // -- -- -- -- -- -- -- --
  // -- Depth Tweaks - -- -- --
  // -- -- -- -- -- -- -- -- -- --
  float depth = 1.0-depthBase;//biasToOne(depthBase);
  //depth = min(1.0, depth*depth*min(1.0,1.5-depth));
  float depthCos = cos(depth*PI*.5);//*-.5+.5;
  
  // -- -- -- -- -- -- -- --
  // -- Screen Space - -- -- --
  // -- -- -- -- -- -- -- -- -- --
  
  
  // -- -- -- -- -- 
  // -- Shadows  -- --
  // -- -- -- -- -- -- --
  //float shadow = dataCd.x;
  //float shadowDepth = dataCd.y;
  //shadowDepth = 1.0-(1.0-shadowDepth)*(1.0-shadowDepth);
  //shadowDepth *= shadowDepth;


  // -- -- -- -- -- -- -- --
  // -- Depth Blur -- -- -- --
  // -- -- -- -- -- -- -- -- -- --
  if( UnderWaterBlur && isEyeInWater >= 1 ){
    float depthBlurInf = smoothstep( .5, 1.5, depth);//biasToOne(depthBase);
    
    float depthBlurTime = worldTime*.07 + depth*3.0;
    float depthBlurWarpMag = .006;
    float uvMult = 20.0 + 10.0*depth;
    
    vec2 depthBlurUV = uv + vec2( sin(uv.x*uvMult+depthBlurTime), cos(uv.y*uvMult+depthBlurTime) )*depthBlurWarpMag*depthBlurInf;
    vec2 depthBlurReach = vec2( max(0.0,depthBlurInf-length(blurMidCd)) * texelSize * 6.0 * (1.0-nightVision));
    vec4 depthBlurCd = boxSample( colortex0, depthBlurUV, depthBlurReach, .2 );
    
    float eyeWaterInf = (1.0-isEyeInWater*.3);
    float fogBlendDepth = (depthCos*.8+.2);
    depthBlurCd.rgb *= mix( (fogColor*fogBlendDepth), vec3(1.0), fogBlendDepth*eyeWaterInf);
    blurMidCd*=depthBase;
    blurLowCd*=depthBase;
    
    baseCd = depthBlurCd;
    outCd = depthBlurCd;
    
  }
  
  
  // -- -- -- -- --
  // -- To Cam - -- --
  // -- -- -- -- -- -- --
  // Fit Normal
  normalCd.rgb = normalCd.rgb*2.0-1.0;
  // Dot To Camera
  //float dotToCam = dot(normalCd.rgb,vec3(0.0,0.0,1.0));
  float dotToCam = dot(normalCd.rgb,normalize(vec3(-(uv-.5),1.0)));
  float dotToCamClamp = max(0.0, dotToCam);
  dotToCamClamp = smoothstep(.2,1.0, dotToCamClamp);

  // -- -- -- -- -- -- -- 
  // -- Sky Influence  -- --
  // -- -- -- -- -- -- -- -- --
  float skyBrightnessMult=eyeBrightnessSmooth.y*0.004166666666666666;//  1.0/240.0
  float skyBrightnessInf = skyBrightnessMult*.5+.5;
  
#ifdef NETHER
  skyBrightnessInf = 1.0;
#endif

  // -- -- -- -- -- -- -- 
  // -- Rain Influence  -- --
  // -- -- -- -- -- -- -- -- --
  float rainInf = (1.0-rainStrength*2.0);
  rainInf = mix( 1.0, rainInf, skyBrightnessMult);
  
  // -- -- -- -- -- -- -- -- -- -- -- -- --
  // -- == == == == == == == == == == == --
  // -- -- -- -- -- -- -- -- -- -- -- -- --
  
  // -- -- -- -- -- -- -- --
  // -- Edge Detection -- -- --
  // -- -- -- -- -- -- -- -- -- --
  float edgeDistanceThresh = .005;
  float reachOffset = min(.4,isEyeInWater*.2) + rainStrength*.2;
  float reachMult = depthCos*(.6+reachOffset)+.4-reachOffset;//1.0;//depthBase*.5+.5 ;
  reachMult = reachMult * (1.0+rainStrength);

#ifdef NETHER
  reachMult *= 1.75;
#endif
  
  vec3 avgNormal = normalCd.rgb;
  float edgeInsidePerc;
  float edgeOutsidePerc;
  findEdges( colortex0, colortex1, colortex2, uv, res*(1.5+isEyeInWater*3.5)*reachMult*EdgeShading, depthBase,normalCd.rgb, edgeDistanceThresh, avgNormal,edgeInsidePerc,edgeOutsidePerc );


  edgeInsidePerc *= 1.0-min(1.0,max(0,isEyeInWater)*.5);
  edgeInsidePerc *= dotToCamClamp*1.5-reachOffset*4.5;
  //edgeInsidePerc *= abs(dotToCam);
  edgeInsidePerc *= min(1.0,depthCos*4.5);
  edgeInsidePerc = clamp(edgeInsidePerc,0.0,1.0);
  edgeOutsidePerc = min(edgeOutsidePerc,depthBase*.3+.1);
  edgeOutsidePerc = clamp(edgeOutsidePerc,0.0,1.0);
  
  
	//const vec3 moonlight = vec3(0.5, 0.9, 1.8) * Moonlight;
  //edgeInsidePerc = smoothstep(.0,.8,min(1.0,edgeInsidePerc));


  float edgeInsideOutsidePerc = max(edgeInsidePerc,edgeOutsidePerc);
  
  
  // -- -- -- -- -- -- -- -- --
  // -- Sun & Moon Edge Influence -- --
  // -- -- -- -- -- -- -- -- -- -- --
#ifdef OVERWORLD
/*
    float sunNightInf = abs(dayNight)*.3;
    float sunInf = dot( avgNormal, sunVecNorm ) * max(0.0, dayNight);
    float moonInf = dot( avgNormal, vec3(1.0-sunVecNorm.x, sunVecNorm.yz) ) * max(0.0, -dayNight);
    //vec3 colorHSV = rgb2hsv(outCd.rgb);
    
    float sunMoonValue = max(0.0, sunInf+moonInf) * edgeInsideOutsidePerc * sunNightInf * shadow;
    //float sunMoonValue = max(0.0, sunInf+moonInf) * sunNightInf;// * edgeInsideOutsidePerc;// * shadow;
    
    //colorHSV.b += sunMoonValue;
  //colorHSV.b += sunMoonValue;//-(shadow*.2+depthBase*.2)*EdgeShading;
    //colorHSV.b *= 1.0*(shadow+.2);//+depthBase*.2)*EdgeShading;
  //outCd.rgb = hsv2rgb(colorHSV);
    //outCd.rgb = mix( baseCd.rgb, mix(baseCd.rgb*1.5,outCd.rgb,shadow)*edgeInsideOutsidePerc, EdgeShading*.25+.5);
  //outCd.rgb = mix( outCd.rgb, hsv2rgb(colorHSV), EdgeShading*.25+.75);
    //outCd.rgb = mix( baseCd.rgb, outCd.rgb, EdgeShading*.25+.5);
*/
#endif



  // -- -- -- -- -- -- -- -- -- -- -- -- --
  // -- World Specific Edge Colorization -- --
  // -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
  
#ifdef NETHER
  //outCd.rgb *= outCd.rgb * vec3(.8,.6,.2) * edgeInsideOutsidePerc;// * (shadow*.3+.7);
  outCd.rgb =  mix(outCd.rgb, outCd.rgb * vec3(.75,.5,.2), edgeInsideOutsidePerc);// * (shadow*.3+.7);
  
  edgeInsidePerc *= .8;
  edgeOutsidePerc *= 2.5;
  
#endif

#ifdef OVERWORLD
  float sunEdgeInf = dot( sunVecNorm, avgNormal );
  //outCd.rgb += outCd.rgb * (edgeOutsidePerc*sunEdgeInf*.5);// * (shadow*.3+.7);
  outCd.rgb+= outCd.rgb * sunEdgeInf*edgeOutsidePerc ;
  outCd.rgb += mix( outCd.rgb, skyColor, sunEdgeInf*.5*dataCd.r*skyBrightnessMult)*edgeOutsidePerc*dataCd.r;
#endif
  
  
  

  // -- -- -- -- -- -- -- --
  // -- Glow Mixing -- -- -- --
  // -- -- -- -- -- -- -- -- -- --
  float lavaSnowFogInf = 1.0 - min(1.0, max(0.0,isEyeInWater-1.0)) ;
  
  vec3 outGlowCd = max(blurMidCd, blurLowCd);
  outCd.rgb += outGlowCd * GlowBrightness;// * lavaSnowFogInf;
  
  float edgeCdInf = step(depthBase, .9999);
  // TODO : Check skyBrightness for inner edges when in caves
  //edgeCdInf *= (skyBrightnessInf*.5+.5) * rainInf;
  edgeCdInf *= lavaSnowFogInf;

  outCd.rgb += outCd.rgb*edgeInsidePerc*abs(dotToCam)*2.0*edgeCdInf;
  outCd.rgb += outCd.rgb*edgeOutsidePerc*edgeCdInf;
  
  float depthInfBase = spectralDataCd.g;
  depthInfBase *= depthInfBase*depthInfBase;
  
  float spectralInt = spectralDataCd.b;// + (spectralDataCd.g-.5)*3.0;
  //spectralInt *= spectralInt*spectralInt;
  //outCd.rgb += outCd.rgb*spectralInt;
  outCd.rgb += outCd.rgb * spectralInt * spectralDataCd.r;
  //outCd.rgb = vec3( spectralDataCd.rgb );
  
  outCd.rgb *= LightingBrightness;
  
	gl_FragColor = vec4(outCd.rgb,1.0);
}
#endif
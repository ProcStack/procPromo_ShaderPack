/* -- -- -- -- -- --
  -Shadow Pass is not being used.
    Buffer currently has Sun Shadow written to it
    Should be block luminance;
      Transparent blocks included
   -- -- -- -- -- -- 
  Notes :
	  Highlighted Block edge thickness is set in gbuffer_basic.glsl
	 
*/


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

uniform sampler2D shadowcolor0;
uniform vec3 cameraPosition;

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


uniform float darknessFactor; //                   strength of the darkness effect (0.0-1.0)
uniform float darknessLightFactor; //              lightmap variations caused by the darkness effect (0.0-1.0) 

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
                  inout vec3 avgNormal, inout float innerEdge, inout float outerEdge ){

  vec2 uvDepthLimit = uv+uvOffset;
  vec2 uvNormalLimit = uv+uvOffset*1.5;
  float curDepth = texture2D(txDepth, uvDepthLimit).r;
  vec3 curNormal = texture2D(txNormal, uvNormalLimit).rgb*2.0-1.0;
  
  float curNormalDot = 1.0-abs(dot(normalRef, curNormal));
	curNormalDot *= curNormalDot;
  //curDepth = max(0.0, abs(curDepth - depthRef)-.009)*50.5;
  curDepth = clamp( (abs(curDepth - depthRef)-.01),0.0,1.0);

  float curInf = step( curDepth, thresh );

  innerEdge = mix( innerEdge, curNormalDot, .125*curInf );
  outerEdge = max( outerEdge, curDepth );
  avgNormal = (mix( avgNormal, curNormal, .125*curInf ));
  
}


// -- -- -- -- -- -- -- -- -- -- -- -- --
// -- Sample Depth & Normals; 3x3 - -- -- --
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// TODO : Implement Base Quality by using Cross instead of 3x3
void findEdges( sampler2D txColor, sampler2D txDepth, sampler2D txNormal,
                vec2 uv, vec2 txRes,
                float depthRef, vec3 normalRef, float thresh,
                inout vec3 avgNormal, inout float innerEdgePerc, inout float outerEdgePerc ){
  
  float innerEdge = 0.0;
  float outerEdge = 0.0;
  
  vec2 uvOffsetReach = txRes;
  
  vec2 curUVOffset;
  curUVOffset = uvOffsetReach * vec2( -1.0, -1.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,avgNormal, innerEdge,outerEdge );
  curUVOffset = uvOffsetReach * vec2( -1.0, 0.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,avgNormal, innerEdge,outerEdge );
  curUVOffset = uvOffsetReach * vec2( -1.0, 1.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,avgNormal, innerEdge,outerEdge );
  
  curUVOffset = uvOffsetReach * vec2( 0.0, -1.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,avgNormal, innerEdge,outerEdge );
  curUVOffset = uvOffsetReach * vec2( 0.0, 1.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,avgNormal, innerEdge,outerEdge );
  
  curUVOffset = uvOffsetReach * vec2( 1.0, -1.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,avgNormal, innerEdge,outerEdge );
  curUVOffset = uvOffsetReach * vec2( 1.0, 0.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,avgNormal, innerEdge,outerEdge );
  curUVOffset = uvOffsetReach * vec2( 1.0, 1.0 );
  edgeLookUp( txColor,txDepth,txNormal, uv,curUVOffset,depthRef,normalRef,thresh,avgNormal, innerEdge,outerEdge );
  
  outerEdge *= step(0.05, outerEdge); 
  
  avgNormal = normalize(avgNormal);
  innerEdgePerc = innerEdge;
  outerEdgePerc = outerEdge;
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
	vec2 uvShifted = abs(uv-.5);
	uvShifted *= uvShifted;
	
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
// All threads are in or out, leaving for now
  if( UnderWaterBlur && isEyeInWater >= 1 ){
    float depthBlurInf = smoothstep( .5, 1.5, depth);//biasToOne(depthBase);
    
    float depthBlurTime = worldTime*.07 + depth*3.0;
    float depthBlurWarpMag = .006;
    float uvMult = 20.0 + 10.0*depthCos;
    
    vec2 depthBlurUV = uv + vec2( sin(uv.x*uvMult+depthBlurTime), cos(uv.y*uvMult+depthBlurTime) )*depthBlurWarpMag*depthBlurInf;
    vec2 depthBlurReach = vec2( max(0.0,depthBlurInf-length(blurMidCd)) * texelSize * 6.0 * (1.0-nightVision));
    vec4 depthBlurCd = boxSample( colortex0, depthBlurUV, depthBlurReach, .25 );
    depthBlurCd.rgb = mix( fogColor*depthCos, (fogColor*.5+.5)*depthBlurCd.rgb, min(1.0,(1.0-depth*.5)));
    
    float eyeWaterInf = (1.0-isEyeInWater*.2);
    //float fogBlendDepth = ((depth+.5)*depth+.8);
    //depthBlurCd.rgb = min(vec3(1.0), depthBlurCd.rgb*mix( (fogColor*fogBlendDepth), vec3(1.0), fogBlendDepth*eyeWaterInf));

    
    baseCd = depthBlurCd;
    outCd = depthBlurCd;
    
  }
  
  
// -- -- -- -- --
// -- To Cam - -- --
// -- -- -- -- -- -- --
// Fit Normal
  normalCd.rgb = normalCd.rgb*2.0-1.0;
// Dot To Camera
  float dotToCam = dot(normalCd.rgb,normalize(vec3(.5-uv,1.0)));
  float dotToCamClamp = max(0.0, dotToCam);
  dotToCamClamp = smoothstep(.2,1.0, dotToCamClamp);


// -- -- -- -- -- -- -- 
// -- Sky Influence  -- --
// -- -- -- -- -- -- -- -- --
  float skyBrightnessMult=eyeBrightnessSmooth.y*0.004166666666666666;//  1.0/240.0
  float skyBrightnessInf = skyBrightnessMult*.5+.5;
  

// -- -- -- -- -- -- -- 
// -- Rain Influence  -- --
// -- -- -- -- -- -- -- -- --
  float rainInf = (1.0-rainStrength*.7);
  rainInf = mix( 1.0, rainInf, skyBrightnessMult);
  
  
// -- -- -- -- -- -- -- --
// -- Edge Detection -- -- --
// -- -- -- -- -- -- -- -- -- --
  float edgeDistanceThresh = .003;
// Edge detect width shift, based on rain or being in water/lava/snow
  float reachOffset = min(.4,isEyeInWater*.5) + rainStrength*1.5;
// Edge detect width
  float reachMult = mix(3.0-dataCd.r*1.65, .6-skyBrightnessMult*.15+reachOffset, depth );//1.0;//depthBase*.5+.5 ;

// Final Edge Value Multipliers
	float innerMult = 1.0;
	float outerMult = 1.0;

#ifdef NETHER
// Tweak Nether settings 
  skyBrightnessInf = 1.0;
// Make the edge lines fatter in the dark
  reachMult *= 0.9+(1.0-dataCd.r*1.5);
// Bias the Cosine Depth closer to the camera
	depthCos=biasToOne(depthCos);
	
	innerMult = .8;
	outerMult = 2.5;
#endif
  
  vec3 avgNormal = normalCd.rgb;
  float innerEdgePerc;
  float outerEdgePerc;
  findEdges( colortex0, colortex1, colortex2,
             uv, res*(1.5)*reachMult*EdgeShading,
             depthBase, normalCd.rgb, edgeDistanceThresh, avgNormal,
             innerEdgePerc,outerEdgePerc );

  innerEdgePerc *= 1.0-min(1.0,float(max(0,isEyeInWater))*.35);
  innerEdgePerc *= dotToCamClamp*1.5-reachOffset*1.5;
	
// Screen edges influence
	float screenEdgeMult = max(0.0, 1.0-maxComponent(uvShifted) * 2.5); // Higher the #, darker the edges
// Edge depth boost
	float edgeDepthInf = (depthCos*.8+.02)*2.5;
	
// Output Individual Edge Values
  innerEdgePerc = clamp(innerEdgePerc * edgeDepthInf * screenEdgeMult * innerMult, 0.0, rainInf )	;
  outerEdgePerc = clamp( outerEdgePerc * edgeDepthInf * outerMult, 0.0, rainInf );
  
// Combine Inner & Outer Edge Values
  //float edgeInsideOutsidePerc = clamp(max(innerEdgePerc,outerEdgePerc)*(depthCos-.01)*10.5, 0.0, rainInf-float(isEyeInWater)*.27 );
  float edgeInsideOutsidePerc = clamp(max(innerEdgePerc,outerEdgePerc), 0.0, rainInf-float(isEyeInWater)*.27 );


// -- -- -- -- -- -- -- -- -- -- -- -- --
// -- World Specific Edge Colorization -- --
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
#ifdef OVERWORLD
	// Edge boost around well lit areas
  float sunEdgeInf = dot( sunVecNorm, avgNormal );
  outCd.rgb += mix( outCd.rgb, fogColor, dataCd.r*skyBrightnessMult)*edgeInsideOutsidePerc*dataCd.r*.3*depthCos;
#elif defined NETHER
  //outCd.rgb *= outCd.rgb * vec3(.8,.6,.2) * edgeInsideOutsidePerc;// * (shadow*.3+.7);
  outCd.rgb =  mix(outCd.rgb, outCd.rgb * vec3(.75,.5,.2), edgeInsideOutsidePerc);// * (shadow*.3+.7);
#endif
  
  
// -- -- -- -- -- -- -- --
// -- Glow Mixing -- -- -- --
// -- -- -- -- -- -- -- -- -- --
  float lavaSnowFogInf = 1.0 - min(1.0, max(0.0,isEyeInWater-1.0)) ;
  
  vec3 outGlowCd = max(blurMidCd, blurLowCd);
  outCd.rgb += outCd.rgb*outGlowCd * GlowBrightness;// * lavaSnowFogInf;
  
  
  float edgeCdInf = step(depthBase, .9999);
  edgeCdInf *= lavaSnowFogInf;
	
// Apply Edge Coloring
  outCd.rgb += outCd.rgb*.3*edgeInsideOutsidePerc*edgeCdInf;
  
// Boost Glowing Entity's Color
  float spectralInt = spectralDataCd.b;// + (spectralDataCd.g-.5)*3.0;
  outCd.rgb += outCd.rgb * spectralInt * spectralDataCd.r;
  
  
// Shadow Helper Mini Window
//   hmmmmm picture-in-picture
//     drooollllssss
  #if ( DebugView == 2 ||  DebugView == 3 )
    //float fitWidth = 1.0 + fract(viewWidth/float(shadowMapResolution))*.5;
    float fitWidth = 1.0 + aspectRatio*.45;
    vec2 debugShadowUV = vec2((uv.x-.5)*fitWidth+.5,uv.y)*2.35 + vec2(-2.25,-.04);
    vec3 shadowCd = texture2D(shadowcolor0, debugShadowUV ).xyz;
    debugShadowUV = abs(debugShadowUV-.5);
    float shadowHelperMix = max(debugShadowUV.x,debugShadowUV.y);
    shadowCd = mix( vec3(0.0), shadowCd.rgb, step(shadowHelperMix, 0.50));
    outCd.rgb = mix( outCd.rgb, shadowCd, step(shadowHelperMix, 0.502));
  #endif
	
// Vanilla -vs- procPromo Debugger
	#if ( DebugView == 4 )
		//vec2 screenSpace = (vPos.xy/vPos.z)  * vec2(aspectRatio);
		float debugBlender = step( .5, uv.x);
		outCd = mix( baseCd, outCd, debugBlender);
	#endif
	//outCd.rgb=vec3(innerEdgePerc);
	//outCd.rgb=vec3(outerEdgePerc);
	//outCd.rgb=vec3(edgeInsideOutsidePerc);
	
	gl_FragColor = vec4(outCd.rgb,1.0);
}
#endif
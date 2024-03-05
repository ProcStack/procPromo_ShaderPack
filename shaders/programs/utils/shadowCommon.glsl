
// Learned from Chocapic13's HighPerformance Toaster shader pack
//  I'm still picking up this shadow stuffs, but mostly wrote whats below
//    Baring the player-space to shadow-space logic
//      It just works; and I like how they defined a function that way
// Functions for Radial & Per-Axis Shadow Biasing below
//   For most situations,
//     Radial Biasing works just fine
//       A little wasteful, but quick & easy
//   For a block game,
//     Per-Axis Biasing reduces mid-distance scalping of a Radial shadow's edge

const bool waterShadowEnabled = false;
const bool generateShadowMipmap = true;
const bool generateShadowColorMipmap = true;
const bool shadowHardwareFiltering = true;
//const bool shadowtexNearest = true;
//const bool shadowtex0Nearest = true;
//const bool shadow0MinMagNearest = true;

const int shadowMapResolution = 2048; // [512 1024 2048 4096 8192 16384]
const float shadowMapTexelSize = 1.0/float(shadowMapResolution);

const float shadowMapFov = 90.0; 
const float shadowDistance = 256.0;//224.0;//128.0;
const float sunPathRotation = 0.0;
const float shadowDistanceRenderMul = 1.0; // [-1.0 1.0] -1 Higher quality.  1 Shadow optimizations 
const float shadowIntervalSize = 1.00;

const float shadowDistBiasMult = 30.0;

const float shadowRadialBiasMult = 1.33;
const float shadowRadialBiasOffset = .02;
const float shadowAxisBiasMult = 1.13;
const float shadowAxisBiasOffset = .65;
const float shadowAxisBiasPosOffset = 0.02;

// Peter-Pan'ing / Shadow Surface Offset
const float shadowThreshold = shadowDistance/(shadowMapFov*.5);
const float shadowThreshBase = 0.000006;
const float shadowThreshDist = 0.000016;

const float oneThird = 1.0 / 3.0;

const vec3 shadowPosOffset = vec3(0.5,0.5,shadowThreshold);
const vec3 shadowPosMult = vec3(0.5);

// -- -- -- -- -- -- -- --


// == Chocapic13's HighPerformance Toaster; Shadow-space helpers ==
//      If it aint broke, don't fix it
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec4 toClipSpace3(mat4 matrixSpace, vec3 viewSpacePosition) {
    return vec4(projMAD(matrixSpace, viewSpacePosition),-viewSpacePosition.z);
}
// == -- -- -- -- ==


// -- -- -- -- -- -- -- --
/*
vec3 toShadowPosition(){
  // Shadow Prep
  position = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;
  
  float shadowPushAmmount = 1.0-abs(dot(sunVecNorm, gl_Normal))*.9;//normal));
  vec3 shadowPush = gl_Normal*shadowPushAmmount*.2 ;
  vec3 ret = mat3(shadowModelView) * (position.xyz+shadowPush) + shadowModelView[3].xyz;
  vec3 shadowProjDiag = diagonal3(shadowProjection);
  ret = shadowProjDiag * shadowPos.xyz + shadowProjection[3].xyz;
  return ret;
}
*/
// -- -- --
/*
vec3 fitShadowOffset( vec3 posOffset ){
  posOffset = fract(posOffset);
  posOffset.x = (posOffset.x<.5 ? -posOffset.x : .5-posOffset.x);
  posOffset.y = (posOffset.y<.5 ? -posOffset.y : .5-posOffset.y);
  posOffset.z = (posOffset.z<.5 ? -posOffset.z : .5-posOffset.z);
  return posOffset;
}
*/
// -- -- -- -- -- -- -- --
// -- -- -- -- -- -- -- --
// -- -- -- -- -- -- -- --

//
// Bias toward Distance-From-Center; Radial Compression
//    https://youtu.be/WZNt9p4LWeA
//

float radialBias(vec2 shadowSpaceUV, float offset, float mult){
  float pLen = length(shadowSpaceUV)*.5;
  return pow(pLen+offset,(.65)-pLen*(mult));
}
float radialBias(vec2 shadowSpaceUV){
  return radialBias(shadowSpaceUV, shadowRadialBiasOffset, shadowRadialBiasMult);
}

vec4 biasShadowRadial(vec4 shadowSpacePos) {
  float distortFactor = radialBias(shadowSpacePos.xy);
  shadowSpacePos.xy /= distortFactor;
  #ifdef SHADOW
    shadowSpacePos.z *= oneThird;
  #endif
  return shadowSpacePos;
}

// -- -- --

//
// Bias toward Axial-Weighting; Individually Biased X/Y 
//    https://youtu.be/GBkT19uH2RQ
//

vec2 axisBias(vec2 shadowSpaceUV, float offset, float mult){
  vec2 outUV=shadowSpaceUV;
  outUV.xy = abs(outUV.xy);
  float pLen = max(outUV.x,outUV.y)*.5;
  outUV.x = pow(pLen+offset,(.65)-pLen*(mult));
  outUV.y=outUV.x;
  return outUV;
}
vec2 perAxisBias(vec2 shadowSpaceUV, float offset, float mult){
  vec2 outUV=shadowSpaceUV;
  float pLen = abs(outUV.x)*.5;
  outUV.x = pow(pLen+offset,(.65)-pLen*(mult));
  pLen = abs(outUV.y)*.5;
  outUV.y = pow(pLen+offset,(.65)-pLen*(mult));
  return outUV;
}
vec2 axisBias(vec2 shadowSpaceUV){
  return axisBias(shadowSpaceUV, shadowAxisBiasOffset, shadowAxisBiasMult);
}
vec4 biasShadowAxis(vec4 shadowSpacePos) {
  vec2 distortFactor = axisBias(shadowSpacePos.xy);
  shadowSpacePos.xy /= distortFactor;
  #ifdef SHADOW
    shadowSpacePos.z *= oneThird;
  #endif
  return shadowSpacePos;
}

// -- -- --
 
vec4 biasShadowShift(vec4 shadowSpacePos) {
  vec2 outUV=shadowSpacePos.xy;
  outUV.xy = abs(outUV.xy);
  //
  float pLen = outUV.x*.5;
  outUV.x = pow(pLen+shadowAxisBiasPosOffset, max(0.0,shadowAxisBiasOffset-pLen*shadowAxisBiasMult));
  pLen = outUV.y*.5;
  outUV.y = pow(pLen+shadowAxisBiasPosOffset, max(0.0,shadowAxisBiasOffset-pLen*shadowAxisBiasMult));
  shadowSpacePos.xy /= outUV;
  //
  
  #ifdef SHADOW
    //shadowSpacePos.z *= oneThird;
  #endif
  return shadowSpacePos;
}

// -- -- --
 
void biasToNDC( mat4 targetSpace, inout vec4 posVal, inout vec4 camDir ){
  //camDir.xz = normalize( (mat3(targetSpace)*vec3(0.0,0.0,1.0)).xz );
  camDir.xz = normalize( vec2(targetSpace[2].x,targetSpace[2].z) );
  camDir.y = 1.0-targetSpace[1].y;
  vec2 uvDir = camDir.xz;
  
  float shiftDot = (dot(normalize(posVal.xy), uvDir));
  float shiftInf = clamp((shiftDot-.15)*1.0, 0.0, 1.0);
  float upDownInf = min(1.0,targetSpace[1].y*2.0);
  
  vec3 apm = vec3(.02, .5, 3.0);
  apm = vec3(.003, .55, 3.83); // Not In View
  //max(abs(posVal.x),abs(posVal.z));
  apm = mix( apm, vec3(.08, .65, .8), shiftInf ); // Not In View or In View
  apm = mix( vec3(.08, .65, 1.0), apm, upDownInf ); // Look Up/Down or Look Out
  
  
  shiftInf = shiftInf*upDownInf;
  
  vec2 biased =  abs(posVal.xy*.5);//*(1.0-shiftInf*.5);
  biased = pow(biased+apm.xx,apm.yy-max(vec2(0.0),biased*apm.zz));
  biased = posVal.xy/biased;
  //posVal.xy = biased;
  //biased =  (posVal.xy);
  
  //posVal.xy = mix( biased, biased, shiftInf );
  //posVal.xy *= 1.0-biased;
  posVal.xy = biased - camDir.xz*(upDownInf)*.5;
  
  //posVal.xy *= shiftInf;
  
  #ifdef SHADOW
    posVal.z *= oneThird;
  #endif
  
  shiftInf = shiftInf+(1.0-upDownInf);
  camDir.w=shiftInf;//length(posVal.xy)*shiftInf;
}


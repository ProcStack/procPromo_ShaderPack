
// Learned from Chocapic13's HighPerformance Toaster shader pack
//  I'm still picking up this shadow stuffs,
//    So the logic may look pretty close to Chocapic13's shader
//    Baring the player-space to shadow-space logic
//      It just works; and I like how they defined a function that way
// Functions for Radial & Per-Axis Shadow Biasing below
//   For most situations,
//     Radial Biasing works just fine
//       A little wasteful, but quick & easy
//   For a block game,
//     Per-Axis Biasing reduces mid-distance scalping of a Radial shadow's edge

// Radial -vs- Axial Distortion Note -
//  'Radial' stuff isn't used.
//    It's the classic shadow distortion
//      I use axial distortion
//        Since this is a 90-degree based block game
//  I'll remove Radial's when I make a 'glsl-bootstrap' repo

const bool waterShadowEnabled = true;
const bool generateShadowMipmap = true;
const bool generateShadowColorMipmap = true;
const bool shadowHardwareFiltering = true;
//const bool shadowtexNearest = true;
//const bool shadowtex0Nearest = true;
//const bool shadow0MinMagNearest = true;

const int shadowMapResolution = 2048; // [512 1024 2048 4096 8192 16384]
const float shadowMapTexelSize = 1.0/float(shadowMapResolution);

// FOV + Distance alters the edge of the shadow
//   Which in turn changes luminance of blocks that should be in shadow
//     Use "Debug Vision: Shadow Debug" while editings these two vvv
//       The color borders at 16 chunks should roughly touch the edges
//         Picture-in-Picture baby!
const float shadowMapFov = 90.0; 
const float shadowDistance = 320.0; //256.0; // 224.0; // 128.0;


const float sunPathRotation = 1.0;
const float shadowDistanceRenderMul = 1.0; // [-1.0 1.0] -1 Higher quality.  1 Shadow optimizations 
const float shadowIntervalSize = 1.00;

//  From Edge
// edgeFade -> 1-(1-abs(world.xy))*edge 
const float shadowEdgeFade = 10.0;

const float shadowMaxSaturation = 0.7; // 0.0-1.0; Lower is darker
const float shadowLightInf = 0.85; // 0.0-1.0; Lower is darker

// Distance from base of shadow to blend in a blurry shadow
//   Close to shadow is sharp, further is blurred
const float shadowDistBiasMult = 5.0;

const float shadowRadialBiasMult = 1.33;
const float shadowRadialBiasOffset = .02;
const float shadowAxisBiasMult = 1.13;
const float shadowAxisBiasOffset = .65;
const float shadowAxisBiasPosOffset = 0.02;

// Peter-Pan'ing / Shadow Surface Offset
const float shadowThreshold = shadowDistance/(shadowMapFov*.5);
const float shadowThreshold_Entity = shadowThreshold*.45;

// Shadow Biases; Scalping Reduction
const float shadowThreshBase = 0.00003; // Bias near to Camera
const float shadowThreshBase_Entity = 0.00003; // gbuffers_entities.glsl
const float shadowThreshDist = 0.000026; // Bias far from Camera

const float oneThird = 1.0 / 3.0;

const vec3 shadowPosOffset = vec3(0.5,0.5,shadowThreshold);
const vec3 shadowPosOffset_Entity = vec3(0.5,0.5,shadowThreshold_Entity);
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
 
vec4 distortShadowShift(vec4 shadowSpacePos) {
  vec2 outUV=shadowSpacePos.xy;
  outUV.xy = abs(outUV.xy);
  //
  float pLen = outUV.x*.5;
  outUV.x = pow(pLen+shadowAxisBiasPosOffset, max(0.0,shadowAxisBiasOffset-pLen*shadowAxisBiasMult));
  pLen = outUV.y*.5;
  outUV.y = pow(pLen+shadowAxisBiasPosOffset, max(0.0,shadowAxisBiasOffset-pLen*shadowAxisBiasMult));
  shadowSpacePos.xy /= outUV;
  //
  
  return shadowSpacePos;
}

vec4 distortShadowShift(vec4 shadowSpacePos, float scalar) {
  vec2 outUV=shadowSpacePos.xy;
  outUV.xy = abs(outUV.xy);
  //
  float pLen = outUV.x*.5;
  outUV.x = pow(pLen+shadowAxisBiasPosOffset*scalar, max(0.0,shadowAxisBiasOffset-pLen*shadowAxisBiasMult));
  pLen = outUV.y*.5;
  outUV.y = pow(pLen+shadowAxisBiasPosOffset*scalar, max(0.0,shadowAxisBiasOffset-pLen*shadowAxisBiasMult));
  shadowSpacePos.xy /= outUV;
  //
  
  #ifdef SHADOW
    //shadowSpacePos.z *= oneThird;
  #endif
  return shadowSpacePos;
}

// -- -- --
 
void distortToNDC( mat4 targetSpace, inout vec4 posVal, inout vec4 camDir ){
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
  
  posVal.xy = biased - camDir.xz*(upDownInf)*.5;
  
  #ifdef SHADOW
    posVal.z *= oneThird;
  #endif
  
  shiftInf = shiftInf+(1.0-upDownInf);
  camDir.w=shiftInf;//length(posVal.xy)*shiftInf;
}




const bool generateShadowMipmap = true;
const bool shadowHardwareFiltering = true;


// Modified from Chocapic13's HighPerformance Toaster shader pack
//  (I'm still learning this shadow stuffs)


const float shadowMapFov = 72.0; 
const float shadowDistance = 192.0;//128.0;
const float shadowDistanceRenderMul = 1.0; //[-1.0 1.0] -1 Higher quality.  1 Shadow optimizations 
const float shadowIntervalSize = 0.50;

const float shadowBiasMult = 1.05;//1.35;//1.5;
float shadowBiasOffset = 1.25;//1.25;//1.29;//1.10;//1.08;


// const float shadowThreshold = 0.0006*shadowDistance/45.;
const float shadowThreshold =0.00001*shadowDistance/shadowMapFov;// * 2048./shadowMapResolution;

const float oneThird = 1.0 / 3.0;
const float thirdHalf = .5 * oneThird;
const float shadowThreshReciprical = 0.5 - shadowThreshold;

const vec3 shadowPosOffset = vec3(0.5,0.5,shadowThreshReciprical);
const vec3 shadowPosMult = vec3(0.5,0.5,thirdHalf);

// -- -- --

vec3 fitShadowOffset( vec3 posOffset ){
  posOffset = fract(posOffset);
  posOffset.x = (posOffset.x<.5 ? -posOffset.x : .5-posOffset.x);
  posOffset.y = (posOffset.y<.5 ? -posOffset.y : .5-posOffset.y);
  posOffset.z = (posOffset.z<.5 ? -posOffset.z : .5-posOffset.z);
  return posOffset;
}

// -- -- --

float shadowBias_bk(vec2 worldPos, float offset, float mult){
  //return (log(length(worldPos)+offset)*mult);
  return pow(length(worldPos)*.1+.1,0.80);
}


float shadowBias(vec2 worldPos, float offset, float mult){
  //return (log(length(worldPos)+offset)*mult);
  float pLen = length(worldPos)*.5;
  //float pLen = length(worldPos);
  //pLen = (1.5-max(1.5,pLen+pLen))-.5;
  return pow(pLen+.05,.65-pLen*.8);
  //return pLen;
}
float shadowBias(vec2 worldPos){
  return shadowBias(worldPos, shadowBiasOffset, shadowBiasMult);
}

vec4 biasShadowPos(vec4 shadowSpacePos) {
  float distortFactor = shadowBias(shadowSpacePos.xy);
  shadowSpacePos.xy /= distortFactor;
  shadowSpacePos.z *= oneThird;
  return shadowSpacePos;
}



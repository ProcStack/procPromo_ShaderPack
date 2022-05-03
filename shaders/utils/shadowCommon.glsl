

const bool generateShadowMipmap = true;
const bool shadowHardwareFiltering = true;


// Modified from Chocapic13's HighPerformance Toaster shader pack
//  (I'm still learning this shadow stuffs)

const int shadowMapResolution = 2048; //[512 768 1024 1536 2048 3172 4096 8192 16384]
//const float shadowMapFov = 90.0; 
const float shadowDistance = 128.0;
const float shadowDistanceRenderMul = -1.0; //[-1.0 1.0] Can help to increase shadow draw distance when set to -1.0, at the cost of performance
const float shadowIntervalSize = 1.0;

const float k = 1.9;
float a = 1.1;//1.08;

vec4 BiasShadowProjection(in vec4 projectedShadowSpacePosition) {
  float distortFactor = log(length(projectedShadowSpacePosition.xy)+a)*k;
  projectedShadowSpacePosition.xy /= distortFactor;
  return projectedShadowSpacePosition;
}
float calcDistort(vec2 worldpos){
  return (log(length(worldpos)+a)*k);
}

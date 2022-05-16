

const bool generateShadowMipmap = true;
const bool shadowHardwareFiltering = true;


// Modified from Chocapic13's HighPerformance Toaster shader pack
//  (I'm still learning this shadow stuffs)

//const float shadowMapFov = 90.0; 
const float shadowDistance = 128.0;
const float shadowDistanceRenderMul = -1.0; //[-1.0 1.0] Can help to increase shadow draw distance when set to -1.0, at the cost of performance
const float shadowIntervalSize = 1.0;

const float k = 1.35;//1.5;
float a = 1.15;//1.10;//1.08;

vec4 BiasShadowProjection(in vec4 projectedShadowSpacePosition) {
  float distortFactor = log(length(projectedShadowSpacePosition.xy)+a)*k;
  projectedShadowSpacePosition.xy /= distortFactor;
  return projectedShadowSpacePosition;
}
float calcDistort(vec2 worldpos){
  return (log(length(worldpos)+a)*k);
}

// GBuffer - Composite #4 GLSL
//   Written by Kevin Edzenga, ProcStack; 2022-2023
//
// Crepuscular Rays
//   Only runs in the Overworld
//     And other worlds marked `0`

#ifdef VSH

  varying vec2 vUv;

  void main() {
    gl_Position = ftransform();
    vUv = gl_MultiTexCoord0.xy;
  }

#endif

#ifdef FSH
/* RENDERTARGETS: 10 */
// target - colortex10

/* COLORTEX9FORMAT:RGBA16 */
/*
const int colortex6Format = RGBA16F;
const int colortex9Format = RGBA16F;
*/

  #include "/shaders.settings"
  #include "utils/mathFuncs.glsl"
  #include "utils/shadowCommon.glsl"

  uniform sampler2D colortex1; // Bind 1
  uniform sampler2D colortex9; // Bind 17
  uniform vec2 texelSize;
  uniform vec2 far;

  uniform sampler2D colortex2; // Normal Pass
  uniform sampler2D gdepth;
  uniform sampler2DShadow shadowtex0;

  uniform mat4 gbufferProjectionInverse;
  uniform mat4 gbufferModelViewInverse;
  uniform mat4 shadowModelView;
  uniform mat4 shadowProjection;
  uniform vec3 sunPosition;
  uniform float rainStrength;
  uniform float moonPhaseMultCrepuscular;
  uniform float moonPhaseFit;


  varying vec2 vUv;


  // -- -- -- -- -- -- -- -- -- -- --
  // -- Shadow Sample Helper  -- --
  // -- -- -- -- -- -- -- -- -- -- -- -- --

  vec3 projectShadowLookup(vec3 viewPos) {
      vec3 worldPos =
          (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

      vec3 shadowPos =
          (shadowModelView * vec4(worldPos, 1.0)).xyz;

      shadowPos = projMAD(shadowProjection, shadowPos);

      vec4 warpedShadowPos = distortShadowShift(vec4(shadowPos, 1.0));

      vec3 lookup = warpedShadowPos.xyz * shadowPosMult + shadowPosOffset;
      lookup.z = 0.5 - min(
          1.0,
          (shadowThreshBase + shadowThreshDist) * shadowThreshold
      );

      return lookup;
  }




  // -- -- -- -- -- -- 
  // -- Doobie Doo! -- --
  // -- -- -- -- -- -- -- --

  void main() {


    vec4 shadowPosDepthBase = texture2D(colortex1, vUv); // Shadow Position and Depth
    vec3 posBase = shadowPosDepthBase.rgb;
    float depthBase = shadowPosDepthBase.a;

    vec4 normalCd = texture2D(colortex2, vUv);


    vec4 outCd = vec4(0.0);


    const int RAY_STEPS = 10;

    float sceneDepth = texture2D(gdepth, vUv).r;
    float hasGeometry = step(sceneDepth, 0.99999);

    vec4 sceneClip = vec4(vUv * 2.0 - 1.0, sceneDepth * 2.0 - 1.0, 1.0);
    vec4 sceneView = gbufferProjectionInverse * sceneClip;
    sceneView.xyz /= sceneView.w;

    float surfaceDistance = length(sceneView.xyz);
    vec3 rayDirection = normalize(sceneView.xyz);

    // Only integrate the intended mid-ground volume.
    float rayStart = 12.0;
    float rayEnd = min(surfaceDistance, 150.0);
    float rayLength = max(0.0, rayEnd - rayStart);

    // Cheap per-pixel phase offset breaks marching bands.
    float jitter = fract(
        sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453
    );

    float rayLight = 0.0;

    for (int stepIndex = 0; stepIndex < RAY_STEPS; ++stepIndex) {
        float stepFit = (float(stepIndex) + jitter) / float(RAY_STEPS);
        float sampleDistance = rayStart + stepFit * rayLength;
        vec3 sampleViewPos = rayDirection * sampleDistance;

        vec3 shadowLookup = projectShadowLookup(sampleViewPos);

        float insideShadowMap =
            step(0.0, shadowLookup.x) * step(shadowLookup.x, 1.0) *
            step(0.0, shadowLookup.y) * step(shadowLookup.y, 1.0);

        float lightVisibility = texture(shadowtex0, shadowLookup);

        // Strongest when looking toward the active sun/moon.
        float forwardScatter = pow(
            max(0.0, dot(-rayDirection, normalize(sunPosition))),
            6.0
        );

        rayLight += lightVisibility * insideShadowMap * forwardScatter;
    }

    float middleDistanceMask =
        smoothstep(8.0, 28.0, surfaceDistance) *
        (1.0 - smoothstep(105.0, 165.0, surfaceDistance));

    float rays =
        rayLight / float(RAY_STEPS) *
        middleDistanceMask *
        hasGeometry *
        (1.0 - rainStrength * 0.65);

    vec3 rayColor = vec3(1.0, 0.92, 0.72);//mix(fogColor, vec3(1.0, 0.92, 0.72), skyBrightnessMult);
    outCd.rgb += rayColor * rays * 0.18;
    outCd.rgb = vec3(  rayLight / float(RAY_STEPS) );
    outCd.rgb = vec3(  moonPhaseMultCrepuscular );



    vec4 dataCdBase = texture2D(colortex9, vUv);

    //float dataSpec = dataCdBase.b;
    float dataSpec = dataCdBase.a;
    vec3 dataRGB = hsv2rgb( vec3(dataCdBase.r, .50, dataCdBase.b) );
    
    float dataDepth = max(0.0, (1.0-dataCdBase.g*1.0) )*dataSpec;
    dataDepth = biasToOne(dataDepth)+.3;
    
    
    gl_FragData[0] = outCd;
    
  }


#endif



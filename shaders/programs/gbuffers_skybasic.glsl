// GBuffer - Sky Basic GLSL
// Written by Kevin Edzenga, ProcStack; 2022-2023
//

#include "/shaders.settings"

#if ( SkyQuality == 0 )
  #include "/programs/gbuffers_skybasic_low.glsl"
#elif( SkyQuality == 1 )
  #include "/programs/gbuffers_skybasic_mid.glsl"
#elif( SkyQuality == 2 )
  #include "/programs/gbuffers_skybasic_high.glsl"
#else
  #include "/programs/gbuffers_skybasic_mid.glsl"
#endif

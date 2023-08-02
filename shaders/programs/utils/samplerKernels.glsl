
#ifndef SamplerKernels
#define SamplerKernels

const int axisSamplesCount = 4;
const vec2 axisSamples[4] = vec2[4](
                              vec2( -1.0, 0.0 ),
                              vec2( 0.0, -1.0 ),
                              vec2( 0.0, 1.0 ),
                              vec2( 1.0, 0.0 )
                            );
                            
const int crossSamplesCount = 4;
const vec2 crossSamples[4] = vec2[4](
                              vec2( -1.0, -1.0 ),
                              vec2( -1.0, 1.0 ),
                              vec2( 1.0, -1.0 ),
                              vec2( 1.0, 1.0 )
                            );
                            
const int boxSamplesCount = 8;
const float boxSampleFit = 0.125; // 1/8;
const vec2 boxSamples[8] = vec2[8](
                              vec2( -1.0, -1.0 ),
                              vec2( -1.0, 0.0 ),
                              vec2( -1.0, 1.0 ),

                              vec2( 0.0, -1.0 ),
                              vec2( 0.0, 1.0 ),

                              vec2( 1.0, -1.0 ),
                              vec2( 1.0, 0.0 ),
                              vec2( 1.0, 1.0 )
                            );
														
const ivec2 boxFetchSamples[8] = ivec2[8](
                              ivec2( -1, -1 ),
                              ivec2( -1, 0 ),
                              ivec2( -1, 1 ),

                              ivec2( 0, -1 ),
                              ivec2( 0, 1 ),

                              ivec2( 1, -1 ),
                              ivec2( 1, 0 ),
                              ivec2( 1, 1 )
                            );

#endif
#version 400

#extension GL_EXT_gpu_shader4 : enable
const bool 	shadowHardwareFiltering0 = true;

#define OVERWORLD

#define FSH

#include "/programs/gbuffers_terrain.glsl"

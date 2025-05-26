#version 330 compatibility

#define OVERWORLD
#define SHADOW

#define FSH

layout(Location = 0) out vec4 outCd;
layout(Location = 1) out vec4 outData;

/* --
const int shadowcolor1Format = RG16;
 -- */

  #include "/shaders.settings"

in vec4 color;
in vec2 texcoord;

uniform sampler2D gtexture;

 
void main() {
    outCd = texture(gtexture, texcoord) * color;
    outData = texture(gtexture, texcoord) * color;
}
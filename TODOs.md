# TODO issues listed in one place
### Git issues are for plebs!
####   ... I'm just too lazy set up a git; <br> But since you're reading this though...


---
#### As of 6/10/2022

### Priorities *(From tasks below)*
- Composite Passes; Move Edge Detection from `final.glsl` to its own `composite#.glsl` file
  - Half Res buffer scale would be good enough for edge detection

#### Code Base -
- Python Splitter Script
  - Write utility to read code and remove #if's and other pragma


#### General-
- Optimizations
  - More parmeter logic
  - More #if #ifdef's
  - Move more generic math to vert stages
- GAT DARM MIN/MAX TEXTURE BOUNDS
  - Would rotating verts around uv mid point work for finding bounds?
  - HOW DO I FIND BOUNDS OF A SPRITE TEXTURE SIZE I DON'T KNOW THE WINDOW OF???
    - What is the texture matrix even doing aside from a set scale value?
- Look into using textureGrad, textureGather, etc. with texture offsets for sampling
  - Do these functions lower/help performance vs running texture2D() multiple times?


#### Terrain-
- Color Blending at depth works poorly with greater color deltas with neighbors
    ( Ore Blocks; Copper Ore turns orange, Emerald Ore turns green )
  - Better color mixing at **Vertex Stage** for block average color
    - Weighted mixing between more common colors
  - Could run more than 5 samples for a better average
- Impliment polsterization math
  - Better detail isolation


#### Shadow-
- Write it!
  - Currently relying on Chocapic13's work
      Unacceptable!

#### Clouds-
- Alter based on being under water


#### Water-
- Write to depth buffer
- Eye in water depth buffer indication


#### Composite Passes-
- New Comp; Edge Detection
- New Comp; Shadow Clean up
  - Already exists as composite1.glsl
      But not sure what could be gained with shadow specific comp
  - Shadows used in crepuscular rays could be useful as a comp, but default shadows?


#### Final Comp-
- Account for Water depth buffer
  - Soften edge highlights in/past water
  - Soften glow through water

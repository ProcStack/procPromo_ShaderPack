# ProcStack's procPromo Code Reference
### Code Disection & Documentation
#### The need to knows to dig through ProcPromo
While the Optifine environment is easy to work within, the learning curve caught me off guard many times.
<br/>General theory and work arrounds documented below.

Since this is a hobby project, a lot of debug or testing code still exists in the files.  Most of which are commented out, but need to find more time to clean up and optimize the code.  Just how life goes it seems, haha.

---

### ProcPromo Render Targets
Since this was the first shader pack I made, initial target buffers weren't set as they were expected from the Optifine docs.
<br/>So until I go through updating all of the prorgams to point to the correct buffers, reference the target render buffers below-
 - `0` - vec4( XYZ; Color, W; Alpha )
 - `1` - vec4( X; Depth, Y; Glow Strength, Z; null, W; Value Exists )
 - `2` - vec4( XYZ; 0-1 fitted normals, W; Value Exists )
 - `6` - vec4( Glow Color HSV; X; Hue, Y; Saturation, Z; Value, W; Value Exists )
 - `7` - vec4( X; MC Block Lighting, Y; Optifine Dynamic Lighting, Z; null, w; Value Exists )
 - `9` - 
 
---

### Detail Blending
#### Block Texture Blending
In `shaders/programs/utils/texSamplers.glsl` there are many different texture sampling blending functions.
<br/>They all have their individual uses, but generally speaking rely on Hue, Saturation, and Value to determine differences in neighboring pixels in the texture.
<br/>With HSV, I can find the deltas in the values, only blending found colors should they be similar enough.  Allowing a blur more akin to `Smart Blur` in photoshop.  Only bluring colors should they be similar, not blending if they vary too much.

#### Distance Based Solid Block Color
In Mojang's promotional art, at a given distance, blocks become singular colors.  Void of any detail at all.
<br/>I'm finding the solid block color by sampling the texture atlas a couple times in the Vertex stage of `gbuffer_block.glsl` and `gbuffer_texture.glsl` and mix the found colors together based on if there is an Alpha value or not.

Some issues I've found is that animated textures, like Water, Lava, Nether Portals, etc., cause rather large jumps in color as they animate.
<br/>For some aspects of this, having a uniform shift in Water and Lava looks pretty good, but does have a penchant for being a little nausiating out at sea or lava walking with a strider.
<br/>(This look and feel is still being worked on.)

Another issue comes from Ores blending to undesirable colors.  For some ores, seeing a solid blue color for lapis at a distance, helps you find blocks at greated distances, but isn't in the vein of minecraft to have such an easy time finding ores.
<br/>Blending in tones that vary from the found "block color" from the vertex stage is allowing ore block colors to be retained at greater distances.  Iron, Copper, Coal, Diamond, and Redstone's visible colors within stone/deepslate, retain more of their shape, and less solid block color tone.
<br/>Course lapis is still janky.  Since the locations I'm sampling the block texture in the Vertex stage, is exactly where the lapis blue color shows through.... Fun times...
<br/>Tweak some values to fix one ore...
<br/>Causing other ore to break how lapis was broken....

All of this being said, Optifine does have block color options where I can manually set every block's color specifically for my needs.
<br/>Paper pushing, book keeping, and tedius monotony... I'll do it anyway...
 
---

### Edge Detection Data
In order to calculate block, entity, and other edges, I'm passing Depth Buffer and Normal Buffer data to post processing passes.
(Currently `final.glsl`, edge detection is being moved to a composite pass.)

#### Depth Data
With Depth Buffer data, we can sample near by pixels to detect jumps in depth of neighboring pixels.  Allowing detection of object's Outside Edges in an image/render.

#### Normal Data
With Normal Buffer data, we can sample near by pixels to detect angle changes of a block or neightboring blocks in game.  Allowing detection of object's Inside Edges in an image/render.

#### Depth + Normal = Articulate Edges
With Depth's Outside Edges and Normal's Inside Edges, we can customize look and feel of blocks we are facing or a cascade of blocks in a cave or build.
<br/>So of course I gotta tweak outside edges separate of inside edges.  Changes in thickness or color, to push the desired style and vibe of the shader pack. 
 
---

### Block & Entity Glow
Gotta have that bloomish glow to really pull in ambiance for a shader pack!
<br/>I'm using a pretty standard 2 pass box blur; U/X Blur then V/Y Blur
<br/>To push the base glow a little more, I'm adding in a scaled down single pass box blur version of the glow buffer
<br/>When combined, the central pixels from the original glowing values pop a bit more with the single pass box blur

#### Blur Passes
 - `scale.composite1=0.4` - Initial scaled down for core box blur glow.  This aids in single pixel glow at a further distance to not pop in and out of existance as you look around. <br/>Render Target - `colortex8`
 - `scale.composite2=0.3` - U/X axis bluring using buffers from `composite1` <br/>Render Target - `colortex10`
 - `scale.composite3=0.3` - V/Y axis bluring using buffers from `composite1` <br/>Render Target - `colortex10`
 
---

### Gotch'yas
#### Atlas Texture Bounds
Texture Atlas dedicated texturing/shading is a common technique in games to get around excess texture buffers wasting space on the GPU.
<br/>In the past, I provide more information to my shaders through Uniform and Attribute variables to be read in the shader itself.
<br/>For Optifine, or Minecraft in general, important data doesn't pass to shaders unless the player themselves turn on specific options.
<br/>Texture bounds within the Atlas, center position of the apecific atlas texture, pixel size within the texture itself, or pixel size within the TextureMatrix multiplied TextureCoords, etc.

<br/>This introduced a rather persistant issue for detail bluring where the Texture2d lookups were reading the neighboring atlas texture.
<br/>While annoying, lead to some rather odd math to figure out color blending percentages and calculating atlas bounds.
<br/>This is still an issue, as you can see in sand, path blocks, gold blocks, and others.
<br/>Its more a matter of putting in the time to fix this issue at this point, than it is knowing how to fix it.

#### Multiple Texture Blocks
Uggghhhh, gotta love specific code for like 6 blocks in the entire game.
<br/>Grass, Snowy Grass, Warped Nylium, Crimsom Nylium Blocks and a couple others, use multiple texture lookups to draw the block.
<br/>So when it comes to Block Color and Detail Blurring, colors are blending into nothingness or the wrong color.
<br/>This is still an issue, and not exactly one I'm looking forward to fixing....
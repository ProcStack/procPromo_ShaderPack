# ProcStack's psPromo v0.1
## Inpired by Mojang's promo art style for Minecraft

### The Style; Vanilla+
Cartoonized Vibes
Softer defails, edges highlights, shadows, and glowing effects.

<img src="show/gal_netherPortal_v0.1_2022-04-11.jpg" alt="Fallen Portal" style="margin-left:auto;margin-right:auto;">
     
---

### Creator's Notes
My first shader pack for Minecraft, it's been quite a journey.
<br>Since I had no footing for how to create for Optifine's environment, I looked towards 3 packs spcifically for learning from. *(Listed Below)*

I wanted to create the backbone for a general purpose shader pack. Some sort of short term project that requires features for future shader pack dev.
<br>Mojang's promotion art style feels really homely to me.
<br>Also a great first shader pack to shoot for!

Sure most of the look could have been achieved in a shader pack + texture pack combo, but decided it was less hastle to have a single pack to install and manage options for.

---

### Under the hood
#### Options
 - `DetailBluring` - How much texture bluring is going on
 - `EdgeShading` - Edge's highlighting's influencicity
 - `GlowBrightness` - Change how much snow blindess you get while playing the game
 - `SolidLeaves` - Don't like the solid leaves? Turn off those bubblicious gum blocks 

#### Tech things
Texture bluring along side an ever growing set of custom block and entity textures.
<br>A two-pass glow/bluring driven by a glow texture atlas.
<br>Edge highlights created from depth and normal buffer data


---

### Edu & Inpiration
Mojang's Promotional Art style'n'vibe!
<br>Their ads and splash images in the launcher

<br>Any Alt Textures from the atlases were generated from Minecraft using `texturedump v1.18.1` in Forge
<br>Then recreated or heavily modified and painted over.
<br>A stop-gap until I can get the detail bluring logic working more universally


#### Shadow Inspiration and Learning Model
*[Chocapic13's HighPerformance Toaster](https://www.curseforge.com/minecraft/customization/chocapic13-high-performance-shaders)*

#### Optifine's Shader Environment Learning Models
*[Capt Tatsu's BSL Shaders v8](https://bitslablab.com)*
<br>*[Sildur's Vibrant shaders](https://www.curseforge.com/minecraft/customization/sildurs-vibrant-shaders)*



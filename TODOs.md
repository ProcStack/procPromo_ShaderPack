# TODO issue listed in one place
### Git issues are for plebs!
###   ... I'm just lazy
#### *(There are more, just whats on my mind)*

---
#### As of 4/22/2022
---

#### General-
- Optimizations
|- More parmeter logic
|- More #if #ifdef's
|- Move more generic math to vert stages
- GAT DARM MIN/MAX TEXTURE BOUNDS
- Move Final Pass to a composite# pass for bloom/glow passes

---

#### Terrain-
|- Mojang's style blends to flat color at depth
- Impliment polsterization math
|- Better detail isolation

---

#### Clouds-
- Alter based on being under water

---

#### Water-
-Write to depth buffer
-Eye in water depth buffer indication

---
#### Composite Passes-
- Initial Comp; Edge Highlights / Shadows
---

#### Final Comp-
-Account for Water depth buffer
|-Soften edge highlights in/past water
|-Soften glow through water
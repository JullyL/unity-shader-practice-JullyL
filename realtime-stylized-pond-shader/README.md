# Real-Time Watercolor Pond Rendering with Shader-Driven Animation

## Project Overview
This project builds a stylized koi pond (water + lily pads + fish) in a 3D/2.5D setup inside Unity URP, then renders it through a **watercolor-inspired non-photorealistic shader pipeline**. The focus is shader-first: textures act as compact data inputs (masks, UV paths, depth), while the shader constructs the final watercolor appearance (wash, edge softness/bleeding, paper grain interaction) procedurally at runtime.

## Objectives
- Render a coherent watercolor pond scene with layered motion and depth using lightweight 3D geometry (planes/layers).
- Use mask maps, depth maps, and UV channels as control signals for reveal, timing, and spatial separation.
- Encode fish motion paths in UV2 and animate via time-based UV scrolling (fish are 2D sprites projected in the shader).
- Procedurally generate water wash and stylization, reducing reliance on fully authored albedo textures.
- Maintain strong runtime performance in URP with an artist-friendly set of exposed parameters.

## Core Technical Approach

### 1) Scene + Data Assets (minimal textures)
**Geometry setup (3D/2.5D)**
- Pond bottom plane, water surface plane, lily pad planes, fish quads (offset in Y).
- Orthographic or mostly top-down camera to preserve the illustrative look.

**Textures (minimal + data-driven)**
- Lily pad binary mask (required): drives reveal and edge effects.
- Depth map (recommended): controls ordered reveal and depth-based styling.
- Paper grain (optional): modulates color absorption/breakup for watercolor feeling.
- Fish atlas PNG with transparency.

*(Optional)* supplementary maps: a subtle normal map for leaf bumps/variation, roughness variations, etc.

### 2) UV Mapping Strategy (Blender + Unity)
- **UV1**: standard mapping for mask/paper grain and any support textures.
- **UV2**: stores fish movement paths flattened into UV space, enabling fish motion through `time * speed` UV offsets.

### 3) Shader Implementation (Shader Graph or HLSL)
**Water (Procedural Wash)**
- Layered noise (e.g., FBM) generates the base wash.
- Slow drift offsets produce gentle pigment/water movement.
- Paper grain modulates intensity and "absorption."

**Watercolor Edge Effects (Lily Pads)**
- Use the lily mask gradients to derive a soft edge mask.
- Add noise-distorted thresholding to create bleeding edges and pigment pooling/darkening near boundaries.
- Use depth map for reveal order and subtle depth tinting/opacity shifts.

**Fish Layer**
- Sample fish texture using UV2 + time offset.
- Apply mild underwater distortion + depth tint to integrate fish below the water plane.

**Final Composition**
- Layered blending (water + lily pads + fish) controlled by masks and depth styling.
- Global stylization pass to unify colors/contrast into an illustrative watercolor palette.

## Expected Results
- A watercolor-rendered pond that looks painterly and cohesive (wash + paper grain + soft edges).
- Shader-driven reveal and motion, with clear separation between data inputs (maps/UV) and procedural rendering.
- Smooth fish motion along UV2 paths with convincing underwater integration.
- Efficient runtime with minimal geometry and controllable complexity.

## Toolchain
- Unity (URP)
- Shader Graph and/or HLSL
- Blender (UV2 path layout)
- Photoshop/Procreate (optional reference textures)
- Substance Designer (optional, for supplemental maps)

## Suggested Folder Structure
```text
realtime-stylized-pond-shader/
  README.md
  Docs/
  Textures/
    Masks/
    Fish/
    Paper/
  Materials/
  Shaders/
  Scenes/
  References/
```

## Milestone Plan (2 weeks)

### Week 1 – Core Shader System (Apr 22–Apr 28)
1. **Project setup + references**: lock style targets (watercolor wash + paper + soft edges); set up scene layers and camera.
2. **UV path + fish data**: create UV2 fish paths in Blender; import and verify UV2 in Unity.
3. **Procedural water wash**: implement FBM noise wash + drift + paper modulation.
4. **Lily pad reveal + bleeding**: mask blending, depth-based reveal, and noise edge bleeding.
5. **Fish compositing**: fish UV2 sampling, underwater distortion, depth tint integration.

### Week 2 – Polish + Scalability (Apr 29–May 5)
6. **Global stylization pass**: unify palette, contrast, and watercolor feeling.
7. **Exposed controls**: time scale, wash drift, bleed strength, depth tint, fish speed/phase.
8. **Optimization + profiling**: reduce samples/branches, tune performance.
9. **Documentation + deliverables**: screenshots/clips, parameter notes, final README/proposal/report summary.

### Final Deliverables Checklist
- Watercolor pond shader scene running in Unity URP.
- Master shader/material with exposed controls.
- Data texture set (lily pad mask, depth map, paper grain, fish atlas).
- Documentation (proposal, final report, implementation notes, media captures).

## Significance
This project shows how shader-based, data-driven rendering can produce rich watercolor-style visuals without heavy geometry, simulation, or texture pipelines. UV channels become behavior carriers, masks/depth become timing and styling signals, and the shader acts as the "painter," bridging procedural design thinking with interactive, real-time visual expression rooted in a culturally inspired koi-and-lotus motif.

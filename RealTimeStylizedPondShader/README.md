# Real-Time Stylized Pond Shader with Mask-Based Animation

## Project Overview
This project explores a real-time stylized pond shader system in Unity (URP), inspired by the visual harmony of koi fish and lily pads in traditional Chinese aesthetics.  
The core idea is to create rich layered motion and appearance effects through shader logic and texture-driven data, instead of complex geometry or expensive simulation.

## Objectives
- Simulate layered water, lily pads, and animated koi fish in a single pond scene.
- Use mask maps and depth maps to control visibility, reveal order, and timing.
- Use custom UV mapping for fish movement paths.
- Achieve visually compelling animation with minimal geometry and strong runtime performance.

## Core Technical Approach

### 1) Texture Design (Substance Designer)
**Water Environment**
- Water albedo with soft painterly color variation.

**Lily Pad System**
- Plant albedo (lily pads composited with water style).
- Plant normal map (leaf detail + subtle ripple distortion support).
- Binary mask map (defines lily pad regions for blending and control).
- Grayscale depth map (defines ordered reveal timing per lily pad).

**Fish**
- Transparent koi PNG textures for compositing.

### 2) UV Mapping Strategy (Blender + Unity)
- **UV1**: Standard base texture mapping for water and lily pad layers.
- **UV2**: Encoded fish path layout used for time-driven movement in shader.

### 3) Shader Implementation (Shader Graph or HLSL)
**Water Layer**
- Base texture sampling.
- Normal-map-based UV distortion to simulate gentle refraction.

**Lily Pad Layer**
- Mask-based blending between water and plant textures.
- Depth-driven reveal using `smoothstep` for ordered, soft animation.

**Fish Layer**
- UV2-based sampling for fish path control.
- Time-driven UV offset for movement.
- Alpha blending for clean compositing over water.

**Final Composition**
- Layered blending and interpolation controlled by maps and timing parameters.

## Expected Results
- A visually rich animated pond scene.
- Smooth and ordered appearance of lily pads.
- Living fish motion along predefined paths.
- Full effect achieved on a single plane mesh via shader logic.

## Toolchain
- Unity (URP)
- Shader Graph and/or HLSL
- Adobe Substance 3D Designer
- Blender (UV2 layout)

## Suggested Folder Structure
```text
RealTimeStylizedPondShader/
  README.md
  Textures/
    Water/
    LilyPads/
    Fish/
  Materials/
  Shaders/
  Scenes/
  References/
```

## Milestone Plan
1. **Texture Authoring**: Create water, lily pad, mask, depth, and fish textures.
2. **UV Setup**: Build UV1/UV2 layouts and validate path readability.
3. **Shader Layering**: Implement water + lily pad blending.
4. **Animation Logic**: Add depth-driven reveal and fish UV animation.
5. **Polish & Optimization**: Tune visual style, performance, and exposed controls.

## Significance
This project demonstrates how texture maps and UV channels can encode spatial and temporal logic for lightweight real-time animation.  
Beyond technical efficiency, it also bridges cultural visual language and computational art practice by reinterpreting traditional pond aesthetics in interactive digital form.

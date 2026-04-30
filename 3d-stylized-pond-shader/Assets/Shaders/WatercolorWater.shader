Shader "Stylized/WatercolorWater"
{
    Properties
    {
        [Header(Water)]
        _WaterColor ("Water Color", Color) = (0.38, 0.72, 0.68, 0.92)
        _PigmentColor ("Pigment Color", Color) = (0.22, 0.52, 0.60, 0.95)
        _WashScale ("Wash Scale", Range(0.5, 18)) = 5
        _DriftSpeed ("Drift Speed", Range(0, 1)) = 0.08
        _SurfaceOpacity ("Surface Opacity", Range(0.35, 1)) = 0.86

        [Header(Paper)]
        _PaperTexture ("Paper Grain Texture", 2D) = "white" {}
        _PaperTextureScale ("Paper Texture Tiling", Float) = 1.5
        _PaperStrength ("Paper Strength", Range(0, 1)) = 0.35

        [Header(Edge)]
        _DistortionStrength ("UV Distortion Strength", Range(0.0, 0.02)) = 0.005
        _EdgeSoftness ("Edge Softness", Range(0.1, 1.0)) = 0.75
        _EdgeNoiseStrength ("Edge Noise Strength", Range(0.0, 0.20)) = 0.10

        [Header(Paint)]
        _FinalDesaturation ("Final Desaturation", Range(0.0, 0.4)) = 0.25
        _PaintSoftness ("Paint Softness", Range(0.0, 0.4)) = 0.16

        [Header(Brush)]
        _BrushTexture ("Brush Texture", 2D) = "white" {}
        _BrushScale ("Brush Scale", Range(0.05, 5)) = 0.5
        _BrushStrength ("Brush Strength", Range(0, 1)) = 0.2

        [Header(Flow)]
        _FlowDirection ("Flow Direction", Vector) = (1.0, 0.5, 0.0, 0.0)
        _FlowSpeed ("Flow Speed", Range(0, 0.2)) = 0.05

        [Header(Caustics)]
        _CausticsScale ("Caustics Scale", Range(0.5, 3)) = 1.5
        _CausticsXSpeed ("Caustics X Speed", Range(0, 0.3)) = 0.08
        _CausticsYSpeed ("Caustics Y Speed", Range(0, 0.3)) = 0.06
        _CausticsStrength ("Caustics Strength", Range(0, 0.35)) = 0.12

        [Header(Interaction)]
        _IntersectionDistance ("Intersection Distance", Range(0.01, 0.5)) = 0.15
        _IntersectionNoiseScale ("Intersection Noise Scale", Range(1, 20)) = 8
        _IntersectionNoiseStrength ("Intersection Noise Strength", Range(0, 0.5)) = 0.15
        _IntersectionNoiseSpeed ("Intersection Noise Speed", Range(0, 1)) = 0.1
        _InteractionRippleStrength ("Interaction Ripple Strength", Range(0, 0.2)) = 0.08
        _InteractionRippleFrequency ("Interaction Ripple Frequency", Range(10, 100)) = 35
        _InteractionRippleSpeed ("Interaction Ripple Speed", Range(0.1, 5)) = 1.2
        _InteractionRippleWidth ("Interaction Ripple Width", Range(0, 0.2)) = 0.08
        _DebugIntersectionMask ("Debug Intersection Mask", Range(0, 1)) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
        }

        Pass
        {
            Name "WatercolorForward"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _WaterColor;
                float4 _PigmentColor;
                float _WashScale;
                float _DriftSpeed;
                float _SurfaceOpacity;
                float _PaperTextureScale;
                float _PaperStrength;
                float _DistortionStrength;
                float _EdgeSoftness;
                float _EdgeNoiseStrength;
                float _FinalDesaturation;
                float _PaintSoftness;
                float _BrushScale;
                float _BrushStrength;
                float4 _FlowDirection;
                float _FlowSpeed;
                float _CausticsScale;
                float _CausticsXSpeed;
                float _CausticsYSpeed;
                float _CausticsStrength;
                float _IntersectionDistance;
                float _IntersectionNoiseScale;
                float _IntersectionNoiseStrength;
                float _IntersectionNoiseSpeed;
                float _InteractionRippleStrength;
                float _InteractionRippleFrequency;
                float _InteractionRippleSpeed;
                float _InteractionRippleWidth;
                float _DebugIntersectionMask;
            CBUFFER_END

            // Global properties written each frame by FishController.cs
            // Declared outside CBUFFER so Shader.SetGlobal* reaches them.
            float4 _FishWorldPos;
            float  _FishRippleStrength;
            float  _FishSwimSpeed;

            TEXTURE2D(_PaperTexture);
            SAMPLER(sampler_PaperTexture);
            TEXTURE2D(_BrushTexture);
            SAMPLER(sampler_BrushTexture);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
            };

            float Hash21(float2 p)
            {
                p = frac(p * float2(123.34, 345.45));
                p += dot(p, p + 34.345);
                return frac(p.x * p.y);
            }

            float ValueNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);

                float a = Hash21(i);
                float b = Hash21(i + float2(1.0, 0.0));
                float c = Hash21(i + float2(0.0, 1.0));
                float d = Hash21(i + float2(1.0, 1.0));

                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            float Fbm(float2 p)
            {
                float sum = 0.0;
                float amp = 0.5;
                float2 shift = float2(17.3, 41.7);

                [unroll]
                for (int i = 0; i < 4; i++)
                {
                    sum += ValueNoise(p) * amp;
                    p = p * 2.03 + shift;
                    amp *= 0.5;
                }

                return sum;
            }

            float2 RotateUV(float2 uv, float angle)
            {
                float s = sin(angle);
                float c = cos(angle);
                float2 p = uv - 0.5;
                return float2(p.x * c - p.y * s, p.x * s + p.y * c) + 0.5;
            }

            float SignedNoise(float n) { return n * 2.0 - 1.0; }

            float3 ApplyPaintFilter(float3 color, float softness, float desaturation)
            {
                color = saturate(0.5 + (color - 0.5) * (1.0 - softness));
                float lum = dot(color, float3(0.299, 0.587, 0.114));
                color = lerp(color, lum.xxx, desaturation);
                return saturate(color + softness * 0.06);
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                float3 worldPos = TransformObjectToWorld(input.positionOS.xyz);

                output.positionHCS = TransformWorldToHClip(worldPos);
                output.uv = input.uv;
                output.worldPos = worldPos;
                output.screenPos = ComputeScreenPos(output.positionHCS);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float2 uv = input.uv;
                float time = _Time.y;

                // STEP 1: Flow-based UV movement (global water drift)
                float2 flowDir = normalize(_FlowDirection.xy);
                float2 flowOffset = flowDir * time * _FlowSpeed;
                float2 flowUV = uv + flowOffset;

                // Subtle UV distortion using low-frequency FBM
                float2 distortionField = float2(
                    Fbm(flowUV * _WashScale * 0.5 + float2(0.11, -0.07) + time * _DriftSpeed * 0.5),
                    Fbm(flowUV * _WashScale * 0.5 + float2(-0.07, 0.11) - time * _DriftSpeed * 0.4)
                ) - 0.5;
                // World-space brush projection — direct tiling, no UV-space pivot
                float2 brushUV = input.worldPos.xz * _BrushScale;
                brushUV += float2(time * 0.02, time * 0.015);

                // Two layers at different scales for stroke richness
                float brushA = dot(SAMPLE_TEXTURE2D(_BrushTexture, sampler_BrushTexture, brushUV).rgb, float3(0.333, 0.333, 0.333));
                float brushB = dot(SAMPLE_TEXTURE2D(_BrushTexture, sampler_BrushTexture, brushUV * 1.7 + float2(0.3, -0.2)).rgb, float3(0.333, 0.333, 0.333));
                float brush = lerp(brushA, brushB, 0.4);
                float brushSigned = brush * 2.0 - 1.0;

                // STEP 2: Integrate flow into distortion system
                float2 uvDistorted = flowUV + distortionField * _DistortionStrength;

                // Two-layer FBM wash — purely UV-based (no time) so large blobs stay static.
                // Flow and distortion animate the fine details above; keeping wash on raw UV
                // prevents the muddy large-patch drift visible when uvDistorted feeds the FBM.
                float2 driftA = uv * _WashScale;
                float2 driftB = uv * (_WashScale * 2.25);
                float wash = Fbm(driftA) * 0.68 + Fbm(driftB) * 0.32;

                // Brush feeds directly into wash so stroke darks/lights shift pigment pooling
                wash = saturate(wash + brushSigned * _BrushStrength * 0.7);

                // Reduced factor (0.35 vs old 0.56) so base color stays dominant and clear
                float3 waterColor = lerp(_WaterColor.rgb, _PigmentColor.rgb, saturate(wash * 0.35));

                // Brightness variation from brush strokes — wider range for visible stroke contrast
                waterColor *= lerp(0.82, 1.18, saturate(brush * _BrushStrength + 0.5 * (1.0 - _BrushStrength)));

                // Paper grain: multiplicative brightening + additive offset
                float paper = SAMPLE_TEXTURE2D(_PaperTexture, sampler_PaperTexture, uvDistorted * _PaperTextureScale).r;
                waterColor *= lerp(0.9, 1.12, paper);
                waterColor += (paper - 0.5) * _PaperStrength * 0.2;

                // Depth gradient: pond center catches reflected sky light (lighter),
                // edges represent deeper / shadowed water (darker).
                // Applied after wash + paper so the gradient shapes the full surface read.
                float2 centerUV = uv - 0.5;
                float uvDist    = length(centerUV);
                float depthMask = smoothstep(0.2, 0.9, uvDist);
                waterColor      = lerp(waterColor * 1.10, waterColor * 0.75, depthMask);

                // STEP 3 (REMOVED): sin(uv.x)*sin(uv.y) produced grid/diamond artifacts.
                // Surface movement is now carried entirely by texture-based caustics below.

                // STEP 4: Texture-based caustics — two layers at different scales and drift directions.
                // distortionField is added to each UV before sampling so the FBM warp that
                // already shapes the wash also breaks any tiling repetition in the caustics.
                float2 causticsUV1 = uvDistorted * _CausticsScale
                                   + distortionField * 0.2
                                   + float2(time * _CausticsXSpeed, time * _CausticsYSpeed);
                float2 causticsUV2 = uvDistorted * (_CausticsScale * 1.7)
                                   + distortionField * 0.15
                                   + float2(-time * _CausticsYSpeed * 1.1, time * _CausticsXSpeed * 0.85);
                float c1 = dot(SAMPLE_TEXTURE2D(_BrushTexture, sampler_BrushTexture, causticsUV1).rgb, float3(0.333, 0.333, 0.333));
                float c2 = dot(SAMPLE_TEXTURE2D(_BrushTexture, sampler_BrushTexture, causticsUV2).rgb, float3(0.333, 0.333, 0.333));
                // lerp blend keeps the result soft — no hard edges between layers
                float combined = lerp(c1, c2, 0.4);
                // Power curve lifts bright spots into light-focus shapes without clamping mid-values
                float lightMask = pow(combined, 1.8);
                waterColor += lightMask * _CausticsStrength;

                // STEP 5: Interaction ripples at scene-water depth intersections
                float2 screenUV = input.screenPos.xy / input.screenPos.w;
                float rawSceneDepth = SampleSceneDepth(screenUV);
                float sceneEyeDepth = LinearEyeDepth(rawSceneDepth, _ZBufferParams);
                // screenPos.w holds the eye-space depth of the water surface vertex
                float waterEyeDepth = input.screenPos.w;
                float depthDiff = sceneEyeDepth - waterEyeDepth;

                // FBM noise in world XZ to give the intersection edge an organic, painterly boundary
                float2 interNoiseUV = input.worldPos.xz * _IntersectionNoiseScale + time * _IntersectionNoiseSpeed;
                float interNoise = Fbm(interNoiseUV);
                float depthDiffNoisy = depthDiff + (interNoise * 2.0 - 1.0) * _IntersectionNoiseStrength * _IntersectionDistance;

                // Intersection mask: 1 right at the object-water boundary, fades to 0 at _IntersectionDistance
                float intersectionMask = 1.0 - smoothstep(0.0, _IntersectionDistance, abs(depthDiffNoisy));

                // Debug: output raw intersection mask so lily pad / stem detection can be tuned
                if (_DebugIntersectionMask > 0.5)
                    return half4(intersectionMask.xxx, 1.0);

                // Concentric ripple rings: depthDiff acts as a radial distance field from the boundary
                float rippleWave = sin(depthDiff * _InteractionRippleFrequency - time * _InteractionRippleSpeed);
                rippleWave = rippleWave * 0.5 + 0.5; // remap to [0,1]

                // Thin the rings using the width parameter: smooth-threshold around the sine peaks
                float rippleRing = smoothstep(0.5, 0.5 + _InteractionRippleWidth, rippleWave) * intersectionMask;

                // Pale, cool highlight on the bright ring line (foam / light catching on water tension)
                float3 rippleHighlight = float3(0.90, 0.94, 0.96);
                waterColor = lerp(waterColor, rippleHighlight, rippleRing * _InteractionRippleStrength);

                // Subtle pigment darkening in the adjacent trough for soft watercolor depth
                float rippleTrough = (1.0 - rippleWave) * intersectionMask;
                waterColor = saturate(waterColor - float3(0.06, 0.05, 0.04) * rippleTrough * _InteractionRippleStrength * 0.5);

                // Edge bleeding — pigment pools at the waterline (wide, noise-displaced band)
                float edgeDistance = min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y));
                float edgeNoise = Fbm(RotateUV(uvDistorted + float2(0.31, -0.22), 0.92) * _WashScale * 0.25 + time * _DriftSpeed * 0.3);
                float normEdge = edgeDistance * 2.0 + SignedNoise(edgeNoise) * _EdgeNoiseStrength;
                float edgeMask = smoothstep(0.0, _EdgeSoftness, normEdge);

                float3 bleedTint = saturate(_PigmentColor.rgb + float3(0.08, 0.06, 0.05));
                waterColor = lerp(waterColor, bleedTint, (1.0 - edgeMask) * 0.35);

                // Shoreline fade — sharper transition over the outermost 5-20% of UV space.
                // High-frequency FBM displaces the effective edge distance so the shore is
                // ragged rather than a hard rectangle matching the water mesh boundary.
                float shoreIrreg = Fbm(uv * 10.0) * 2.0 - 1.0;
                float shoreEdge  = edgeDistance + shoreIrreg * 0.025;
                float shoreFade  = smoothstep(0.05, 0.20, shoreEdge);

                // Warm muted greenish tint where shallow water meets wet earth
                float3 shoreTint = float3(0.55, 0.65, 0.50);
                waterColor = lerp(shoreTint, waterColor, shoreFade);
                // Darken approaching shore — murky shallow water absorbs more incident light
                waterColor *= lerp(0.70, 1.0, shoreFade);

                // ── Fish wake ripple ──────────────────────────────────────────
                // Concentric rings expand outward from the fish's XZ position.
                // sin() creates the ring pattern; exp() fades rings with distance
                // so only water close to the fish is disturbed.
                float2 toFish   = input.worldPos.xz - _FishWorldPos.xz;
                float  fishDist = max(length(toFish), 0.01);
                // Ring frequency: tighter rings = more detail; speed tracks swim speed
                float  wakeRing = sin(fishDist * 6.0 - time * (_FishSwimSpeed * 1.8 + 1.5)) * 0.5 + 0.5;
                float  wakeFade = exp(-fishDist * 1.4) * _FishRippleStrength;
                // Pale cool highlight on ring peaks, subtle darkening in troughs
                float3 wakeHighlight = float3(0.91, 0.96, 0.95);
                waterColor = lerp(waterColor, wakeHighlight, wakeRing  * wakeFade * 0.18);
                waterColor = saturate(waterColor - float3(0.05, 0.04, 0.03)
                           * (1.0 - wakeRing) * wakeFade * 0.25);

                waterColor = ApplyPaintFilter(saturate(waterColor), _PaintSoftness, _FinalDesaturation);

                // Contrast lift — makes surface structure readable without breaking watercolor softness
                waterColor = saturate((waterColor - 0.5) * 1.18 + 0.5);
                // Slight green-blue tint bias to unify the pond palette
                waterColor = lerp(waterColor, float3(0.60, 0.80, 0.76), 0.10);

                // edgeMask: wide noisy bleed band (controlled by _EdgeSoftness)
                // shoreFade: tight irregular fade at the mesh UV boundary
                // Together they produce a multi-scale soft shoreline with no hard rectangular edge.
                return half4(waterColor, saturate(_SurfaceOpacity * edgeMask * shoreFade));
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}

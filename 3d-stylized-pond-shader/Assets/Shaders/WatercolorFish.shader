Shader "Stylized/WatercolorFish"
{
    Properties
    {
        [Header(Fish Texture)]
        _BaseMap ("Fish Texture", 2D) = "white" {}
        _SaturationBoost ("Saturation Boost", Range(0.5, 2.5)) = 1.4

        [Header(Watercolor)]
        _ContrastReduction ("Contrast Reduction", Range(0, 0.5)) = 0.08
        _Desaturation ("Desaturation", Range(0, 0.6)) = 0.08
        _WaterTintColor ("Water Tint Color", Color) = (0.38, 0.72, 0.68, 1)
        _WaterTintStrength ("Water Tint Strength", Range(0, 0.3)) = 0.06

        [Header(Paper)]
        _PaperTexture ("Paper Grain Texture", 2D) = "white" {}
        _PaperTextureScale ("Paper Texture Tiling", Float) = 1.5
        _PaperStrength ("Paper Strength", Range(0, 1)) = 0.20

        [Header(Brush)]
        _BrushTexture ("Brush Texture", 2D) = "white" {}
        _BrushScale ("Brush Scale", Range(0.05, 5)) = 0.5
        _BrushStrength ("Brush Strength", Range(0, 1)) = 0.18

        [Header(Edge)]
        _EdgeDarken ("Edge Softening", Range(0, 0.4)) = 0.20
        _RimWidth ("Rim Width", Range(0, 1)) = 0.45

        [Header(Paint)]
        _FinalDesaturation ("Final Desaturation", Range(0, 0.4)) = 0.05
        _PaintSoftness ("Paint Softness", Range(0, 0.3)) = 0.08

        [Header(Lighting)]
        _LightInfluence ("Light Influence", Range(0, 0.3)) = 0.12
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        // ============================================================
        // PASS 1 — Main watercolor forward pass
        // ============================================================
        Pass
        {
            Name "WatercolorFishForward"
            Tags { "LightMode" = "UniversalForward" }

            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // _BaseMap_ST must be in the CBUFFER for TRANSFORM_TEX (tiling/offset) to work.
            // Property name _BaseMap matches URP/Lit so existing material texture slots carry over.
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float _SaturationBoost;
                float _ContrastReduction;
                float _Desaturation;
                float4 _WaterTintColor;
                float _WaterTintStrength;
                float _PaperTextureScale;
                float _PaperStrength;
                float _BrushScale;
                float _BrushStrength;
                float _EdgeDarken;
                float _RimWidth;
                float _FinalDesaturation;
                float _PaintSoftness;
                float _LightInfluence;
            CBUFFER_END

            TEXTURE2D(_BaseMap);      SAMPLER(sampler_BaseMap);
            TEXTURE2D(_PaperTexture); SAMPLER(sampler_PaperTexture);
            TEXTURE2D(_BrushTexture); SAMPLER(sampler_BrushTexture);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float3 worldPos    : TEXCOORD1;
                float3 normalWS    : TEXCOORD2;
                float3 viewDirWS   : TEXCOORD3;
            };

            // --- Helpers identical to all other watercolor shaders in this project ---

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
                float b = Hash21(i + float2(1, 0));
                float c = Hash21(i + float2(0, 1));
                float d = Hash21(i + float2(1, 1));
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            float Fbm(float2 p)
            {
                float sum = 0.0; float amp = 0.5;
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
                float3 worldPos    = TransformObjectToWorld(input.positionOS.xyz);
                output.positionHCS = TransformWorldToHClip(worldPos);
                output.uv          = TRANSFORM_TEX(input.uv, _BaseMap);
                output.worldPos    = worldPos;
                output.normalWS    = TransformObjectToWorldNormal(input.normalOS);
                output.viewDirWS   = GetWorldSpaceViewDir(worldPos);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float2 uv       = input.uv;
                float3 normalWS = normalize(input.normalWS);
                float3 viewDir  = normalize(input.viewDirWS);

                // Step 1: Sample fish texture — preserves the original scale pattern
                float3 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv).rgb;

                // Saturation boost: lerp(grey, color, boost) — values > 1 punch saturation past original
                float baseLum = dot(color, float3(0.299, 0.587, 0.114));
                color = lerp(baseLum.xxx, color, _SaturationBoost);
                color = saturate(color);

                // Step 2: Reduce contrast + desaturate
                // Contrast: compress toward mid-grey so texture darks/lights spread less
                color = lerp(color, float3(0.5, 0.5, 0.5), _ContrastReduction);
                // Desaturation: lerp toward perceptual luminance
                float texLum = dot(color, float3(0.299, 0.587, 0.114));
                color = lerp(color, texLum.xxx, _Desaturation);

                // Step 3: No specular, no PBR — only the minimal NdotL pass below.
                // The fish texture already encodes its pattern; photorealistic lighting
                // would fight the watercolor read.

                // Step 4: World-space brush texture modulation — same two-layer blend
                // as WatercolorWater so stroke direction is consistent across the scene.
                float2 brushUV = input.worldPos.xz * _BrushScale;
                float brushA = dot(SAMPLE_TEXTURE2D(_BrushTexture, sampler_BrushTexture, brushUV).rgb,
                                   float3(0.333, 0.333, 0.333));
                float brushB = dot(SAMPLE_TEXTURE2D(_BrushTexture, sampler_BrushTexture,
                                   brushUV * 1.7 + float2(0.3, -0.2)).rgb, float3(0.333, 0.333, 0.333));
                float brush = lerp(brushA, brushB, 0.4);
                color *= lerp(0.90, 1.10, brush * _BrushStrength + 0.5 * (1.0 - _BrushStrength));

                // Paper grain — same math as water / lily pad for surface continuity
                float paper = SAMPLE_TEXTURE2D(_PaperTexture, sampler_PaperTexture, uv * _PaperTextureScale).r;
                color *= lerp(0.93, 1.05, paper);
                color += (paper - 0.5) * _PaperStrength * 0.12;

                // Step 5: Blend with water tint — fish underwater absorbs ambient water color.
                // Default strength 0.12 keeps the fish recognisable while tying it to the pond.
                color = lerp(color, _WaterTintColor.rgb, _WaterTintStrength);

                // Step 6: Edge softening via NdotV — shallow view angles darken silhouette edges.
                // Makes scales at the fish outline read as soft painted marks rather than hard geometry.
                float NdotV   = saturate(dot(normalWS, viewDir));
                float rimMask = smoothstep(0.0, _RimWidth, 1.0 - NdotV);
                color *= lerp(1.0, 1.0 - _EdgeDarken, rimMask);

                // Minimal directional light — low contrast so NdotL only reads form, not material
                Light mainLight = GetMainLight();
                float NdotL = saturate(dot(normalWS, mainLight.direction));
                color *= lerp(1.0 - _LightInfluence, 1.0, NdotL);

                // World-space FBM micro-variation — unifies surface texture with lily pad and lotus
                float fbmSurface = Fbm(input.worldPos.xz * 4.0) * 2.0 - 1.0;
                color += fbmSurface * 0.012;

                // Step 7: Same paint filter as every other watercolor shader in this project
                color = ApplyPaintFilter(saturate(color), _PaintSoftness, _FinalDesaturation);

                return half4(color, 1.0);
            }
            ENDHLSL
        }

        // ============================================================
        // PASS 2 — Shadow caster
        // ============================================================
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma vertex ShadVert
            #pragma fragment ShadFrag
            #pragma multi_compile_shadowcaster
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float _SaturationBoost;
                float _ContrastReduction;
                float _Desaturation;
                float4 _WaterTintColor;
                float _WaterTintStrength;
                float _PaperTextureScale;
                float _PaperStrength;
                float _BrushScale;
                float _BrushStrength;
                float _EdgeDarken;
                float _RimWidth;
                float _FinalDesaturation;
                float _PaintSoftness;
                float _LightInfluence;
            CBUFFER_END

            float3 _LightDirection;
            float3 _LightPosition;

            struct ShadAttr { float4 positionOS : POSITION; float3 normalOS : NORMAL; };
            struct ShadVary  { float4 positionCS : SV_POSITION; };

            ShadVary ShadVert(ShadAttr input)
            {
                ShadVary output;
                float3 posWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 nrmWS = TransformObjectToWorldNormal(input.normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDir = normalize(_LightPosition - posWS);
                #else
                    float3 lightDir = _LightDirection;
                #endif

                float4 posCS = TransformWorldToHClip(ApplyShadowBias(posWS, nrmWS, lightDir));
                #if UNITY_REVERSED_Z
                    posCS.z = min(posCS.z, posCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    posCS.z = max(posCS.z, posCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif
                output.positionCS = posCS;
                return output;
            }

            half4 ShadFrag(ShadVary input) : SV_Target { return 0; }
            ENDHLSL
        }

        // ============================================================
        // PASS 3 — Depth only (writes _CameraDepthTexture)
        // ============================================================
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R
            Cull Back

            HLSLPROGRAM
            #pragma vertex DepVert
            #pragma fragment DepFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float _SaturationBoost;
                float _ContrastReduction;
                float _Desaturation;
                float4 _WaterTintColor;
                float _WaterTintStrength;
                float _PaperTextureScale;
                float _PaperStrength;
                float _BrushScale;
                float _BrushStrength;
                float _EdgeDarken;
                float _RimWidth;
                float _FinalDesaturation;
                float _PaintSoftness;
                float _LightInfluence;
            CBUFFER_END

            struct DepAttr { float4 positionOS : POSITION; };
            struct DepVary  { float4 positionCS : SV_POSITION; };

            DepVary DepVert(DepAttr input)
            {
                DepVary output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half4 DepFrag(DepVary input) : SV_Target { return 0; }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}

Shader "Stylized/WatercolorLilyPad"
{
    Properties
    {
        [Header(Color)]
        _BaseColor ("Base Color", Color) = (0.27, 0.48, 0.23, 1.0)
        _PigmentColor ("Dark Pigment", Color) = (0.15, 0.33, 0.16, 1.0)
        _RadialStrength ("Radial Pigment Strength", Range(0, 1)) = 0.55

        [Header(Veins)]
        _VeinColor ("Vein Highlight Color", Color) = (0.44, 0.60, 0.26, 1.0)
        _VeinCount ("Vein Count", Range(8, 22)) = 14
        _VeinWidth ("Vein Width", Range(0.02, 0.3)) = 0.10
        _VeinStrength ("Vein Strength", Range(0, 0.6)) = 0.20

        [Header(Edge Tint)]
        _EdgeTintColor ("Edge Tint Color", Color) = (0.50, 0.54, 0.20, 1.0)
        _EdgeTintStart ("Edge Tint Start Radius", Range(0.15, 0.55)) = 0.32
        _EdgeTintStrength ("Edge Tint Strength", Range(0, 1)) = 0.48

        [Header(Paper)]
        _PaperTexture ("Paper Grain Texture", 2D) = "white" {}
        _PaperTextureScale ("Paper Texture Tiling", Float) = 1.5
        _PaperStrength ("Paper Strength", Range(0, 1)) = 0.32

        [Header(Brush)]
        _BrushTexture ("Brush Texture", 2D) = "white" {}
        _BrushScale ("Brush Scale", Range(0.05, 5)) = 0.5
        _BrushStrength ("Brush Strength", Range(0, 1)) = 0.28

        [Header(Edge)]
        _EdgeDarken ("Edge Darkening", Range(0, 0.3)) = 0.12
        _RimWidth ("Rim Width", Range(0, 1)) = 0.35

        [Header(Paint)]
        _FinalDesaturation ("Final Desaturation", Range(0, 0.4)) = 0.18
        _PaintSoftness ("Paint Softness", Range(0, 0.4)) = 0.20

        [Header(Animation)]
        _BobSpeed ("Bob Speed", Range(0, 3)) = 0.8
        _BobAmount ("Bob Amount", Range(0, 0.05)) = 0.008

        [Header(Lighting)]
        _LightInfluence ("Light Influence", Range(0, 0.3)) = 0.10
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
            Name "WatercolorLilyPadForward"
            Tags { "LightMode" = "UniversalForward" }

            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _PigmentColor;
                float _RadialStrength;
                float4 _VeinColor;
                float _VeinCount;
                float _VeinWidth;
                float _VeinStrength;
                float4 _EdgeTintColor;
                float _EdgeTintStart;
                float _EdgeTintStrength;
                float _PaperTextureScale;
                float _PaperStrength;
                float _BrushScale;
                float _BrushStrength;
                float _EdgeDarken;
                float _RimWidth;
                float _FinalDesaturation;
                float _PaintSoftness;
                float _BobSpeed;
                float _BobAmount;
                float _LightInfluence;
            CBUFFER_END

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

            // --- Helpers identical to WatercolorWater ---

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
                float3 worldPos = TransformObjectToWorld(input.positionOS.xyz);
                worldPos.y += sin(_Time.y * _BobSpeed + worldPos.x * 0.5 + worldPos.z * 0.3) * _BobAmount;
                output.positionHCS = TransformWorldToHClip(worldPos);
                output.uv          = input.uv;
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

                // Polar coords from UV center — shared by radial, vein, and edge tint steps
                float2 centered  = uv - 0.5;
                float  padRadius = length(centered);
                float  padAngle  = atan2(centered.y, centered.x); // [-PI, PI]

                // --- Step 1: Flat base + minimal directional light ---
                float3 color = _BaseColor.rgb;
                Light mainLight = GetMainLight();
                float NdotL = saturate(dot(normalWS, mainLight.direction));
                color *= lerp(1.0 - _LightInfluence, 1.0, NdotL);

                // --- Step 2: Radial pigment gradient ---
                // Bright center highlight (light collecting at the thick center vein hub),
                // dark pigment pools toward the outer half matching the reference.
                float radial = smoothstep(0.55, 0.0, padRadius);   // 1 at center, 0 at rim
                float radialBrightness = lerp(0.82, 1.15, radial);
                color *= lerp(1.0, radialBrightness, _RadialStrength);
                // Bleed dark pigment into the mid-to-outer zone
                color = lerp(color, _PigmentColor.rgb, (1.0 - radial) * _RadialStrength * 0.32);

                // --- Step 3: Radial vein pattern ---
                // frac maps angle to [0,1] per vein segment; abs(frac-0.5)*2 = 0 on vein, 1 between
                float veinFrac   = frac((padAngle / (2.0 * PI) + 0.5) * _VeinCount);
                float veinAngDist = abs(veinFrac - 0.5) * 2.0;
                float veinLine   = 1.0 - smoothstep(0.0, _VeinWidth, veinAngDist);
                // Fade: don't draw in the very center (avoids star artifact) or past the rim
                veinLine *= smoothstep(0.06, 0.20, padRadius);
                veinLine *= smoothstep(0.52, 0.38, padRadius);
                // ValueNoise breaks the perfectly angular lines into organic marks
                float veinBreak = ValueNoise(float2(padRadius * 12.0, veinAngDist * 6.0 + padRadius * 3.0));
                veinLine *= lerp(0.45, 1.0, veinBreak);
                // Apply as a subtle brightening along the vein — not darkening
                color = lerp(color, saturate(color + _VeinColor.rgb * 0.18), veinLine * _VeinStrength);

                // --- Step 4: Warm yellow-green edge tint ---
                // The reference shows a clear warm/olive shift in the outer ~30% of each pad.
                float edgeBlend = smoothstep(_EdgeTintStart, 0.52, padRadius);
                // Layer a slightly darker warm tone between tint start and rim for depth
                float edgeDark  = smoothstep(0.45, 0.52, padRadius);
                color = lerp(color, _EdgeTintColor.rgb, edgeBlend * _EdgeTintStrength);
                color *= lerp(1.0, 0.88, edgeDark * _EdgeTintStrength * 0.5);

                // --- Step 5: World-space brush texture (same params as water shader) ---
                float2 brushUV = input.worldPos.xz * _BrushScale;
                float brushA = dot(SAMPLE_TEXTURE2D(_BrushTexture, sampler_BrushTexture, brushUV).rgb,
                                   float3(0.333, 0.333, 0.333));
                float brushB = dot(SAMPLE_TEXTURE2D(_BrushTexture, sampler_BrushTexture,
                                   brushUV * 1.7 + float2(0.3, -0.2)).rgb, float3(0.333, 0.333, 0.333));
                float brush = lerp(brushA, brushB, 0.4);
                color *= lerp(0.90, 1.10, brush * _BrushStrength + 0.5 * (1.0 - _BrushStrength));

                // --- Step 6: Paper grain ---
                float paper = SAMPLE_TEXTURE2D(_PaperTexture, sampler_PaperTexture, uv * _PaperTextureScale).r;
                color *= lerp(0.92, 1.05, paper);
                color += (paper - 0.5) * _PaperStrength * 0.15;

                // --- Step 7: Rim darkening (NdotV) + world FBM boundary noise ---
                float NdotV   = saturate(dot(normalWS, viewDir));
                float rimMask = smoothstep(0.0, _RimWidth, 1.0 - NdotV);
                color *= lerp(1.0, 1.0 - _EdgeDarken, rimMask);

                float fbmEdge = Fbm(input.worldPos.xz * 2.5) * 2.0 - 1.0;
                color += fbmEdge * 0.016;

                // --- Step 8: Unified paint filter ---
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
                float4 _BaseColor;
                float4 _PigmentColor;
                float _RadialStrength;
                float4 _VeinColor;
                float _VeinCount;
                float _VeinWidth;
                float _VeinStrength;
                float4 _EdgeTintColor;
                float _EdgeTintStart;
                float _EdgeTintStrength;
                float _PaperTextureScale;
                float _PaperStrength;
                float _BrushScale;
                float _BrushStrength;
                float _EdgeDarken;
                float _RimWidth;
                float _FinalDesaturation;
                float _PaintSoftness;
                float _BobSpeed;
                float _BobAmount;
                float _LightInfluence;
            CBUFFER_END

            float3 _LightDirection;
            float3 _LightPosition;

            struct ShadAttr { float4 positionOS : POSITION; float3 normalOS : NORMAL; };
            struct ShadVary { float4 positionCS : SV_POSITION; };

            ShadVary ShadVert(ShadAttr input)
            {
                ShadVary output;
                float3 posWS = TransformObjectToWorld(input.positionOS.xyz);
                posWS.y += sin(_Time.y * _BobSpeed + posWS.x * 0.5 + posWS.z * 0.3) * _BobAmount;
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
        // PASS 3 — Depth only (feeds _CameraDepthTexture for water ripple intersection)
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
                float4 _BaseColor;
                float4 _PigmentColor;
                float _RadialStrength;
                float4 _VeinColor;
                float _VeinCount;
                float _VeinWidth;
                float _VeinStrength;
                float4 _EdgeTintColor;
                float _EdgeTintStart;
                float _EdgeTintStrength;
                float _PaperTextureScale;
                float _PaperStrength;
                float _BrushScale;
                float _BrushStrength;
                float _EdgeDarken;
                float _RimWidth;
                float _FinalDesaturation;
                float _PaintSoftness;
                float _BobSpeed;
                float _BobAmount;
                float _LightInfluence;
            CBUFFER_END

            struct DepAttr { float4 positionOS : POSITION; };
            struct DepVary { float4 positionCS : SV_POSITION; };

            DepVary DepVert(DepAttr input)
            {
                DepVary output;
                float3 posWS = TransformObjectToWorld(input.positionOS.xyz);
                posWS.y += sin(_Time.y * _BobSpeed + posWS.x * 0.5 + posWS.z * 0.3) * _BobAmount;
                output.positionCS = TransformWorldToHClip(posWS);
                return output;
            }

            half4 DepFrag(DepVary input) : SV_Target { return 0; }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}

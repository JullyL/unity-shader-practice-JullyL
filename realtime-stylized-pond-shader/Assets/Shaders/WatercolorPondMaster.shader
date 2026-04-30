Shader "Pond/WatercolorPondMaster"
{
    Properties
    {
        [Header(Water)]
        _WaterColor ("Water Color", Color) = (0.61, 0.83, 0.82, 0.82)
        _PigmentColor ("Pigment Color", Color) = (0.16, 0.39, 0.43, 1)
        _WashScale ("Wash Scale", Range(0.5, 18)) = 5
        _DriftSpeed ("Drift Speed", Range(0, 1)) = 0.08
        _SurfaceOpacity ("Surface Opacity", Range(0.35, 1)) = 0.86

        [Header(Paper)]
        _PaperGrainTexture ("Paper Grain Texture", 2D) = "white" {}
        _PaperStrength ("Paper Strength", Range(0, 1)) = 0.35

        [Header(Depth)]
        _DepthMap ("Depth Map", 2D) = "gray" {}
        _DepthTint ("Depth Tint", Color) = (0.22, 0.48, 0.51, 1)
        _DistortionStrength ("Distortion Strength", Range(0, 1)) = 0.2

        [Header(Lily Pad)]
        _LilyMask ("Lily Mask", 2D) = "black" {}
        _LilyAlbedo ("Lily Albedo", 2D) = "black" {}
        _LilyMaskScale ("Lily Mask Scale", Float) = 1
        _LilyMaskOffset ("Lily Mask Offset", Vector) = (0, 0, 0, 0)
        _LilyRadialIntensity ("Lily Radial Intensity", Range(0, 1)) = 0.3
        _LilyVeinCount ("Lily Vein Count", Float) = 6
        _LilyVeinIntensity ("Lily Vein Intensity", Range(0, 0.5)) = 0.1
        _LilyColorVariation ("Lily Color Variation", Range(0, 0.2)) = 0.08
        _LilyPadOpacity ("Lily Pad Opacity", Range(0, 1)) = 1.0

        [Header(Fish 1)]
        _FishMask ("Fish Mask", 2D) = "black" {}
        _FishAlbedo ("Fish Albedo", 2D) = "black" {}
        _FishSpeed ("Fish Speed", Range(-2, 2)) = 0.18
        _FishScale ("Fish Scale", Range(1, 8)) = 2
        _FishAngle ("Fish Angle", Range(-0.5, 0.5)) = 0.15
        _FishCurveAmp ("Fish Curve Amp", Range(0, 0.4)) = 0.08
        _FishWagSpeed ("Fish Wag Speed", Range(0, 15)) = 6
        _FishWagAmp ("Fish Wag Amp", Range(-0.3, 0.3)) = 0.08
        _FishOpacity ("Fish Opacity", Range(0, 1)) = 1.0

        [Header(Fish 2)]
        _Fish2Mask ("Fish 2 Mask", 2D) = "black" {}
        _Fish2Albedo ("Fish 2 Albedo", 2D) = "black" {}
        _Fish2Speed ("Fish 2 Speed", Range(-2, 2)) = -0.12
        _Fish2Scale ("Fish 2 Scale", Range(1, 8)) = 3
        _Fish2Angle ("Fish 2 Angle", Range(-0.5, 0.5)) = -0.1
        _Fish2YOffset ("Fish 2 Y Offset", Range(-0.5, 0.5)) = 0.2
        _Fish2CurveAmp ("Fish 2 Curve Amp", Range(0, 0.4)) = 0.1
        _Fish2WagSpeed ("Fish 2 Wag Speed", Range(0, 15)) = 6
        _Fish2WagAmp ("Fish 2 Wag Amp", Range(-0.3, 0.3)) = 0.08
        _Fish2Opacity ("Fish 2 Opacity", Range(0, 1)) = 1.0

        [Header(Fish 3)]
        _Fish3Mask ("Fish 3 Mask", 2D) = "black" {}
        _Fish3Albedo ("Fish 3 Albedo", 2D) = "black" {}
        _Fish3Speed ("Fish 3 Speed", Range(-2, 2)) = -0.2
        _Fish3Scale ("Fish 3 Scale", Range(1, 8)) = 3
        _Fish3Angle ("Fish 3 Angle", Range(-0.5, 0.5)) = 0.1
        _Fish3YOffset ("Fish 3 X Offset (track position)", Range(-0.5, 0.5)) = 0.0
        _Fish3CurveAmp ("Fish 3 Curve Amp", Range(0, 0.4)) = 0.08
        _Fish3WagSpeed ("Fish 3 Wag Speed", Range(0, 15)) = 5
        _Fish3WagAmp ("Fish 3 Wag Amp", Range(-0.3, 0.3)) = -0.08
        _Fish3Opacity ("Fish 3 Opacity", Range(0, 1)) = 1.0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }

        Pass
        {
            Name "WatercolorComposite"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_LilyMask);
            SAMPLER(sampler_LilyMask);
            TEXTURE2D(_LilyAlbedo);
            SAMPLER(sampler_LilyAlbedo);
            TEXTURE2D(_DepthMap);
            SAMPLER(sampler_DepthMap);
            TEXTURE2D(_FishMask);
            SAMPLER(sampler_FishMask);
            TEXTURE2D(_FishAlbedo);
            SAMPLER(sampler_FishAlbedo);
            TEXTURE2D(_Fish2Mask);
            SAMPLER(sampler_Fish2Mask);
            TEXTURE2D(_Fish2Albedo);
            SAMPLER(sampler_Fish2Albedo);
            TEXTURE2D(_Fish3Mask);
            SAMPLER(sampler_Fish3Mask);
            TEXTURE2D(_Fish3Albedo);
            SAMPLER(sampler_Fish3Albedo);
            TEXTURE2D(_PaperGrainTexture);
            SAMPLER(sampler_PaperGrainTexture);


            CBUFFER_START(UnityPerMaterial)
                float4 _WaterColor;
                float4 _PigmentColor;
                float4 _DepthTint;
                float4 _LilyMask_ST;
                float4 _LilyAlbedo_ST;
                float4 _LilyMaskOffset;
                float4 _DepthMap_ST;
                float4 _FishMask_ST;
                float4 _FishAlbedo_ST;
                float4 _PaperGrainTexture_ST;
                float _LilyMaskScale;
                float _LilyRadialIntensity;
                float _LilyVeinCount;
                float _LilyVeinIntensity;
                float _LilyColorVariation;
                float _LilyPadOpacity;
                float _WashScale;
                float _DriftSpeed;
                float _PaperStrength;
                float _FishSpeed;
                float _FishScale;
                float _FishAngle;
                float4 _Fish2Mask_ST;
                float4 _Fish2Albedo_ST;
                float _Fish2Speed;
                float _Fish2Scale;
                float _Fish2Angle;
                float _Fish2YOffset;
                float _FishCurveAmp;
                float _FishWagSpeed;
                float _FishWagAmp;
                float _FishOpacity;
                float _Fish2CurveAmp;
                float _Fish2WagSpeed;
                float _Fish2WagAmp;
                float _Fish2Opacity;
                float4 _Fish3Mask_ST;
                float4 _Fish3Albedo_ST;
                float _Fish3Speed;
                float _Fish3Scale;
                float _Fish3Angle;
                float _Fish3YOffset;
                float _Fish3CurveAmp;
                float _Fish3WagSpeed;
                float _Fish3WagAmp;
                float _Fish3Opacity;
                float _DistortionStrength;
                float _SurfaceOpacity;
            CBUFFER_END

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

            // Radial gradient for lily center depth
            float RadialShade(float2 uv, float innerRadius, float outerRadius)
            {
                float2 p = uv - 0.5;
                float r = length(p);
                return smoothstep(outerRadius, innerRadius, r);
            }

            // Procedural veins using radial lines
            float ProceduralVeins(float2 uv, float veinCount, float intensity)
            {
                float2 p = uv - 0.5;
                float r = length(p);
                float angle = atan2(p.y, p.x);
                
                // Create radial vein pattern
                float veins = sin(angle * veinCount);
                veins = abs(veins);
                veins = smoothstep(0.5, 0.2, veins);
                
                // Fade toward center and edges
                veins *= smoothstep(0.05, 0.25, r);
                veins *= smoothstep(0.5, 0.35, r);
                
                return veins * intensity;
            }

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.uv;
                float time = _Time.y;

                float2 driftA = uv * _WashScale + float2(time * _DriftSpeed, time * _DriftSpeed * 0.37);
                float2 driftB = uv * (_WashScale * 2.25) + float2(-time * _DriftSpeed * 0.43, time * _DriftSpeed * 0.61);
                float wash = Fbm(driftA) * 0.68 + Fbm(driftB) * 0.32;

                float paper = SAMPLE_TEXTURE2D(_PaperGrainTexture, sampler_PaperGrainTexture, TRANSFORM_TEX(uv, _PaperGrainTexture)).r;
                float3 color = lerp(_WaterColor.rgb, _PigmentColor.rgb, saturate(wash * 0.56));
                color *= lerp(0.9, 1.12, paper);
                color += (paper - 0.5) * _PaperStrength * 0.2;

                float depth = SAMPLE_TEXTURE2D(_DepthMap, sampler_DepthMap, TRANSFORM_TEX(uv, _DepthMap)).r;

                // Procedural UV distortion based on noise
                float distortNoise1 = Fbm(uv * 14.0 + time * 0.12);
                float distortNoise2 = Fbm(uv * 17.0 - time * 0.09);
                float2 uvDistortion = (float2(distortNoise1, distortNoise2) - 0.5) * 0.08;
                float2 maskUv = uv / _LilyMaskScale + _LilyMaskOffset.xy + 0.5 * (1 - 1.0 / _LilyMaskScale);
                float2 lilySurfaceUv = maskUv + uvDistortion * _DistortionStrength;

                // Sample mask and albedo with the same moving surface coordinates.
                float lilyMask = SAMPLE_TEXTURE2D(_LilyMask, sampler_LilyMask, lilySurfaceUv).r;
                float3 lilyAlbedo = SAMPLE_TEXTURE2D(_LilyAlbedo, sampler_LilyAlbedo, lilySurfaceUv).rgb;
                float albedoLuma = dot(lilyAlbedo, float3(0.299, 0.587, 0.114));
                float albedoCoverage = smoothstep(0.04, 0.14, albedoLuma);
                lilyMask *= albedoCoverage;

                float lilyCore = smoothstep(0.45, 0.72, lilyMask);
                float lilySoft = smoothstep(0.03, 0.8, lilyMask);

                // Procedural radial shading for lily depth
                float radialShade = RadialShade(lilySurfaceUv, 0.1, 0.45) * _LilyRadialIntensity;

                // Procedural veins for texture variation
                float veins = ProceduralVeins(lilySurfaceUv, _LilyVeinCount, _LilyVeinIntensity);

                // Noise-based color variation
                float colorVar = Fbm(lilySurfaceUv * 8.0 + time * 0.05) - 0.5;

                // Combine lily color with procedural effects
                float3 lilyColor = lilyAlbedo * lerp(0.9, 1.12, wash);
                lilyColor += radialShade * float3(0.15, 0.2, 0.1);
                lilyColor += veins * float3(0.08, 0.1, 0.05);
                lilyColor += colorVar * _LilyColorVariation;

                float2 fishUV;
                float fishScroll = uv.x * _FishScale - time * _FishSpeed;
                fishUV.x = frac(fishScroll);
                float fishTileCenterX = frac((floor(fishScroll) + 0.5 + time * _FishSpeed) / _FishScale);
                float fishPathY = sin(fishTileCenterX * 6.28318) * _FishCurveAmp;
                fishUV.y = uv.y * _FishScale + (1.0 - _FishScale) * 0.5 + uv.x * _FishAngle + fishPathY;
                fishUV.y += sin(time * _FishWagSpeed) * _FishWagAmp * fishUV.x * fishUV.x;
                float fishMask = SAMPLE_TEXTURE2D(_FishMask, sampler_FishMask, TRANSFORM_TEX(fishUV, _FishMask)).r;
                float fishEdgeFade = smoothstep(0.0, 0.06, fishUV.x) * smoothstep(1.0, 0.94, fishUV.x);
                fishMask *= fishEdgeFade;
                float3 fishColor = SAMPLE_TEXTURE2D(_FishAlbedo, sampler_FishAlbedo, TRANSFORM_TEX(fishUV, _FishAlbedo)).rgb;
                color = lerp(color, fishColor, fishMask * _FishOpacity);

                float2 fish2UV;
                float fish2Scroll = uv.x * _Fish2Scale - time * _Fish2Speed;
                fish2UV.x = frac(fish2Scroll);
                float fish2TileCenterX = frac((floor(fish2Scroll) + 0.5 + time * _Fish2Speed) / _Fish2Scale);
                float fish2PathY = sin(fish2TileCenterX * 6.28318) * _Fish2CurveAmp;
                fish2UV.y = uv.y * _Fish2Scale + (1.0 - _Fish2Scale) * 0.5 + uv.x * _Fish2Angle + _Fish2YOffset + fish2PathY;
                fish2UV.y += sin(time * _Fish2WagSpeed) * _Fish2WagAmp * fish2UV.x * fish2UV.x;
                float fish2Mask = SAMPLE_TEXTURE2D(_Fish2Mask, sampler_Fish2Mask, TRANSFORM_TEX(fish2UV, _Fish2Mask)).r;
                float fish2EdgeFade = smoothstep(0.0, 0.06, fish2UV.x) * smoothstep(1.0, 0.94, fish2UV.x);
                fish2Mask *= fish2EdgeFade;
                float3 fish2Color = SAMPLE_TEXTURE2D(_Fish2Albedo, sampler_Fish2Albedo, TRANSFORM_TEX(fish2UV, _Fish2Albedo)).rgb;
                color = lerp(color, fish2Color, fish2Mask * _Fish2Opacity);

                float2 fish3UV;
                float fish3Scroll = uv.y * _Fish3Scale - time * _Fish3Speed;
                float fish3TexY = frac(fish3Scroll);
                float fish3TileCenterY = frac((floor(fish3Scroll) + 0.5 + time * _Fish3Speed) / _Fish3Scale);
                float fish3PathX = sin(fish3TileCenterY * 6.28318) * _Fish3CurveAmp;
                float fish3TexX = uv.x * _Fish3Scale + (1.0 - _Fish3Scale) * 0.5 + _Fish3YOffset + uv.y * _Fish3Angle + fish3PathX;
                // rotate UV 90° so the horizontal fish texture swims vertically on screen
                fish3UV.x = fish3TexY;
                fish3UV.y = 1.0 - fish3TexX;
                float fish3UVclamped = saturate(fish3UV.x);
                fish3UV.y += sin(time * _Fish3WagSpeed) * _Fish3WagAmp * fish3UVclamped * fish3UVclamped;
                float fish3Mask = SAMPLE_TEXTURE2D(_Fish3Mask, sampler_Fish3Mask, TRANSFORM_TEX(fish3UV, _Fish3Mask)).r;
                float fish3EdgeFade = smoothstep(0.0, 0.06, fish3UV.x) * smoothstep(1.0, 0.94, fish3UV.x);
                float fish3BoundsH = smoothstep(0.0, 0.05, fish3TexX) * smoothstep(1.0, 0.95, fish3TexX);
                fish3Mask *= fish3EdgeFade * fish3BoundsH;
                float3 fish3Color = SAMPLE_TEXTURE2D(_Fish3Albedo, sampler_Fish3Albedo, TRANSFORM_TEX(fish3UV, _Fish3Albedo)).rgb;
                color = lerp(color, fish3Color, fish3Mask * _Fish3Opacity);

                color = lerp(color, lilyColor, max(lilyCore * 0.96, lilySoft * 0.45) * _LilyPadOpacity);

                color = saturate(color);
                float alpha = saturate(max(_SurfaceOpacity, max(lilySoft * _LilyPadOpacity, fishMask * 0.65)));
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}

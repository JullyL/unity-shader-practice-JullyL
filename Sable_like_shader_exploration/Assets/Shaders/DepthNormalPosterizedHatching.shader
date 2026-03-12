Shader "Custom/MoebiusDepthNormalPosterizedHatching"
{
    Properties
    {
        _LineColor ("Line Color", Color) = (0,0,0,1)

        _Thickness ("Thickness", Range(0.5, 4)) = 1

        _DepthThreshold ("Depth Threshold", Range(0.0001, 0.05)) = 0.0001
        _NormalThreshold ("Normal Threshold", Range(0.001, 1.0)) = 0.1

        _DepthStrength ("Depth Strength", Range(0, 5)) = 1
        _NormalStrength ("Normal Strength", Range(0, 5)) = 1

        _PosterizeSteps ("Posterize Steps", Range(2, 8)) = 4

        _HatchDensity ("Hatch Density", Range(10, 300)) = 120
        _HatchThickness ("Hatch Thickness", Range(0.01, 0.3)) = 0.08
        _HatchShadowThreshold ("Hatch Shadow Threshold", Range(0, 1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Name "DepthNormalPosterizedHatching"

            ZWrite Off
            ZTest Always
            Cull Off
            Blend Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

            float4 _LineColor;
            float _Thickness;
            float _DepthThreshold;
            float _NormalThreshold;
            float _DepthStrength;
            float _NormalStrength;

            float _HatchDensity;
            float _HatchThickness;
            float _HatchShadowThreshold;

            float _PosterizeSteps;

            float SampleLinearDepth01(float2 uv)
            {
                float rawDepth = SampleSceneDepth(uv);
                return Linear01Depth(rawDepth, _ZBufferParams);
            }

            float3 SampleSceneNormal(float2 uv)
            {
                return normalize(SampleSceneNormals(uv));
            }

            float GetLuminance(float3 color)
            {
                return dot(color, float3(0.299, 0.587, 0.114));
            }

            float3 PosterizeColor(float3 color, float steps)
            {
                float luminance = GetLuminance(color);
                float quantized = round(luminance * steps) / steps;
                float scale = quantized / max(luminance, 0.0001);
                return color * scale;
            }

            //Helper Functions for hatching
            float HatchHorizontal(float2 uv, float density, float thickness)
            {
                float v = frac(uv.y * density);
                return step(v, thickness);
            }

            float HatchVertical(float2 uv, float density, float thickness)
            {
                float v = frac(uv.x * density);
                return step(v, thickness);
            }

            float HatchDiagonal(float2 uv, float density, float thickness)
            {
                float v = frac((uv.x + uv.y) * density);
                return step(v, thickness);
            }

            float HatchPattern(float2 uv, float density, float thickness)
            {
                float v = frac((uv.x + uv.y) * density);
                return step(v, thickness);
            }

            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 uv = input.texcoord;
                float2 texel = _BlitTexture_TexelSize.xy * _Thickness;

                half4 sceneCol = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv);
                sceneCol.rgb = PosterizeColor(sceneCol.rgb, _PosterizeSteps);

                // Calculate hatching based on Brightness
                float luminance = GetLuminance(sceneCol.rgb);
                float quantizedLum = round(luminance * _PosterizeSteps) / _PosterizeSteps;

                float hatchH = HatchHorizontal(uv, _HatchDensity, _HatchThickness);
                float hatchV = HatchVertical(uv, _HatchDensity, _HatchThickness);
                float hatchD = HatchDiagonal(uv, _HatchDensity, _HatchThickness);

                float hatchMask = 0.0;

                // band 1: slightly dark
                if (quantizedLum < 0.75)
                    hatchMask = max(hatchMask, hatchH);

                // band 2: darker
                if (quantizedLum < 0.50)
                    hatchMask = max(hatchMask, hatchV);

                // band 3: darkest
                if (quantizedLum < 0.25)
                    hatchMask = max(hatchMask, hatchD);

                sceneCol.rgb = lerp(sceneCol.rgb, _LineColor.rgb, hatchMask);

                float dC = SampleLinearDepth01(uv);
                float dL = SampleLinearDepth01(uv + float2(-texel.x, 0));
                float dR = SampleLinearDepth01(uv + float2( texel.x, 0));
                float dU = SampleLinearDepth01(uv + float2(0,  texel.y));
                float dD = SampleLinearDepth01(uv + float2(0, -texel.y));

                float depthEdge =
                    abs(dC - dL) +
                    abs(dC - dR) +
                    abs(dC - dU) +
                    abs(dC - dD);

                depthEdge *= _DepthStrength;
                float depthMask = step(_DepthThreshold, depthEdge);

                float3 nC = SampleSceneNormal(uv);
                float3 nL = SampleSceneNormal(uv + float2(-texel.x, 0));
                float3 nR = SampleSceneNormal(uv + float2( texel.x, 0));
                float3 nU = SampleSceneNormal(uv + float2(0,  texel.y));
                float3 nD = SampleSceneNormal(uv + float2(0, -texel.y));

                float normalEdge =
                    (1.0 - dot(nC, nL)) +
                    (1.0 - dot(nC, nR)) +
                    (1.0 - dot(nC, nU)) +
                    (1.0 - dot(nC, nD));

                normalEdge *= _NormalStrength;
                float normalMask = step(_NormalThreshold, normalEdge);

                float finalMask = max(depthMask, normalMask);

                return lerp(sceneCol, _LineColor, finalMask);
            }

            ENDHLSL
        }
    }
}
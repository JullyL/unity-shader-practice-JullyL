Shader "Custom/MoebiusDepthNormalPosterizedOutline"
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
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Name "DepthNormalPosterizedOutline"

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

            float _PosterizeSteps;

            float SampleLinearDepth01(float2 uv)
            {
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r; //store in the red channel
                return Linear01Depth(rawDepth, _ZBufferParams);
            }

            float3 SampleSceneNormal(float2 uv)
            {
                float4 packedNormal = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, uv);
                float3 normalWS = packedNormal.xyz * 2.0 - 1.0;
                return normalize(normalWS);
            }

            float3 PosterizeColor(float3 color, float steps)
            {
                float luminance = dot(color, float3(0.299, 0.587, 0.114));

                float quantized = round(luminance * steps) / steps;

                float scale = quantized / max(luminance, 0.0001);

                return color * scale;
            }          

            half4 Frag(Varyings input) : SV_Target
            {

                float2 uv = input.texcoord;
                float2 texel = _BlitTexture_TexelSize.xy * _Thickness;

                half4 sceneCol = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv);
                sceneCol.rgb = PosterizeColor(sceneCol.rgb, _PosterizeSteps);

                // Depth samples
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

                // Normal samples
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
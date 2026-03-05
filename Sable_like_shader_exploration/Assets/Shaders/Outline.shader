Shader "Hidden/Moebius/SobelOutline"
{
    Properties
    {
        _LineColor ("Line Color", Color) = (0,0,0,1)
        _Threshold ("Threshold", Range(0,2)) = 0.25
        _Thickness ("Thickness (px)", Range(1,4)) = 1

        _DepthScale ("Depth Scale", Range(0,50)) = 15
        _NormalScale ("Normal Scale", Range(0,50)) = 8
        _NormalBias ("Normal Bias", Range(0,5)) = 1.0
        _Wobble ("Wobble (px)", Range(0,2)) = 0.6
        _WobbleScale ("Wobble Scale", Range(10,400)) = 140
        _WobbleFPS ("Wobble FPS", Range(1,30)) = 8
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        ZWrite Off Cull Off

        Pass
        {
            Name "SobelOutline"
            ZTest Always

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            // Unity 6.x: include order matters
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _LineColor;
                float _Threshold;
                float _Thickness;
                float _DepthScale;
                float _NormalScale;
                float _NormalBias;
                float _Wobble;
                float _WobbleScale;
                float _WobbleFPS;
            CBUFFER_END

            float Hash12(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }
            float2 Hash22(float2 p)
            {
                float n = Hash12(p);
                return float2(n, Hash12(p + n));
            }

            float Depth01(float2 uv)
            {
                float raw = SampleSceneDepth(uv);
                return Linear01Depth(raw, _ZBufferParams);
            }

            float SobelScalar(float s00, float s10, float s20,
                              float s01, float s11, float s21,
                              float s02, float s12, float s22)
            {
                float gx = (s20 + 2*s21 + s22) - (s00 + 2*s01 + s02);
                float gy = (s02 + 2*s12 + s22) - (s00 + 2*s10 + s20);
                return sqrt(gx*gx + gy*gy);
            }

            float SobelDepth(float2 uv, float2 texel)
            {
                float d00 = Depth01(uv + texel * float2(-1,-1));
                float d10 = Depth01(uv + texel * float2( 0,-1));
                float d20 = Depth01(uv + texel * float2( 1,-1));
                float d01 = Depth01(uv + texel * float2(-1, 0));
                float d11 = Depth01(uv);
                float d21 = Depth01(uv + texel * float2( 1, 0));
                float d02 = Depth01(uv + texel * float2(-1, 1));
                float d12 = Depth01(uv + texel * float2( 0, 1));
                float d22 = Depth01(uv + texel * float2( 1, 1));

                return SobelScalar(d00,d10,d20,d01,d11,d21,d02,d12,d22) * _DepthScale;
            }

            float SobelNormals(float2 uv, float2 texel)
            {
                float3 n00 = SampleSceneNormals(uv + texel * float2(-1,-1));
                float3 n10 = SampleSceneNormals(uv + texel * float2( 0,-1));
                float3 n20 = SampleSceneNormals(uv + texel * float2( 1,-1));
                float3 n01 = SampleSceneNormals(uv + texel * float2(-1, 0));
                float3 n11 = SampleSceneNormals(uv);
                float3 n21 = SampleSceneNormals(uv + texel * float2( 1, 0));
                float3 n02 = SampleSceneNormals(uv + texel * float2(-1, 1));
                float3 n12 = SampleSceneNormals(uv + texel * float2( 0, 1));
                float3 n22 = SampleSceneNormals(uv + texel * float2( 1, 1));

                float nx = SobelScalar(n00.x,n10.x,n20.x,n01.x,n11.x,n21.x,n02.x,n12.x,n22.x);
                float ny = SobelScalar(n00.y,n10.y,n20.y,n01.y,n11.y,n21.y,n02.y,n12.y,n22.y);
                float nz = SobelScalar(n00.z,n10.z,n20.z,n01.z,n11.z,n21.z,n02.z,n12.z,n22.z);

                return sqrt(nx*nx + ny*ny + nz*nz) * _NormalScale;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 uv = input.texcoord;
                float2 texel = (_Thickness / _ScreenParams.xy);
                float t = floor(_Time.y * _WobbleFPS) / _WobbleFPS;
                float2 jitter = (Hash22(uv * _WobbleScale + t) - 0.5) * (_Wobble / _ScreenParams.xy);
                float2 uvJ = uv + jitter;

                // Color from Fetch Color Buffer
                float3 col = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uvJ).rgb;

                float eDepth  = SobelDepth(uvJ, texel);
                float eNormal = SobelNormals(uvJ, texel);
                eNormal = max(0, eNormal - _NormalBias);

                float e = max(eDepth, eNormal);

                // Make a line mask
                float lineMask = smoothstep(_Threshold, _Threshold * 1.5, e);

                float3 outCol = lerp(col, _LineColor.rgb, lineMask);
                return half4(outCol, 1);
            }
            ENDHLSL
        }
    }
}
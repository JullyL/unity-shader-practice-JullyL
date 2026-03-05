Shader "Custom/MoebiusObjectFlat"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _MainTex ("Albedo", 2D) = "white" {}

        _DetailTex ("Detail (B/W)", 2D) = "black" {}
        _DetailTiling ("Detail Tiling", Float) = 6
        _DetailThreshold ("Detail Threshold", Range(0,1)) = 0.5
        _DetailStrength ("Detail Strength", Range(0,2)) = 0.8
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        // 1) Flat color forward pass (no lighting)
        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }
            ZWrite On

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes { float4 positionOS:POSITION; float2 uv:TEXCOORD0; };
            struct Varyings { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; };

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseColor;
            float _DetailTiling, _DetailThreshold, _DetailStrength;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

            Varyings vert(Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = v.uv;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb * _BaseColor.rgb;
                return half4(albedo, 1);
            }
            ENDHLSL
        }

        // 2) DepthNormals pass (THIS is what your Sobel reads)
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormals" }
            ZWrite On

            HLSLPROGRAM
            #pragma vertex vertDN
            #pragma fragment fragDN
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; };
            struct Varyings { float4 positionCS:SV_POSITION; float3 normalWS:TEXCOORD0; float2 uv:TEXCOORD1; };

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseColor;
            float _DetailTiling, _DetailThreshold, _DetailStrength;
            CBUFFER_END

            TEXTURE2D(_DetailTex); SAMPLER(sampler_DetailTex);

            Varyings vertDN(Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.uv = v.uv;
                return o;
            }

            half4 fragDN(Varyings i) : SV_Target
            {
                float3 n = normalize(i.normalWS);

                // Sample B/W detail and turn it into a hard +/- signal
                float2 duv = i.uv * _DetailTiling;
                float d = SAMPLE_TEXTURE2D(_DetailTex, sampler_DetailTex, duv).r;
                float sign = (d > _DetailThreshold) ? 1.0 : -1.0;

                // Pick a direction to "push" normals (creates edges in normal buffer)
                float3 up = float3(0,1,0);
                float3 dir = cross(n, up);
                dir = (dot(dir,dir) < 1e-5) ? float3(1,0,0) : normalize(dir);

                n = normalize(n + dir * sign * _DetailStrength);

                // Encode normal to 0..1 for normal buffer
                return half4(n * 0.5 + 0.5, 1);
            }
            ENDHLSL
        }
    }
}
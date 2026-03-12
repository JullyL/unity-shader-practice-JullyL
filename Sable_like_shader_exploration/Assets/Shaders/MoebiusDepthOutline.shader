Shader "Custom/MoebiusDepthOutline"
{
    Properties
    {
        _LineColor ("Line Color", Color) = (0,0,0,1)
        _Thickness ("Thickness", Range(0.5, 4)) = 1
        _DepthThreshold ("Depth Threshold", Range(0.0001, 0.05)) = 0.005
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Name "DepthOutline"

            ZWrite Off
            ZTest Always
            Cull Off
            Blend Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            // IMPORTANT: Core first, then Blit
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            float4 _LineColor;
            float _Thickness;
            float _DepthThreshold;


            float SampleLinearDepth01(float2 uv)
            {
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r; //store in the red channel
                return Linear01Depth(rawDepth, _ZBufferParams);
            }

            half4 Frag(Varyings input) : SV_Target
            {

                float2 uv = input.texcoord;
                float2 texel = _BlitTexture_TexelSize.xy * _Thickness;

                half4 sceneCol = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv);

                float dC = SampleLinearDepth01(uv);
                float dL = SampleLinearDepth01(uv + float2(-texel.x, 0));
                float dR = SampleLinearDepth01(uv + float2( texel.x, 0));
                float dU = SampleLinearDepth01(uv + float2(0,  texel.y));
                float dD = SampleLinearDepth01(uv + float2(0, -texel.y));

                float edge =
                    abs(dC - dL) +
                    abs(dC - dR) +
                    abs(dC - dU) +
                    abs(dC - dD);

                float mask = step(_DepthThreshold, edge);

                return lerp(sceneCol, _LineColor, mask);
            }

            ENDHLSL
        }
    }
}
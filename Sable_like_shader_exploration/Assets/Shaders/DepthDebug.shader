Shader "Hidden/Moebius/DepthDebug"
{
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" }
        ZWrite Off Cull Off

        Pass
        {
            Name "DepthDebug"
            ZTest Always

            HLSLPROGRAM
            // ✅ Core.hlsl MUST come before Blit.hlsl (defines TEXTURE2D_X, etc.)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            #pragma vertex Vert
            #pragma fragment Frag

            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float raw = SampleSceneDepth(input.texcoord);
                float d01 = Linear01Depth(raw, _ZBufferParams);

                // Near = white, Far = black (easy to read)
                float v = 1.0 - d01;
                return half4(v, v, v, 1);
            }
            ENDHLSL
        }
    }
}
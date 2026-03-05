Shader "Hidden/Moebius/NormalsDebug"
{
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        Pass
        {
            Name "NormalsDebug"
            ZWrite Off ZTest Always Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

            half4 Frag(Varyings IN) : SV_Target
            {
                float3 n = SampleSceneNormals(IN.texcoord); // -1..1
                n = n * 0.5 + 0.5; // -> 0..1
                return half4(n, 1);
            }
            ENDHLSL
        }
    }
}
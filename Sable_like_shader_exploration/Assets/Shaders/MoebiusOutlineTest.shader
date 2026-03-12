Shader "Custom/MoebiusOutlineTest" //name
{
    Properties //expose in the inspector
    {
        _TintColor ("Tint Color", Color) = (0.7, 0.8, 0.9, 1)
        
        _TintStrength ("Tint Strength", Range(0,1)) = 0.5
    }

    SubShader
    {
		    Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
		    
        Pass //one rendering step
        {
		    Name "MoebiusOutlineTestPass"
		        
		    //pass settings
		    ZWrite Off
            ZTest Always
            Cull Off
            Blend Off
		        
            HLSLPROGRAM
            
            //connect the function names to GPU pipeline
            #pragma vertex Vert
            #pragma fragment Frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            float4 _TintColor;
            float _TintStrength;

            half4 Frag(Varyings input) : SV_Target //Final pixal color
            {
                float2 uv = input.texcoord;
                half4 col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv);

                col.rgb = lerp(col.rgb, col.rgb * _TintColor.rgb, _TintStrength);
                return col;
            }
            ENDHLSL
        }
    }
}
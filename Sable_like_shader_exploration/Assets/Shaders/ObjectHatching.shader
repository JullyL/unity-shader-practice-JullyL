Shader "Custom/MoebiusObjectHatching"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (0.85, 0.62, 0.45, 1)
        _LineColor ("Hatch Color", Color) = (0,0,0,1)

        _PosterizeSteps ("Posterize Steps", Range(2, 6)) = 3

        _HatchDensity ("Hatch Density", Range(1, 50)) = 12
        _HatchThickness ("Hatch Thickness", Range(0.01, 0.3)) = 0.08

        _ShadowBand1 ("Shadow Band 1", Range(0,1)) = 0.75
        _ShadowBand2 ("Shadow Band 2", Range(0,1)) = 0.5
        _ShadowBand3 ("Shadow Band 3", Range(0,1)) = 0.25
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
            "Queue"="Geometry"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            Cull Back
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // Main light + shadow variants
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionOS  : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
                float3 positionWS  : TEXCOORD2;
                float4 shadowCoord : TEXCOORD3;
            };

            float4 _BaseColor;
            float4 _LineColor;

            float _PosterizeSteps;

            float _HatchDensity;
            float _HatchThickness;

            float _ShadowBand1;
            float _ShadowBand2;
            float _ShadowBand3;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs posInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS);

                OUT.positionHCS = posInputs.positionCS;
                OUT.positionWS = posInputs.positionWS;
                OUT.positionOS = IN.positionOS.xyz;
                OUT.normalWS = normalize(normalInputs.normalWS);
                OUT.shadowCoord = GetShadowCoord(posInputs);

                return OUT;
            }

            float PosterizeValue(float v, float steps)
            {
                return round(v * steps) / steps;
            }

            float HatchHorizontalOS(float3 posOS, float density, float thickness)
            {
                float v = frac(posOS.y * density);
                return step(v, thickness);
            }

            float HatchVerticalOS(float3 posOS, float density, float thickness)
            {
                float v = frac(posOS.x * density);
                return step(v, thickness);
            }

            float HatchDiagonalOS(float3 posOS, float density, float thickness)
            {
                float v = frac((posOS.x + posOS.y) * density);
                return step(v, thickness);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 normalWS = normalize(IN.normalWS);

                // Main light with shadow attenuation
                Light mainLight = GetMainLight(IN.shadowCoord);
                float3 lightDir = normalize(mainLight.direction);

                // If lighting looks inverted in your scene, change lightDir to -lightDir
                float NdotL = saturate(dot(normalWS, lightDir));

                // Include real Unity shadow map attenuation
                float lighting = NdotL * mainLight.shadowAttenuation;

                // Posterize the lighting
                float litBand = PosterizeValue(lighting, _PosterizeSteps);

                // Base lit color
                float3 color = _BaseColor.rgb * litBand;

                // Object-space hatch patterns
                float hatchH = HatchHorizontalOS(IN.positionOS, _HatchDensity, _HatchThickness);
                float hatchV = HatchVerticalOS(IN.positionOS, _HatchDensity, _HatchThickness);
                float hatchD = HatchDiagonalOS(IN.positionOS, _HatchDensity, _HatchThickness);

                float hatchMask = 0.0;

                if (litBand < _ShadowBand1)
                    hatchMask = max(hatchMask, hatchH);

                if (litBand < _ShadowBand2)
                    hatchMask = max(hatchMask, hatchV);

                if (litBand < _ShadowBand3)
                    hatchMask = max(hatchMask, hatchD);

                color = lerp(color, _LineColor.rgb, hatchMask);

                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
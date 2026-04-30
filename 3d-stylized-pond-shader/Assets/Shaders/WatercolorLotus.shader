Shader "Stylized/WatercolorLotus"
{
    Properties
    {
        [Header(Color)]
        _BaseColor ("Petal Base Color", Color) = (0.95, 0.97, 0.93, 1.0)
        _PetalTipColor ("Petal Tip Tint", Color) = (0.92, 0.96, 1.0, 1.0)
        _CenterColor ("Center Warmth Color", Color) = (0.98, 0.92, 0.72, 1.0)
        _GradientStrength ("Petal Gradient Strength", Range(0, 1)) = 0.65
        _CenterStrength ("Center Color Strength", Range(0, 1)) = 0.55

        [Header(Paper)]
        _PaperTexture ("Paper Grain Texture", 2D) = "white" {}
        _PaperTextureScale ("Paper Texture Tiling", Float) = 1.5
        _PaperStrength ("Paper Strength", Range(0, 1)) = 0.18

        [Header(Brush)]
        _BrushTexture ("Brush Texture", 2D) = "white" {}
        _BrushScale ("Brush Scale", Range(0.05, 5)) = 0.5
        _BrushStrength ("Brush Strength", Range(0, 1)) = 0.15

        [Header(Edge)]
        _EdgeDarken ("Edge Darkening", Range(0, 0.4)) = 0.15
        _RimWidth ("Rim Width", Range(0, 1)) = 0.4

        [Header(Paint)]
        _FinalDesaturation ("Final Desaturation", Range(0, 0.3)) = 0.08
        _PaintSoftness ("Paint Softness", Range(0, 0.3)) = 0.15

        [Header(Animation)]
        _AnimSpeed ("Sway Speed", Range(0, 3)) = 1.0
        _AnimAmount ("Sway Amount", Range(0, 0.02)) = 0.005

        [Header(Lighting)]
        _LightInfluence ("Light Influence", Range(0, 0.2)) = 0.08
        _TranslucencyStrength ("Translucency", Range(0, 0.15)) = 0.05
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry+1"
        }

        // ============================================================
        // PASS 1 — Main watercolor forward pass
        // ============================================================
        Pass
        {
            Name "WatercolorLotusForward"
            Tags { "LightMode" = "UniversalForward" }

            ZWrite On
            Cull Off   // thin petals need both sides shaded

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _PetalTipColor;
                float4 _CenterColor;
                float _GradientStrength;
                float _CenterStrength;
                float _PaperTextureScale;
                float _PaperStrength;
                float _BrushScale;
                float _BrushStrength;
                float _EdgeDarken;
                float _RimWidth;
                float _FinalDesaturation;
                float _PaintSoftness;
                float _AnimSpeed;
                float _AnimAmount;
                float _LightInfluence;
                float _TranslucencyStrength;
            CBUFFER_END

            TEXTURE2D(_PaperTexture); SAMPLER(sampler_PaperTexture);
            TEXTURE2D(_BrushTexture); SAMPLER(sampler_BrushTexture);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float3 worldPos    : TEXCOORD1;
                float3 normalWS    : TEXCOORD2;
                float3 viewDirWS   : TEXCOORD3;
            };

            // --- Helpers identical to WatercolorWater and WatercolorLilyPad ---

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
                float b = Hash21(i + float2(1, 0));
                float c = Hash21(i + float2(0, 1));
                float d = Hash21(i + float2(1, 1));
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            float Fbm(float2 p)
            {
                float sum = 0.0; float amp = 0.5;
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

            float3 ApplyPaintFilter(float3 color, float softness, float desaturation)
            {
                color = saturate(0.5 + (color - 0.5) * (1.0 - softness));
                float lum = dot(color, float3(0.299, 0.587, 0.114));
                color = lerp(color, lum.xxx, desaturation);
                return saturate(color + softness * 0.06);
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                float3 worldPos = TransformObjectToWorld(input.positionOS.xyz);

                // Step 8: Gentle sway — world XZ offsets the phase so each petal drifts uniquely
                float swayPhase = _Time.y * _AnimSpeed + worldPos.x * 0.5 + worldPos.z * 0.3;
                worldPos.y += sin(swayPhase) * _AnimAmount;

                output.positionHCS = TransformWorldToHClip(worldPos);
                output.uv          = input.uv;
                output.worldPos    = worldPos;
                output.normalWS    = TransformObjectToWorldNormal(input.normalOS);
                output.viewDirWS   = GetWorldSpaceViewDir(worldPos);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float2 uv       = input.uv;
                float3 normalWS = normalize(input.normalWS);
                float3 viewDir  = normalize(input.viewDirWS);

                // Cull Off: back faces share geometry but have flipped normals — correct them so
                // NdotL, NdotV, and translucency all compute from the surface-facing direction.
                if (dot(normalWS, viewDir) < 0.0) normalWS = -normalWS;

                // Step 1: Off-white base — NOT pure white.
                // Low-frequency FBM adds organic tonal shift across each petal face.
                float3 color = _BaseColor.rgb;
                float fbmVar = Fbm(uv * 3.5);
                color = lerp(color, _PetalTipColor.rgb, fbmVar * 0.10);

                // Step 2: Base-to-tip petal gradient via UV.y
                // UV.y=0 at petal base (attached to stem), UV.y=1 at tip
                float3 gradColor = lerp(_BaseColor.rgb * 0.85, _BaseColor.rgb * 1.05, uv.y);
                color = lerp(color, gradColor, _GradientStrength);

                // Step 3: Radial center warmth — warm cream at petal base, cooler toward tip.
                // Mirrors how real lotus petals are cream/yellow near the stamens.
                float2 centeredUV = uv - 0.5;
                float  dist       = length(centeredUV);
                float  centerMask = smoothstep(0.0, 0.5, dist);  // 0 at center, 1 toward edge
                color = lerp(color, _CenterColor.rgb, (1.0 - centerMask) * _CenterStrength * 0.55);
                // Brightness: center slightly darker (thick petal base), outer face brighter
                color *= lerp(0.80, 1.10, centerMask);

                // Step 4: World-space brush texture — same two-layer blend as water and lily pad
                float2 brushUV = input.worldPos.xz * _BrushScale;
                float brushA = dot(SAMPLE_TEXTURE2D(_BrushTexture, sampler_BrushTexture, brushUV).rgb,
                                   float3(0.333, 0.333, 0.333));
                float brushB = dot(SAMPLE_TEXTURE2D(_BrushTexture, sampler_BrushTexture,
                                   brushUV * 1.7 + float2(0.3, -0.2)).rgb, float3(0.333, 0.333, 0.333));
                float brush = lerp(brushA, brushB, 0.4);
                color *= lerp(0.92, 1.08, brush * _BrushStrength + 0.5 * (1.0 - _BrushStrength));

                // Step 5: Paper grain
                float paper = SAMPLE_TEXTURE2D(_PaperTexture, sampler_PaperTexture, uv * _PaperTextureScale).r;
                color *= lerp(0.95, 1.05, paper);

                // Step 6: NdotV rim darkening — shallow view angles soften the silhouette edge
                float NdotV   = saturate(dot(normalWS, viewDir));
                float rimMask = smoothstep(0.0, _RimWidth, 1.0 - NdotV);
                color *= lerp(1.0, 1.0 - _EdgeDarken, rimMask);

                // Very low-contrast directional light — just enough to read petal surfaces in 3D
                Light mainLight = GetMainLight();
                float NdotL = saturate(dot(normalWS, mainLight.direction));
                color *= lerp(1.0 - _LightInfluence, 1.0, NdotL);

                // Step 7: Translucency — back-lit petals receive a warm glow through the petal body.
                // -lightDir dot normal is positive when light hits the back surface.
                float backLit = saturate(dot(-mainLight.direction, normalWS));
                color += backLit * _TranslucencyStrength * float3(1.0, 0.98, 0.94);

                // World-space FBM micro-variation — same approach as lily pad for unified surface texture
                float fbmSurface = Fbm(input.worldPos.xz * 3.0) * 2.0 - 1.0;
                color += fbmSurface * 0.010;

                // Step 9: Same unified paint filter as WatercolorWater and WatercolorLilyPad
                color = ApplyPaintFilter(saturate(color), _PaintSoftness, _FinalDesaturation);

                return half4(color, 1.0);
            }
            ENDHLSL
        }

        // ============================================================
        // PASS 2 — Shadow caster (lotus casts shadows on water)
        // Sway animation is mirrored so shadow matches visible position.
        // ============================================================
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            #pragma vertex ShadVert
            #pragma fragment ShadFrag
            #pragma multi_compile_shadowcaster
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _PetalTipColor;
                float4 _CenterColor;
                float _GradientStrength;
                float _CenterStrength;
                float _PaperTextureScale;
                float _PaperStrength;
                float _BrushScale;
                float _BrushStrength;
                float _EdgeDarken;
                float _RimWidth;
                float _FinalDesaturation;
                float _PaintSoftness;
                float _AnimSpeed;
                float _AnimAmount;
                float _LightInfluence;
                float _TranslucencyStrength;
            CBUFFER_END

            float3 _LightDirection;
            float3 _LightPosition;

            struct ShadAttr { float4 positionOS : POSITION; float3 normalOS : NORMAL; };
            struct ShadVary  { float4 positionCS : SV_POSITION; };

            ShadVary ShadVert(ShadAttr input)
            {
                ShadVary output;
                float3 posWS = TransformObjectToWorld(input.positionOS.xyz);
                float swayPhase = _Time.y * _AnimSpeed + posWS.x * 0.5 + posWS.z * 0.3;
                posWS.y += sin(swayPhase) * _AnimAmount;
                float3 nrmWS = TransformObjectToWorldNormal(input.normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDir = normalize(_LightPosition - posWS);
                #else
                    float3 lightDir = _LightDirection;
                #endif

                float4 posCS = TransformWorldToHClip(ApplyShadowBias(posWS, nrmWS, lightDir));
                #if UNITY_REVERSED_Z
                    posCS.z = min(posCS.z, posCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    posCS.z = max(posCS.z, posCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif
                output.positionCS = posCS;
                return output;
            }

            half4 ShadFrag(ShadVary input) : SV_Target { return 0; }
            ENDHLSL
        }

        // ============================================================
        // PASS 3 — Depth only
        // Writes _CameraDepthTexture so the water intersection shader
        // detects flower stems and draws ripple rings around them.
        // ============================================================
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R
            Cull Off

            HLSLPROGRAM
            #pragma vertex DepVert
            #pragma fragment DepFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _PetalTipColor;
                float4 _CenterColor;
                float _GradientStrength;
                float _CenterStrength;
                float _PaperTextureScale;
                float _PaperStrength;
                float _BrushScale;
                float _BrushStrength;
                float _EdgeDarken;
                float _RimWidth;
                float _FinalDesaturation;
                float _PaintSoftness;
                float _AnimSpeed;
                float _AnimAmount;
                float _LightInfluence;
                float _TranslucencyStrength;
            CBUFFER_END

            struct DepAttr { float4 positionOS : POSITION; };
            struct DepVary  { float4 positionCS : SV_POSITION; };

            DepVary DepVert(DepAttr input)
            {
                DepVary output;
                float3 posWS = TransformObjectToWorld(input.positionOS.xyz);
                float swayPhase = _Time.y * _AnimSpeed + posWS.x * 0.5 + posWS.z * 0.3;
                posWS.y += sin(swayPhase) * _AnimAmount;
                output.positionCS = TransformWorldToHClip(posWS);
                return output;
            }

            half4 DepFrag(DepVary input) : SV_Target { return 0; }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}

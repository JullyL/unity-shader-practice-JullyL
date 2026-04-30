Shader "Stylized/WatercolorOutline"
{
    // No Properties block — all values are set per-frame from WatercolorOutlineFeature.cs
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Cull Off  ZWrite Off  ZTest Always

        Pass
        {
            Name "WatercolorOutlinePass"

            HLSLPROGRAM
            #pragma vertex   Vert
            #pragma fragment Frag

            // Blit.hlsl provides the standard fullscreen triangle Vert + Varyings.
            // _BlitTexture (scene color) is declared there.
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

            // ── Per-material uniforms (set by WatercolorOutlineFeature) ──────
            CBUFFER_START(UnityPerMaterial)
                float _DepthWeight;
                float _NormalWeight;
                float _ThresholdLow;
                float _ThresholdHigh;
                float _OutlineStrength;
                float _EdgeDarken;
                float _NoiseStrength;
                float _NoiseScale;
            CBUFFER_END

            // ── Noise — same Hash21 / ValueNoise / Fbm as the rest of this project ──
            float Hash21(float2 p)
            {
                p  = frac(p * float2(123.34, 345.45));
                p += dot(p, p + 34.345);
                return frac(p.x * p.y);
            }

            float ValueNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                float a = Hash21(i),            b = Hash21(i + float2(1, 0));
                float c = Hash21(i + float2(0, 1)), d = Hash21(i + float2(1, 1));
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            float Fbm(float2 p)
            {
                float v = 0.0;
                float a = 0.5;
                float2 shift = float2(17.3, 41.7);
                [unroll]
                for (int i = 0; i < 3; i++)
                {
                    v += a * ValueNoise(p);
                    p  = p * 2.03 + shift;
                    a *= 0.5;
                }
                return v;
            }

            // ── Helpers ──────────────────────────────────────────────────────

            // Convert raw depth buffer value → linear eye depth
            float EyeDepth(float2 uv)
            {
                return LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
            }

            // Full edge signal at a given UV: depth diff + normal diff combined
            float EdgeSignal(float2 uv, float2 texel)
            {
                // STEP 1 — Depth edges
                float d0 = EyeDepth(uv);
                float dN = EyeDepth(uv + float2( 0,  1) * texel);
                float dS = EyeDepth(uv + float2( 0, -1) * texel);
                float dE = EyeDepth(uv + float2( 1,  0) * texel);
                float dW = EyeDepth(uv + float2(-1,  0) * texel);

                // Normalise by local depth so threshold is view-distance–independent
                float safeD0   = max(d0, 0.001);
                float depthDiff = max(max(abs(d0 - dN), abs(d0 - dS)),
                                      max(abs(d0 - dE), abs(d0 - dW))) / safeD0;

                // STEP 2 — Normal edges
                float3 nC = SampleSceneNormals(uv);
                float3 nN = SampleSceneNormals(uv + float2( 0,  1) * texel);
                float3 nS = SampleSceneNormals(uv + float2( 0, -1) * texel);
                float3 nE = SampleSceneNormals(uv + float2( 1,  0) * texel);
                float3 nW = SampleSceneNormals(uv + float2(-1,  0) * texel);

                float normalDiff = ((1.0 - dot(nC, nN)) + (1.0 - dot(nC, nS)) +
                                    (1.0 - dot(nC, nE)) + (1.0 - dot(nC, nW))) * 0.25;

                // STEP 3 — Combine
                return depthDiff * _DepthWeight + normalDiff * _NormalWeight;
            }

            // Depth-only edge signal — cheap version used for the blur step
            float DepthEdgeSignal(float2 uv, float2 texel, float d0)
            {
                float dN = EyeDepth(uv + float2( 0,  1) * texel);
                float dS = EyeDepth(uv + float2( 0, -1) * texel);
                float dE = EyeDepth(uv + float2( 1,  0) * texel);
                float dW = EyeDepth(uv + float2(-1,  0) * texel);
                return max(max(abs(d0 - dN), abs(d0 - dS)),
                           max(abs(d0 - dE), abs(d0 - dW))) / max(d0, 0.001) * _DepthWeight;
            }

            // ── Fragment ──────────────────────────────────────────────────────
            half4 Frag(Varyings input) : SV_Target
            {
                float2 uv    = input.texcoord;
                float2 texel = _BlitTexture_TexelSize.xy;

                // Scene color from the camera colour target
                float3 scene = SAMPLE_TEXTURE2D_X(_BlitTexture,
                                                   sampler_LinearClamp, uv).rgb;

                // ── STEP 1-3: Raw edge at pixel centre ────────────────────────
                float rawEdge = EdgeSignal(uv, texel);

                // ── STEP 4: Smooth edges — no sharp toon line ─────────────────
                float edge = smoothstep(_ThresholdLow, _ThresholdHigh, rawEdge);

                // ── STEP 5: Blur — average with 4 depth-only diagonal samples
                //    at 1.5-texel offset; avoids re-running full normal sampling.
                float d0       = EyeDepth(uv);
                float2 diag    = texel * 1.5;
                float bNE = smoothstep(_ThresholdLow, _ThresholdHigh,
                                DepthEdgeSignal(uv + float2( diag.x,  diag.y), texel, d0));
                float bSW = smoothstep(_ThresholdLow, _ThresholdHigh,
                                DepthEdgeSignal(uv + float2(-diag.x, -diag.y), texel, d0));
                float bNW = smoothstep(_ThresholdLow, _ThresholdHigh,
                                DepthEdgeSignal(uv + float2(-diag.x,  diag.y), texel, d0));
                float bSE = smoothstep(_ThresholdLow, _ThresholdHigh,
                                DepthEdgeSignal(uv + float2( diag.x, -diag.y), texel, d0));
                // Centre weighted 4:1 to preserve the full edge signal quality
                edge = (edge * 4.0 + bNE + bSW + bNW + bSE) / 8.0;

                // ── STEP 8: Watercolor noise ───────────────────────────────────
                // Noise modulates the edge WIDTH: some areas thicker, some break
                // apart entirely — mimics a dry-brush / pigment-bleed look.
                float aspect = _BlitTexture_TexelSize.z / max(_BlitTexture_TexelSize.w, 0.001);
                float noise  = Fbm(uv * _NoiseScale * float2(aspect, 1.0) * 6.0);
                // Remap noise to [0, 2] so mean=1 — keeps average edge intact while
                // adding local variation (not just uniformly dimming the edge).
                edge *= lerp(1.0, noise * 2.0, _NoiseStrength * 0.65);
                edge  = saturate(edge);

                // ── STEP 6: Edge color — scene color darkened + slightly cool ──
                // Never pure black: the edge is a darker, cooler version of whatever
                // is underneath, so it reads as absorbed ink rather than a drawn line.
                float3 edgeColor = lerp(scene,
                                        scene * float3(0.48, 0.54, 0.68),
                                        _EdgeDarken);

                // ── STEP 7: Soft blend ─────────────────────────────────────────
                float3 final = lerp(scene, edgeColor, edge * _OutlineStrength);

                return half4(final, 1.0);
            }
            ENDHLSL
        }
    }

    FallBack Off
}

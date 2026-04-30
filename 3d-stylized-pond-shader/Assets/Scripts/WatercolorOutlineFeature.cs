using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;

// ─────────────────────────────────────────────────────────────────────────────
// WatercolorOutlineFeature
//
// Setup:
//   1. Open your URP Renderer asset (e.g. PC_Renderer).
//   2. Add Renderer Feature → WatercolorOutlineFeature.
//   3. In the URP Asset, enable "Depth Texture" and "Opaque Texture".
//   4. The feature automatically requests the DepthNormals prepass via
//      ConfigureInput — no extra renderer settings needed.
//
// Requires: Unity 6 / URP 17+ (uses Render Graph API).
// ─────────────────────────────────────────────────────────────────────────────
public class WatercolorOutlineFeature : ScriptableRendererFeature
{
    // ── Inspector-exposed settings ─────────────────────────────────────────
    [System.Serializable]
    public class Settings
    {
        [Header("Edge Detection")]
        [Range(0f, 3f)]    public float depthWeight   = 1.0f;
        [Range(0f, 3f)]    public float normalWeight  = 0.8f;
        // thresholdLow / High control the smoothstep window; tweak until
        // thick geometry edges appear but flat surfaces stay clean.
        [Range(0f, 0.05f)] public float thresholdLow  = 0.002f;
        [Range(0f, 0.30f)] public float thresholdHigh = 0.06f;

        [Header("Appearance")]
        [Range(0f, 1f)]    public float outlineStrength = 0.45f;
        // How much the edge darkens relative to the scene color (0 = invisible, 1 = fully dark tint)
        [Range(0f, 1f)]    public float edgeDarken     = 0.28f;

        [Header("Watercolor Noise")]
        [Range(0f, 1f)]    public float noiseStrength  = 0.40f;
        [Range(0.5f, 8f)]  public float noiseScale     = 3.0f;

        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    public Settings settings = new();

    WatercolorOutlinePass _pass;

    public override void Create()
    {
        _pass = new WatercolorOutlinePass();
        _pass.renderPassEvent = settings.renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer,
                                         ref RenderingData renderingData)
    {
        // Skip preview cameras (avoids errors in Material/Model inspector windows)
        if (renderingData.cameraData.cameraType == CameraType.Preview) return;

        _pass.Setup(settings);
        _pass.renderPassEvent = settings.renderPassEvent;
        renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        _pass?.Dispose();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// WatercolorOutlinePass — ScriptableRenderPass (Render Graph API, URP 17+)
// ─────────────────────────────────────────────────────────────────────────────
class WatercolorOutlinePass : ScriptableRenderPass
{
    WatercolorOutlineFeature.Settings _settings;
    Material _mat;
    RTHandle _tempColor;
    readonly ProfilingSampler _profilingSampler = new("Watercolor Outline");

    static readonly int ID_DepthWeight   = Shader.PropertyToID("_DepthWeight");
    static readonly int ID_NormalWeight  = Shader.PropertyToID("_NormalWeight");
    static readonly int ID_ThresholdLow  = Shader.PropertyToID("_ThresholdLow");
    static readonly int ID_ThresholdHigh = Shader.PropertyToID("_ThresholdHigh");
    static readonly int ID_Strength      = Shader.PropertyToID("_OutlineStrength");
    static readonly int ID_EdgeDarken    = Shader.PropertyToID("_EdgeDarken");
    static readonly int ID_NoiseStrength = Shader.PropertyToID("_NoiseStrength");
    static readonly int ID_NoiseScale    = Shader.PropertyToID("_NoiseScale");

    public WatercolorOutlinePass()
    {
        _mat = CoreUtils.CreateEngineMaterial("Stylized/WatercolorOutline");
        requiresIntermediateTexture = true;
        // Requesting Normal triggers the DepthNormals prepass so
        // _CameraDepthTexture and _CameraNormalsTexture are populated.
        ConfigureInput(ScriptableRenderPassInput.Color
                     | ScriptableRenderPassInput.Depth
                     | ScriptableRenderPassInput.Normal);
    }

    public void Setup(WatercolorOutlineFeature.Settings s) => _settings = s;

    void SetMaterialProperties()
    {
        _mat.SetFloat(ID_DepthWeight,   _settings.depthWeight);
        _mat.SetFloat(ID_NormalWeight,  _settings.normalWeight);
        _mat.SetFloat(ID_ThresholdLow,  _settings.thresholdLow);
        _mat.SetFloat(ID_ThresholdHigh, _settings.thresholdHigh);
        _mat.SetFloat(ID_Strength,      _settings.outlineStrength);
        _mat.SetFloat(ID_EdgeDarken,    _settings.edgeDarken);
        _mat.SetFloat(ID_NoiseStrength, _settings.noiseStrength);
        _mat.SetFloat(ID_NoiseScale,    _settings.noiseScale);
    }

    public override void Configure(CommandBuffer cmd,
                                   RenderTextureDescriptor cameraTextureDescriptor)
    {
        var desc = cameraTextureDescriptor;
        desc.depthBufferBits = 0;
        desc.depthStencilFormat = GraphicsFormat.None;
        desc.msaaSamples = 1;
        RenderingUtils.ReAllocateHandleIfNeeded(ref _tempColor, desc,
            FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_WatercolorOutlineTemp");
    }

    public override void Execute(ScriptableRenderContext context,
                                 ref RenderingData renderingData)
    {
        if (_mat == null || _tempColor == null) return;
        if (renderingData.cameraData.cameraType == CameraType.Preview) return;

        SetMaterialProperties();

        var source = renderingData.cameraData.renderer.cameraColorTargetHandle;
        var cmd = CommandBufferPool.Get();

        using (new ProfilingScope(cmd, _profilingSampler))
        {
            Blitter.BlitCameraTexture(cmd, source, _tempColor, _mat, 0);
            Blitter.BlitCameraTexture(cmd, _tempColor, source);
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public override void RecordRenderGraph(RenderGraph renderGraph,
                                           ContextContainer frameData)
    {
        if (_mat == null) return;

        var resourceData = frameData.Get<UniversalResourceData>();
        if (resourceData.isActiveTargetBackBuffer) return;

        SetMaterialProperties();

        TextureHandle src = resourceData.activeColorTexture;

        // Transient temp texture — render graph manages its lifetime.
        var desc = renderGraph.GetTextureDesc(src);
        desc.name        = "_WatercolorOutlineTemp";
        desc.clearBuffer = false;
        TextureHandle tmp = renderGraph.CreateTexture(desc);

        // ── Pass 1: src → tmp  (apply outline material) ──────────────────
        renderGraph.AddBlitPass(new RenderGraphUtils.BlitMaterialParameters(src, tmp, _mat, 0),
                                "WatercolorOutline_Apply");

        // ── Pass 2: tmp → src  (copy result back to camera colour) ───────
        renderGraph.AddBlitPass(tmp, src, Vector2.one, Vector2.zero,
                                passName: "WatercolorOutline_CopyBack");
    }

    public void Dispose()
    {
        _tempColor?.Release();
        CoreUtils.Destroy(_mat);
    }
}

using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;

public class MoebiusOutlineFeature : ScriptableRendererFeature
{
    [System.Serializable]
    
    //inspector control
    public class Settings
    {
		    //Material containing the shader
        public Material material;
        
        //When the pass runs - after post-processing
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingPostProcessing;
    }
    
		//setting instance
    public Settings settings = new Settings();

    private MoebiusOutlinePass pass;

    public override void Create()
    {
        pass = new MoebiusOutlinePass(settings.material)
        {
            renderPassEvent = settings.passEvent
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (settings.material == null)
            return;

        renderer.EnqueuePass(pass);
    }

    private class MoebiusOutlinePass : ScriptableRenderPass
    {
        private readonly Material material;

        public MoebiusOutlinePass(Material material)
        {
            this.material = material;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            if (material == null)
                return;

            var resourceData = frameData.Get<UniversalResourceData>();

            if (resourceData.isActiveTargetBackBuffer)
                return;

            var source = resourceData.activeColorTexture;

            var blitParams = new RenderGraphUtils.BlitMaterialParameters(
                source,
                source,
                material,
                0
            );

            renderGraph.AddBlitPass(blitParams, "Moebius Outline Test Pass");
        }
    }
}
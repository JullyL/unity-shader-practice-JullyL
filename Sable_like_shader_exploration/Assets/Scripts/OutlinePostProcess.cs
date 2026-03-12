using UnityEngine;

[ExecuteInEditMode] //rendered in edit mode as well
[RequireComponent(typeof(Camera))] //Game Object must have Camera component
public class OutlinePostProcess : MonoBehaviour
{
    public Material outlineMaterial; // shown in the spector, drag material onto here

    private void OnRenderImage(RenderTexture src, RenderTexture dest) //Called after camera renders
    {
        if (outlineMaterial != null)
        {
            Graphics.Blit(src, dest, outlineMaterial);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
}
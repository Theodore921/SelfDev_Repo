using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

[ExecuteInEditMode]
#if UNITY_5_4_OR_NEWER
[ImageEffectAllowedInSceneView]
#endif

struct CD_DIM
{
    public float fieldOfViewY;
    public float zNear;
    public float zFar;

    public float sD;
    public float logDimY;
    public float logDepth;

    public int clusterDimX;
    public int clusterDimY;
    public int clusterDimZ;
    public int clusterDimXYZ;
};

public class Script_ClusterBasedLighting : MonoBehaviour
{

    private ComputeBuffer cb_ClusterAABBs;

    private CD_DIM m_DimData;

    // Start is called before the first frame update
    void Start()
    {
        _rtColor = new RenderTexture(Screen.width, Screen.height, 24);
        _rtDepth = new RenderTexture(Screen.width, Screen.height, 24, RenderTextureFormat.Depth, RenderTextureReadWrite.Linear);

        CalculateMDim(_camera);
        int stride = Marshal.SizeOf(typeof(AABB));
        cb_ClusterAABBs = new ComputeBuffer(m_DimData.clusterDimXYZ, stride);
    }

    void OnRenderingInmage(RenderTexture sourceTexture, RenderTexture destTexture)
    {
        Graphics.SetRenderTarget(_rtColor.colorBuffer, _rtDepth.depthBuffer);
        GL.Clear(true, true, Color.gray);

        Graphics.Blit(_rtColor, destTexture);
    }

    void CalculateMDim(Camera cam)
    {
        // The half-angle of the filedd of vew in the Y-direction
        float fieldOfViewY = cam.fieldOfView * Mathf.Deg2Rad * 0.5f;//Degree 2 Radiance:  Param.CameraInfo.Property.Perspective.fFovAngleY * 0.5f;
        float zNear = cam.nearClipPlane;
        float zFar = cam.farClipPlane;

        // Number of clusters in the screen X direction.
        int clusterDimX = Mathf.CeilToInt(Screen.width / (float)m_ClusterGridBlockSize);
        // Number of clusters in the screen Y direction.
        int clusterDimY = Mathf.CeilToInt(Screen.height / (float)m_ClusterGridBlockSize);

        // The depth of the cluster grid during clustered rendering is dependent on the 
        // number of clusters subdivisions in the screen Y direction.
        // Source: Clustered Deferred and Forward Shading (2012) (Ola Olsson, Markus Billeter, Ulf Assarsson).
        float sD = 2.0f * Mathf.Tan(fieldOfViewY) / (float)clusterDimY;
        float logDimY = 1.0f / Mathf.Log(1.0f + sD);

        float logDepth = Mathf.Log(zFar / zNear);
        int clusterDimZ = Mathf.FloorToInt(logDepth * logDimY);

        m_DimData.zNear = zNear;
        m_DimData.zFar = zFar;
        m_DimData.sD = sD;
        m_DimData.fieldOfViewY = fieldOfViewY;
        m_DimData.logDepth = logDepth;
        m_DimData.logDimY = logDimY;
        m_DimData.clusterDimX = clusterDimX;
        m_DimData.clusterDimY = clusterDimY;
        m_DimData.clusterDimZ = clusterDimZ;
        m_DimData.clusterDimXYZ = clusterDimX * clusterDimY * clusterDimZ;
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}

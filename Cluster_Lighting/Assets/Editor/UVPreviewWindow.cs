using UnityEngine;
using UnityEditor;
using System.Collections.Generic;

public class UVPreviewWindow : EditorWindow
{
    private Mesh mesh;
    private Vector2 scroll;
    private float zoom = 1.0f;
    private bool showAllTiles = false;
    private bool fitToUVBounds = true;
    private bool regenerateTexture = true;
    private Texture2D uvTexture;
    private Color lineColor = Color.black;
    private Color bgColor = new Color(0.92f,0.92f,0.92f);
    private int textureSize = 1024;
    private enum DrawMode { GLImmediate, Texture }
    private DrawMode drawMode = DrawMode.GLImmediate;

    // cached UV tile bounds
    private int uvTileMinX = 0, uvTileMinY = 0, uvTileMaxX = 0, uvTileMaxY = 0;
    private int tileCountX = 1, tileCountY = 1;

    [MenuItem("Tools/UV Preview")]
    public static void Open()
    {
        GetWindow<UVPreviewWindow>("UV Preview");
    }

    // Alternative Window menu entry for easier discovery
    [MenuItem("Window/UV Preview")]
    public static void OpenFromWindowMenu()
    {
        Open();
    }

    private void OnGUI()
    {
        EditorGUILayout.Space();
        mesh = (Mesh)EditorGUILayout.ObjectField("Mesh", mesh, typeof(Mesh), true);
        drawMode = (DrawMode)EditorGUILayout.EnumPopup("Draw Mode", drawMode);
        zoom = EditorGUILayout.Slider("Zoom", zoom, 0.25f, 10f);
        fitToUVBounds = EditorGUILayout.Toggle("Fit To UV Tiles", fitToUVBounds);
        showAllTiles = EditorGUILayout.Toggle("Repeat Surrounding Tiles", showAllTiles);
        lineColor = EditorGUILayout.ColorField("Line Color", lineColor);
        textureSize = EditorGUILayout.IntSlider("Texture Size", textureSize, 256, 4096);
        if (drawMode == DrawMode.Texture)
        {
            if (GUILayout.Button("Regenerate Texture"))
                regenerateTexture = true;
        }

        if (mesh == null)
        {
            EditorGUILayout.HelpBox("Select a Mesh to preview its UVs.", MessageType.Info);
            return;
        }

        // Compute UV tile extents and drawing rectangle sized to tile counts
        var uvs = mesh.uv;
        ComputeUVTileExtents(uvs, out uvTileMinX, out uvTileMinY, out uvTileMaxX, out uvTileMaxY);
        if (fitToUVBounds)
        {
            tileCountX = Mathf.Max(1, uvTileMaxX - uvTileMinX + 1);
            tileCountY = Mathf.Max(1, uvTileMaxY - uvTileMinY + 1);
        }
        else
        {
            tileCountX = 1;
            tileCountY = 1;
        }

        // Scrollable drawing area sized by tile counts
        scroll = EditorGUILayout.BeginScrollView(scroll, GUILayout.ExpandHeight(true));
        Rect drawRect = GUILayoutUtility.GetRect(position.width * zoom * tileCountX, position.width * zoom * tileCountY);
        if (drawMode == DrawMode.GLImmediate)
        {
            DrawUV_GL(drawRect);
        }
        else
        {
            if (regenerateTexture)
            {
                uvTexture = GenerateTexture(mesh, textureSize, lineColor, bgColor);
                regenerateTexture = false;
            }
            DrawUV_Texture(drawRect);
        }
        EditorGUILayout.EndScrollView();
    }

    private void DrawUV_Texture(Rect rect)
    {
        if (uvTexture == null) return;
        GUI.DrawTexture(rect, uvTexture, ScaleMode.StretchToFill, false);
        DrawGridOverlay(rect, tileCountX, tileCountY);
    }

    private Texture2D GenerateTexture(Mesh m, int sizePerTile, Color line, Color bg)
    {
        int tx = Mathf.Max(1, fitToUVBounds ? (uvTileMaxX - uvTileMinX + 1) : 1);
        int ty = Mathf.Max(1, fitToUVBounds ? (uvTileMaxY - uvTileMinY + 1) : 1);
        int width = sizePerTile * tx;
        int height = sizePerTile * ty;
        var tex = new Texture2D(width, height, TextureFormat.RGBA32, false);
        var pixels = new Color[width * height];
        for (int i = 0; i < pixels.Length; i++) pixels[i] = bg;
        var uvs = m.uv;
        var tris = m.triangles;
        // Draw triangle edges
        for (int i = 0; i < tris.Length; i += 3)
        {
            PlotEdge(uvs[tris[i]], uvs[tris[i+1]], pixels, width, height, sizePerTile, line);
            PlotEdge(uvs[tris[i+1]], uvs[tris[i+2]], pixels, width, height, sizePerTile, line);
            PlotEdge(uvs[tris[i+2]], uvs[tris[i]], pixels, width, height, sizePerTile, line);
        }
        tex.SetPixels(pixels);
        tex.Apply();
        return tex;
    }

    private void PlotEdge(Vector2 a, Vector2 b, Color[] pixels, int width, int height, int sizePerTile, Color line)
    {
        int steps = Mathf.CeilToInt(Vector2.Distance(a, b) * sizePerTile * 2f);
        for (int s = 0; s <= steps; s++)
        {
            float t = s / (float)steps;
            var p = Vector2.Lerp(a, b, t);
            // Map uv to texture coords across full tile extents
            float ux = p.x - (fitToUVBounds ? uvTileMinX : 0);
            float uy = p.y - (fitToUVBounds ? uvTileMinY : 0);
            int x = Mathf.Clamp(Mathf.RoundToInt(ux * sizePerTile), 0, width - 1);
            int y = Mathf.Clamp(Mathf.RoundToInt(uy * sizePerTile), 0, height - 1);
            pixels[y * width + x] = line;
        }
    }

    private void DrawUV_GL(Rect rect)
    {
        var uvs = mesh.uv;
        var tris = mesh.triangles;
        Handles.BeginGUI();
        // Background
        EditorGUI.DrawRect(rect, bgColor);
        DrawGridOverlay(rect, tileCountX, tileCountY);

        if (fitToUVBounds)
        {
            // Draw actual UVs mapped to fitted bounds once
            DrawMeshUVLines(rect, uvs, tris, 0, 0);
        }
        else
        {
            // Repeat surrounding tiles for a quick tiled preview
            int tileRadius = showAllTiles ? 1 : 0;
            for (int tileX = -tileRadius; tileX <= tileRadius; tileX++)
            {
                for (int tileY = -tileRadius; tileY <= tileRadius; tileY++)
                {
                    DrawMeshUVLines(rect, uvs, tris, tileX, tileY);
                }
            }
        }
        Handles.EndGUI();
    }

    private void DrawMeshUVLines(Rect rect, Vector2[] uvs, int[] tris, int offsetX, int offsetY)
    {
        Handles.color = lineColor;
        for (int i = 0; i < tris.Length; i += 3)
        {
            DrawEdge(rect, uvs[tris[i]], uvs[tris[i+1]], offsetX, offsetY);
            DrawEdge(rect, uvs[tris[i+1]], uvs[tris[i+2]], offsetX, offsetY);
            DrawEdge(rect, uvs[tris[i+2]], uvs[tris[i]], offsetX, offsetY);
        }
    }

    private void DrawEdge(Rect rect, Vector2 a, Vector2 b, int ox, int oy)
    {
        // When fitting to UV bounds, do not repeat tiles via offsets
        Vector2 aUV = fitToUVBounds ? a : a + new Vector2(ox, oy);
        Vector2 bUV = fitToUVBounds ? b : b + new Vector2(ox, oy);
        Vector2 ap = UVToRect(aUV, rect);
        Vector2 bp = UVToRect(bUV, rect);
        Handles.DrawLine(ap, bp);
    }

    private Vector2 UVToRect(Vector2 uv, Rect rect)
    {
        // Map UV to rect with optional bounds fitting
        int tx = Mathf.Max(1, tileCountX);
        int ty = Mathf.Max(1, tileCountY);
        float tileW = rect.width / tx;
        float tileH = rect.height / ty;
        float ux = uv.x - (fitToUVBounds ? uvTileMinX : 0);
        float uy = uv.y - (fitToUVBounds ? uvTileMinY : 0);
        return new Vector2(
            rect.xMin + ux * tileW,
            rect.yMax - uy * tileH
        );
    }

    private void DrawGridOverlay(Rect rect, int tx, int ty)
    {
        // Draw per-tile grid with major tile borders and minor divisions
        tx = Mathf.Max(1, tx);
        ty = Mathf.Max(1, ty);
        float tileW = rect.width / tx;
        float tileH = rect.height / ty;

        // Major tile borders
        Handles.color = Color.black;
        for (int i = 0; i <= tx; i++)
        {
            float x = rect.xMin + i * tileW;
            Handles.DrawLine(new Vector2(x, rect.yMin), new Vector2(x, rect.yMax));
        }
        for (int j = 0; j <= ty; j++)
        {
            float y = rect.yMin + j * tileH;
            Handles.DrawLine(new Vector2(rect.xMin, y), new Vector2(rect.xMax, y));
        }

        // Minor divisions inside each tile
        Handles.color = Color.gray;
        int divisions = 10;
        for (int txi = 0; txi < tx; txi++)
        {
            for (int i = 1; i < divisions; i++)
            {
                float x = rect.xMin + txi * tileW + (i / (float)divisions) * tileW;
                Handles.DrawLine(new Vector2(x, rect.yMin + txi * 0), new Vector2(x, rect.yMax));
            }
        }
        for (int tyi = 0; tyi < ty; tyi++)
        {
            for (int i = 1; i < divisions; i++)
            {
                float y = rect.yMin + tyi * tileH + (i / (float)divisions) * tileH;
                Handles.DrawLine(new Vector2(rect.xMin, y), new Vector2(rect.xMax, y));
            }
        }
    }

    private void ComputeUVTileExtents(Vector2[] uvs, out int minX, out int minY, out int maxX, out int maxY)
    {
        if (uvs == null || uvs.Length == 0)
        {
            minX = minY = maxX = maxY = 0;
            return;
        }
        float minUx = float.PositiveInfinity, minUy = float.PositiveInfinity;
        float maxUx = float.NegativeInfinity, maxUy = float.NegativeInfinity;
        for (int i = 0; i < uvs.Length; i++)
        {
            var uv = uvs[i];
            if (uv.x < minUx) minUx = uv.x;
            if (uv.y < minUy) minUy = uv.y;
            if (uv.x > maxUx) maxUx = uv.x;
            if (uv.y > maxUy) maxUy = uv.y;
        }
        minX = Mathf.FloorToInt(minUx);
        minY = Mathf.FloorToInt(minUy);
        maxX = Mathf.FloorToInt(maxUx);
        maxY = Mathf.FloorToInt(maxUy);
    }
}
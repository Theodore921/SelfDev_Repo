Shader "Unlit/Water"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "Black" {} // MainTex
        _NormalTex ("NormalTex", 2D) = "bump" {} // 法线
        _NormalScale ("Normal Scale", float) = 1.0 // 法线强度
        _NormalRefract ("Normal Refract", float) = 0.07 //法线偏移程度可控
        _GTex ("Gradient", 2D) = "white" {} //水深度颜色滤镜
        _WaterSpeed ("WaterSpeed", float) = 0.74 //水速度
        _WaveXSpeed ("Wave X Speed", float) = 0.1
        _WaveYSpeed ("Wave Y Speed", float) = 0.1
        _Refract ("Refract", float) = 0.07 //折射（法线偏移程度可控
        _Specular ("Specular", float) = 1.86 //反射系数
        _Gloss ("Gloss", float) = 0.71            //折射光照
		_SpecColor ("SpecColor", color) = (1, 1, 1, 1)   //折射颜色（一般为白色
		_Range ("Range", vector) = (0.13, 1.53, 0.37, 0.78)  //公开四个数
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent" }
        LOD 200
        Cull off

        GrabPass{}

        zwrite off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 TtoW0 : TEXCOORD2;
                float4 TtoW1 : TEXCOORD3;
                float4 TtoW2 : TEXCOORD4;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _NormalTex;
            float _NormalScale;
            float _WaveXSpeed;
            float _WaveYSpeed;
            float _NormalRefract;
            float _Specular;
            float _Gloss;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 worldNormal = normalize(UnityObjectToWorldNormal(v.normal));
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;

                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
                float3 halfDir = normalize(lightDir + viewDir);

                float4 offsetColor = (tex2D(_NormalTex, i.uv 
                                    + float2(_WaveXSpeed*_Time.x,0)) 
                                    + tex2D(_NormalTex, float2(i.uv.y,i.uv.x) 
                                    + float2(_WaveYSpeed*_Time.x,0)))/2;
            
                //   float4 waveOffset = tex2D(_NormalTex ,i.uv +  wave_offset);
                half2 offset = UnpackNormal(offsetColor).xy * _NormalRefract;//法线偏移程度可控之后offset被用于这里

                fixed3 tangentNormal1 = UnpackNormal(tex2D(_NormalTex, i.uv + offset)).rgb;
                fixed3 tangentNormal2 = UnpackNormal(tex2D(_NormalTex, i.uv - offset)).rgb;
                fixed3 tangentNormal = normalize(tangentNormal1 + tangentNormal2);
                tangentNormal.xy *= _NormalScale;
                tangentNormal.z = sqrt(1 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
                float3 worldNormal = normalize(float3(dot(i.TtoW0.xyz, tangentNormal), dot(i.TtoW1.xyz, tangentNormal), dot(i.TtoW2.xyz, tangentNormal)));

                float NdotH = max(0, dot(halfDir, worldNormal));
                float NdotL = max(0, dot(worldNormal, lightDir));

                fixed4 col = tex2D(_MainTex, i.uv);

                fixed3 diffuse = _LightColor0.rgb * col * saturate(dot(worldNormal, lightDir));
                fixed3 specular = pow(NdotH, _Specular * 128.0) * _Gloss;
                float3 ambient = col * UNITY_LIGHTMODEL_AMBIENT.xyz;

                
                return float4(diffuse + specular + ambient, col.a);
            }
            ENDCG
        }
    }
}

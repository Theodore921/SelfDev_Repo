Shader "Unlit/Raindrop_Static"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            #define HAS_HEART
			#define USE_POST_PROCESSING


            float3 N13(float p) 
            {
                //  from DAVE HOSKINS
                float3 p3 = frac(float3(p, p, p) * float3(.1031, .11369, .13787));
                p3 += dot(p3, p3.yzx + 19.19);
                return frac(float3((p3.x + p3.y)*p3.z, (p3.x + p3.z)*p3.y, (p3.y + p3.z)*p3.x));
            }

            float Saw(float b, float t)
            {
                return smoothstep(0., b, t)* smoothstep(1., b, t);
            }

            float StaticDrops(float2 uv, float time)
            {
                uv *= 30.; // Scale UVs to increase raindrop density
                float2 id = floor(uv); // Get integer grid cell
                uv = frac(uv) - .5; // .5 to center the raindrop
                /// Random ///
                float3 n = N13(id.x * 107.45 + id.y*3543.654); // Pseudo-random values based on cell ID
                /// Offset ///
                float2 p = (n.xy - .5) * .7;
                float d = length(uv - p);// get the distance from center
                /// fade ///
                float fade = Saw(.025, frac(time + n.z));
                //frac(n.z*10.) creates variation in raindrop size
                float drop = smoothstep(.3, 0, d) * frac(n.z * 10.) * fade; // create a circular mask for the raindrop // 0.3 is the radius of the raindrop

                return drop;
            }

            float2 Drops(float2 uv, float time, float l0)
            {
                float s = StaticDrops(uv, time) * l0;
                s = smoothstep(.3, 1., s);
                return float2(s, 0);
            }



            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = ((i.uv * _ScreenParams.xy) - .5 * _ScreenParams.xy)/_ScreenParams.y; // Adjust UVs to be screen-space
                float2 UV = i.uv.xy;
                float time = _Time.y * .2;

                /// Rain Intensity Simulation ///
                float rainAmount = sin(_Time.y * .05) * .3 + .7; // Simulate changing rain intensity
                float maxBlur = lerp(3., 6., rainAmount); // Maximum blur based on rain intensity
                float minBlur = 2.; // Minimum blur

                float staticDrops = smoothstep(-.5, 1., rainAmount) * 2;
                float2 c = Drops(uv, time, staticDrops); // c.x is the raindrop mask
                
                // 求出 uv 方向水珠厚度的变化率
                float2 e = float2(.001, 0.);
                float cx = Drops(uv + e, time, staticDrops).x;
                float cy = Drops(uv + e.yx, time, staticDrops).x;
                float2 n = float2(cx - c.x, cy - c.x);

                //水珠越厚，用越小的 blur，也即越小的 LOD，即更加清晰
                float focus = lerp(maxBlur, minBlur, smoothstep(.1, .2, c.x));

                //根据水珠厚度变化率，偏移采样坐标，模拟水珠折射
                float4 texCoord = float4(UV.x + n.x, UV.y + n.y, 0, focus); 
                float4 lod = tex2Dlod(_MainTex, texCoord);
                float3 col = lod.rgb;

                return float4(col, 1);
            }
            ENDCG
        }
    }
}

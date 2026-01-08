Shader "Unlit/Raindrop_backup"
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


            float N(float t)
            {
                return frac(sin(t * 12345.564) * 7658.76);
            }

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
                float time = _Time.y * 0.2;
                uv.y += time * 0.75;

                float2 scale = float2(6.0, 1.0);
                float2 grid = scale * 2.0; // Flow UV Base Scale

                float2 id = floor(uv * grid); // Flow UV Base Shape
                float colShift = N(id.x);
                uv.y += colShift; // Add vertical Col offset to flow UVs

                float2 flowUV = frac(uv * grid) - float2(0.5, 0);

                id = floor(uv * grid); // Recalculate ID after offset
                float3 n1 = N13(id.x * 35.2 + id.y*2376.1); 
                float x = n1.x - 0.5; 
                float y = UV.y * 20.0;
                float wiggle = sin(y + sin(y));// Add Water flow wiggle effect
                x += wiggle * (0.5 - abs(x)) * (n1.z - 0.5);
                x *= 0.7;// Flow Strength

                ///Fading factor///
                float ti = frac(time + n1.z);
                y = (Saw(0.85, ti) - 0.5) * 0.9 + 0.5; 

                float2 uvOffest = float2(x, y);
                float2 drop = length((flowUV - uvOffest) * scale.yx);

                float mainDrop = smoothstep(0.4, 0.0, drop); // Main drop shape

                float r = sqrt(smoothstep(1.0, y, flowUV.y));

                float cd = abs(flowUV.x - x);
                float test = abs(flowUV.y - y);
                // float cd = length((flowUV - uvOffest) * float2(1.0, 0.2));

                float trail = smoothstep(0.23*r, 0.15*r*r, cd);
                // float trail = smoothstep(0.15*r*r, 0.23*r, cd);
                float trailFront = smoothstep(-0.02, 0.02, flowUV.y - y); // Trailing effect
                trail *= trailFront*r*r;

                /*Drop由 mainDrop 和 trail 叠加而成，mainDrop部分，分为雨滴的纵向拖尾和下坠时的加减速动画
                具体效果可以debug上述代码131行和132行的cd和test变量来观察。可以注意到，cd即x方向的偏移量，形成了拖尾及拖尾的左右偏移
                test即y方向的偏移量，形成了雨滴下坠的动画效果。二者组合的float2，就是125行的drop。
                不过实际编写时，原开发者是先使用了Drop点乘uv的纵向缩放倍率来获取到雨点，然后再单独用x方向的cd来做拖尾效果。（132行的test变量是为了方便debug自行添加的）
                所以你可以尝试用133行的drop代码替换131行，因为我还原了此前点乘的uv倍率scale，可以发现效果是几乎一样的。
                
                Trail部分，我并没能完全理解透彻，以我的理解，129行的r实际是拖尾的尾部渐变变短的范围，135行对cd也就是拖尾的smoothstep实际上相当于
                用r和rr来控制拖尾在流动时的粗细变化，你可以尝试调成135行smoothstep前两个参数的点乘数值，可以发现拖尾的粗细会发生变化。
                最后点乘的trailFront，我的理解是用一个卡的很死的smoothstep来产生拖尾长度上的变化，且尽量不改变深浅，模拟雨滴下坠时拖尾的拉长和缩短。
                你可以尝试调整137行smoothstep中的前两个常数值，可以发现拖尾的颜色深浅会发生变化，这就是为什么会用一个卡的很死的smoothstep来做这个。
                */


                

                return float4(trail,0, 0, 1);








                

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

Shader "Unlit/Raindrop"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _StaticRainDropSpeed ("Static Rain Drop Speed", Float) = 0.2
        _DynamicRainDropSpeed ("Dynamic Rain Drop Speed", Float) = 0.2
        _DynamiceLayer1Tiling ("Dynamic Layer 1 Tiling", Float) = 1.0
        _DynamiceLayer2Tiling ("Dynamic Layer 2 Tiling", Float) = 1.0
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
            float _StaticRainDropSpeed;
            float _DynamicRainDropSpeed;
            float _DynamiceLayer1Tiling;
            float _DynamiceLayer2Tiling;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            //// Functions ////
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

            float2 DropLayer2(float2 uv, float time)
            {
                float2 UV = uv;

                uv.y += time * 0.75;
                float2 scale = float2(6.0, 1.0);
                float2 grid = scale * 2.0; // Flow UV Base Scale

                float2 id = floor(uv * grid); // Flow UV Base Shape
                float colShift = N(id.x);
                uv.y += colShift; // Add vertical Col offset to flow UVs

                float2 flowUV = frac(uv * grid) - float2(0.5, 0);

                id = floor(uv * grid); // Recalculate ID after offset
                float3 n1 = N13(id.x * 35.2 + id.y*2376.1); 
                float x = n1.x - 0.5; // Strength of water flow
                float y = UV.y * 20.0;
                float wiggle = sin(y + sin(y));// Add Water flow wiggle effect
                x += wiggle * (0.5 - abs(x)) * (n1.z - 0.5);
                x *= 0.7;// Flow Strength

                ///Fading factor///
                float ti = frac(time + n1.z);
                y = (Saw(0.85, ti) - 0.5) * 0.9 + 0.5; 

                float2 p = float2(x, y);
                float2 d = length((flowUV - p) * scale.yx);

                float mainDrop = smoothstep(0.4, 0.0, d); // Main drop shape

                float r = sqrt(smoothstep(1.0, y, flowUV.y));
                float cd = abs(flowUV.x - x);
                float trail = smoothstep(0.23*r, 0.15*r*r, cd);
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
                y = UV.y;
                float trail2 = smoothstep(0.2 * r, 0, cd);
                float droplets = max(0, (sin(y * (1.0 - y) * 120.0) - flowUV.y)) * trail2 * trailFront * n1.z;


                y = frac(y * 10.0) + (flowUV.y - 0.5);
                float dd = length(flowUV - float2(x, y));
                droplets = smoothstep(0.3, 0, dd);

                float m = mainDrop + droplets * r * trailFront; //此处的droplets * r * trailFront是模拟水珠拖尾变浅过程中形成的水珠

                return float2(m, trail);
            }

            float2 Drops(float2 uv, float time, float l0, float l1, float l2)
            {
                float staticRainDropTime = _Time.y * _StaticRainDropSpeed;
                float dynamicRainDropTime = _Time.y * _DynamicRainDropSpeed;
                float s = StaticDrops(uv, time) * l0;
                float2 m1 = DropLayer2(uv * _DynamiceLayer1Tiling, dynamicRainDropTime) * l1;
                float2 m2 = DropLayer2(uv * _DynamiceLayer2Tiling, dynamicRainDropTime) * l2;
                /*
                此处拆分出m1和m2是为了给动态雨增加一些层次，DropLayer2函数传回的y值即Trail其实并没有用到
                */

                float c = s + m1.x + m2.x;
                c = smoothstep(0.3, 1.0, c);

                return float2(c, max(m1.y*l0, m2.y*l1));
            }
            //// End Functions ////




            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = ((i.uv * _ScreenParams.xy) - .5 * _ScreenParams.xy)/_ScreenParams.y; // Adjust UVs to be screen-space
                float2 UV = i.uv.xy;
                float time = _Time.y * 0.2;

                /// Rain Intensity Simulation ///
                float rainAmount = sin(_Time.y * 0.05) * 0.3 + 0.7; // Simulate changing rain intensity
                float maxBlur = lerp(3.0, 6.0, rainAmount); // Maximum blur based on rain intensity
                float minBlur = 2.0; // Minimum blur

                float staticDrops = smoothstep(-0.5, 1.0, rainAmount) * 2.0;
                float layer1 = smoothstep(0.25, 0.75, rainAmount);
                float layer2 = smoothstep(0, 0.5, rainAmount);

                float2 c = Drops(uv, time, staticDrops, layer1, layer2); // c.x is the raindrop mask
                
                // 求出 uv 方向水珠厚度的变化率
                float2 e = float2(0.001, 0.0);
                float cx = Drops(uv + e, time, staticDrops, layer1, layer2).x;
                float cy = Drops(uv + e.yx, time, staticDrops, layer1, layer2).x;
                float2 n = float2(cx - c.x, cy - c.x);

                //水珠越厚，用越小的 blur，也即越小的 LOD，即更加清晰
                float focus = lerp(maxBlur, minBlur, smoothstep(0.1, 0.2, c.x));

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

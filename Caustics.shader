Shader "Custom/Caustics"
{
    Properties
    {
        [Header(Colors)]
        _ShallowColor ("Shallow Color", Color) = (1,1,1,1)
        _DeepColor ("Deep Color", Color) = (1,1,1,1)

        [Header(Depth Values)]
        _ShoreThresh ("Shoreline Thresh", float) = 1
        _DepthThresh ("Depth Thresh", float) = 1

        [Header(Noise)]
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _NoiseSpeed ("Noise Speed", float) = 1

        [Header(Caustics)]
        _CausticsTex ("Caustics Texture", 2D) = "white" {}
        _CausticsSpeedA ("Caustics Speed A", float) = 1
        _CausticsSpeedB ("Caustics Speed B", float) = 1
        _CausticsSplit("Caustics Split", float) = 1
        _CausticsStrength("Caustics Strength", float) = 1

        [Header(ShoreLines)]
        _ShoreSpeed ("Shore Speed", float) = 1
        _ShoreWaveLength ("Shore Length", float) = 1
        _ShoreNoiseRed ("Shore Noise Reduction", Range(0, 1)) = .5

        [NoScaleOffset] _NormalTex ("Normal Texture", 2D) = "bump" {}
        _NormalTextureScale ("Normal Texture Scale (XY & ZW)", vector) = (1, 1, 1, 1)
        _NormalTextureOffset ("Normal Texture Offset (XY & ZW)", vector) = (1, 1, 1, 1)        
        _NormalScaleA ("Normal A Scale", float) = 1
        _NormalScaleB ("Normal B Scale", float) = 1

        _NormalSpeed ("Normal Speed (XY & ZW)", vector) = (1, 1, 1, 1)

        [Header(Unity Values)]
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "DisableBatching"="True"}
        LOD 300


        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows alpha:premul

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.5

        struct Input
        {
            float2 uv_NormalA;
            float2 uv_NormalB;
            float4 screenPos;
            float3 worldPos;
            float3 viewDir;
        };

        sampler2D _CameraDepthTexture;

        fixed4 _ShallowColor, _DeepColor;

        float _ShoreThresh, _DepthThresh;

        sampler2D _NoiseTex;
        float4 _NoiseTex_ST;
        float _NoiseSpeed;

        sampler2D _CausticsTex;
        float4 _CausticsTex_ST;
        float _CausticsSpeedA, _CausticsSpeedB;
        float _CausticsSplit, _CausticsStrength;

        float _ShoreSpeed, _ShoreWaveLength, _ShoreNoiseRed;

        sampler2D _NormalTex;   
        float4 _NormalTextureScale;
        float4 _NormalTextureOffset;
        float _NormalScaleA, _NormalScaleB;
        float4 _NormalSpeed;

        half _Glossiness;
        half _Metallic;

        //from ronja
        float3 GetWorldPos(float depth, float3 ray){
            
            //because the depth is only in the z direction we need to scale our ray by how many depth units fit in the ray
            //this gives us the world space ray of the correct size
            ray /= dot(ray, -UNITY_MATRIX_V[2].xyz);

            //then multiply the depth value by this value plus the cameras position to get the worldPos
            float3 worldPos = _WorldSpaceCameraPos + ray * depth;

            return worldPos;
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            //get screen UV
            float2 screenUV = IN.screenPos.xy / IN.screenPos.w;

            //Calculate view ray and camera direction
            float3 viewRay = _WorldSpaceCameraPos - IN.worldPos;
            float3 camDir = normalize(viewRay);

            //get depth from depth buffer
            float sceneDepth = tex2D(_CameraDepthTexture, screenUV);
            sceneDepth = Linear01Depth(sceneDepth) * _ProjectionParams.z;

            //get depth of current fragment
            float fragDepth = IN.screenPos.w;

            //then get the world pos
            float3 worldPos = GetWorldPos(sceneDepth, camDir);
            
            //sample a noise texture to add some randomness to values later on
            float noise = tex2D(_NoiseTex,  worldPos.xz * _NoiseTex_ST.xy + _NoiseTex_ST.zw + _Time.y * _NoiseSpeed).r;
            //multiply with the noise reduction to get the noise we will use for the shore LineS
            float shoreNoise = noise * _ShoreNoiseRed;

            //calcuate depth difference ratios saturate so 01
            float difference = sceneDepth - fragDepth;
            float depthValue = saturate(difference / _DepthThresh);

            //do the same for the shore but add a little noise so the waves dont look the same eveytime
            float shoreValue = saturate(difference / (_ShoreThresh + shoreNoise));

            //start calculating the COLOR

            //lerp between the shallow and deep colors based off of the depth difference
            float4 col = lerp(_ShallowColor, _DeepColor, depthValue);

            //assign the albedo color
            o.Albedo = col.rgb;

            //calculate Caustics
            //first declare two color variables
            float3 col1;
            float3 col2;
            
            //then split the rgb values using the _CausticsSplit as an UV offset
            col1.r = tex2D(_CausticsTex, worldPos.xz * _CausticsTex_ST.xy + _Time.y * _CausticsSpeedA + float2(_CausticsSplit, _CausticsSplit)).r;
            col1.g = tex2D(_CausticsTex, worldPos.xz * _CausticsTex_ST.xy + _Time.y * _CausticsSpeedA + float2(_CausticsSplit, -_CausticsSplit)).g;
            col1.b = tex2D(_CausticsTex, worldPos.xz * _CausticsTex_ST.xy + _Time.y * _CausticsSpeedA + float2(-_CausticsSplit, -_CausticsSplit)).b;

            //we add the offset to this texuture so that we never perfectly line up
            col2.r = tex2D(_CausticsTex, (worldPos.xz * _CausticsTex_ST.xy + _CausticsTex_ST.zw) + _Time.y * _CausticsSpeedB + float2(_CausticsSplit, _CausticsSplit)).r;
            col2.g = tex2D(_CausticsTex, (worldPos.xz * _CausticsTex_ST.xy + _CausticsTex_ST.zw) + _Time.y * _CausticsSpeedB + float2(_CausticsSplit, -_CausticsSplit)).g;
            col2.b = tex2D(_CausticsTex, (worldPos.xz * _CausticsTex_ST.xy + _CausticsTex_ST.zw) + _Time.y * _CausticsSpeedB + float2(-_CausticsSplit, -_CausticsSplit)).b;

            //then combine the two colors with a min
            float3 causticsColor = min(col1, col2) * _CausticsStrength;

            //before we can add the caustics to the emission we want to calculate out shore mask 
            //that way we can mask out the caustics in the deep and shore areas

            //to get the shore mask we do a one minus with the shore value calculated earlier
            float shoreMask = 1 - shoreValue;
            //and then step it with a very small value so it is 1 everywhere 1 - the shoreValue is greater than the epsilon (or almost 0) 
            shoreMask = step(.0001, shoreMask);

            //now that we have our shore mask we can add the caustics to the emission masking out deep and shore areas
            o.Emission += causticsColor * (1 - depthValue) * (1 - shoreMask);

            //assign the alpha. we lerp based on the shore value so that the alpha drops to 0 at the shore
            o.Alpha = lerp(col.a, 0, 1 - shoreValue);

            //now we start to calculate the shore LineS

            //we get a gradient in the shore mask by taking the frac of the shoreValue - time and noise
            float shoreGradient = frac((1 - shoreValue) - _Time.y * _ShoreSpeed + shoreNoise) * shoreMask;

            //then to get distance between the different shore lines we step the shore gradient (01 value) - a sin value (-1 1 value) * the shore mask to keep it in the shore
            //with the noise + the shoreGradient
            //it is a little complicated but think of stepping a value than goes up and down with another value that goes up and down
            float shoreLines = step(shoreGradient - sin(shoreGradient * _ShoreWaveLength) * shoreMask, noise + (1 - shoreGradient));

            //then we can add in the shore lines by multiplying the shore lines with the shore gradient to get fading in and out wave lines
            o.Emission += shoreGradient * shoreLines;

            //sample the normal texture, we multiply the scale by the depth value so that the normals scale down as they approach the shore
            float3 normalA = UnpackScaleNormal(tex2D(_NormalTex, IN.worldPos.xz * _NormalTextureScale.xy + (_Time.y * _NormalSpeed.xy) + _NormalTextureOffset.xy), _NormalScaleA * depthValue);
            float3 normalB = UnpackScaleNormal(tex2D(_NormalTex, IN.worldPos.xz * _NormalTextureScale.zw + (_Time.y * _NormalSpeed.zw) + _NormalTextureOffset.zw), _NormalScaleB * depthValue);
            //adding the normals look better than using BlendNormals();
            o.Normal = normalA + normalB;

            // Metallic and smoothness, we multiply by the shorevalue because of premul. If we didn't it looks like the alpha isnt being applied at the shore
            o.Metallic = _Metallic * shoreValue;
            o.Smoothness = _Glossiness * shoreValue;

        }
        ENDCG
    }
    FallBack "Diffuse"
}

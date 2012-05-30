//@author: Elliot Woods
//@help: Display projected area
//@tags: ProjectionSimulation
//@credits:

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------
#define PROJECTOR_COUNT 6

//transforms
float4x4 tW: WORLD;        //the models world matrix
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tP: PROJECTION;   //projection matrix as set via Renderer (EX9)
float4x4 tWVP: WORLDVIEWPROJECTION;
float4x4 tWV: WORLDVIEW;

//colour
float4 lAmb  : COLOR <String uiname="Ambient Color";>  = {0.15, 0.15, 0.15, 1};
float4 lDiff : COLOR <String uiname="Diffuse Color";>  = {0.85, 0.85, 0.85, 1};
float4 lSpec : COLOR <String uiname="Specular Color";> = {0.35, 0.35, 0.35, 1};
float3 lDir <String uiname="Light Direction";> = {0.0, 0.0, 1.0};


//texture
texture TexDepth <string uiname="Depth Map";>;
sampler SampDepth = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexDepth);          //apply a texture to the sampler
    MipFilter = NONE;         //sampler states
    MinFilter = NONE;
    MagFilter = NONE;
};

//the data structure: vertexshader to pixelshader
//used as output data with the VS function
//and as input data with the PS function
struct vs2ps
{
    float4 Pos : POSITION;
	float4 PosP : TEXCOORD1;
	float4 PosW : TEXCOORD0;
    float4 Diffuse: COLOR0;
    float4 Specular: COLOR1;
};

// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------

vs2ps VS(
    float4 Pos : POSITION,
    float3 NormO : NORMAL,
    float4 TexCd : TEXCOORD0)
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;

    //transform position
    Out.Pos = mul(Pos, tWVP);

	Out.PosW = mul(Pos,tW);
	
	//inverse light direction in view space
    float3 LightDirV = normalize(-mul(lDir, tV));

    //normal in view space
    float3 NormV = normalize(mul(NormO, tWV));

    //view direction = inverse vertexposition in viewspace
    float4 PosV = mul(Pos, tWV);
    float3 ViewDirV = normalize(-PosV);

    //halfvector
    float3 H = normalize(ViewDirV + LightDirV);

    //compute blinn lighting
    float3 shades = lit(dot(NormV, LightDirV), dot(NormV, H), 25);

    float4 diff = lDiff * shades.y;
    diff.a = 1;
    float4 spec = lSpec * shades.z;
    spec.a = 1;
	Out.Diffuse = diff + lAmb;
    Out.Specular = spec;
	
	
    return Out;
}

// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// --------------------------------------------------------------------------------------------------

float4x4 tProjector[PROJECTOR_COUNT];
int2 ProjectorResolution = {1024, 768};
float threshold = 0.001;
float brightness = 5;
bool applyAliasing = false;
float Alpha = 1.0f;

float testProjector(int i, float4 PosW, bool applyFade=true)
{
	float4 PosProjector = mul(PosW, tProjector[i]);
	float Depth = PosProjector.z;
	
	PosProjector /= PosProjector.w;
	float2 DepthMapCd = PosProjector.xy;
	DepthMapCd += 1.0f;
	DepthMapCd /= 2.0f;
	DepthMapCd.y = 1.0f - DepthMapCd.y;
	
	DepthMapCd.x += i;
	DepthMapCd.x /= float(PROJECTOR_COUNT);
	

	float DepthMapValue = tex2D(SampDepth, DepthMapCd).r;
	
	float value;
	
	//this step applies depth testing and aliasing
	//aliasing occurs if threshold is very low (< 0.01)
	value = 1.0f - smoothstep(0, threshold, abs(Depth - DepthMapValue));	
	
	if (applyFade)
	{
		//inverse square brightness
		value /= Depth * Depth;
		value *= brightness;
	
		//test inside
		value *= abs(PosProjector.x) < 1.0f && abs(PosProjector.y) < 1.0f;	
	}
	
	return value;
}

float4 PreviewCoverage(vs2ps In): COLOR
{
	//BLUE REPRESENTS COVERAGE
	float4 col = 1;
	col.rgb = 0;
	
	for (int i=0; i<PROJECTOR_COUNT; i++)
		col.b += testProjector(i, In.PosW);
	
	float4 Light = lAmb + In.Diffuse + In.Specular;
	Light.b = 0.0f;
	
	float4 result = col + Light;
	result.a *= Alpha;
	return result;
}

float4 ProjectorPosition(int iProjector, float4 PosW)
{
	float4 PosProjector = mul(PosW, tProjector[iProjector]);
	float Depth = PosProjector.z;
	
	PosProjector /= PosProjector.w;
	return PosProjector;
}
int ProjectorIndex(int iProjector, float4 PosW)
{
	float4 PosProjector = mul(PosW, tProjector[iProjector]);
	float Depth = PosProjector.z;
	
	PosProjector /= PosProjector.w;
	float2 DepthMapCd = PosProjector.xy;
	DepthMapCd += 1.0f;
	DepthMapCd /= 2.0f;
	DepthMapCd.y = 1.0f - DepthMapCd.y;
	
	DepthMapCd.x += iProjector;
	DepthMapCd.x /= float(PROJECTOR_COUNT);
	
	float DepthMapValue = tex2D(SampDepth, DepthMapCd).r;
	
	float value;
	value = 1.0f - smoothstep(0, threshold, abs(Depth - DepthMapValue));	

	int index = floor(DepthMapCd.x * ProjectorResolution.x) + floor(DepthMapCd.y * ProjectorResolution.y) * ProjectorResolution.x;
	return (value > 0.1f) * index;
}

int4 PSScanPreview(vs2ps In) : COLOR
{
	int4 output = 0;
	if (PROJECTOR_COUNT >= 3)
	{
		output.x = ProjectorIndex(0, In.PosW);
		output.y = ProjectorIndex(1, In.PosW);
		output.z = ProjectorIndex(2, In.PosW);	
	}
	output.w = 1;
	
    return output;
}

float4 PSWorldXYZ(vs2ps In) : COLOR
{
	float4 xyz = In.PosW;
	float4 col;
	col.rgb = xyz.xyz / xyz.w;
	col.rgb += 5.0f;
	col.a = 1;
	return col;
}

float4 PSProjector1XYZ(vs2ps In) : COLOR
{
	float size = 1.0f;
	float4 PosP = ProjectorPosition(0, In.PosW);
	PosP.a = 1.0f - (PosP.x < -size || PosP.x > size);
	PosP.a *= 1.0f - (PosP.y < -size || PosP.y > size);
	return PosP;
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique TProjectShadows
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage();
    }
}

technique TDataSetPreview
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PSScanPreview();
    }
}

technique TWorldXYZ
{
	pass P0
	{
		VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PSWorldXYZ();
	}
}

technique TProjector1XYZ
{
	pass P0
	{
		VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PSProjector1XYZ();
	}
}
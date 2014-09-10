//@author: Elliot Woods
//@help: Display projected area
//@tags: ProjectionSimulation
//@credits:

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------
//#define PROJECTOR_COUNT 2
#define MAX_PROJECTOR_COUNT 64

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

int ProjectorCount = 2;

//texture
texture TexDepth <string uiname="Depth Map";>;
sampler SampDepth = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexDepth);          //apply a texture to the sampler
    MipFilter = NONE;         //sampler states
    MinFilter = NONE;
    MagFilter = NONE;
};

texture TexImage <string uiname="Image";>;
sampler SampImage = sampler_state    //sampler for doing the texture-lookup
{
    Texture   = (TexImage);          //apply a texture to the sampler
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
	float4 NormW : TEXCOORD2;
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
	Out.NormW = normalize(mul(NormO, tW));
	
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

float4x4 tProjector[MAX_PROJECTOR_COUNT];
int2 ProjectorResolution = {1024, 768};
float threshold = 0.001;
float brightness[MAX_PROJECTOR_COUNT];
float Alpha = 1.0f;
bool applyFade = true;
bool applyNormals = true;

float3 applyProjector(int i, vs2ps input, int projectorCount)
{
	float4 PosProjector = mul(input.PosW, tProjector[i]);
	float Depth = PosProjector.z;
	
	PosProjector /= PosProjector.w;
	float2 DepthMapCd = PosProjector.xy;
	DepthMapCd += 1.0f;
	DepthMapCd /= 2.0f;
	DepthMapCd.y = 1.0f - DepthMapCd.y;
	
	DepthMapCd.x += i;
	DepthMapCd.x /= float(projectorCount);

	float DepthMapValue = tex2D(SampDepth, DepthMapCd).r;
	
	float value = 1.0f;
	
	//this step applies depth testing and aliasing
	//aliasing occurs if threshold is very low (< 0.01)
	value -= smoothstep(0, threshold, abs(Depth - DepthMapValue));	
	
	if (applyFade)
	{
		//inverse square brightness
		value /= Depth * Depth;
	}
	
	if (applyNormals)
	{
		//we draw on front and back faces, we presume shadow performs back culling for us
		value *= clamp(abs(normalize(mul(input.NormW, tProjector[i])).z), 0, 1);
	}
	
	value *= brightness[i];
	
	//test inside
	value *= abs(PosProjector.x) < 1.0f && abs(PosProjector.y) < 1.0f;	
	
	return value * tex2D(SampImage, DepthMapCd).rgb;
}

float4 PreviewCoverage(vs2ps In, int projectorCount): COLOR
{
	//BLUE REPRESENTS COVERAGE
	float4 col = 1;
	col.rgb = 0;
	
	for (int i=0; i<projectorCount; i++)
		col.rgb += applyProjector(i, In, projectorCount);
	
	float4 Light = lAmb + In.Diffuse + In.Specular;
	
	float4 result = col + Light;
	result.a = saturate(result.a);
	result.a *= Alpha;
	return result;
}

float4 PreviewCoverage1(vs2ps In): COLOR
{ return PreviewCoverage(In, 1); }
float4 PreviewCoverage2(vs2ps In): COLOR
{ return PreviewCoverage(In, 2); }
float4 PreviewCoverage3(vs2ps In): COLOR
{ return PreviewCoverage(In, 3); }
float4 PreviewCoverage4(vs2ps In): COLOR
{ return PreviewCoverage(In, 4); }
float4 PreviewCoverage5(vs2ps In): COLOR
{ return PreviewCoverage(In, 5); }
float4 PreviewCoverage6(vs2ps In): COLOR
{ return PreviewCoverage(In, 6); }
float4 PreviewCoverage7(vs2ps In): COLOR
{ return PreviewCoverage(In, 7); }
float4 PreviewCoverage8(vs2ps In): COLOR
{ return PreviewCoverage(In, 8); }
float4 PreviewCoverage9(vs2ps In): COLOR
{ return PreviewCoverage(In, 9); }
float4 PreviewCoverage10(vs2ps In): COLOR
{ return PreviewCoverage(In, 10); }
float4 PreviewCoverage11(vs2ps In): COLOR
{ return PreviewCoverage(In, 11); }
float4 PreviewCoverage12(vs2ps In): COLOR
{ return PreviewCoverage(In, 12); }
float4 PreviewCoverage13(vs2ps In): COLOR
{ return PreviewCoverage(In, 13); }
float4 PreviewCoverage14(vs2ps In): COLOR
{ return PreviewCoverage(In, 14); }
float4 PreviewCoverage15(vs2ps In): COLOR
{ return PreviewCoverage(In, 15); }
float4 PreviewCoverage16(vs2ps In): COLOR
{ return PreviewCoverage(In, 16); }

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
	DepthMapCd.x /= float(ProjectorCount);
	
	float DepthMapValue = tex2D(SampDepth, DepthMapCd).r;
	
	float value;
	value = 1.0f - smoothstep(0, threshold, abs(Depth - DepthMapValue));	

	int index = floor(DepthMapCd.x * ProjectorResolution.x) + floor(DepthMapCd.y * ProjectorResolution.y) * ProjectorResolution.x;
	return (value > 0.1f) * index;
}

int4 PSScanPreview(vs2ps In) : COLOR
{
	int4 output = 0;
	if (ProjectorCount >= 3)
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

technique TProjectShadows1
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage1();
    }
}

technique TProjectShadows2
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage2();
    }
}

technique TProjectShadows3
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage3();
    }
}

technique TProjectShadows4
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage4();
    }
}

technique TProjectShadows5
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage5();
    }
}

technique TProjectShadows6
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage6();
    }
}

technique TProjectShadows7
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage7();
    }
}

technique TProjectShadows8
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage8();
    }
}

technique TProjectShadows9
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage9();
    }
}

technique TProjectShadows10
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage10();
    }
}

technique TProjectShadows11
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage11();
    }
}

technique TProjectShadows12
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage12();
    }
}

technique TProjectShadows13
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage13();
    }
}

technique TProjectShadows14
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage14();
    }
}

technique TProjectShadows15
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage15();
    }
}

technique TProjectShadows16
{
    pass P0
    {
        //Wrap0 = U;  // useful when mesh is round like a sphere
        VertexShader = compile vs_3_0 VS();
        PixelShader = compile ps_3_0 PreviewCoverage16();
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
//@author: Elliot Woods
//@help: Display projected area
//@tags: ProjectionSimulation
//@credits:

 
cbuffer cbPerDraw : register( b0 )
{
	float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
	float4x4 tVP: VIEWPROJECTION;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
	float4x4 TargetVPI;
};

//--
//Parameters
//--
//
#define MAX_PROJECTOR_COUNT 64

//transforms
float3 ProjectorPosition;
float3 ProjectorLookVector;

int ActiveProjectorCount = 2;

float4x4 tProjector[MAX_PROJECTOR_COUNT];
float brightness[MAX_PROJECTOR_COUNT];
float DepthEpsilon = 1e-4;
float Alpha = 1.0f;

bool ApplyShadows = true;
bool ApplyFade = true;
bool ApplyNormals = true;

//
//--



//--
//Samplers and textures
//--
//
SamplerState g_SamLinear {
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};

SamplerState g_SamPoint {
	Filter = MIN_MAG_MIP_POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};

Texture2D<float> TexTargetDepth;
Texture2DArray<float> TexArrayDepth <string uiname="Depth Maps"; >;
Texture2D TexImage <string uiname="Image";>;
//
//--



//--
//Inter-shader structs
//--
//
struct vs_in
{
	float4 PosO : POSITION;
	float4 TexCd : TEXCOORD0;
};

struct ps_in {
	float4 PosWVP : SV_POSITION;
	float4 TexCd : TEXCOORD0;
};

struct Pixel {
	float4 PosTargetP;
	float4 PosW;
};
//
//--



//--
//Vertex shaders
//--
//
ps_in VS(vs_in input)
{
    ps_in output;
    output.PosWVP  = mul(input.PosO,mul(tW,tVP));
    output.TexCd = input.TexCd;
    return output;
}
//
//--



//--
//Pixel shaders
//--
//
float3 applyProjector(int i, Pixel pixel, int projectorCount)
{
	float4 PosProjector = mul(pixel.PosW, tProjector[i]);
	float Depth = PosProjector.z / PosProjector.w;	
	PosProjector /= PosProjector.w;
	float3 DepthMapCd;
	DepthMapCd.x = (1.0f + PosProjector.x) / 2.0f;
	DepthMapCd.y = (1.0f - PosProjector.y) / 2.0f;
	DepthMapCd.z = i;
	bool insideProjector = all(abs(DepthMapCd - 0.5) <= 0.5f);
	/*DEBUG*/ //return DepthMapCd * insideProjector;
	

	//--
	//Calculate output value
	//--
	//
	float value = 1.0f;
	
	//this step applies depth testing and aliasing
	//aliasing occurs if threshold is very low (< 1e-6)
	float DepthMapValue = TexArrayDepth.Sample(g_SamPoint, DepthMapCd);
	/*DEBUG*/ return sin(DepthMapValue * 1000);
	/*DEBUG*/ //return DepthMapValue == 1;
	/*DEBUG*/ //return sin(float3(DepthMapValue, Depth, 0) * 10000) * insideProjector;
	/*DEBUG*/ //return (abs(DepthMapValue - Depth) < DepthEpsilon) * insideProjector;
	
	if (ApplyShadows) {
		value -= smoothstep(0, DepthEpsilon, abs(Depth - DepthMapValue));	
	}
	
	//this step applies an inverse square relationship
	//brightness ~= 1/(Distance in z)^2
	float Distance = length(dot(pixel.PosW.xyz - ProjectorPosition, ProjectorLookVector));
	if (ApplyFade)
	{
		value /= Distance * Distance;
	}
	
	//this step applies the normal of the surface relative to the projector's Z direction
	//this is slightly inaccurate, as angled towards the projector would be brighter than angled in z
	//would be great to use a differential method instead
	/*
	if (ApplyNormals)
	{
		//we draw on front and back faces, we presume shadow performs back culling for us
		value *= saturate(abs(normalize(mul(pixel.NormW, tProjector[i])).z));
	}
	*/
	
	value *= brightness[i];
	
	value *= abs(PosProjector.x) < 1.0f && abs(PosProjector.y) < 1.0f;	
	//
	//--
	
	
	
	//check if we have a projector signal
	bool hasImageTexture = false;
	{
		uint width, height;
		uint levelCount;
		TexImage.GetDimensions(0, width, height, levelCount);
		hasImageTexture = width != 1 && height != 1;
	}
	
	float3 image;
	if(hasImageTexture) {
		image = TexImage.Sample(g_SamLinear, DepthMapCd.xy).rgb;
	} else {
		image = float3(0,0,1); //blue = no signal
	}
	
	return value * image;
}

float4 PreviewCoverage(ps_in In): SV_Target
{
	Pixel pixel = (Pixel) 0;
	
	pixel.PosTargetP.x = In.TexCd.x * 2.0f - 1.0f;
	pixel.PosTargetP.y = 1.0f - In.TexCd.y * 2.0f;
	pixel.PosTargetP.z = TexTargetDepth.Sample(g_SamPoint, In.TexCd.xy);
	pixel.PosTargetP.w = 1.0f;
	
	pixel.PosW = mul(pixel.PosTargetP, TargetVPI);
	
	float4 col = 1;
	col.rgb = 0;
	
	for (int i=0; i<ActiveProjectorCount; i++) {
		col.rgb += applyProjector(i, pixel, ActiveProjectorCount);
	}
	
	//kill far plane
	col *= pixel.PosTargetP.z != 1.0f;
	
	return saturate(col);
}
//
//--





technique10 Constant
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PreviewCoverage() ) );
	}
}





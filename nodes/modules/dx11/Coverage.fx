//@author: Elliot Woods
//@help: Display projected area
//@tags: ProjectionSimulation
//@credits:



//--
//Parameters
//--
//
#define MAX_PROJECTOR_COUNT 64

//transforms
float4x4 tW: WORLD;        //the models world matrix
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tP: PROJECTION;   //projection matrix as set via Renderer (EX9)
float4x4 tWVP: WORLDVIEWPROJECTION;
float4x4 tWV: WORLDVIEW;
float4x4 tWIT: WORLDINVERSETRANSPOSE;
float3 ProjectorPosition;
float3 ProjectorLookVector;

//lighting
float3 lDir <string uiname="Light Direction";> = {0, -5, 2}; 
float4 lAmb  <bool color=true; String uiname="Ambient Color";>  = {0.15, 0.15, 0.15, 1};
float4 lDiff <bool color=true;String uiname="Diffuse Color";>  = {0.85, 0.85, 0.85, 1};
float4 lSpec <bool color=true; String uiname="Specular Color";> = {0.35, 0.35, 0.35, 1};
float lPower <String uiname="Power"; float uimin=3.0;> = 25.0;     

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

Texture2DArray<float> TexArrayDepth <string uiname="Depth Maps"; >;
Texture2D TexImage <string uiname="Image";>;
//
//--



//--
//Inter-shader structs
//--
//
struct vs_in {
	float4 PosO : POSITION;
	float4 NormO : NORMAL;
	float4 TexCd : TEXCOORD0;
};

struct Lighting {
	float4 Diffuse: COLOR0;
    float4 Specular: COLOR1;
};

struct vs2ps
{
    float4 Pos : SV_POSITION;
	float4 PosP : TEXCOORD1;
	float4 PosW : TEXCOORD0;
	float4 NormW : TEXCOORD2;
	Lighting lighting;
};
//
//--



//--
//Vertex shader
//--
//
Lighting diffuseLighting(vs_in input) {
    //inverse light direction in view space
    float3 LightDirV = normalize(-mul(float4(lDir,0.0f), tV).xyz);

    //normal in view space
    float3 NormV = normalize(mul(mul(input.NormO.xyz, (float3x3)tWIT),(float3x3)tV).xyz);
	
    //view direction = inverse vertexposition in viewspace
    float4 PosV = mul(input.PosO, tWV);
    float3 ViewDirV = normalize(-PosV.xyz);

    //halfvector
    float3 H = normalize(ViewDirV + LightDirV);

    //compute blinn lighting
    float3 shades = lit(dot(NormV, LightDirV), dot(NormV, H), lPower).xyz;
    
	float4 diff = lDiff * shades.y;
    diff.a = 1;
    float4 spec = lSpec * shades.z;
    spec.a = 1;
	
	Lighting lighting;
	lighting.Diffuse = diff;
	lighting.Specular = spec;
	return lighting;
}

vs2ps VS(vs_in input) {
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;

    //transform position
    Out.Pos = mul(input.PosO, tWVP);

	Out.PosW = mul(input.PosO,tW);
	Out.NormW = normalize(mul(input.NormO, tW));
	
	Out.lighting = diffuseLighting(input);
	
    return Out;
}
//
//--



//--
//Pixel shaders
//--
//

float3 applyProjector(int i, vs2ps input, int projectorCount)
{
	float4 PosProjector = mul(input.PosW, tProjector[i]);
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
	/*DEBUG*/ //return DepthMapValue == 1;
	/*DEBUG*/ //return sin(float3(DepthMapValue, Depth, 0) * 10000) * insideProjector;
	/*DEBUG*/ //return (abs(DepthMapValue - Depth) < DepthEpsilon) * insideProjector;
	
	if (ApplyShadows) {
		value -= smoothstep(0, DepthEpsilon, abs(Depth - DepthMapValue));	
	}
	
	//this step applies an inverse square relationship
	//brightness ~= 1/(Distance in z)^2
	float Distance = length(dot(input.PosW.xyz - ProjectorPosition, ProjectorLookVector));
	if (ApplyFade)
	{
		value /= Distance * Distance;
	}
	
	//this step applies the normal of the surface relative to the projector's Z direction
	//this is slightly inaccurate, as angled towards the projector would be brighter than angled in z
	//would be great to use a differential method instead
	if (ApplyNormals)
	{
		//we draw on front and back faces, we presume shadow performs back culling for us
		value *= saturate(abs(normalize(mul(input.NormW, tProjector[i])).z));
	}
	
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

float4 PreviewCoverage(vs2ps In): SV_Target
{
	//Treat incoming data
	In.PosW /= In.PosW.w;
	
	float4 col = 1;
	col.rgb = 0;
	
	for (int i=0; i<ActiveProjectorCount; i++) {
		col.rgb += applyProjector(i, In, ActiveProjectorCount);
	}
	
	float4 Light = lAmb + In.lighting.Diffuse + In.lighting.Specular;
	
	float4 result = col + Light;
	result.a = saturate(result.a);
	result.a *= Alpha;
	return result;
}

// --------------------------------------------------------------------------------------------------
// TECHNIQUES:
// --------------------------------------------------------------------------------------------------

technique10 TPreviewCoverage
{
    pass P0
    {
		SetGeometryShader(0);
    	SetVertexShader(CompileShader(vs_5_0, VS()));
    	SetPixelShader(CompileShader(ps_5_0, PreviewCoverage()));
    }
}
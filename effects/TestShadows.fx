//@author: Elliot Woods
//@help: Display projected area
//@tags: ProjectionSimulation
//@credits:

// --------------------------------------------------------------------------------------------------
// PARAMETERS:
// --------------------------------------------------------------------------------------------------
#define PROJECTOR_COUNT 4

//transforms
float4x4 tW: WORLD;        //the models world matrix
float4x4 tV: VIEW;         //view matrix as set via Renderer (EX9)
float4x4 tP: PROJECTION;   //projection matrix as set via Renderer (EX9)
float4x4 tWVP: WORLDVIEWPROJECTION;

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
	float4 PosW : TEXCOORD0;
};

// --------------------------------------------------------------------------------------------------
// VERTEXSHADERS
// --------------------------------------------------------------------------------------------------

vs2ps VS(
    float4 Pos : POSITION,
    float4 TexCd : TEXCOORD0)
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;

    //transform position
    Out.Pos = mul(Pos, tWVP);

	Out.PosW = mul(Pos,tW);
	
    return Out;
}

// --------------------------------------------------------------------------------------------------
// PIXELSHADERS:
// --------------------------------------------------------------------------------------------------

float4x4 tProjector[PROJECTOR_COUNT];
float threshold = 0.001;
float brightness = 5;

float4 testProjector(int i, float4 PosW)
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
	
	float4 col;
	col = 1.0f - smoothstep(0, threshold, abs(Depth - DepthMapValue));	
	
	//inverse square brightness
	col /= Depth * Depth;
	col *= brightness;
	
	//test inside
	col.rgb *= abs(PosProjector.x) < 1.0f && abs(PosProjector.y) < 1.0f;
	
	col.a = 1;
	return col;
}

float4 PS(vs2ps In): COLOR
{
	float4 col = 1;
	col.rgb = 0;
	
	for (int i=0; i<PROJECTOR_COUNT; i++)
		col += testProjector(i, In.PosW);
	
    return col;
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
        PixelShader = compile ps_3_0 PS();
    }
}
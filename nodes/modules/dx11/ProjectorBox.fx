//@author: vux
//@help: standard constant shader
//@tags: color
//@credits: 

struct vsInput
{
    float4 posObject : POSITION;
};

struct psInput
{
    float4 posScreen : SV_Position;
	float towardsProjector : COLOR0;
};

cbuffer cbPerDraw : register(b0)
{
	float4x4 tVP : VIEWPROJECTION;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
	float Alpha <float uimin=0.0; float uimax=1.0;> = 1; 
	float4 cAmb <bool color=true;String uiname="Color";> = { 1.0f,1.0f,1.0f,1.0f };
	float4x4 tColor <string uiname="Color Transform";>;
};

psInput VS(vsInput input)
{
	psInput output;
	output.posScreen = mul(input.posObject,mul(tW,tVP));
	
	output.towardsProjector = input.posObject.z < 0.0f;
	return output;
}

float4 PS(psInput input): SV_Target
{
    float4 col = cAmb;
	col = mul(col, tColor);
	col.a *= Alpha;
	col.a *= pow(abs(input.towardsProjector),0.1);
    return col;
}

technique11 ProjectorBox
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}






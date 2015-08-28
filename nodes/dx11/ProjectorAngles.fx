//@author: elliotwoods
//@help: template for standard shaders
//@tags: feathers
//@credits: 

RWStructuredBuffer<float3> emission : BACKBUFFER;
float FrameTime = 0.01f;
float4x4 ProjectorInverse;

[numthreads(64,1,1)]
void CS_1(uint3 dtid : SV_DispatchThreadID)
{
	uint i = dtid.x;
	
}

technique11 Integrate
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS_1() ) );
	}
}

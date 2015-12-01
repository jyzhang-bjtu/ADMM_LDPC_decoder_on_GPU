/*
 * Copyright 1993-2012 NVIDIA Corporation.  All rights reserved.
 *
 * Please refer to the NVIDIA end user license agreement (EULA) associated
 * with this source code for terms and conditions that govern your use of
 * this software. Any use, reproduction, disclosure, or distribution of
 * this software and related documentation outside the terms of the EULA
 * is strictly prohibited.
 *
 */

/* Vector addition: C = A + B.
 *
 * This sample is a very basic sample that implements element by element
 * vector addition. It is the same as the sample illustrating Chapter 3
 * of the programming guide with some additions like error checking.
 *
 */

#include <stdio.h>
#include <cuda_fp16.h>

////////////////////////////////////////////////////////////////////////////////////////////////////////

#define SWAP_des(x,y) sort2_swap_des(&d##x, &d##y, &p##x, &p##y)
__device__ void sort2_swap_des(float* dx, float* dy, int* px, int* py)
{
	const auto Dx = *dx, Dy = (*dy);
	const auto Px = *px, Py = (*py);
	const bool test = (Dx > Dy);
	(*dx) = fmaxf(Dx,Dy);
	(*dy) = fminf(Dx,Dy);
	(*px) = test ? Px : Py;
	(*py) = test ? Py : Px;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////

#define SWAP_asc(x,y) sort2_swap_asc(&d##x, &d##y, &p##x, &p##y)
__device__ void sort2_swap_asc(float* dx, float* dy, int* px, int* py)
{
	const auto Dx = *dx, Dy = (*dy);
	const auto Px = *px, Py = (*py);
	const bool test = (Dx < Dy);
	(*dx) = fminf(Dx,Dy);
	(*dy) = fmaxf(Dx,Dy);
	(*px) = test ? Px : Py;
	(*py) = test ? Py : Px;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////

__device__ void sort6_swap(float d[6], int p[6])
{
	#define SWAP SWAP_des
    auto p0 = 0;    auto p1 = 1;    auto p2 = 2;
    auto p3 = 3;    auto p4 = 4;    auto p5 = 5;
    float d0 = d[0]; float d1 = d[1]; float d2 = d[2];
    float d3 = d[3]; float d4 = d[4]; float d5 = d[5];
    SWAP(1, 2); SWAP(0, 2); SWAP(0, 1); SWAP(4, 5);
    SWAP(3, 5); SWAP(3, 4); SWAP(0, 3); SWAP(1, 4);
    SWAP(2, 5); SWAP(2, 4); SWAP(1, 3); SWAP(2, 3);
    d[0] = d0; d[1] = d1; d[2] = d2;
    d[3] = d3; d[4] = d4; d[5] = d5;
    p[0] = p0; p[1] = p1; p[2] = p2;
    p[3] = p3; p[4] = p4; p[5] = p5;
	#undef SWAP
}

////////////////////////////////////////////////////////////////////////////////////////////////////////

__device__ void sort6_swap(float illr[6], float rllr[6], int ipos[6], int rpos[6])
{
	#define SWAP SWAP_asc
    auto  p0 = ipos[0]; auto  p1 = ipos[1]; auto  p2 = ipos[2];
    auto  p3 = ipos[3]; auto  p4 = ipos[4]; auto  p5 = ipos[5];
    float d0 = illr[0]; float d1 = illr[1]; float d2 = illr[2];
    float d3 = illr[3]; float d4 = illr[4]; float d5 = illr[5];
    SWAP(1, 2); SWAP(0, 2); SWAP(0, 1); SWAP(4, 5);
    SWAP(3, 5); SWAP(3, 4); SWAP(0, 3); SWAP(1, 4);
    SWAP(2, 5); SWAP(2, 4); SWAP(1, 3); SWAP(2, 3);
    rllr[0] = d0; rllr[1] = d1; rllr[2] = d2;
    rllr[3] = d3; rllr[4] = d4; rllr[5] = d5;
    rpos[0] = p0; rpos[1] = p1; rpos[2] = p2;
    rpos[3] = p3; rpos[4] = p4; rpos[5] = p5;
	#undef SWAP
}

////////////////////////////////////////////////////////////////////////////////////////////////////////

__device__ void sort6_rank_order_reg(float llr[ ], int pos[ ])
{
	const float x0 = llr[0]; const float x1 = llr[1]; const float x2 = llr[2];
    const float x3 = llr[3]; const float x4 = llr[4]; const float x5 = llr[5];
    const int   o0 = (x0< x1) + (x0< x2) + (x0< x3) + (x0< x4) + (x0<x5);
    const int   o1 = (x1<=x0) + (x1< x2) + (x1< x3) + (x1< x4) + (x1<x5);
    const int   o2 = (x2<=x0) + (x2<=x1) + (x2< x3) + (x2< x4) + (x2<x5);
    const int   o3 = (x3<=x0) + (x3<=x1) + (x3<=x2) + (x3< x4) + (x3<x5);
    const int   o4 = (x4<=x0) + (x4<=x1) + (x4<=x2) + (x4<=x3) + (x4<x5);
    const int   o5 = 15 - (o0 + o1 + o2 + o3 + o4);
    llr[o0]=x0; llr[o1]=x1; llr[o2]=x2; llr[o3]=x3; llr[o4]=x4; llr[o5]=x5;
    pos[o0]= 0; pos[o1]= 1; pos[o2]= 2; pos[o3]= 3; pos[o4]= 4; pos[o5]= 5;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////

__device__ void sort6_rank_order_reg_modif(float illr[ ], float rllr[ ], int ipos[ ], int rpos[ ])
{
	const float x0 = illr[0], x1 = illr[1], x2 = illr[2];
	const float x3 = illr[3], x4 = illr[4], x5 = illr[5];
	const int   o0 = (x0> x1) + (x0> x2) + (x0> x3) + (x0> x4) + (x0>x5);
	const int   o1 = (x1>=x0) + (x1> x2) + (x1> x3) + (x1> x4) + (x1>x5);
	const int   o2 = (x2>=x0) + (x2>=x1) + (x2> x3) + (x2> x4) + (x2>x5);
	const int   o3 = (x3>=x0) + (x3>=x1) + (x3>=x2) + (x3> x4) + (x3>x5);
	const int   o4 = (x4>=x0) + (x4>=x1) + (x4>=x2) + (x4>=x3) + (x4>x5);
	const int   o5 = 15 - (o0 + o1 + o2 + o3 + o4);
	rllr[o0]=x0;      rllr[o1]=x1;      rllr[o2]=x2;      rllr[o3]=x3;      rllr[o4]=x4;      rllr[o5]=x5;
	rpos[o0]=ipos[0]; rpos[o1]=ipos[1]; rpos[o2]=ipos[2]; rpos[o3]=ipos[3]; rpos[o4]=ipos[4]; rpos[o5]=ipos[5];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////

__shared__ int sdata[128*6]; // > 512

////////////////////////////////////////////////////////////////////////////////////////////////////////

__device__ void projection_deg6(float llr[], float results[])
{
	const int length = 6;
	bool finished    = false;


	/////////////////////////////////////////////////////////////////////////////////////////////////////////
	int AllZero = (llr[0] <= 0);
	int AllOne  = (llr[0] <= 0);

	#pragma unroll
	for(int i = 1; i < length; i++)
	{
		AllZero = AllZero + (llr[i] <= 0);
		AllOne  = AllOne  + (llr[i] <= 0);
	}

	/////////////////////////////////////////////////////////////////////////////////////////////////////////

	finished = (AllZero == length);

    __syncthreads( );

    /////////////////////////////////////////////////////////////////////////////////////////////////////////

    bool test = (finished == false) && (AllOne == length) && ((length&0x01) == 0);
	#pragma unroll
	for(int i = 0; i < length; i++)
		results[i] = (test == true) ? 1.0f : 0.0f;
	finished = finished | test;

    __syncthreads( );

	/////////////////////////////////////////////////////////////////////////////////////////////////////////
	float constituent = 0;
	float llrClip[6];
	int   zSorti[6] = {0, 1, 2, 3, 4, 5};

	sort6_swap(llr, zSorti);

	#pragma unroll
	for(int i = 0; i < length; i++)// project on the [0,1]^d cube
	{
		const float vMax = fminf(fmaxf(llr[i], 0.0f), 1.0f);
		llrClip[i]       = vMax;
		constituent     += vMax;
	}

	int r = (int)constituent;
    r     = r - (r & 0x01);

	float sum_Clip = llrClip[0];
	for(int i = 1; i < length; i++)
	{
		sum_Clip += (i <  r+1) ? llrClip[i] : -llrClip[i];
	}

	// affectation conditionnelle des resultats
	bool valid = ( finished == false ) && (sum_Clip <= r);
	#pragma unroll
	for(int i = 0; i < length; i++)
		results[zSorti[i]] = (valid == true) ? llrClip[i] : results[zSorti[i]];
	finished = finished || valid;

	/////////////////////////////////////////////////////////////////////////////////////////////////////////

    __syncthreads();

	/////////////////////////////////////////////////////////////////////////////////////////////////////////

    if( finished == false )
	{
		float beta     = 0;
		float beta_max = (r + 2 <= length) ? (llr[r] - llr[r+1])/2 : llr[r]; // assign beta_max

	    // sorting zBetaRep
		int   zSorti_m[6] = {0, 1, 2, 3, 4, 5};
		float T_in[6];
	    float T_out[6];
	    int   order_out[6];

		#pragma unroll
		for(int i = 0; i < length; i++)
	        T_in[i] = (i < r+1) ? llr[i] - 1.0f : -llr[i];

		sort6_rank_order_reg_modif (T_in, T_out, zSorti_m, order_out);

		int clip_idx  = -1;
		int zero_idx  =  0;
		int idx_start =  0;
		int idx_end   = -1;

		#pragma unroll 6
		for(int i = 0; i < length; i++)
		{
			clip_idx  += (llr[i]   >     1.0f);
			zero_idx  += (llr[i]   >= -1e-10f);
			idx_start += (T_out[i] <   1e-10f);
			idx_end   += (T_out[i] < beta_max);
		}

		float active_sum = 0;

		#pragma unroll 6
		for(int i = 0;i < length; i++)
		{
			active_sum += (i > clip_idx && i <= r      ) ? llr[i] : 0.0f;
			active_sum -= (i > r        && i < zero_idx) ? llr[i] : 0.0f;
		}

		float total_sum           = active_sum + clip_idx + 1;
		int previous_clip_idx     = clip_idx;
		int previous_zero_idx     = zero_idx;
		float previous_active_sum = active_sum;
		bool change_pre           = false;

		for(int i = idx_start; i <= idx_end; i++)// pour tous les beta entre 0 et beta_max
		{
			if(change_pre)
			{
				// save previous things
				previous_clip_idx   = clip_idx;
				previous_zero_idx   = zero_idx;
				previous_active_sum = active_sum;
			}
			change_pre = false;

			beta = T_out[i];
			clip_idx   -= (order_out[i] <= r);
			zero_idx   += (order_out[i] >  r);
			active_sum += (order_out[i] <= r) ? llr[order_out[i]] : -llr[order_out[i]];

			if (i < length - 1)
			{
				if (beta != T_out[i+1])
				{
					total_sum  = (clip_idx + 1) + active_sum - beta * (zero_idx - clip_idx - 1);
					change_pre = true;
					if(total_sum < r)
						break;
				}

			}
			else if (i == length - 1)
			{
				total_sum  = (clip_idx + 1)  + active_sum - beta * (zero_idx - clip_idx - 1);
				change_pre = true;
			}
		}

		clip_idx   = (total_sum > r) ? clip_idx   : previous_clip_idx;
		active_sum = (total_sum > r) ? active_sum : previous_active_sum;
		zero_idx   = (total_sum > r) ? zero_idx   : previous_zero_idx;
		beta       = -(r - clip_idx - 1 - active_sum)/(zero_idx - clip_idx - 1);

		#pragma unroll 6
		for(int i = 0; i < length; i++)
		{
			const float vA = llr[i];
			const float vD = (i <= r) ? vA - beta : vA + beta;
			results[zSorti[i]] = fminf(fmaxf(vD, 0.0f), 1.0f);
		}
	}

	/////////////////////////////////////////////////////////////////////////////////////////////////////////

    __syncthreads();

	/////////////////////////////////////////////////////////////////////////////////////////////////////////
}



/////////////////////////////////////////////////////////////////////////////////////////////////////////



#define FLOAT2

__global__ void ADMM_InitArrays(float* LZr, int N)
{
//    t.x = 0.00f;
//    t.y = 0.50f;
//	__half  t1 = __float2half (  );
//	__half  t2 = __float2half ( 0.00f );
//  __half2 t3 =__halves2half2 ( t1, t2 );
//  float2 	__half22float2 ( const __half2 a )
    // __high2float
    // __low2float
    const int i = blockDim.x * blockIdx.x + threadIdx.x;
    if (i < N)
    {
#ifdef FLOAT2
    	float2* ptr = reinterpret_cast<float2*>(LZr);
    	ptr[i]      = make_float2(0.00f, 0.50f);
#else
        Lambda  [i] = 0.00f;
        zReplica[i] = 0.50f;
#endif
    }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////



__global__ void ADMM_ScaleLLRs(float* LLRs, int N)
{
    const int i = blockDim.x * blockIdx.x + threadIdx.x;
    if (i < N)
    {
    	const float mu = 3.0f;
    	LLRs[i] = LLRs[i] / mu;
    }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////


__global__ void ADMM_VN_kernel_deg3(
	const float* _LogLikelihoodRatio, float* OutputFromDecoder, float* LZr, const unsigned int *t_row, int N)
{
    const int i             = blockDim.x * blockIdx.x + threadIdx.x;
	constexpr float mu      = 3.0f;
	constexpr float  alpha  = 0.8;
	constexpr float _amu_   = alpha / mu;
	constexpr float _2_amu_ = _amu_+ _amu_;
    constexpr float factor  = 1.0f / (3.0f - _2_amu_);
    const int   degVn       = 3;

    if (i < N){
        float temp                  = -_LogLikelihoodRatio[i]; // <= OK
        const int frame_offset      = (i%2640);
        const int num_trame         = (i/2640);
        const ushort4  off          = reinterpret_cast<ushort4*>((unsigned int *)t_row)[ frame_offset ];
        const unsigned short tab[4] = {off.x, off.y, off.z, off.w};

        #pragma unroll 3
        for(int k = 0; k < degVn; k++)
        {
//        	const int pos = 3 * i + k;
        	const int off = tab[k];//t_row[ pos ];
#ifdef FLOAT2
        	const float2* ptr = reinterpret_cast<float2*>(LZr);
        	const float2 data = ptr[ (7920 * num_trame) + off ];
            temp       += (data.y + data.x);
#else
            temp       += ( zReplica[ off ] + Lambda[ off ] );
#endif
        }
        const float xx       = (temp  -  _amu_) * factor;
        OutputFromDecoder[i] = fmaxf(fminf(xx, 1.0f), 0.0f);
    }
}



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



__global__ void ADMM_CN_kernel_deg6(
	const float *OutputFromDecoder, float *LZr, const unsigned int *t_col1, int *cn_synrome, int N)
{
    const int i = blockDim.x * blockIdx.x + threadIdx.x; // NUMERO DU CHECK NODE A CALCULER
	const float rho      = 1.9f;
	const float un_m_rho = 1.0f - rho;
	const int   degCn    = 6;
    float v_proj[6], ztemp [6];

    if (i < N){
        const int frame_offset = i%1320;
        const int trame_start  = 2640 * (i/1320);

    	int syndrom = 0;
        #pragma unroll
        for(int k = 0; k < degCn; k++)
        {
            const int ind      = degCn * i + k;
            const int offset   = t_col1[ degCn * frame_offset + k ];
            const float xpred  = OutputFromDecoder[ trame_start + offset ];
            syndrom           += (xpred > 0.5);
            reinterpret_cast<float*>(sdata)[threadIdx.x + 128 * k] = xpred;
#ifdef FLOAT2
        	const float2* ptr = reinterpret_cast<float2*>(LZr);
        	const float2 data = ptr[ ind ];
            v_proj[k]         = (rho * xpred) + (un_m_rho * data.y) - data.x;
#else
            v_proj[k]         = (rho * xpred) + (un_m_rho * zReplica[ind]) - Lambda[ind];
#endif
        }
        cn_synrome[i] = syndrom & 0x01;

        projection_deg6(v_proj, ztemp);

        #pragma unroll
        for(int k = 0; k < degCn; k++)
        {
            const int ind     = degCn * i + k;
            const float xpred = reinterpret_cast<float*>(sdata)[threadIdx.x + 128 * k];
#ifdef FLOAT2
        	float2* ptr = reinterpret_cast<float2*>(LZr);
            float2 data = ptr[ ind ];
            float x     = data.x + (rho * (ztemp[k] - xpred) + un_m_rho * (ztemp[k] - data.y));
            ptr[ ind ]  = make_float2(x, ztemp[k]);
#else
            Lambda[ind]    = Lambda[ind] + (rho * (ztemp[k] - xpred) + un_m_rho * (ztemp[k] - zReplica[ind]));
            zReplica[ind]  = ztemp[k];
#endif
        }
    }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


__global__ void ADMM_HardDecision(
		float* OutputFromDecoder, int* HardDecision, int N
		)
{
    int i = blockDim.x * blockIdx.x + threadIdx.x;
    if (i < N)
    {
        HardDecision[i] = floorf(OutputFromDecoder[i] + 0.50f);
    }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


__global__ void reduce(int *g_idata, unsigned int n)
{
    // perform first level of reduction,
    // reading from global memory, writing to shared memory
    unsigned int tid      =                               threadIdx.x;
    unsigned int i        = blockIdx.x * blockDim.x * 2 + threadIdx.x;
    unsigned int gridSize = blockDim.x * 2 * gridDim.x;

    int mySum = 0;

    // we reduce multiple elements per thread.  The number is determined by the
    // number of active thread blocks (via gridDim).  More blocks will result
    // in a larger gridSize and therefore fewer elements per thread
    while (i < n)
    {
        mySum += g_idata[i];
        // ensure we don't read out of bounds
        if (i + blockDim.x < n)
            mySum += g_idata[i+blockDim.x];
        i += gridSize;
    }

    // each thread puts its local sum into shared memory
    sdata[tid] = mySum;
    __syncthreads();

    // do reduction in shared mem
    if (blockDim.x >= 1024) { if (tid < 512) { sdata[tid] = mySum = mySum + sdata[tid + 512]; } __syncthreads(); }
    if (blockDim.x >=  512) { if (tid < 256) { sdata[tid] = mySum = mySum + sdata[tid + 256]; } __syncthreads(); }
    if (blockDim.x >=  256) { if (tid < 128) { sdata[tid] = mySum = mySum + sdata[tid + 128]; } __syncthreads(); }
    if (blockDim.x >=  128) { if (tid <  64) { sdata[tid] = mySum = mySum + sdata[tid +  64]; } __syncthreads(); }

    // avoid bank conflict
    if (tid < 32)
    {
        // now that we are using warp-synchronous programming (below)
        // we need to declare our shared memory volatile so that the compiler
        // doesn't reorder stores to it and induce incorrect behavior.
        volatile int* smem = sdata;
        if (blockDim.x >=  64) { smem[tid] = mySum = mySum + smem[tid + 32]; }
        if (blockDim.x >=  32) { smem[tid] = mySum = mySum + smem[tid + 16]; }
        if (blockDim.x >=  16) { smem[tid] = mySum = mySum + smem[tid +  8]; }
        if (blockDim.x >=   8) { smem[tid] = mySum = mySum + smem[tid +  4]; }
        if (blockDim.x >=   4) { smem[tid] = mySum = mySum + smem[tid +  2]; }
        if (blockDim.x >=   2) { smem[tid] = mySum = mySum + smem[tid +  1]; }
    }

    // write result for this block to global mem
    if (tid == 0)
    	g_idata[blockIdx.x] = sdata[0];
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

__global__ void ADMM_InitArrays_16b(float* LZr, int N)
{
    const int i = blockDim.x * blockIdx.x + threadIdx.x;
    if (i < N)
    {
    	__half   t1  = __float2half  ( 0.00f  ); // Lambda
    	__half   t2  = __float2half  ( 0.50f  ); // zReplica
    	__half2* ptr = reinterpret_cast<__half2*>(LZr);
    	ptr[i]       = __halves2half2( t1, t2 );
    }
}

__global__ void ADMM_VN_kernel_deg3_16b(
	const float* _LogLikelihoodRatio, float* OutputFromDecoder, float* LZr, const unsigned int *t_row, int N)
{
    const int i             = blockDim.x * blockIdx.x + threadIdx.x;
	constexpr float mu      = 3.0f;
	constexpr float  alpha  = 0.8;
	constexpr float _amu_   = alpha / mu;
	constexpr float _2_amu_ = _amu_+ _amu_;
    constexpr float factor  = 1.0f / (3.0f - _2_amu_);
    const int   degVn       = 3;
	const __half2* ptr      = reinterpret_cast<__half2*>(LZr);

    if (i < N){
        float temp                  = -_LogLikelihoodRatio[i];
        const int frame_offset      = (i%2640);
        const int num_trame         = (i/2640);
        const ushort4  off          = reinterpret_cast<ushort4*>((unsigned int *)t_row)[ frame_offset ];
        const unsigned short tab[4] = {off.x, off.y, off.z, off.w};

        #pragma unroll 3
        for(int k = 0; k < degVn; k++)
        {
        	const int off = tab[k];
        	const __half2 data = ptr[ (7920 * num_trame) + off ];
            temp              += ( __high2float(data) + __low2float(data) );
        }
        const float xx       = (temp  -  _amu_) * factor;
        OutputFromDecoder[i] = fmaxf(fminf(xx, 1.0f), 0.0f);
    }
}

__global__ void ADMM_CN_kernel_deg6_16b(
	const float *OutputFromDecoder, float *Lzr, const unsigned int *t_col1, int *cn_synrome, int N)
{
    const int i = blockDim.x * blockIdx.x + threadIdx.x; // NUMERO DU CHECK NODE A CALCULER
    constexpr float rho      = 1.9f;
    constexpr float un_m_rho = 1.0f - rho;
    constexpr int   degCn    = 6;
    float v_proj[6];
    float ztemp [6];
    __half2* ptr = reinterpret_cast<__half2*>(Lzr);
    float*   PTR = reinterpret_cast<float*>(sdata);

    if (i < N){
        const int frame_offset = i%1320;
        const int trame_start  = 2640 * (i/1320);

    	int syndrom = 0;

    	#pragma unroll 6
        for(int k = 0; k < degCn; k++)
        {
            const int ind      = degCn * i + k;
            const int offset   = t_col1[ degCn * frame_offset + k ];
            const float xpred  = OutputFromDecoder[ trame_start + offset ];
            syndrom           += (xpred > 0.5);

            PTR[threadIdx.x + 128 * k] = xpred;
        	const __half2 data         = ptr[ ind ];
        	v_proj[k]                  = (rho * xpred) + (un_m_rho * __high2float(data)) - __low2float(data);
        }
        cn_synrome[i] = syndrom & 0x01;

        projection_deg6(v_proj, ztemp);

        #pragma unroll 6
        for(int k = 0; k < degCn; k++)
        {
            const int ind      = degCn * i + k;
            const float  xpred = PTR[threadIdx.x + 128 * k];
            const __half2 data = ptr[ ind ];
            float x            = __low2float(data) + (rho * (ztemp[k] - xpred) + un_m_rho * (ztemp[k] - __high2float(data)));
            ptr[ ind ]         = __halves2half2( __float2half(x), __float2half(ztemp[k]) );
        }
    }
}

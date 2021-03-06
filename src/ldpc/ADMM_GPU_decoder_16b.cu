/*
 *  ldcp_decoder.h
 *  ldpc3
 *
 *  Created by legal on 02/04/11.
 *  Copyright 2011 ENSEIRB. All rights reserved.
 *
 */

/*----------------------------------------------------------------------------*/

#include "ADMM_GPU_decoder_16b.h"

#include "../gpu/ADMM_GPU_16b.h"

#if 0
	#include "../codes/Constantes_4000x2000.h"
#else
	#include "./admm/admm_2640x1320.h"
#endif


ADMM_GPU_decoder_16b::ADMM_GPU_decoder_16b( int _frames )
{
    cudaError_t Status;

    frames         = _frames;
    VNs_per_frame  = NOEUD;
    CNs_per_frame  = PARITE;
    MSGs_per_frame = MESSAGES;
    VNs_per_load   = frames *  VNs_per_frame;
    CNs_per_load   = frames *  CNs_per_frame;
    MSGs_per_load  = frames * MSGs_per_frame;

    // LLRs entrant dans le decodeur
    CUDA_MALLOC_HOST  (&h_iLLR, VNs_per_load);
    CUDA_MALLOC_DEVICE(&d_iLLR, VNs_per_load);

    // LLRs interne au decodeur
    CUDA_MALLOC_DEVICE(&d_oLLR, VNs_per_load);

    // LLRs (decision dure) sortant du le decodeur
    CUDA_MALLOC_HOST  (&h_hDecision, VNs_per_load);
    CUDA_MALLOC_DEVICE(&d_hDecision, VNs_per_load);

    // Le tableau fournissant le degree des noeuds VNs
    CUDA_MALLOC_DEVICE(&d_degVNs, VNs_per_frame);
//    Status = cudaMemcpy(d_degVNs, t_degVN, nb_Node * sizeof(unsigned int), cudaMemcpyHostToDevice);
//    ERROR_CHECK(Status, (char*)__FILE__, __LINE__);

    // Le tableau fournissant le degree des noeuds CNs
    CUDA_MALLOC_DEVICE(&d_degCNs, CNs_per_frame);
//    Status = cudaMemcpy(d_degCNs, t_degCN, nb_Check * sizeof(unsigned int), cudaMemcpyHostToDevice);
//    ERROR_CHECK(Status, (char*)__FILE__, __LINE__);

#if 0
    CUDA_MALLOC_DEVICE(&d_t_row, nb_Msg);
    Status = cudaMemcpy(d_t_row, t_row, nb_Msg * sizeof(unsigned int), cudaMemcpyHostToDevice);
    ERROR_CHECK(Status, (char*)__FILE__, __LINE__);
#else
    CUDA_MALLOC_DEVICE(&d_t_row, MSGs_per_frame);
    Status = cudaMemcpy(d_t_row, t_row_pad_4, MSGs_per_frame * sizeof(unsigned int), cudaMemcpyHostToDevice);
    ERROR_CHECK(Status, (char*)__FILE__, __LINE__);
#endif

#if 1
    CUDA_MALLOC_DEVICE(&d_t_col, MSGs_per_frame);
    unsigned short* t_col_m = new unsigned short[MSGs_per_frame];
    for(int i=0; i<MSGs_per_frame; i++)
    	 t_col_m[i] = t_col[i];

    Status = cudaMemcpy(d_t_col, (int*)t_col_m, MSGs_per_frame * sizeof(unsigned int), cudaMemcpyHostToDevice);
    ERROR_CHECK(Status, (char*)__FILE__, __LINE__);
    delete t_col_m;
#else
    CUDA_MALLOC_DEVICE(&d_t_col, MSGs_per_frame);
    Status = cudaMemcpy(d_t_col, (int*)t_col, MSGs_per_frame * sizeof(unsigned int), cudaMemcpyHostToDevice);
    ERROR_CHECK(Status, (char*)__FILE__, __LINE__);
#endif
    // Espace memoire pour l'échange de messages dans le decodeur
    CUDA_MALLOC_DEVICE(&LZr, 2 * MSGs_per_load);
//    exit( 0 );
}


ADMM_GPU_decoder_16b::~ADMM_GPU_decoder_16b()
{
	cudaError_t Status;
	Status = cudaFreeHost(h_iLLR);		ERROR_CHECK(Status, (char*)__FILE__, __LINE__);
	Status = cudaFree(d_iLLR);			ERROR_CHECK(Status, (char*)__FILE__, __LINE__);
	Status = cudaFree(d_oLLR);			ERROR_CHECK(Status, (char*)__FILE__, __LINE__);

	Status = cudaFreeHost(h_hDecision);	ERROR_CHECK(Status, (char*)__FILE__, __LINE__);
	Status = cudaFree(d_hDecision);		ERROR_CHECK(Status, (char*)__FILE__, __LINE__);

	Status = cudaFree(d_degCNs);		ERROR_CHECK(Status, (char*)__FILE__, __LINE__);
	Status = cudaFree(d_degVNs);		ERROR_CHECK(Status, (char*)__FILE__, __LINE__);

	Status = cudaFree(d_t_row);			ERROR_CHECK(Status, (char*)__FILE__, __LINE__);
	Status = cudaFree(d_t_col);			ERROR_CHECK(Status, (char*)__FILE__, __LINE__);

	Status = cudaFree(LZr);				ERROR_CHECK(Status, (char*)__FILE__, __LINE__);
}

void ADMM_GPU_decoder_16b::decode(float* llrs, int* bits, int nb_iters)
{
//	#define CHECK_ERRORS
    cudaError_t Status;
	int threadsPerBlock     = 128;
    int blocksPerGridNode   = (VNs_per_load  + threadsPerBlock - 1) / threadsPerBlock;
    int blocksPerGridCheck  = (CNs_per_load  + threadsPerBlock - 1) / threadsPerBlock;
    int blocksPerGridMsgs   = (MSGs_per_load + threadsPerBlock - 1) / threadsPerBlock;

    /* On copie les donnees d'entree du decodeur */
    cudaMemcpyAsync(d_iLLR, llrs, VNs_per_load * sizeof(float), cudaMemcpyHostToDevice);

    /* INITIALISATION DU DECODEUR LDPC SUR GPU */
    ADMM_InitArrays_16b<<<blocksPerGridMsgs, threadsPerBlock>>>(LZr, MSGs_per_load);
	#ifdef CHECK_ERRORS
    	ERROR_CHECK(cudaGetLastError( ), __FILE__, __LINE__);
	#endif

    ADMM_ScaleLLRs<<<blocksPerGridNode, threadsPerBlock>>>(d_iLLR, VNs_per_load);
	#ifdef CHECK_ERRORS
    	ERROR_CHECK(cudaGetLastError( ), __FILE__, __LINE__);
	#endif

    // LANCEMENT DU PROCESSUS DE DECODAGE SUR n ITERATIONS
    for(int k = 0; k < 200; k++)
    {
    	ADMM_VN_kernel_deg3_16b<<<blocksPerGridNode,  threadsPerBlock>>>
    			(d_iLLR, d_oLLR, LZr, d_t_row, VNs_per_load);
		#ifdef CHECK_ERRORS
        	ERROR_CHECK(cudaGetLastError( ), __FILE__, __LINE__);
		#endif

        ADMM_CN_kernel_deg6_16b<<<blocksPerGridCheck, threadsPerBlock>>>
        		(d_oLLR, LZr, d_t_col, d_hDecision, CNs_per_load);
		#ifdef CHECK_ERRORS
        	ERROR_CHECK(cudaGetLastError( ), __FILE__, __LINE__);
		#endif

        // GESTION DU CRITERE D'ARRET DES CODEWORDS
        if( (k > 10) && (k%2 == 0) )
        {
            reduce<<<blocksPerGridCheck, threadsPerBlock>>>(d_hDecision, CNs_per_load);
			#ifdef CHECK_ERRORS
				ERROR_CHECK(cudaGetLastError( ), __FILE__, __LINE__);
			#endif

            Status = cudaMemcpy(h_hDecision, d_hDecision, blocksPerGridCheck * sizeof(int), cudaMemcpyDeviceToHost);
			#ifdef CHECK_ERRORS
				ERROR_CHECK(Status, __FILE__, __LINE__);
			#endif

            int sum = 0;
            for(int p=0; p<blocksPerGridCheck; p++)
            	sum += h_hDecision[p];
            if( sum == 0 ) break;
        }
    }

    // LANCEMENT DU PROCESSUS DE DECODAGE SUR n ITERATIONS
    ADMM_HardDecision<<<blocksPerGridNode, threadsPerBlock>>>(d_oLLR, d_hDecision, VNs_per_load);
	#ifdef CHECK_ERRORS
		ERROR_CHECK(cudaGetLastError(), __FILE__, __LINE__);
	#endif

    // LANCEMENT DU PROCESSUS DE DECODAGE SUR n ITERATIONS
    Status = cudaMemcpy(bits, d_hDecision, VNs_per_load * sizeof(int), cudaMemcpyDeviceToHost);
	#ifdef CHECK_ERRORS
		ERROR_CHECK(Status, __FILE__, __LINE__);
	#endif
}


/*---------------------------------------------------------------------------*/
/*!
 * \file   env_cuda_kernels.h
 * \author Wayne Joubert
 * \date   Tue Apr 22 17:03:08 EDT 2014
 * \brief  Environment settings for cuda, code for comp. kernel.
 * \note   Copyright (C) 2014 Oak Ridge National Laboratory, UT-Battelle, LLC.
 */
/*---------------------------------------------------------------------------*/

#ifndef _env_cuda_kernels_h_
#define _env_cuda_kernels_h_

#if defined USE_CUDA
#include "cuda.h"
#elif defined USE_HIP
#include "hip/hip_runtime.h"
#include "hip/hip_runtime_api.h"
#endif

#include "types_kernels.h"
#include "env_assert_kernels.h"

#ifdef USE_EXTERN_C
extern "C"
{
#endif

/*===========================================================================*/
/*---Enums---*/

#ifndef __MIC__
enum{ VEC_LEN = 32 };
#endif

/*===========================================================================*/
/*---Pointer to device shared memory---*/

#if defined __CUDA_ARCH__ || defined __HIP_DEVICE_COMPILE__
//#if defined __CUDA_ARCH__
__shared__ extern char cuda_shared_memory[];
#endif

TARGET_HD static char* Env_cuda_shared_memory()
{
#if defined __CUDA_ARCH__ || defined __HIP_DEVICE_COMPILE__
//#if defined __CUDA_ARCH__
  return cuda_shared_memory;
#elif defined __HIP_DEVICE_COMPILE__
  HIP_DYNAMIC_SHARED(char, cuda_shared_memory);
  return cuda_shared_memory;
#else
  return (char*)0;
#endif
}

/*===========================================================================*/
/*---Device thread management---*/

TARGET_HD static int Env_cuda_threadblock( int axis )
{
  Assert( axis >= 0 && axis < 3 );

#if defined __CUDA_ARCH__
  return axis==0 ? blockIdx.x :
         axis==1 ? blockIdx.y :
                   blockIdx.z;
#elif defined __HIP_DEVICE_COMPILE__
  return axis==0 ? hipBlockIdx_x :
         axis==1 ? hipBlockIdx_y :
                   hipBlockIdx_z;
#else
  return 0;
#endif
}

/*---------------------------------------------------------------------------*/

TARGET_HD static int Env_cuda_thread_in_threadblock( int axis )
{
  Assert( axis >= 0 && axis < 3 );

#if defined __CUDA_ARCH__
  return axis==0 ? threadIdx.x :
         axis==1 ? threadIdx.y :
                   threadIdx.z;
#elif defined __HIP_DEVICE_COMPILE__
  return axis==0 ? hipThreadIdx_x :
         axis==1 ? hipThreadIdx_y :
                   hipThreadIdx_z;
#else
  return 0;
#endif
}

/*---------------------------------------------------------------------------*/

TARGET_HD static void Env_cuda_sync_threadblock()
{
#if defined __CUDA_ARCH__ || defined __HIP_DEVICE_COMPILE__
  __syncthreads();
/*
  __threadfence_block();
*/
#endif
}

/*===========================================================================*/

#ifdef USE_EXTERN_C
} /*---extern "C"---*/
#endif

#endif /*---_env_cuda_kernels_h_---*/

/*---------------------------------------------------------------------------*/

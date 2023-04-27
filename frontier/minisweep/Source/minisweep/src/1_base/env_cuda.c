/*---------------------------------------------------------------------------*/
/*!
 * \file   env_cuda.c
 * \author Wayne Joubert
 * \date   Tue Apr 22 17:03:08 EDT 2014
 * \brief  Environment settings for cuda.
 * \note   Copyright (C) 2014 Oak Ridge National Laboratory, UT-Battelle, LLC.
 */
/*---------------------------------------------------------------------------*/

#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>

#include "types.h"
#include "env_types.h"
#include "env_assert.h"
#include "arguments.h"
#include "env_cuda.h"

#ifdef USE_EXTERN_C
extern "C"
{
#endif


/*===========================================================================*/
/*---Error handling---*/

Bool_t Env_cuda_last_call_succeeded()
{
  Bool_t result = Bool_true;

#if defined USE_CUDA
  /*---NOTE: this read of the last error is a destructive read---*/
  cudaError_t error = cudaGetLastError();

  if ( error != cudaSuccess )
  {
      result = Bool_false;
      printf( "CUDA error detected: %s\n", cudaGetErrorString( error ) );
  }
#elif defined USE_HIP
  /*---NOTE: this read of the last error is a destructive read---*/
  hipError_t error = hipGetLastError();

  if ( error != hipSuccess )
  {
      result = Bool_false;
      printf( "HIP error detected: %s\n", hipGetErrorString( error ) );
  }
#endif

  return result;
}

/*===========================================================================*/
/*---Initialize CUDA---*/

void Env_cuda_initialize_( Env *env, int argc, char** argv )
{
#if defined USE_CUDA
  cudaStreamCreate( & env->stream_send_block_ );
  Assert( Env_cuda_last_call_succeeded() );

  cudaStreamCreate( & env->stream_recv_block_ );
  Assert( Env_cuda_last_call_succeeded() );

  cudaStreamCreate( & env->stream_kernel_faces_ );
  Assert( Env_cuda_last_call_succeeded() );
#elif defined USE_HIP
  hipStreamCreate( & env->stream_send_block_ );
  Assert( Env_cuda_last_call_succeeded() );

  hipStreamCreate( & env->stream_recv_block_ );
  Assert( Env_cuda_last_call_succeeded() );

  hipStreamCreate( & env->stream_kernel_faces_ );
  Assert( Env_cuda_last_call_succeeded() );
#endif
}

/*===========================================================================*/
/*---Finalize CUDA---*/

void Env_cuda_finalize_( Env* env )
{
#if defined USE_CUDA
  cudaStreamDestroy( env->stream_send_block_ );
  Assert( Env_cuda_last_call_succeeded() );

  cudaStreamDestroy( env->stream_recv_block_ );
  Assert( Env_cuda_last_call_succeeded() );

  cudaStreamDestroy( env->stream_kernel_faces_ );
  Assert( Env_cuda_last_call_succeeded() );
#elif defined USE_HIP
  hipStreamDestroy( env->stream_send_block_ );
  Assert( Env_cuda_last_call_succeeded() );

  hipStreamDestroy( env->stream_recv_block_ );
  Assert( Env_cuda_last_call_succeeded() );

  hipStreamDestroy( env->stream_kernel_faces_ );
  Assert( Env_cuda_last_call_succeeded() );
#endif
}

/*===========================================================================*/
/*---Set values from args---*/

void Env_cuda_set_values_( Env *env, Arguments* args )
{
#if defined USE_CUDA || defined USE_HIP
  env->is_using_device_ = Arguments_consume_int_or_default( args,
                                             "--is_using_device", Bool_false );
  Insist( env->is_using_device_ == 0 ||
          env->is_using_device_ == 1 ? "Invalid is_using_device value." : 0 );
#endif
}

/*===========================================================================*/
/*---Determine whether using device---*/

Bool_t Env_cuda_is_using_device( const Env* const env )
{
#if defined USE_CUDA || defined USE_HIP
  return env->is_using_device_;
#else
  return Bool_false;
#endif
}

/*===========================================================================*/
/*---Memory management, for CUDA and all platforms ex. MIC---*/

#ifndef __MIC__

int* malloc_host_int( size_t n )
{
  Assert( n+1 >= 1 );
  int* result = (int*)malloc( n * sizeof(int) );
  Assert( result );
  return result;
}

/*---------------------------------------------------------------------------*/

P* malloc_host_P( size_t n )
{
  Assert( n+1 >= 1 );
  P* result = (P*)malloc( n * sizeof(P) );
  Assert( result );
  return result;
}

/*---------------------------------------------------------------------------*/

P* malloc_host_pinned_P( size_t n )
{
  Assert( n+1 >= 1 );

  P* result = NULL;

#if defined USE_CUDA
  cudaMallocHost( &result, n==0 ? ((size_t)1) : n*sizeof(P) );
  Assert( Env_cuda_last_call_succeeded() );
#elif defined USE_HIP
  //hipMallocHost( (void**) &result, n==0 ? ((size_t)1) : n*sizeof(P) );
  hipHostMalloc( (void**) &result, n==0 ? ((size_t)1) : n*sizeof(P) );
  Assert( Env_cuda_last_call_succeeded() );
#else
  result = (P*)malloc( n * sizeof(P) );
#endif
  Assert( result );

  return result;
}

/*---------------------------------------------------------------------------*/

P* malloc_device_P( size_t n )
{
  Assert( n+1 >= 1 );

  P* result = NULL;

#if defined USE_CUDA
  cudaMalloc( &result, n==0 ? ((size_t)1) : n*sizeof(P) );
  Assert( Env_cuda_last_call_succeeded() );
  Assert( result );
#elif defined USE_HIP
  hipMalloc( (void**) &result, n==0 ? ((size_t)1) : n*sizeof(P) );
  Assert( Env_cuda_last_call_succeeded() );
  Assert( result );
#endif

  return result;
}

/*---------------------------------------------------------------------------*/

void free_host_int( int* p )
{
  Assert( p );
  free( (void*) p );
}

/*---------------------------------------------------------------------------*/

void free_host_P( P* p )
{
  Assert( p );
  free( (void*) p );
}

/*---------------------------------------------------------------------------*/

void free_host_pinned_P( P* p )
{
  Assert( p );
#if defined USE_CUDA
  cudaFreeHost( p );
  Assert( Env_cuda_last_call_succeeded() );
#elif defined USE_HIP
  //hipFreeHost( (void*) p );
  hipHostFree( (void*) p );
  Assert( Env_cuda_last_call_succeeded() );
#else
  free( (void*) p );
#endif
}

/*---------------------------------------------------------------------------*/

void free_device_P( P* p )
{
#if defined USE_CUDA
  cudaFree( p );
  Assert( Env_cuda_last_call_succeeded() );
#elif defined USE_HIP
  hipFree( p );
  Assert( Env_cuda_last_call_succeeded() );
#endif
}

#endif /*---__MIC__---*/

/*---------------------------------------------------------------------------*/

void cuda_copy_host_to_device_P( P*     p_d,
                                 P*     p_h,
                                 size_t n )
{
#if defined USE_CUDA
  Assert( p_d );
  Assert( p_h );
  Assert( n+1 >= 1 );

  cudaMemcpy( p_d, p_h, n*sizeof(P), cudaMemcpyHostToDevice );
  Assert( Env_cuda_last_call_succeeded() );
#elif defined USE_HIP
  Assert( p_d );
  Assert( p_h );
  Assert( n+1 >= 1 );

  hipMemcpy( p_d, p_h, n*sizeof(P), hipMemcpyHostToDevice );
  Assert( Env_cuda_last_call_succeeded() );
#endif
}

/*---------------------------------------------------------------------------*/

void cuda_copy_device_to_host_P( P*     p_h,
                                 P*     p_d,
                                 size_t n )
{
#if defined USE_CUDA
  Assert( p_h );
  Assert( p_d );
  Assert( n+1 >= 1 );

  cudaMemcpy( p_h, p_d, n*sizeof(P), cudaMemcpyDeviceToHost );
  Assert( Env_cuda_last_call_succeeded() );
#elif defined USE_HIP
  Assert( p_h );
  Assert( p_d );
  Assert( n+1 >= 1 );

  hipMemcpy( p_h, p_d, n*sizeof(P), hipMemcpyDeviceToHost );
  Assert( Env_cuda_last_call_succeeded() );
#endif
}

/*---------------------------------------------------------------------------*/

void cuda_copy_host_to_device_stream_P( P*       p_d,
                                        P*       p_h,
                                        size_t   n,
                                        Stream_t stream )
{
#if defined USE_CUDA
  Assert( p_d );
  Assert( p_h );
  Assert( n+1 >= 1 );

  cudaMemcpyAsync( p_d, p_h, n*sizeof(P), cudaMemcpyHostToDevice, stream );
  Assert( Env_cuda_last_call_succeeded() );
#elif defined USE_HIP
  Assert( p_d );
  Assert( p_h );
  Assert( n+1 >= 1 );

  hipMemcpyAsync( p_d, p_h, n*sizeof(P), hipMemcpyHostToDevice, stream );
  Assert( Env_cuda_last_call_succeeded() );
#endif
}

/*---------------------------------------------------------------------------*/

void cuda_copy_device_to_host_stream_P( P*       p_h,
                                        P*       p_d,
                                        size_t   n,
                                        Stream_t stream )
{
#if defined USE_CUDA
  Assert( p_h );
  Assert( p_d );
  Assert( n+1 >= 1 );

  cudaMemcpyAsync( p_h, p_d, n*sizeof(P), cudaMemcpyDeviceToHost, stream );
  Assert( Env_cuda_last_call_succeeded() );
#elif defined USE_HIP
  Assert( p_h );
  Assert( p_d );
  Assert( n+1 >= 1 );

  hipMemcpyAsync( p_h, p_d, n*sizeof(P), hipMemcpyDeviceToHost, stream );
  Assert( Env_cuda_last_call_succeeded() );
#endif
}

/*===========================================================================*/
/*---Stream management---*/

Stream_t Env_cuda_stream_send_block( Env* env )
{
#if defined USE_CUDA || defined USE_HIP
  return env->stream_send_block_;
#else
  return 0;
#endif
}

/*---------------------------------------------------------------------------*/

Stream_t Env_cuda_stream_recv_block( Env* env )
{
#if defined USE_CUDA || defined USE_HIP
  return env->stream_recv_block_;
#else
  return 0;
#endif
}

/*---------------------------------------------------------------------------*/

Stream_t Env_cuda_stream_kernel_faces( Env* env )
{
#if defined USE_CUDA || defined USE_HIP
  return env->stream_kernel_faces_;
#else
  return 0;
#endif
}

/*---------------------------------------------------------------------------*/

void Env_cuda_stream_wait( Env* env, Stream_t stream )
{
#if defined USE_CUDA
  cudaStreamSynchronize( stream );
  Assert( Env_cuda_last_call_succeeded() );
#elif defined USE_HIP
  hipStreamSynchronize( stream );
  Assert( Env_cuda_last_call_succeeded() );
#endif
}

/*===========================================================================*/

#ifdef USE_EXTERN_C
} /*---extern "C"---*/
#endif

/*---------------------------------------------------------------------------*/

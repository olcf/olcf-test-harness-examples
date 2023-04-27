/*---------------------------------------------------------------------------*/
/*!
 * \file   env_assert_kernels.h
 * \author Wayne Joubert
 * \date   Wed Jan 15 16:06:28 EST 2014
 * \brief  Environment settings for assertions, code for comp. kernel.
 * \note   Copyright (C) 2014 Oak Ridge National Laboratory, UT-Battelle, LLC.
 */
/*---------------------------------------------------------------------------*/

#ifndef _env_assert_kernels_h_
#define _env_assert_kernels_h_

#if (! defined __CUDA_ARCH__) && (! defined __HIP_DEVICE_COMPILE__)
/*---Do the following on the HDST---*/

#ifdef USE_EXTERN_C
extern "C"
{
#endif

#include <assert.h>

/*===========================================================================*/
/*---Assertions---*/

#define Assert(v) assert(v)

#ifndef Insist
#define Insist( condition ) \
  (void)((condition) || (insist_ (#condition, __FILE__, __LINE__),0))
#endif

void insist_( const char *condition_string, const char *file, int line );

/*===========================================================================*/

#ifdef USE_EXTERN_C
} /*---extern "C"---*/
#endif

#else /*---(! defined __CUDA_ARCH__) && (! defined __HIP_DEVICE_COMPILE__)---*/
/*---Do the following on the DEVICE---*/

/*---Ignore on device.---*/

#define Assert(v)
#define Insist(v)

#endif /*--(! defined __CUDA_ARCH__) && (! defined __HIP_DEVICE_COMPILE__)---*/

/*===========================================================================*/
/*---Static assertions---*/

#ifndef NDEBUG
/*---Fail compilation and (hopefully) give a filename/line number---*/
#define Static_Assert( condition ) { int a[ ( condition ) ? 1 : -1 ]; (void)a; }
#else
#define Static_Assert( condition )
#endif

#endif /*---_env_assert_h_kernels_---*/

/*---------------------------------------------------------------------------*/

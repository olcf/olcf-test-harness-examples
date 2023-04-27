#==============================================================================

cmake_minimum_required(VERSION 2.8)

project("minisweep")

enable_language(CXX)

set(HIPLOCAL_DIR "${CMAKE_SOURCE_DIR}/scripts")

SET(INCLUDE_DIRS
  ${CMAKE_SOURCE_DIR}/src/1_base
  ${CMAKE_SOURCE_DIR}/src/2_sweeper_base
  ${CMAKE_SOURCE_DIR}/src/3_sweeper
  ${CMAKE_SOURCE_DIR}/src/4_driver
  )

SET(SOURCES
  src/1_base/arguments.c
  src/1_base/env.c
  src/1_base/env_assert.c
  src/1_base/env_cuda.c
  src/1_base/env_mpi.c
  src/1_base/pointer.c
  src/2_sweeper_base/array_operations.c
  src/2_sweeper_base/dimensions.c
  src/3_sweeper/faces_kba.c
  src/3_sweeper/quantities.c
  src/3_sweeper/stepscheduler_kba.c
  src/3_sweeper/sweeper.c
  src/3_sweeper/sweeper_kernels.c
  src/4_driver/runner.c
  )

SET(CUDA_SOURCES)
FOREACH(FILE IN LISTS SOURCES)
  STRING(REPLACE ".c" ".cu" FILE2 ${FILE})
  SET(CUDA_SOURCES ${CUDA_SOURCES} ${FILE2})
ENDFOREACH()

SET(HIP_SOURCES)
FOREACH(FILE IN LISTS SOURCES)
  STRING(REPLACE ".c" ".cpp" FILE2 ${FILE})
  SET(HIP_SOURCES ${HIP_SOURCES} ${FILE2})
ENDFOREACH()

#set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS} -Werror")

IF(CMAKE_C_COMPILER_ID STREQUAL "XL")
  STRING(REPLACE "qhalt=e" "qhalt=w" CMAKE_CXX_FLAGS_ADJUSTED "${CMAKE_CXX_FLAGS}")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS_ADJUSTED}")
ENDIF()

#SET(CUDA_PROPAGATE_HOST_FLAGS OFF)

IF(USE_MPI)
  find_package(MPI REQUIRED)
  include_directories(${MPI_INCLUDE_PATH})
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DUSE_MPI")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DUSE_MPI")
ENDIF()

IF(USE_OPENMP)
  find_package(OpenMP REQUIRED)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OpenMP_C_FLAGS} -DUSE_OPENMP -DUSE_OPENMP_THREADS")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS} -DUSE_OPENMP -DUSE_OPENMP_THREADS")
ENDIF()

IF(USE_CUDA)
  find_package(CUDA REQUIRED)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DUSE_CUDA")
  STRING(REPLACE " " ";" CMAKE_C_FLAGS_ADJUSTED ${CMAKE_C_FLAGS})
  SET(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS};${CMAKE_C_FLAGS_ADJUSTED}")
#  STRING(REGEX MATCH " -DNM_VALUE=[0-9]*" NM_VALUE_DEF_ " ${CMAKE_C_FLAGS} ")
#  STRING(REPLACE " " ";" NM_VALUE_DEF "${NM_VALUE_DEF_}")
#  SET(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS}${NM_VALUE_DEF};-DUSE_CUDA")
  CUDA_INCLUDE_DIRECTORIES(${INCLUDE_DIRS})
  CUDA_ADD_LIBRARY(sweeper STATIC ${CUDA_SOURCES})
  CUDA_ADD_EXECUTABLE(sweep src/4_driver/sweep.cu)
  TARGET_LINK_LIBRARIES(sweep sweeper ${MPI_C_LIBRARIES})
  CUDA_ADD_EXECUTABLE(tester src/4_driver/tester.cu)
  TARGET_LINK_LIBRARIES(tester sweeper ${MPI_C_LIBRARIES})
elseif(USE_HIP) #=========================================
  if(NOT DEFINED HIP_PATH)
    if(NOT DEFINED ENV{HIP_PATH})
      message(FATAL_ERROR "Could not find HIP..")
    else()
      set(HIP_PATH $ENV{HIP_PATH} CACHE PATH "Path to HIP install")
    endif()
  endif()
  set(CMAKE_MODULE_PATH "${HIP_PATH}/cmake" ${CMAKE_MODULE_PATH})
  find_package(HIPLOCAL QUIET)
  if(HIPLOCAL_FOUND)
    message(STATUS "Found HIP: " ${HIP_VERSION})
  else()
    message(FATAL_ERROR "Could not find HIP.")
  endif()
  #set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DUSE_HIP")
  set(CMAKE_LINKER "${ROCM_PATH}/bin/hipcc")
  set_source_files_properties(src/4_driver/sweep.cpp src/4_driver/tester.cpp ${HIP_SOURCES} PROPERTIES HIP_SOURCE_PROPERTY_FORMAT 1)
  hip_add_library(sweeper ${HIP_SOURCES} HIPCC_OPTIONS ${CMAKE_CXX_FLAGS})

  INCLUDE_DIRECTORIES(${INCLUDE_DIRS})
  #ADD_LIBRARY(sweeper STATIC ${SOURCES})
  ADD_EXECUTABLE(sweep src/4_driver/sweep.cpp)
  TARGET_LINK_LIBRARIES(sweep sweeper ${MPI_C_LIBRARIES})
  ADD_EXECUTABLE(tester src/4_driver/tester.cpp)
  TARGET_LINK_LIBRARIES(tester sweeper ${MPI_C_LIBRARIES})

ELSE()
  INCLUDE_DIRECTORIES(${INCLUDE_DIRS})
  ADD_LIBRARY(sweeper STATIC ${HIP_SOURCES})
  ADD_EXECUTABLE(sweep src/4_driver/sweep.c)
  TARGET_LINK_LIBRARIES(sweep sweeper ${MPI_C_LIBRARIES})
  ADD_EXECUTABLE(tester src/4_driver/tester.c)
  TARGET_LINK_LIBRARIES(tester sweeper ${MPI_C_LIBRARIES})
ENDIF()

install(TARGETS sweep DESTINATION bin)
#install(TARGETS tester DESTINATION bin)

SET(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS)

IF(CMAKE_C_COMPILER_ID STREQUAL "GNU")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ansi -Wmissing-prototypes -Dinline=")
ENDIF()

IF(CMAKE_C_COMPILER_ID STREQUAL "Intel")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Dinline=__forceinline -D__restrict__=restrict -restrict")
ENDIF()



MESSAGE("Compiler ID: ${CMAKE_C_COMPILER_ID}")
#MESSAGE("Cmake stuff: ${CMAKE_CXX_FLAGS}, CUDA stuff: ${CUDA_NVCC_FLAGS}")

# enable_testing()
# add_test(test1 tester)

#==============================================================================

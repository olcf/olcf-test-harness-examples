/*
 * Copyright (C) 2002-2022 the Network-Based Computing Laboratory
 * (NBCL), The Ohio State University.
 *
 * Contact: Dr. D. K. Panda (panda@cse.ohio-state.edu)
 *
 * For detailed copyright and licensing information, please refer to the
 * copyright file COPYRIGHT in the top level OMB directory.
 */

#include <mpi.h>
#include "osu_util.h"
#include "osu_util_graph.h"
#include "osu_util_papi.h"

#define MPI_CHECK(stmt)                                          \
do {                                                             \
   int mpi_errno = (stmt);                                       \
   if (MPI_SUCCESS != mpi_errno) {                               \
       fprintf(stderr, "[%s:%d] MPI call failed with %d \n",     \
        __FILE__, __LINE__,mpi_errno);                           \
       exit(EXIT_FAILURE);                                       \
   }                                                             \
   assert(MPI_SUCCESS == mpi_errno);                             \
} while (0)

extern MPI_Aint disp_remote;
extern MPI_Aint disp_local;

/*
 * Non-blocking Collectives
 */
double call_test(int * num_tests, MPI_Request** request);
void allocate_device_arrays(int n);
double dummy_compute(double target_secs, MPI_Request *request);
void init_arrays(double seconds);
double do_compute_and_probe(double seconds, MPI_Request *request);
void free_host_arrays();

#ifdef _ENABLE_CUDA_KERNEL_
extern void call_kernel(float a, float *d_x, float *d_y, int N, cudaStream_t *stream);
void free_device_arrays();
#endif

/*
 * Managed Memory
 */
#ifdef _ENABLE_CUDA_KERNEL_
void touch_managed(char *buf, size_t length);
void launch_empty_kernel(char *buf, size_t length);
void create_cuda_stream();
void destroy_cuda_stream();
void synchronize_device();
void synchronize_stream();
void prefetch_data(char *buf, size_t length, int devid);
void create_cuda_event();
void destroy_cuda_event();
void event_record_start();
void event_record_stop();
void event_elapsed_time(float *);
extern void call_touch_managed_kernel(char *buf, size_t length, cudaStream_t *stream);
extern void call_empty_kernel(char *buf, size_t length, cudaStream_t *stream);
#define PREFETCH_THRESHOLD 131072
#endif /* #ifdef _ENABLE_CUDA_KERNEL_ */

/*
 * Print Information
 */
void print_bad_usage_message (int rank);
void print_help_message (int rank);
void print_version_message (int rank);
void print_preamble (int rank);
void print_preamble_nbc (int rank);
void print_stats (int rank, int size, double avg, double min, double max);
void print_stats_validate(int rank, int size, double avg, double min,
                          double max, int errors);
void print_stats_nbc (int rank, int size, double ovrl, double cpu,
                      double avg_comm, double min_comm, double max_comm,
                      double wait, double init, double test, int errors);

/*
 * Memory Management
 */
int allocate_memory_coll (void ** buffer, size_t size, enum accel_type type);
void free_buffer (void * buffer, enum accel_type type);
void set_buffer (void * buffer, enum accel_type type, int data, size_t size);
void set_buffer_pt2pt (void * buffer, int rank, enum accel_type type, int data,
                       size_t size);
void set_buffer_validation(void* s_buf, void* r_buf, size_t size,
                           enum accel_type type, int iter);
void set_buffer_float (float * buffer, int is_send_buf, size_t size, int iter,
                       enum accel_type type);
void set_buffer_char (char * buffer, int is_send_buf, size_t size, int rank,
                      int num_procs, enum accel_type type, int iter);
void check_mem_limit(int numprocs); 

/*
 * CUDA Context Management
 */
int init_accel (void);
int cleanup_accel (void);

extern MPI_Request request[MAX_REQ_NUM];
extern MPI_Status  reqstat[MAX_REQ_NUM];
extern MPI_Request send_request[MAX_REQ_NUM];
extern MPI_Request recv_request[MAX_REQ_NUM];

void usage_mbw_mr();
int allocate_memory_pt2pt (char **sbuf, char **rbuf, int rank);
int allocate_memory_pt2pt_size (char **sbuf, char **rbuf, int rank, size_t size);
int allocate_memory_pt2pt_mul (char **sbuf, char **rbuf, int rank, int pairs);
int allocate_memory_pt2pt_mul_size (char **sbuf, char **rbuf, int rank, int pairs, size_t size);
void print_header_pt2pt (int rank, int type);
void free_memory (void *sbuf, void *rbuf, int rank);
void free_memory_pt2pt_mul (void *sbuf, void *rbuf, int rank, int pairs);
void print_header(int rank, int full);
void usage_one_sided (char const *);
void print_header_one_sided (int, enum WINDOW, enum SYNC);

void print_help_message_get_acc_lat (int);

extern char const * benchmark_header;
extern char const * benchmark_name;
extern int accel_enabled;
extern struct options_t options;
extern struct bad_usage_t bad_usage;

void allocate_memory_one_sided(int rank, char **sbuf,
        char **win_base, size_t size, enum WINDOW type, MPI_Win *win);
void free_memory_one_sided (void *user_buf, void *win_baseptr, enum WINDOW win_type, MPI_Win win, int rank);
void allocate_atomic_memory(int rank,
        char **sbuf, char **tbuf, char **cbuf,
        char **win_base, size_t size, enum WINDOW type, MPI_Win *win);
void free_atomic_memory (void *sbuf, void *win_baseptr, void *tbuf, void *cbuf, enum WINDOW type, MPI_Win win, int rank);
int omb_get_local_rank();

/*
 * Data Validation
 */
#define VALIDATION_STATUS(error) (error > 0) ? "Fail" : "Pass"
#define ERROR_DELTA 0.001
uint8_t validate_data(void* r_buf, size_t size, int num_procs,
                      enum accel_type type, int iter);
int validate_reduction(float * buffer, size_t size, int iter, int num_procs,
                       enum accel_type type);
int validate_collective(char *buffer, size_t size, int value1, int value2,
                        enum accel_type type, int itr);
int validate_reduce_scatter(float *buffer, size_t size, int* recvcounts,
                            int rank, int num_procs, enum accel_type type,
                            int iter);

/*
 * DDT 
 */
#define OMB_DDT_INDEXED_MAX_LENGTH 100
#define OMB_DDT_FILE_LINE_MAX_LENGTH 500
size_t omb_ddt_assign(MPI_Datatype *datatype, MPI_Datatype base_datatype,
        size_t count);
void omb_ddt_free(MPI_Datatype *datatype);
size_t omb_ddt_get_size(size_t size);
void omb_ddt_append_stats(size_t omb_ddt_transmit_size);

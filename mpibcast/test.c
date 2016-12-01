
#include <stdio.h>
#include <mpi.h>
#include "sdn_mpi_bcast.h"

#define SIZE 1000005         // broadcast data max size

// set value to data[]
void set_data (int *data, int size, int value) {
  int i;
  for (i=0; i<size; i++) {
    data[i] = i+1;
  }
}

// calculate average time of all mpi process' broadcast time
double average_time(double *dtime, int world_size) {
  int i;
  double stime;
  stime = 0;
  for (i=0; i<world_size; i++) {
    stime = stime + dtime[i];
  }
  stime = stime/world_size;
  return stime;
}

// mpirun -np 28 -machinefile hosts ./test hosts method count size connect effring
int main (int argc, char *argv[]) {

  int numprocs, rank, namelen, root;
  char processor_name[MPI_MAX_PROCESSOR_NAME];

  double dtime[MAX_PROCESS_NUMBER], mtime, start, end;

  // conventional method or research method
  int method; // 1: research method, 0: conventional
  int data[SIZE];
  int count, size;
  int eff;

  strcpy(host_file, argv[1]);
  method = atoi(argv[2]);
  count = atoi(argv[3]);
  size = atoi(argv[4]);
  connect_to_ctrl = atoi(argv[5]);
  eff = atoi(argv[6]);
  
  MPI_Init(&argc, &argv);

  MPI_Comm_size(MPI_COMM_WORLD, &numprocs);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Get_processor_name(processor_name, &namelen);

  root = 0;

  if (rank == root)
    set_data(data, size, 22);

  if (method)
    SDN_MPI_Bcast_Init(root, eff);

  MPI_Barrier(MPI_COMM_WORLD);

  dtime[rank] = 0.0;

  if (rank == root && method) {
    printf("Using research method for broadcast\n");
  }
  
  int i, count_packet_loss[MAX_PROCESS_NUMBER], result_bcast;
  for (i=0; i<numprocs; i++)
    count_packet_loss[i] = 0;
  
  for (i=0; i<count; i++) {

    if (rank == root) {
      printf("i = %d\n", i);
      fflush(stdout);
    }
    
    start = MPI_Wtime();
    if (method) {
      //result_bcast = SDN_MPI_Bcast(data, size, MPI_INT, root, MPI_COMM_WORLD);
      result_bcast = SDN_MPI_Bcast_thread(data, size, MPI_INT, root, MPI_COMM_WORLD);
    } else
      MPI_Bcast(data, size, MPI_INT, root, MPI_COMM_WORLD);
    end = MPI_Wtime();
    
    if (result_bcast == FAILED)
      count_packet_loss[rank]++;
    // printf("rank %d is received data\n", rank);
    
    MPI_Barrier(MPI_COMM_WORLD);

    dtime[rank] = dtime[rank] + end-start;
    
  }

  MPI_Gather (&count_packet_loss[rank], 1, MPI_INT,
	      count_packet_loss, 1, MPI_INT, root, MPI_COMM_WORLD);
  
  MPI_Gather (&dtime[rank], 1, MPI_DOUBLE, dtime,
		          1, MPI_DOUBLE, root, MPI_COMM_WORLD);

  if (rank == root) {
    mtime = average_time(dtime, numprocs);
    printf("%f\n", mtime);

    printf("Number of bcast packet loss on multicast step\n");
    for (i=0; i<numprocs-1; i++)
      printf("rank %d: %d, ", i, count_packet_loss[i]);
    printf("rank %d: %d.\n", i, count_packet_loss[i]);
    fflush(stdout);
  } else {
    printf("rank %d : data[%d] = %d\n", rank, size-1, data[size-1]);
    //printf("rank %d : successful bcast count %d\n", rank, bcast_count);
  }
  
  MPI_Barrier(MPI_COMM_WORLD);
  
  MPI_Finalize();

  //exit(1);
  return 0;
}

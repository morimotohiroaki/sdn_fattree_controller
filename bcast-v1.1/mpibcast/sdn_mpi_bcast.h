
#include <mpi.h>
#include "transfer_data.h"

#include <pthread.h>

#define NOT_STARTED -1
#define IN_PROGRESS 0
#define COMPLETED 1
#define FAILED -2

#define CONN 2
#define RECV 0
#define SEND 1

// max node number
#define MAX_NODE_NUMBER 500
// max processor number
#define MAX_PROCESS_NUMBER 1000

// data from controller answer
#define ADDR_DATA_LEN 1024

// node number of mpi program
int node_number;

// decide whether connect to controller or not
// if 1, connect to controller
// for debuggin purpose
int connect_to_ctrl;

// controller ip address
#define CONTROLLER_IP "192.168.10.106"
#define CONTROLLER_PORT 50000


char host_file[255];

int bcast_sock;

uint8_t mpi_mac[ETH_ALEN];
char mpi_ip[32];

// for the ring communication of reliability
int ring_topology[MAX_NODE_NUMBER];
int rank_send, rank_recv;

typedef struct thread_variables {
  void *data;
  int size;
  int *status_receiving_bcast;
  int rank;
} variables;

/*********** Global functions *************/

int SDN_MPI_Bcast_Init (int , int );

int SDN_MPI_Bcast (int *, int ,
		   struct ompi_datatype_t *,
		   int , struct ompi_communicator_t *);

/*********** Global functions *************/

// connect to controller and send node information
// and get mpi ip, mac information, also efficient ring info
int connect_to_controller (int , char [MAX_NODE_NUMBER][MAX_IPOPTLEN]);

// copy mpi mac address to  mpi_mac from data.
// data should be "mpi_mac"
int copy_mpi_addresses (char []);

void create_effective_ring_topology (char [MAX_NODE_NUMBER][MAX_IPOPTLEN], char []);

int get_recv_process (int , int );

int get_send_process (int , int );

// send mpi mac address and mpi ip address to slaves
void send_information_from_root(int , int );

void display_global_information (int );

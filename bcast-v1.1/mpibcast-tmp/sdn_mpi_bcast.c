
#include "sdn_mpi_bcast.h"

int SDN_MPI_Bcast_Init(int root, int eff) {

  int rank, numprocs;

  MPI_Comm_size(MPI_COMM_WORLD, &numprocs);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);

  node_number = numprocs;

  // setting ETHERNET_NAME to promisc
  set_promisc_nic();
  // get index of ETHERNET_NAME
  // to nic_index (int)
  get_nic_index();
  // get ip of ETHERNET_NAME
  // to nic_ip (string)
  get_nic_ip_addr();

  // get all ip address of mpi processes
  char addresses[MAX_NODE_NUMBER][MAX_IPOPTLEN];
  int ip_len = strlen(nic_ip);
  MPI_Gather(nic_ip, ip_len+1, MPI_CHAR,
	     addresses, MAX_IPOPTLEN, MPI_CHAR, root, MPI_COMM_WORLD);
  
  if (root == rank)
    connect_to_controller(root, addresses);

  // broadcast mpi ip and mac to others
  send_information_from_root(root, eff);

  if (rank == root) {
    bcast_sock = init_udp_socket();
    //printf("bcast_sock = %d\n", bcast_sock);
  } else {
    bcast_sock = init_pcap(mpi_mac, mpi_ip);
  }
}

void* Bcast_receive_thread (void *args) {
  int result, start;
  variables *arg;
  arg = (variables *)args;
  result = start = 0;
  //sleep(2);
  *(arg->status_receiving_bcast) = IN_PROGRESS;
  while (1) {
    result = recv_data_with_pcap(arg->data, arg->size, mpi_mac, mpi_ip, arg->rank, start);
    if (result != -1) {
      start = result;
    }
    if (start == arg->size)
      break;
  }
  *(arg->status_receiving_bcast) = COMPLETED;
  pthread_exit(NULL);
}

int SDN_MPI_Bcast_thread (int *data, int size,
			  struct ompi_datatype_t *type,
			  int root, struct ompi_communicator_t *comm) {
  int rank, numprocs;
  int result;
  int data_size;

  int status_sending, status_receiving, status_receiving_bcast;
  MPI_Request request[CONN], request_recv, request_send; // for reliability communication
  int flag;      // for MPI_Test
  int index;     // for MPI_Waitnay
  MPI_Status status;
  
  MPI_Comm_size(comm, &numprocs);
  MPI_Comm_rank(comm, &rank);

  if (type == MPI_INT) {
    data_size = size * sizeof(int);
  } else {
    data_size = size;
  }

  if (rank == root) {
   // printf("mpi_ip = %s\n", mpi_ip);
    send_udp_data(bcast_sock, (char *)data, data_size, mpi_mac, mpi_ip);
    MPI_Send(data, data_size, MPI_BYTE, rank_send, 0, comm);
  } else {
    status_receiving_bcast = NOT_STARTED;
    status_receiving = status_sending = NOT_STARTED;
    
    // handing over data, data_size, rank number to thread
    variables arg;
    arg.data = (void*)data; arg.size = data_size;
    arg.status_receiving_bcast = &status_receiving_bcast; arg.rank = rank;
    // create thread that receive bcast data using pcap
    pthread_t tid;
    pthread_create(&tid, NULL, &Bcast_receive_thread, (void*)&arg);
    /*
    sleep(1);
    if (rank == 1) {
      if (status_receiving_bcast != NOT_STARTED) 
	printf("it is working!\n");
      printf("status_receiving_bcast = %d\n", status_receiving_bcast);
      }*/
    while (1) {
      // if receiving of reliable communication not started
      // start it
      if ((status_receiving == NOT_STARTED)) {
	MPI_Irecv(data, data_size, MPI_BYTE,
		  rank_recv, 0, comm, &(request[RECV]));
	status_receiving = IN_PROGRESS;
      }
      
      // if received data and not started sending of reliable communication
      // start it
      if ((status_sending == NOT_STARTED)) {
	if ((status_receiving_bcast == COMPLETED)
	    || (status_receiving_bcast == FAILED)) {
	  status_sending = IN_PROGRESS;
	  MPI_Isend(data, data_size, MPI_BYTE,
		    rank_send, 0, comm, &(request[SEND]));
	}
      }

      int ret;
      if (status_sending == IN_PROGRESS
	  && status_receiving == IN_PROGRESS) {
	ret = MPI_Waitany(CONN, request, &index, &status);
      } else if (status_sending == IN_PROGRESS) {
	ret = MPI_Wait(&request[SEND], &status);
	index = SEND;
      } else if (status_receiving == IN_PROGRESS) {
	ret = MPI_Wait(&request[RECV], &status);
	index = RECV;
      }

      if (index == RECV) {
	if (status_receiving_bcast == IN_PROGRESS) {
	  
	  pthread_cancel(tid);
	  status_receiving_bcast = FAILED;
	}
	status_receiving = COMPLETED;
      } else if (index == SEND) {
	status_sending = COMPLETED;
      } else {
	// error handler
      }

      /*
      if (rank == 1)
	printf("status_receiving_bcast = %d, status_receving = %d, status_sending = %d\n",
	       status_receiving_bcast, status_receiving, status_sending);
      */
      
      // check whether all communication completed or not
      if ( ((status_receiving_bcast == COMPLETED) || (status_receiving_bcast == FAILED))
	   && status_receiving == COMPLETED
	   && status_sending == COMPLETED ) {
	break;
      }
    } // end of while(1)
    //pthread_join(tid, NULL);
  } // end of if (rank==root)
  return status_receiving_bcast;
}

int SDN_MPI_Bcast (int *data, int size,
		   struct ompi_datatype_t *type,
		   int root, struct ompi_communicator_t *comm) {

  int rank, numprocs;
  int result, start;
  int status_sending, status_receiving, status_receiving_bcast;
  MPI_Request request_recv, request_send; // for reliability communication
  int flag;      // for MPI_Test
  int data_size; // size in byte

  MPI_Comm_size(comm, &numprocs);
  MPI_Comm_rank(comm, &rank);

  if (type == MPI_INT) {
    data_size = size * sizeof(int);
  } else {
    data_size = size;
  }

  status_receiving_bcast = IN_PROGRESS;
  status_receiving = status_sending = NOT_STARTED;
  start = result = 0;
  if (rank == root) {
    send_udp_data(bcast_sock, (char *)data, data_size, mpi_mac, mpi_ip);
    MPI_Send(data, data_size, MPI_BYTE,
	     rank_send, 0, comm);
  } else {
    while (1) {
      if (status_receiving_bcast == IN_PROGRESS) {
	result = recv_data_with_pcap(data, size, mpi_mac, mpi_ip, rank, start);
	if (result != -1) {
	  start = result;
	}
	if (start == data_size) {
	  status_receiving_bcast = COMPLETED;
	} else if (start > data_size) {
	  status_receiving_bcast = FAILED;
	}
      } // end of if (status_receiving_bcast == IN_PROGRESS)
      
      // if receiving of reliable communication not started
      // start it
      if ((status_receiving == NOT_STARTED)) {
	MPI_Irecv(data, data_size, MPI_BYTE,
		  rank_recv, 0, comm, &request_recv);
	status_receiving = IN_PROGRESS;
      }
      
      // if received data and not started sending of reliable communication
      // start it
      if ((status_sending == NOT_STARTED)) {
	if ((status_receiving_bcast == COMPLETED)
	    || (status_receiving_bcast == FAILED)) {
	  status_sending = IN_PROGRESS;
	  MPI_Isend(data, data_size, MPI_BYTE,
		    rank_send, 0, comm, &request_send);
	}
      }
      
      // check mpi_irecv is received data
      if (status_receiving == IN_PROGRESS) {
	flag = 0;
	MPI_Test(&request_recv, &flag, NULL);
	if (flag) {
	  if (status_receiving_bcast == IN_PROGRESS) {
	    status_receiving_bcast = FAILED;
	  }
	  status_receiving = COMPLETED;
	}
      }
      
      // check mpi_isend is sent data
      if (status_sending == IN_PROGRESS) {
	flag = 0;
	MPI_Test (&request_send, &flag, NULL);
	if (flag) {
	  status_sending = COMPLETED;
	}
      }

      // check whether all communication completed or not
      if ( ((status_receiving_bcast == COMPLETED) || (status_receiving_bcast == FAILED))
	   && status_receiving == COMPLETED
	   && status_sending == COMPLETED ) {
	break;
      }
    } // end of while(1)
  } // if (rank == root)
  return status_receiving_bcast;
}

// connect to controller and send node information
// and get mpi ip, mac information, also efficient ring info
int connect_to_controller(int root, char addresses[MAX_NODE_NUMBER][MAX_IPOPTLEN]) {
  int sock, data_len, addr_len, i;
  struct sockaddr_in sdn_server, client_addr;
  struct hostent *host;
  char data[ADDR_DATA_LEN];

  // create ip address list
  strcpy(data, addresses[0]);
  for (i=1; i<node_number; i++) {
    strcat(data, " ");
    strcat(data, addresses[i]);
  }

  if (connect_to_ctrl) {
    printf("Connecting to %s address %d port for controller\n",
	   CONTROLLER_IP, CONTROLLER_PORT);
    sock = socket(AF_INET, SOCK_DGRAM, 0);
    sdn_server.sin_family = AF_INET;
    sdn_server.sin_port = htons(CONTROLLER_PORT);
    inet_aton(CONTROLLER_IP, &sdn_server.sin_addr);
    bzero( &(sdn_server.sin_zero), 8 );

    sendto ( sock, data, strlen(data), 0,
             (struct sockaddr *)&sdn_server,
             sizeof(struct sockaddr) );

    bind ( sock, (struct sockaddr *) &sdn_server, sizeof(struct sockaddr) );

    data_len = recvfrom ( sock, data, ADDR_DATA_LEN, 0,
                          (struct sockaddr *)&client_addr,
                          &addr_len );
    close(sock);
    data[data_len] = '\0';
    data_len++;
    printf("Received data from controller. data is : %s\n", data);
  } else {
    // strcpy(data, "00:e0:81:fa:fa:fa 172.21.1.100 172.21.1.1 172.21.1.2 172.21.1.3 172.21.1.4 172.21.1.5 172.21.1.6 172.21.1.7 172.21.3.1 172.21.3.2 172.21.3.3 172.21.3.4 172.21.3.5 172.21.3.6 172.21.3.7 172.21.2.1 172.21.2.2 172.21.2.3 172.21.2.4 172.21.2.5 172.21.2.6 172.21.2.7 172.21.4.1 172.21.4.2 172.21.4.3 172.21.4.4 172.21.4.5 172.21.4.6 172.21.4.7");
    // strcpy(data, "00:e0:81:fa:fa:fa 10.0.0.100 10.0.0.1 10.0.0.2 10.0.0.3 10.0.0.4 10.0.0.5 10.0.0.6 10.0.0.7");
    strcpy(data, "00:e0:81:fa:fa:fa 192.168.100.100 192.168.100.2 192.168.100.3 192.168.4 192.168.100.5");
    data_len = strlen(data);
  }
  i = copy_mpi_addresses(data) + 1;

  create_effective_ring_topology (addresses, data+i);
}

// copy mpi mac address to  mpi_mac from data.
// data should be "mpi_mac"
int copy_mpi_addresses (char data[]) {
  int i;
  char mac[32];
  struct ether_addr e_addr;

  i = 0;
  while (data[i] != ' ') {
    mac[i] = data[i];
    i++;
  }
  mac[i] = '\0';
  
  ether_aton_r(mac, (struct ether_addr*)&e_addr);
  for (i=0; i<6; i++)
    mpi_mac[i] = e_addr.ether_addr_octet[i];

  for (i=18; ;i++) {
    if (data[i] == ' ')
      break;
    mpi_ip[i-18] = data[i];
  }
  mpi_ip[i-18] = '\0';
  //printf("mpi_mac = %02x:%02x:%02x:%02x:%02x:%02x\n",
  //     mpi_mac[0],mpi_mac[1],mpi_mac[2],mpi_mac[3],mpi_mac[4],mpi_mac[5]);
  //printf("mpi_ip = %s\n", mpi_ip);
  return 18+strlen(mpi_ip);
}

void create_effective_ring_topology (char addresses[MAX_NODE_NUMBER][MAX_IPOPTLEN],
				     char data[]) {
  int i, data_len, nodei, j;
  char address[MAX_IPOPTLEN];
  int tmp_ring[MAX_NODE_NUMBER];

  for (i=0; i<node_number; i++)
    ring_topology[i] = i;

  for (i=0; i<node_number; i++)
    tmp_ring[i] = ring_topology[i];
  data_len = strlen(data);
  nodei = 0;
  j = 0;
  strcpy(address, "");
  for (i=0; i<=data_len; i++) {
    if (data[i] == ' ' || data[i] == '\0') {
      if (data[i] == '\0') address[j+1] = '\0';
      else address[j] = '\0';
      
      for (j=0; j<node_number; j++)
	if (strcmp(addresses[j], address) == 0)
	  break;
      ring_topology[nodei] = tmp_ring[j];
      nodei++;
      j = 0;
    } else {
      address[j] = data[i];
      j++;
    }
  }

}

int get_recv_process (int rank, int eff) {
  int ranki;
  int r;

  if (eff) {
    for (ranki=0; ranki<node_number; ranki++)
      if (ring_topology[ranki] == rank)
	break;
    if (ranki == 0)
      ranki = node_number-1;
    else
      ranki = ranki-1;
    // printf("rank %d is receiving data from rank %d\n", rank, ring_topology[ranki]);
    return ring_topology[ranki];
  } else {
    if (rank-1<0)
      r = node_number-1;
    else
      r = rank-1;
    return r;
  }
}

int get_send_process (int rank, int eff) {
  int ranki;
  int r;

  if (eff) {
    for (ranki=0; ranki<node_number; ranki++)
      if (ring_topology[ranki] == rank)
	break;
    ranki = ranki+1;
    if (ranki == node_number)
      ranki = 0;
    // printf("rank %d is sending data to rank %d\n", rank, ring_topology[ranki]);
    return ring_topology[ranki];
  } else {
    if (rank+1<node_number)
      r = rank+1;
    else
      r = 0;
    return r;
  }
}

// send mpi mac address and mpi ip address to slaves
void send_information_from_root(int root, int eff) {
  int i, rank;

  MPI_Comm_rank(MPI_COMM_WORLD, &rank);

  MPI_Bcast(mpi_ip, MAX_IPOPTLEN, MPI_CHAR, root, MPI_COMM_WORLD);
  MPI_Bcast(mpi_mac, ETH_ALEN, MPI_UINT8_T, root, MPI_COMM_WORLD);

  // MPI_Bcast (mpi_mac, 6, MPI_UNSIGNED_CHAR, root, MPI_COMM_WORLD);
  // MPI_Bcast (mpi_ip, 15, MPI_CHAR, root, MPI_COMM_WORLD);
  MPI_Bcast (ring_topology, node_number, MPI_INT, root, MPI_COMM_WORLD);

  rank_send = get_send_process(rank, eff);
  rank_recv = get_recv_process(rank, eff);
  // printf("rank_recv %d -> rank %d -> rank_send %d\n", rank_recv, rank, rank_send);
  //if (rank == root)
  //display_global_information(rank);
}

void display_global_information (int rank) {
  int i;
  
  //  printf("rank %d says : my leader is %d, process_number = %d\n",
  //	 rank, leader, process_number);

  printf("ring topology on rank %d : ", rank);
  for (i=0; i<node_number; i++)
    printf ("%d ", ring_topology[i]);
  printf("\n");
}

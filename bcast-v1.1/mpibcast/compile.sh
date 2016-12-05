#!/bin/bash

echo "+++++++++++++++++++++++ Compiling in regular method ++++++++++++++++++++++++"
echo ""

echo "Compiling transfer_data ..."
mpicc -c transfer_data.c -lpcap

echo "Compiling sdn_mpi_bcast library ..."
mpicc -c sdn_mpi_bcast.c -lpcap

echo "Compiling test.c ..."
mpicc -c test.c -lpcap

echo "Creating execution file test ..."
mpicc -o test test.o sdn_mpi_bcast.o transfer_data.o -lpcap

echo "Running example"
echo "mpirun -np 28 -machinefile hosts ./test hosts method count size connect_to_ctrl effective_ring"
echo "mpirun -np 28 -machinefile hosts ./test hosts 1 1 100 1 1"
echo "mpirun -np 4 --mca btl_tcp_if_include ens3 -machinefile host2 ./test host2 1 1 100 1 0"

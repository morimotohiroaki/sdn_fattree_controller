#!/bin/bash

mpirun -np 4 --mca btl_tcp_if_include ens3 -machinefile host2 ./test host2 1 1 10000 0 0
mpirun -np 4 --mca btl_tcp_if_include ens3 -machinefile host2 ./test host2 1 1 10000 0 0
mpirun -np 4 --mca btl_tcp_if_include ens3 -machinefile host2 ./test host2 1 1 10000 0 0
mpirun -np 4 --mca btl_tcp_if_include ens3 -machinefile host2 ./test host2 1 1 10000 0 0
mpirun -np 4 --mca btl_tcp_if_include ens3 -machinefile host2 ./test host2 1 1 10000 0 0

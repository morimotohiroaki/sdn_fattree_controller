

# install openmpi
sudo yum install make gcc gcc-c++ gcc-gfortran -y

wget http://www.open-mpi.org/software/ompi/v1.6/downloads/openmpi-1.6.5.tar.gz
tar zxf openmpi-1.6.5.tar.gz
(cd openmpi-1.6.5;
./configure --prefix=$HOME/openmpi/ --disable-mpi-cxx --disable-mpi-f77 --disable-mpi-f90;
make;
make install;)
rm -r openmpi-1.6.5.tar.gz openmpi-1.6.5

echo "
LD_LIBRARY_PATH=$HOME/openmpi/lib
PATH=$PATH:$HOME/openmpi/bin

export LD_LIBRARY_PATH
export PATH
" >> ~/.bashrc
source ~/.bashrc

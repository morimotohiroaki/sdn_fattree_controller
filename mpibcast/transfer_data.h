
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <stdint.h>          // uint8_t

#include <sys/types.h>
#include <sys/socket.h>      // socket

#include <linux/if_ether.h>  // ETH_P_IP, ETH_ALEN(=6)
#include <net/ethernet.h>    // L2 layer

#include <sys/ioctl.h>
#include <net/if.h>

#include <netinet/ip.h>

#include <netinet/udp.h>

#include <error.h>
#include <errno.h>

#include <netinet/in.h>      // inet_ntoa
#include <arpa/inet.h>

#include <pcap.h>
#include <sys/select.h>
#include <unistd.h>
#include <sys/time.h>

int pcapFd;
fd_set fdRead;
pcap_t* descr;

#define ETHERNET_NAME "eth10"

#define UDP_MAXPACKET 65507 // = IP_MAX-IP4_HDRLEN-UDP_HDRLEN

#define MTU 1500

#define IP4_HDRLEN 20
#define UDP_HDRLEN 8
#define UDP_FRAME 1472 // = MTU - IP_HDRLEN - UDP_HDRLEN

#define HEADERS_LEN 28

#define SIZE_ETHERNET 14

#define BCAST_PORT 50001

struct sockaddr_ll {
  unsigned short  sll_family;
  __be16          sll_protocol;
  int             sll_ifindex;
  unsigned short  sll_hatype;
  unsigned char   sll_pkttype;
  unsigned char   sll_halen;
  unsigned char   sll_addr[8];
};

struct pseudo_header {
  u_int32_t source_address;
  u_int32_t dest_address;
  u_int8_t placeholder;
  u_int8_t protocol;
  u_int16_t udp_length;
};

int  nic_index;
char nic_ip[MAX_IPOPTLEN];     // = 40

int tmp_sock;

//char if_name[10];

/************** Global Functions ****************/

void set_promisc_nic ();

void get_nic_index ();

void get_nic_ip_addr ();

int init_raw_socket ();

void bind_sock (int);

void send_data (int , void *, int , uint8_t *, char *);

void recv_data (int, void *, int);

int recv_data_nonblock (int sock, void *data, int size, uint8_t *dst_mac, char *dst_ip, int rank, int start);


int init_udp_sockete();
int send_udp_data(int, char *, int, uint8_t *, char *);
int init_pcap (uint8_t *, char *);
int recv_data_with_pcap (void *, int, uint8_t *, char *, int, int);

/************** Local Functions ****************/

void send_frame (int, void *, int, uint8_t *, char *);

void setup_sll (struct sockaddr_ll *, uint8_t *);

void setup_ip_header (struct ip *, char *);

void setup_udp_header (struct udphdr *);

int convert_mac_str (char *, uint8_t *);

void convert_mac_str_oct (char *, uint8_t *);

unsigned short checksum (unsigned short *, int);

unsigned short udp_csum (unsigned short *, int);

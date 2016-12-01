
#include "transfer_data.h"

int init_udp_socket() {
  int sock;

  sock = socket (AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (sock == -1) {
    printf("initializing udp socket has error\n");
  }
  return sock;
}

int send_udp_data (int sock, char *data, int size, uint8_t *dst_mac, char *dst_ip) {
  struct sockaddr_in si_other;
  int slen = sizeof(si_other);

  memset((char *) &si_other, 0, sizeof(si_other));
  si_other.sin_family = AF_INET;
  si_other.sin_port = htons(BCAST_PORT);
  if (inet_aton(dst_ip, &si_other.sin_addr) == 0) {
    printf("inet_aton error\n");
  }

  // if the data is bigger than UDP_MAXPACKET=65507
  int start = 0;
  while (size > UDP_MAXPACKET) {
    if (sendto(sock, data+start, UDP_MAXPACKET, 0,
	       (struct sockaddr *)&si_other, slen) < 0) {
      printf("sendto error: errno = %d, %s\n", errno, strerror(errno));
      break;
    }
    start = start + UDP_MAXPACKET;
    size = size - UDP_MAXPACKET;
  }
  if (sendto(sock, data+start, size, 0,
	     (struct sockaddr *)&si_other, slen) < 0) {
      printf("sendto error: errno = %d, %s\n", errno, strerror(errno));
  }
}

int init_pcap (uint8_t mac[ETH_ALEN], char ip[32]) {
  struct bpf_program fp;      /* hold compiled program     */
  bpf_u_int32 netp, maskp;    /* ip                        */
  char errbuf[PCAP_ERRBUF_SIZE];  /* buffer to hold error text */
  char filter[1024];
  int ret;

  // set up filter rule
  strcpy(filter, "ether dst ");
  char mac_str[ETH_ZLEN];
  convert_mac_str(mac_str, mac);
  //strcpy(mac_str, "00:00:00:00:00:01");
  strcat(filter, mac_str);
  
  descr = pcap_open_live(ETHERNET_NAME, BUFSIZ, 1, -1, NULL);
  if (descr == NULL) {
    printf("error on pcap_open_live\n");
  }
  
  if (pcap_setnonblock(descr, 1, NULL) == -1) {
    printf("error on setnonblock\n");
  }

  /*
  if (pcap_lookupnet(if_name, &netp, &maskp, NULL) == -1) {
    printf("error on lookupnet\n");
  }
  */

  if (pcap_compile(descr, &fp, filter, 0, PCAP_NETMASK_UNKNOWN) == -1) {
    printf("error on pcap_compile\n");
  }
  
  if (pcap_setfilter(descr, &fp) == -1) {
    printf("error on pcap_setfilter\n");
  }
  
  pcap_freecode(&fp);
  
  //pcapFd = pcap_get_selectable_fd(descr);
  pcapFd = pcap_fileno(descr);
  if (pcapFd == -1) {
    printf("error on pcap_get_selectable_fd\n");
  }

  FD_ZERO(&fdRead);
  FD_SET(pcapFd, &fdRead);
}

int recv_data_with_pcap (void *data, int size,  uint8_t *dst_mac,
			 char *dst_ip, int rank, int start) {
  struct ip *iphdr;
  u_char *pkt_data;
  int data_size;
  int offset;
  
  select(FD_SETSIZE, &fdRead, NULL, NULL, NULL);
  if (FD_ISSET(pcapFd, &fdRead)) {
    struct pcap_pkthdr* pktHeader;
    const u_char* pktData;
    while (pcap_next_ex(descr, &pktHeader, &pktData) > 0) {
      iphdr = (struct ip *)(pktData+SIZE_ETHERNET);
      //offset = ntohs(iphdr->ip_off);
      offset = ntohs(iphdr->ip_off) & 0x1fff;
      //printf("rank %d: offset = %d\n", rank, offset);
      if (offset == 0) { // with UDP header
	data_size = ntohs(iphdr->ip_len) - HEADERS_LEN;
	memcpy(data+start, pktData+HEADERS_LEN+SIZE_ETHERNET, data_size);
      } else {
	data_size = ntohs(iphdr->ip_len) - IP4_HDRLEN;
	memcpy(data+start, pktData+IP4_HDRLEN+SIZE_ETHERNET, data_size);
      }
      start = start + data_size;
      //printf("rank %d: start = %d, offset = %d\n", rank, start, offset);
    }
    return start;
  }
  return -1;
}

int convert_mac_str (char mac_str[ETH_ZLEN], uint8_t mac_uint[ETH_ALEN]) {
  strcpy(mac_str, "");
  sprintf(mac_str, "%02x:%02x:%02x:%02x:%02x:%02x",
	  mac_uint[0], mac_uint[1], mac_uint[2],
	  mac_uint[3], mac_uint[4], mac_uint[5]);
}


void set_promisc_nic () {
  int sock;
  struct ifreq ifr;

  sock = init_raw_socket();

  memset(&ifr, 0, sizeof(ifr));

  strncpy(ifr.ifr_name, ETHERNET_NAME, strlen(ETHERNET_NAME));
  if (ioctl(sock, SIOCGIFFLAGS, &ifr) != 0) {
    printf("%s : error in ioctl\n", ETHERNET_NAME);
  }
  ifr.ifr_flags |= IFF_PROMISC;
  if (ioctl(sock, SIOCSIFFLAGS, &ifr) != 0) {
    printf("%s : error in ioctl\n", ETHERNET_NAME);
  }

  close(sock);
}

void get_nic_ip_addr () {
  int sock;
  struct ifreq ifr;

  sock = init_raw_socket();

  memset(&ifr, 0, sizeof(ifr));
  ifr.ifr_addr.sa_family = AF_INET;
  strncpy(ifr.ifr_name, ETHERNET_NAME, strlen(ETHERNET_NAME));

  ioctl(sock, SIOCGIFADDR, &ifr);
  strcpy(nic_ip, inet_ntoa(((struct sockaddr_in *)&ifr.ifr_addr)->sin_addr));
  
  close(sock);
}

void get_nic_index () {
  int sock;
  struct ifreq ifr;

  sock = init_raw_socket();

  memset(&ifr, 0, sizeof(ifr));
  strncpy(ifr.ifr_name, ETHERNET_NAME, strlen(ETHERNET_NAME));

  ioctl(sock, SIOGIFINDEX, &ifr);
  nic_index = ifr.ifr_ifindex; //if_nametoindex(if_name);
  
  close(sock);
}

int init_raw_socket() {
  int sock;
  sock = socket(AF_PACKET, SOCK_DGRAM, htons(ETH_P_IP));
}

/*
void bind_sock(int sock) {
  struct sockaddr_ll sll_me;

  sll_me.sll_family = AF_PACKET;
  sll_me.sll_protocol = htons(ETH_P_IP);
  sll_me.sll_ifindex = nic_index;
  bind(sock, (struct sockaddr *)&sll_me, sizeof(sll_me));
}

void setup_sll (struct sockaddr_ll *sll, uint8_t *dst_mac) {
  int i;
  
  memset(sll, 0, sizeof(sll));
  sll->sll_family = AF_PACKET;
  for (i=0; i<ETH_ALEN; i++)
    sll->sll_addr[i] = dst_mac[i];
  sll->sll_halen = ETH_ALEN;
  sll->sll_ifindex = nic_index;
  sll->sll_protocol = htons(ETH_P_IP);
}

void setup_ip_header (struct ip *iphdr, char *dst_ip) {
  iphdr->ip_hl = sizeof(struct ip) >> 2;
  iphdr->ip_v = IPVERSION;
  iphdr->ip_tos = 0;
  iphdr->ip_id = 0;
  iphdr->ip_ttl = IPDEFTTL;
  iphdr->ip_p = IPPROTO_UDP;
  inet_pton(AF_INET, nic_ip, &iphdr->ip_src);
  inet_pton(AF_INET, dst_ip, &iphdr->ip_dst);
}

void setup_udp_header (struct udphdr *udp) {
  udp->source = htons(BCAST_PORT);
  udp->dest   = htons(BCAST_PORT);
}

void setup_pseudo_header (struct pseudo_header *psh, char *dst_ip) {
  psh->source_address = inet_addr(nic_ip);
  psh->dest_address = inet_addr(dst_ip);
  psh->placeholder = 0;
  psh->protocol = IPPROTO_UDP;
}

void send_data (int sock, void *data, int size, uint8_t *dst_mac, char *dst_ip) {
  int current_sended_size, sending_size;

  current_sended_size = 0;

  while (current_sended_size < size) {
    if (UDP_MAXPACKET < size-current_sended_size) sending_size = UDP_MAXPACKET;
    else sending_size = size-current_sended_size;
    send_frame(sock, data+current_sended_size, sending_size, dst_mac, dst_ip);
    current_sended_size += sending_size;
  }
}

void send_frame (int sock, void *data, int size, uint8_t *dst_mac, char *dst_ip) {
  char frame[ETH_DATA_LEN];         // actual sending data frame
  
  struct sockaddr_ll sll;
  
  struct ip *iphdr;
  int ip_flag[4];
  
  struct udphdr *udp;

  setup_sll(&sll, dst_mac);

  iphdr = (struct ip *)frame;
  setup_ip_header(iphdr, dst_ip);

  udp = (struct udphdr *)(frame + IP4_HDRLEN);
  setup_udp_header(udp);

  char *pseudogram;
  pseudogram = malloc(sizeof(struct pseudo_header)+ETH_DATA_LEN-IP4_HDRLEN);
  struct pseudo_header psh;
  int psize;
  setup_pseudo_header(&psh, dst_ip);

  int start = 0, framesize;
  int data_size = 0;

  while (start < size) {
    if (start+UDP_FRAME > size) {
      ip_flag[0] = 0; // zero (1 bit)
      ip_flag[1] = 0; // do not fragment flag (1 bit)
      ip_flag[2] = 1; // more fragments following flag (1 bit)
      ip_flag[3] = 0; // fragmentation offset (13 bit)
      iphdr->ip_off = htons ((ip_flag[0] << 15)
			    + (ip_flag[1] << 14)
			    + (ip_flag[2] << 13)
			    + ip_flag[3]);
      //iphdr->ip_off = IP_MF;
      framesize = size-start+HEADERS_LEN;
    } else {
      ip_flag[0] = 0; // zero (1 bit)
      ip_flag[1] = 0; // do not fragment flag (1 bit)
      ip_flag[2] = 0; // more fragments following flag (1 bit)
      ip_flag[3] = 0; // fragmentation offset (13 bit)
      iphdr->ip_off = htons ((ip_flag[0] << 15)
			    + (ip_flag[1] << 14)
			    + (ip_flag[2] << 13)
			    + ip_flag[3]);
      //iphdr->ip_off = IP_DF;
      framesize = ETH_DATA_LEN;
    }
    data_size = framesize - HEADERS_LEN;

    iphdr->ip_id++;
    iphdr->ip_len = htons(framesize);
    iphdr->ip_sum = 0;
    iphdr->ip_sum = checksum((unsigned short *)iphdr, sizeof(struct ip));


    memcpy ( frame+HEADERS_LEN, data+start, data_size );

    udp->len=htons(data_size+UDP_HDRLEN);
    psh.udp_length = udp->len;
    udp->check = 0;
    psize = sizeof(struct pseudo_header) + UDP_HDRLEN + data_size;
    memcpy(pseudogram, (char*)&psh, sizeof(struct pseudo_header));
    memcpy(pseudogram + sizeof(struct pseudo_header),
	   frame+IP4_HDRLEN , sizeof(struct udphdr) + data_size);
    udp->check = udp_csum( (unsigned short*) pseudogram , psize);

    sendto(sock, frame, framesize, 0, (struct sockaddr *)&sll, sizeof(sll));
    start = start + framesize-HEADERS_LEN;
  }
  free(pseudogram);
  
}
int recv_data_nonblock (int sock, void *data, int size, uint8_t *dst_mac,
			char *dst_ip, int rank, int start) {
  int framesize;
  char frame[MTU];
  struct udphdr *udp;
  struct ip *iphdr;
  int data_size = 0;

  
  iphdr = (struct ip *)frame;
  udp = (struct udphdr *)(frame+IP4_HDRLEN);

  framesize = recvfrom (sock, frame, MTU, MSG_DONTWAIT, NULL, NULL);
  if (framesize != -1) {
    //printf("rank %d, frame size = %d\n", rank, framesize);
    if (iphdr->ip_p == IPPROTO_UDP) {
      if (udp->source == htons(BCAST_PORT)) {
	data_size = framesize - HEADERS_LEN;
	memcpy(data+start, frame+HEADERS_LEN, data_size);
	//printf("rank %d, frame size = %d\n", rank, framesize);
	start = start + data_size;
	return start;
      }
    }
  }
  return -1;
}

void recv_data (int sock, void *data, int size) {
  int frame_size, data_size;
  char frame[ETH_DATA_LEN];
  struct udphdr *udp;
  struct ip *iphdr;

  iphdr = (struct ip *)frame;
  udp = (struct udphdr *)(frame+IP4_HDRLEN);

  data_size = 0;
  while (data_size < size) {
    frame_size = recvfrom (sock, frame, ETH_DATA_LEN, 0, NULL, NULL);
    if (frame_size != -1)
    if (iphdr->ip_p == IPPROTO_UDP) {
      if (udp->source == htons(BCAST_PORT)) {
	frame_size = frame_size - HEADERS_LEN;
	memcpy(data+data_size, frame+HEADERS_LEN, frame_size);
	data_size = data_size + frame_size;
      }
    }
  }
}

void convert_mac_str_oct (char *mac_str, uint8_t *mac) {
  struct ether_addr e_addr;
  int i;
  
  ether_aton_r(mac_str, (struct ether_addr*)&e_addr);
  for (i=0; i<ETH_ALEN; i++)
    mac[i] = e_addr.ether_addr_octet[i];
}

unsigned short checksum(unsigned short *buf, int bufsz) { 
  unsigned long sum = 0; 
  while(bufsz > 1){
    sum += *buf; 
    buf++; 
    bufsz -= 2; 
  } 
  if (bufsz == 1){
    sum += *(unsigned char *)buf;
  }
  sum = (sum & 0xffff) + (sum >> 16); 
  sum = (sum & 0xffff) + (sum >> 16); 
  return ~sum;
}

unsigned short udp_csum(unsigned short *ptr,int nbytes) {
  register long sum;
  unsigned short oddbyte;
  register short answer;
 
  sum=0;
  while(nbytes>1) {
    sum+=*ptr++;
    nbytes-=2;
  }
  if(nbytes==1) {
    oddbyte=0;
    *((u_char*)&oddbyte)=*(u_char*)ptr;
    sum+=oddbyte;
  }
 
  sum = (sum>>16)+(sum & 0xffff);
  sum = sum + (sum>>16);
  answer=(short)~sum;
     
  return(answer);
}
*/

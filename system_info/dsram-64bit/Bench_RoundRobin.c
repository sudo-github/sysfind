/*

    DSRAM Benchmark
   =================

    This benchmark is a synthetic benchmark intended to create a DSRAM load on
   a system and collect statistics on the time it takes to perform a DSRAM. As
   a last minute inclusion, CPT pwerformance is also measured.

   The basic test uses a set of threads - each running on a separate board.
   These threads use a set of pages and "pass" them around. This is done by
   having each thread, at its turn, writing to the same set of pages.

   Such a set of threads we call a "chain". A chain of threads all run on the
   same numbered CPU on the boards (e.g. the first thread runs on CPU 1 on
   board 0, the seocnd thread in the chain runs on CPU 1 on board 1, etc).

   To allow for increased load on the system, multiple chains can be requested.
   For example: The first chain would run on CPU 0 on all boards, and the
   second chain will run on CPU1 on all boards and so on. The maximum number of
   chains allowed is the number of CPUs per board.

   By default only a single set of pages is passed between the threads of a
   chain. This means that at any given time, only one CPU on the chain is
   actively performing DSRAM, while the others are patiently waiting for their
   turn. Optionally the load on the system can be further increased by using
   multiple sets of pages in each chain. We call these sets of pages "streams".

   When multiple streams are requested, each chain has that number of page sets
   to work with. This measn that at any given point in time, with N streams, N
   cpus in each chain are busy performing DSRAM. The maximum number of streams
   allowed equals the maximum number of members in a chain - i.e. the number of
   boards in the system.

   Playing with the settings allows us to check the DSRAM and CPT performance
   at varying levels of load.


    Command line arguments:

      -c N    : Indicates the first CPU on the system to use.     Default = 0

      -l N    : Indicates the number of thread "chains" to use.   Default = 1

      -s N    : Indicates the number of "streams" to use.         Default = 1

      -b N    : Limit the number of boards to use.                Default = all

      -n N    : Indicates the number of CPUs in the system        Default = automatic

      -m N    : Indicates the number of CPUs per board            Default = automatic

      -o <name> : Specifies the name of the output file.      Default is stdout

      -p      : Indicates "prefetch" order (pages accessed in ascending order).

    Output:

   During the run, each thread saves its individual DSRAM timing information.
   At the end of the run, after all threads complete, statistics are calculated
   globally and specifically for each thread. The program writes out general
   information about the runtime environment followed by the general statistics
   and the general distribution table (timing based bucket counters which can
   be used to chart a graph of the DSRAM timing distribution). Finally the
   thread specific statistics and distribution tables (a.k.a. histograms) are
   written. Only sumnmary information is output related to CPT performance.

   To allow for "grep" of specific parts of the report, the global statistics
   lines are prefixed with "sls:" (system level summary). The global histogram
   is prefixed by "slh:" (system level histogram). The thread based statistics
   are prefixed by "cls:" (CPU level summary), and the thread specific
   histograms are prefixed by "clh:" (CPU level histogram).


    Special behavior:

   When multiple chains are used, the chains synchonize the work so that when
   a certain board is DSRAM active, the CPUs from all chains are active on
   that board.

   If the start CPU is not explicitly specified, the CPU binding is done from
   the last CPU on the board and downwards.


   17-APR-2009 Written by Tal Nevo            Copyright (c) 2009 ScaleMP Inc.

*/

#include <math.h>
#include <time.h>
#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <malloc.h>
#include <assert.h>
#include <stdlib.h>
#include <limits.h>
#include <string.h>
#include <unistd.h>
#include <getopt.h>
//#define __USE_GNU
//#include <sched.h>
#include <dirent.h>
#include <pthread.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/syscall.h>

/* To Allow up to 4096 we must override the existing affinity related
   structures, macroes and functions
*/
#ifdef CPU_SETSIZE
#undef CPU_SETSIZE
#endif
#define CPUS_PER_ITEM (8*sizeof(unsigned char))
#define CPU_SETSIZE (((4096+CPUS_PER_ITEM-1)/CPUS_PER_ITEM)*CPUS_PER_ITEM)

typedef struct vsmp_cpu_set {
    unsigned char b[CPU_SETSIZE/CPUS_PER_ITEM];
} vsmp_cpu_set_t;

#ifdef cpu_set_t
#undef cpu_set_t
#endif
#define cpu_set_t vsmp_cpu_set_t

#ifdef CPU_ZERO
#undef CPU_ZERO
#endif
#define CPU_ZERO(maskp) memset((maskp), 0, sizeof(cpu_set_t))

#ifdef CPU_SET
#undef CPU_SET
#endif
#define CPU_SET(cpu, maskp) (((cpu_set_t *)(maskp))->b[(cpu) / CPUS_PER_ITEM] |= (1 << ((cpu) % CPUS_PER_ITEM)))

#ifdef CPU_ISSET
#undef CPU_ISSET
#endif
#define CPU_ISSET(cpu, maskp) ((((cpu_set_t *)(maskp))->b[(cpu) / CPUS_PER_ITEM] & (1 << ((cpu) % CPUS_PER_ITEM))) != 0)

#define sched_setaffinity(pid, new_mask) syscall(SYS_sched_setaffinity,(pid),sizeof(cpu_set_t),(new_mask))
#define sched_getaffinity(pid, new_mask) syscall(SYS_sched_getaffinity,(pid),sizeof(cpu_set_t),(new_mask))


#define MAX_BOARDS      64
#define MAX_CPUS        256

#define PAGE_SIZE	4096
#define NUM_PAGES	2560
#define NUM_ITER	20
#define NUM_SAMPLES	(NUM_ITER*NUM_PAGES)
#define NUM_COPY	NUM_ITER
#define BUCKETS		(99+40+16+1)

#define IDLE_CHECK_COUNT	10000000
#define IDLE_CHECK_TIME		8000000.0	/* 8 seconds */
#define IDLE_MAX_STUCK		3

#define BSYNC_UNKNOWN	0
#define BSYNC_INIT	1
#define BSYNC_READY	2
#define BSYNC_DONE	3

#define STATUS_WAIT	10
#define STATUS_SYNC	11
#define STATUS_WORK	12
#define STATUS_SAVE	13
#define STATUS_DONE	20

#define DEBUG_NONE	0
#define DEBUG_MINIMUM	1
#define DEBUG_MEDIUM	2
#define DEBUG_MAXIMUM	3

#define DBG_PRINT(a)	{ if (debug_mode) { printf a; fflush(stdout); } }

#define FALSE (0)
#define TRUE  (1)

/* Type definitions and global variables */

typedef char page[PAGE_SIZE];

page startpad;
double cpu_period;
int debug_mode = DEBUG_NONE;
int boards = 0;
long ncpus = 0;
int cpus_per_board = 0;
int first_cpu = 999;
int cpu_specified = 0;
int use_boards = 0;
int num_streams = 1;
int load_stress = 1;
int do_cpt = 1;
int prefetch_order = 0;
int ignore_threads = 0;
int display_topology = 0;
page midpad;
volatile int all_threads_started = BSYNC_UNKNOWN;
page endpad;
double start_time, end_time;
double c_start_time, c_end_time;

typedef struct page_stream {
	page padding1;
	volatile int turn_counter;
	page padding2;
	page data[NUM_PAGES];
	page padding3;
} page_stream_t;

typedef struct results {
	long int count;
	int from, to, mean, eighty;
	double avg, min, max;
	double sum, sq_sum;
	double stddev, var, conf;
	int bucket[BUCKETS];
	unsigned long long int raw[NUM_SAMPLES];
	page padding;
} results_t;

typedef struct c_results {
	long int c_count;
	double c_avg, c_min, c_max, c_sum;
	unsigned long long int c_raw[NUM_COPY];
	page padding;
} c_results_t;

typedef struct board_sync {
	page padding1;
	volatile int action;
	volatile int status[MAX_CPUS];
	page padding2;
} board_sync_t;

board_sync_t bsync[MAX_BOARDS];

typedef struct chain {
	page padding1;
	int number;
	int cpu;
	page_stream_t *streams;
	results_t *times;
	c_results_t *c_times;
	page padding2;
} chain_t;

chain_t *chains;

typedef struct thread_data {
	page padding1;
	struct thread_data *allargs;
	chain_t *chain;
	page_stream_t *local, *remote;
	int board;
	volatile int status;
	volatile int stream_no;
	volatile int sample_no;
	int dbg_stream[NUM_ITER];
	int dbg_counter[NUM_ITER];
	double current_time;
	double wait_time;
	double sync_time;
	double active_time;
} thread_data_t ;

/* Build page access permutation */

#define EMPTY (-1)
#define PERMUTE_MAX (NUM_PAGES*4/3)
int permutable[PERMUTE_MAX+1];

void build_permutation_table(void)
{
    unsigned int i, p;

    srand(987654321);

    for (i = 0; i < PERMUTE_MAX; i++)
        permutable[i] = EMPTY;
    // Fill hash with entries
    for (p = 0 ; p < NUM_PAGES; p++) {
        i = rand() % PERMUTE_MAX;
        while (permutable[i] != EMPTY) {
            i++;
            if (i >= PERMUTE_MAX)
                i = 0;
        }
        permutable[i] = p;
    }
    p = 0;
    // Compress hash into permutation table
    for (i = 0; i < PERMUTE_MAX; i++) {
        if (permutable[i] != EMPTY)
            permutable[p++] = permutable[i];
    }
}

/* Bucket handling */

int bucket_break[BUCKETS];

void build_buckets(void)
{
	int i;

	for (i=0; i < 99; i++)
		bucket_break[i] = i+1;
	for (i=0; i < 40; i++)
		bucket_break[i+99] = 100 + i * 10;
	for (i=0; i < 16; i++)
		bucket_break[i+139] = 500 + i * 100;
	bucket_break[BUCKETS-1] = INT_MAX;
}

int bucket_number(double _uS)
{
	int uS = _uS;
	int i;
	for( i = 0; uS >= bucket_break[i]; i++ ) {}
	return(i);
}

/* Reading the CPU clock */

static __inline__ unsigned long long int read_tsc(void)
{
	unsigned int upper, lower;
        __asm__ __volatile__ ("rdtsc" : "=a"(lower), "=d"(upper));
        return (unsigned long long)(lower)|((unsigned long long)(upper)<<32 );
}

static __inline__ double timeofday(void)
{
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return (double)tv.tv_sec + 1e-6 * tv.tv_usec;
}

/*
 * Detect vSMP Foundation
 */

#define PCI_LOOKUP "/sys/bus/pci/devices/"
#define SCALEMP_PCI_ID "0x8686\n"

int is_vsmp_foundation(void)
{
        int fd;
	DIR *dirp;
	int found = 0;
	char name[256];
	char buffer[256];
	struct dirent *direntp;

	buffer[0] = 0;
	dirp = opendir(PCI_LOOKUP);
	if (dirp != NULL) {
		while ((direntp = readdir(dirp)) != NULL && !found) {
			sprintf(name, PCI_LOOKUP "%s/vendor", direntp->d_name);
			fd = open(name, O_RDONLY);
			if (fd > -1) {
        			read(fd, buffer, sizeof(buffer));
				close(fd);
				found = (strcmp(SCALEMP_PCI_ID, buffer) == 0);
			}
		}
		closedir(dirp);
	}
	return found;
}

/*
 * Parse NUMA topology
 */
#define STARTING_DIRECTORY "/sys/devices/system/node/"
#define BOARD_DISTANCE_THREASHOLD 200

static int numa_parsed = 0;
static int numa_node_count = 0;
static int *numa_node_num;
static int *numa_node_index;
static int **numa_node_distances;
static int **numa_node_cpus;
static int *numa_node_cpu_count;
static int *numa_node_board;
static int numa_cpu_count = 0;
static int *numa_cpu_num;

static int numa_boards = 0;
static int numa_cpus_per_board = 0;
static int *cpu_map;

int numa_read_list(char *filename, int **result)
{
	char c;
	int mode;
	int number[2];
	int count = 0;
	int size = 0;
	int *list = NULL;

	*result = NULL;
	FILE *fp = fopen(filename,"r");
	if (fp == NULL)
		return count;

	mode = -1;
	number[0] = number[1] = 0;
	while ((c = fgetc(fp)) != 0 && !feof(fp)) {
		if (c >= '0' && c <= '9') {
			if (mode < 0)
				mode = 0;
			number[mode] = number[mode] * 10 + (c - '0');
		}
		else if (c == '-') {
			if (mode != 0) {
				fprintf(stderr, "ERROR: error parsing range in list in %s\n",filename);
				exit(1);
			}
			mode = 1;
		}
		else if (mode >= 0) {
			if (mode == 0)
				number[1] = number[0];
			for (;number[0] <= number[1]; number[0]++) {
				if (count == size) {
					size += 16;
					list = (count == 0) ? malloc(sizeof(int) * size)
							    : realloc(list, sizeof(int) * size);
					if (list == NULL) {
						fprintf(stderr, "ERROR: unable to allocate memory for topology.\n");
						exit(1);
					}
				}
				list[count++] = number[0];
			}
			mode = -1;
			number[0] = number[1] = 0;
		}
	}

	fclose(fp);
	*result = list;
	return count;
}

int folder_exists(char *path)
{
	int ret_val = 0;
	DIR *dir = opendir(path);

	if (dir) {
		ret_val = 1;
		closedir(dir);
	}

	return ret_val;
}

void fill_one_numa_node_info()
{
	int *list;
	numa_node_num = calloc(1,sizeof(int));
	numa_node_index = calloc(1,sizeof(int));
	numa_node_distances = calloc(1,sizeof(int *));
	numa_node_cpus = calloc(1,sizeof(int *));
	numa_node_cpu_count = calloc(1,sizeof(int));
	if (numa_node_num == NULL || numa_node_index == NULL || numa_node_distances == NULL ||
	    numa_node_cpus == NULL || numa_node_cpu_count == NULL) {
		fprintf(stderr, "ERROR: unable to allocate numa data structures.\n");
		exit(1);
	}

	numa_node_index[0] = 0;
	numa_node_num[0] = 0;
	numa_node_distances[0] = calloc(1,sizeof(int));
	if (numa_node_distances[0] == NULL) {
		fprintf(stderr, "ERROR: unable to allocate numa data structures.\n");
		exit(1);
	}
	numa_node_distances[0][0] = 10;
	numa_node_count = 1;

	numa_cpu_count = numa_read_list("/sys/devices/system/cpu/online", &list);
	numa_cpu_num = list;

	numa_node_cpus[0] = list;
	numa_node_cpu_count[0] = numa_cpu_count;

	numa_parsed = 1;
}

void parse_numa(void)
{
	int i;
	int last;
	int count;
	int *list;
	char filename[256];

	if (!folder_exists(STARTING_DIRECTORY)) {
		fill_one_numa_node_info();
		return;
	}

	count = numa_read_list(STARTING_DIRECTORY "online", &list);
	if (count == 0) {
		fprintf(stderr, "ERROR: unable to parse NUMA topology.\n");
		exit(1);
	}
	last = list[count-1];
	free(list);
	numa_node_num = calloc(last+1,sizeof(int));
	numa_node_index = calloc(last+1,sizeof(int));
	numa_node_distances = calloc(last+1,sizeof(int *));
	numa_node_cpus = calloc(last+1,sizeof(int *));
	numa_node_cpu_count = calloc(last+1,sizeof(int));
	if (numa_node_num == NULL || numa_node_index == NULL || numa_node_distances == NULL || numa_node_cpus == NULL || numa_node_cpu_count == NULL) {
		fprintf(stderr, "ERROR: unable to allocate numa data structures.\n");
		exit(1);
	}
	for (i = 0; i <= last; i++)
		numa_node_index[i] = -1;

	for (i = 0; i <= last; i++) {
		sprintf(filename, STARTING_DIRECTORY "node%d/distance", i);
		count = numa_read_list(filename, &list);
		if (count > 0) {
			numa_node_index[i] = numa_node_count;
			numa_node_num[numa_node_count] = i;
			numa_node_distances[numa_node_count] = list;
			sprintf(filename, STARTING_DIRECTORY "node%d/cpulist", i);
			count = numa_read_list(filename, &list);
			numa_node_cpus[numa_node_count] = list;
			numa_node_cpu_count[numa_node_count] = count;
			numa_node_count++;
			if (display_topology) {
			    int k;
			    fprintf(stderr, "NUMA node %d (%d CPUs):", i, count);
			    for (k = 0; k < count; k++)
        			    fprintf(stderr, " %d", list[k]);
			    fprintf(stderr, "\n");
			}
		}
	}

	numa_cpu_count = numa_read_list(STARTING_DIRECTORY "../cpu/online", &list);
	numa_cpu_num = list;

	numa_parsed = 1;
}

int numa_max_node(void)
{
	if (!numa_parsed)
		parse_numa();
	return numa_parsed ? numa_node_num[numa_node_count-1] : -1;
}

int numa_max_cpu(void)
{
	if (!numa_parsed)
		parse_numa();
	return numa_parsed ? numa_cpu_num[numa_cpu_count-1] : -1;
}

int numa_distance(int node1, int node2)
{
	int true1, true2;

	if (!numa_parsed)
		parse_numa();
	true1 = numa_node_index[node1];
	true2 = numa_node_index[node2];
	return (true1 != -1 && true2 != -1) ? numa_node_distances[true1][true2] : 0;
}

int remove_threads(void)
{
        int i, j;
	int index;
	int *list;
	int count;
	char *seen;
	char filename[256];
	int cpus = numa_cpu_num[numa_cpu_count-1]+1;

	if ((seen = calloc(cpus, sizeof(char))) == NULL) {
        	fprintf(stderr, "ERROR: unable to allocate numa data structures.\n");
		exit(1);
	}

	for (i = 0; i < numa_node_count; i++) {
        	index = 0;
		memset(seen, 0, cpus);
		for (j = 0; j < numa_node_cpu_count[i]; j++) {
			sprintf(filename, "/sys/devices/system/cpu/cpu%d/topology/thread_siblings_list", numa_node_cpus[i][j]);
			count = numa_read_list(filename, &list);
			if (count > 0 && seen[list[0]] == 0) {
        			seen[list[0]] = 1;
        			numa_node_cpus[i][index++] = list[count-1];
			}
			if (list != NULL)
        			free(list);
		}
		numa_node_cpu_count[i] = index;
	}
}

// Looking only on boards with CPUs
int parse_boards(void)
{
        int i,j,k;
        int last;
	int cpus;
	int count;
	int max_cpus = 0;
	int min_cpus = 0;
	int board = 0;
	if (!numa_parsed)
		parse_numa();

	if (ignore_threads)
        	remove_threads();

	if (numa_node_count == 0) {
		fprintf(stderr, "ERROR: No NUMA topology.\n");
		exit(1);
	}

	last = numa_node_num[numa_node_count-1];
	numa_node_board = calloc(last+1, sizeof(int));
	if (numa_node_board == NULL) {
		fprintf(stderr, "ERROR: unable to allocate numa data structures.\n");
		exit(1);
	}
	for (i = 0; i <= last; i++)
        	numa_node_board[i] = -1;

	board = 0;
	for (i = 0; i <= last; i++) {
        	if (numa_node_index[i] == -1 || numa_node_board[i] != -1 || numa_node_cpu_count[numa_node_index[i]] == 0)
        		continue;
		if (use_boards > 0 && use_boards <= board) {
			//fprintf(stderr, "WARNING: Not using all boards.\n")
        		break;
		}
		cpus = 0;
        	for (j = i; j <= last; j++) {
        		if (numa_node_index[j] == -1 || numa_node_board[j] != -1 || numa_node_cpu_count[numa_node_index[j]] == 0)
        			continue;
			if (numa_distance(i,j) < BOARD_DISTANCE_THREASHOLD) {
        			numa_node_board[j] = board;
				cpus += numa_node_cpu_count[numa_node_index[j]];
			}
		}
		if (cpus > max_cpus)
        		max_cpus = cpus;
		if (min_cpus == 0)
        		min_cpus = cpus;
		else if (min_cpus > cpus)
        		min_cpus = cpus;
		board++;
	}
	if (display_topology) {
        	fprintf(stderr, "%d board%s with %d CPUs", board, board > 1 ? "s" : "", min_cpus);
		if (board > 1)
        		fprintf(stderr, " each");
		if (min_cpus != max_cpus)
			fprintf(stderr, " (max %d)", max_cpus);
		fprintf(stderr, "\n");
	}
	if (board <= 1) {
        	fprintf(stderr, "ERROR: Insufficient number of boards - at least two are required.\n");
		exit(1);
	}
	if (min_cpus != max_cpus) {
        	fprintf(stderr, "WARNING: Non uniform topology. Using CPUs per board based on board with least CPUs.\n");
	}
	// Now build CPU MAP
	cpu_map = calloc(min_cpus * board, sizeof(int));
	if (cpu_map == NULL) {
		fprintf(stderr, "ERROR: unable to allocate numa data structures.\n");
		exit(1);
	}
	count = 0;
	for (i = 0; i < board; i++) {
        	cpus = 0;
		for (j = 0; j <= last; j++) {
        		if (numa_node_board[j] == i) {
        			for (k = 0; k < numa_node_cpu_count[numa_node_index[j]] && k + cpus < min_cpus; k++) {
        				cpu_map[count++] = numa_node_cpus[numa_node_index[j]][k];
				}
				cpus += k;
			}
		}
	}

	if (display_topology) {
        	for (i = 0; i < board; i++) {
			fprintf(stderr, "Board %d (nodes",i);
			for (j = 0; j <= last; j++) {
        			if (numa_node_board[j] == i)
        				fprintf(stderr, " %d", j);
			}
			fprintf(stderr, ") :");
			for (k = 0; k < min_cpus; k++)
        			fprintf(stderr, " %d", cpu_map[i * min_cpus + k]);
			fprintf(stderr, "\n");
		}
		exit(0);
	}

        numa_boards = board;
	numa_cpus_per_board = min_cpus;
	return board;
}

/* General information gathering functions */

void get_cmd_string(char *cmd, char *buf, int size, int oneline)
{
	int i, c;
	FILE *pipe = popen( cmd, "r" );

	if (pipe == NULL) {
		fprintf(stderr,"Unable to read from cmd:\"%s\"\n", cmd);
		exit(1);
	}

	buf[0] = '\0';
	for (i = 0; i < size; i++) {
		if ((c = fgetc(pipe)) < 0 || (oneline && c == '\n')) {
			buf[i] = '\0';
			break;
		}
		else
			buf[i] = c;
	}
	buf[size-1] = '\0';
	pclose(pipe);
	return;
}

#define get_cpuid(func,eax,ebx,ecx,edx)\
	__asm__ __volatile__ ("cpuid":\
	"=a" (eax), "=b" (ebx), "=c" (ecx), "=d" (edx) : "a" (func));

double get_cpu_mhz()
{
	static double cpu_mhz = 0;

	if (cpu_mhz != 0)
		return cpu_mhz;

#ifdef OBOLETE
        char buf[100];

	get_cmd_string("grep 'cpu MHz' /proc/cpuinfo | head -1 | awk '{print $4}'", buf, 100, TRUE );

        if( sscanf(buf, "%lf", &cpu_mhz) != 1 ) {
                fprintf(stderr,"Cannot get 'cpu MHz' from /proc/cpuinfo\n");
                exit(1);
        }
#else
	unsigned int eax, ebx, ecx, edx;
	get_cpuid(0, eax, ebx, ecx, edx);
	// SkyLake and above support getting base frequency from CPU
	if (eax >= 0x16) {
		get_cpuid(0x16, eax, ebx, ecx, edx);
		cpu_mhz = eax;
	}
	else {
		double stime, etime;
		unsigned long long before, after;
		cpu_set_t cpu_mask;
		CPU_ZERO(&cpu_mask);
		CPU_SET( 0 , &cpu_mask);
		sched_setaffinity( 0, &cpu_mask );
		do {
			stime = timeofday();
			before = read_tsc();
			sleep(1);
			after = read_tsc();
			etime = timeofday();
		} while (after < before);
		cpu_mhz = (after - before) / (etime - stime) / 1e6;
	}
#endif
        return(cpu_mhz);
}

int get_num_boards()
{
	int nboards = 0;
	static char buf[100] = "";

	if (strlen(buf) == 0)
		get_cmd_string( "vsmpctl --boards", buf, 100, TRUE );

	if( sscanf(buf, "%d", &nboards) != 1 ) {
		fprintf(stderr,"Cannot get number of boards\n");
		exit(1);
	}
	return nboards;
}

char *get_kernel()
{
	static char kernel[256] = "";

	if (strlen(kernel) == 0)
		get_cmd_string( "uname -r", kernel, 256, TRUE );

	return kernel;
}

char *get_vsmp_longversion()
{
	static char vsmp[25600] = "";

	if (strlen(vsmp) == 0)
		get_cmd_string( "vsmpversion", vsmp, 25600, FALSE );

	return vsmp;
}

/* old - obsolete */
char *get_vsmpversion()
{
	static char vsmp[256] = "";

	if (strlen(vsmp) == 0)
		get_cmd_string( "vsmpversion | grep 'vSMP Foundation' | awk '{print $3}'", vsmp, 256, TRUE );

	return vsmp;
}

/* old - obsolete */
char *get_cpu_string()
{
	static char cpuid[256] = "";

	if (strlen(cpuid) == 0)
		get_cmd_string( "grep 'model name' /proc/cpuinfo | head -1 | cut -d : -f 2", cpuid, 256, TRUE );

	return cpuid;
}

/* old - obsolete */
char *get_vsmp_total_memory()
{
	static char total[100] = "";

	if (strlen(total) == 0)
		get_cmd_string( "vsmpversion | grep 'Total memory' | awk '{print $3}'", total, 100, TRUE );

	return total;
}

/* old - obsolete */
char *get_vsmp_memory()
{
	static char memory[100] = "";

	if (strlen(memory) == 0)
		get_cmd_string( "vsmpversion | grep 'System memory' | awk '{print $3}'", memory, 100, TRUE );

	return memory;
}

/* old - obsolete */
int get_sockets()
{
	int sockets;
	static char buf[100] = "";

	if (strlen(buf) == 0)
		get_cmd_string("vsmpversion | grep 'Processors' | awk '{print $2}'", buf, 100, TRUE );

	if (sscanf(buf, "%d", &sockets) != 1) {
		fprintf(stderr, "Unable to find system configuration (sockets)\n");
		exit(1);
	}

	return sockets;
}

/* old - obsolete */
int get_cores()
{
	static int cores = 0;
	static int threads = 1;
	static char buf[100] = "";

	if (strlen(buf) == 0) {
		get_cmd_string("vsmpversion | grep 'Processors' | cut -d : -f 3 | cut -d \\) -f 1", buf, 100, TRUE );

		if (strlen(buf) >= 10) {
			get_cmd_string("vsmpversion | grep 'Processors' | cut -d : -f 4 | cut -d \\) -f 1", buf, 100, TRUE );

			if (sscanf(buf, "%d", &threads) != 1) {
				fprintf(stderr, "Unable to find system configuration (threads)\n");
				exit(1);
			}
			get_cmd_string("vsmpversion | grep 'Processors' | cut -d : -f 3 | cut -d , -f 1", buf, 100, TRUE );
		}
		if (sscanf(buf, "%d", &cores) != 1) {
			/* Old CPUs have no cores or threads specified - must check for that too */
			get_cmd_string("vsmpversion | grep 'Processors' | grep cores | wc -l", buf, 100, TRUE );
			if (sscanf(buf, "%d", &cores) == 1 && cores == 0) {
				cores = 1;
			}
			else {
				fprintf(stderr, "Unable to find system configuration (cores)\n");
				exit(1);
			}
		}
	}
	return cores * threads;
}

/* old - obsolete */
int get_vsmp_cpus()
{
	return get_sockets() * get_cores();
}

char *get_host()
{
	static char hostname[100] = "";

	if (strlen(hostname) == 0)
		get_cmd_string( "hostname | sed 's/[-_]/ /' | awk '{print $1}'", hostname, 100, TRUE );

	return hostname;
}

long get_cpus()
{
	return sysconf(_SC_NPROCESSORS_CONF);
}

/* Thread assistance functions */

int pin_thread_to_cpu(int cpu, int thread_number)
{
	int rc;
	int shift = thread_number * cpus_per_board;
	int cpu_number = cpu + shift;

	if ( ! cpu_specified )
		cpu_number = (cpus_per_board - 1 - cpu) + shift;
        cpu_set_t cpu_mask;
        CPU_ZERO(&cpu_mask);
        CPU_SET( cpu_map[cpu_number], &cpu_mask);

        if ((rc = sched_setaffinity( 0, &cpu_mask )) != 0) {
		fprintf(stderr, "Error (%d) setting affinity to CPU %d\n", errno, cpu_map[cpu_number]);
        	abort();
	}
	return cpu_number;
}

static inline void clflush(volatile void *__p)
{
	asm __volatile__ (
		"mfence\n\t"
		"clflush (%0)"
		: : "r" (__p));
}

void board_sync_barrier(int cpu, int board)
{
	int i,j,count;
	int c = cpu % cpus_per_board;
	if (cpu == first_cpu) {
		bsync[board].status[c] = BSYNC_INIT;
		bsync[board].action = BSYNC_INIT;
		clflush(&bsync[board].action);
		/* Wait for all cpus to be ready */
		do {
			//sched_yield();
			count = 0;
			for (i = 0; i < load_stress; i++)
				if (bsync[board].status[c + i] == BSYNC_INIT || bsync[board].status[c + i] == BSYNC_DONE)
					count++;
		} while (count < load_stress);
		/* Give the go-ahead */
		bsync[board].status[c] = BSYNC_READY;
		bsync[board].action = BSYNC_READY;
		clflush(&bsync[board].action);
		/* Wait for all others to start */
		do {
			count = 0;
			for (i = 0; i < load_stress; i++)
				if (bsync[board].status[c + i] == BSYNC_READY || bsync[board].status[c + i] == BSYNC_DONE)
					count++;
		} while (count < load_stress);
	}
	else {
		/* Wait for 1st to enter barrier */
		while ( bsync[board].action != BSYNC_INIT) {
			if (bsync[board].action == BSYNC_DONE)
				return;
		}
		bsync[board].status[c] = BSYNC_INIT;
		clflush(&bsync[board].status[c]);
		/* Wait for the go-ahead */
		while ( bsync[board].action != BSYNC_READY) { }
		bsync[board].status[c] = BSYNC_READY;
		clflush(&bsync[board].status[c]);
	}
}

void board_sync_done(int cpu, int board)
{
	bsync[board].status[cpu % cpus_per_board] = BSYNC_DONE;
	clflush(&bsync[board].status[cpu % cpus_per_board]);
	if (cpu == first_cpu)
		bsync[board].action = BSYNC_DONE;
}

void my_copy(page *dst, page *src, long size)
{
	dst = (page *)(((unsigned long)dst) & ~0xFFF);
	src = (page *)(((unsigned long)src) & ~0xFFF);
	size *= PAGE_SIZE;

	long c1,d1,s1;
	asm __volatile__ (
		"cld\n\t"
		"rep\n\t"
		"movsb"
		: "=&D" (d1), "=&S" (s1), "=&c" (c1)
		: "0" (dst), "1" (src), "2" (size)
		: "cc", "memory" );
}

/* Actual DSRAM thread function */

void *thread_dsram_routine(void *param)
{
	FILE *dbgf = (FILE *)NULL;
	int got_stuck = 0;
	int stuck_count = 0;
	int real_counter = 0;

	results_t *localres;
	double delta;
	int i, j, b, cpu;
	int my_stream;
	unsigned long long int before, after;
	unsigned long long int idle_time, idle_count;
	unsigned long long int *samples;
	thread_data_t *arg = (thread_data_t *)param;
	int thread_number = arg->board;
	chain_t *chain = arg->chain;
	page_stream_t *streams = chain->streams;
	results_t *times = chain->times;
	thread_data_t dbg;

	cpu = pin_thread_to_cpu( chain->cpu, thread_number );

	samples = calloc(NUM_PAGES, sizeof(*samples));
	localres = calloc(1, sizeof(*localres));

	localres->to = cpu;
	if (thread_number == 0)
		localres->from = cpu + (boards - 1) * cpus_per_board;
	else
		localres->from = cpu - cpus_per_board;

	if (thread_number < num_streams) {
		i = num_streams - thread_number - 1;
		for (j = 0; j < NUM_PAGES; j++)
			streams[i].data[j][0] = '\0';
		streams[i].turn_counter = thread_number + 1;
		my_stream = (i + 1) % num_streams;
	}
	else
		my_stream = 0;

	/* Wait for all threads to be up and running before continuing */
	while ( all_threads_started != BSYNC_INIT ) { sleep(1); }
	arg->status = BSYNC_INIT;
	clflush(&arg->status);
	while ( all_threads_started != BSYNC_READY) {}

	arg->stream_no = my_stream;

	for( i = 0; i < NUM_SAMPLES; i += NUM_PAGES ) {
		arg->status = STATUS_WAIT;
		arg->sample_no = i / NUM_PAGES;
		arg->dbg_stream[arg->sample_no] = my_stream;
		arg->dbg_counter[arg->sample_no] = streams[my_stream].turn_counter;
		idle_count = 0;
		idle_time = read_tsc();
		while( (streams[my_stream].turn_counter % boards) != thread_number ) {
			if (++idle_count > IDLE_CHECK_COUNT) {
				after = read_tsc();
				if ((after - idle_time) * cpu_period > IDLE_CHECK_TIME) {
					if (dbgf == NULL) {
						char name[100];
						sprintf(name, "dbg%d-%d-%d.txt", getpid(), chain->number, thread_number);
						dbgf = fopen(name, "w");
					}
					int k, problem = streams[my_stream].turn_counter % boards;
					memcpy(&dbg, &arg->allargs[chain->number * boards + problem], sizeof(dbg));
					fprintf(stderr, "P%d (cpu %d) thread %d waiting for stream %d (at %d) ->%d\n",
						getpid(), cpu_map[chain->cpu], thread_number, my_stream, problem, i / NUM_PAGES);
					fprintf(stderr, "====>>> %d is now at %d on stream %d\n",
						problem, dbg.status, dbg.stream_no);
					fprintf(dbgf, "P%d (cpu %d) thread %d waiting for stream %d (at %d) ->%d\n",
						getpid(), cpu_map[chain->cpu], thread_number, my_stream, problem, i / NUM_PAGES);
					fprintf(dbgf, "====>>> %d is now at %d on stream %d\n",
						problem, dbg.status, dbg.stream_no);
					for (j = 0; j < boards; j++) {
						memcpy(&dbg, &arg->allargs[chain->number * boards + j], sizeof(dbg));
						fprintf(dbgf, "\n-> %d (%2d : %3d)\n--->", dbg.board, dbg.status, dbg.sample_no);
						for (k = 0; k < NUM_ITER; k++)
							fprintf(dbgf, "\t%d", dbg.dbg_stream[k]);
						fprintf(dbgf, "\n--->");
						for (k = 0; k < NUM_ITER; k++)
							fprintf(dbgf, "\t%d", dbg.dbg_counter[k]);
					}
					fprintf(dbgf, "\n===>");
					for (j = 0; j < num_streams; j++)
						fprintf(dbgf, "\t%d", streams[j].turn_counter);
					fprintf(dbgf, "\n\n");
					idle_time = after;
					if (stuck_count++ > IDLE_MAX_STUCK) {
						got_stuck = 1;
						break;
					}
				}
				idle_count = 0;
			}
		}

		if (got_stuck)
			break;

		stuck_count = 0;
		arg->dbg_counter[arg->sample_no] = streams[my_stream].turn_counter;

		arg->status = STATUS_SYNC;
		board_sync_barrier(chain->cpu, thread_number);
		arg->status = STATUS_WORK;

		/* Measure DSRAM speed */
		if (prefetch_order) {
			for (j = 0; j < NUM_PAGES; j++) {
				before = read_tsc();
				streams[my_stream].data[j][0] = '\0';
				after = read_tsc();
				samples[j] = after - before;
			}
		}
		else {
			for (j = 0; j < NUM_PAGES; j++) {
				before = read_tsc();
				streams[my_stream].data[permutable[j]][0] = '\0';
				after = read_tsc();
				samples[j] = after - before;
			}
		}
		arg->status = STATUS_SAVE;
		streams[my_stream].turn_counter++;
		clflush(&streams[my_stream].turn_counter);
		arg->stream_no = my_stream = (my_stream + 1) % num_streams;

		for (j = 0; j < NUM_PAGES; j++)
			if (i+j < NUM_SAMPLES)
				localres->raw[i+j] = samples[j];
	}

	memcpy(times + thread_number, localres, sizeof(*localres));

	board_sync_done(chain->cpu, thread_number);
	arg->status = STATUS_DONE;

	if (dbgf != NULL)
		fclose(dbgf);

	free(samples);
	free(localres);
}

/* Actual CPT Thread function */

void *thread_cpt_routine(void *param)
{
	int got_stuck = 0;
	int stuck_count = 0;
	int real_counter = 0;

	c_results_t* localres;
	double delta;
	int i, j, b, cpu;
	int my_stream;
	unsigned long long int before, after;
	unsigned long long int idle_time, idle_count;
	thread_data_t *arg = (thread_data_t *)param;
	int thread_number = arg->board;
	chain_t *chain = arg->chain;
	page_stream_t *streams = chain->streams;
	c_results_t *c_times = chain->c_times;
	page_stream_t *localbuf = arg->local;
	page_stream_t *remotebuf = arg->remote;

	pin_thread_to_cpu( chain->cpu, thread_number );

	localres = calloc(1, sizeof(*localres));

	memset(localbuf[0].data, 0, sizeof(localbuf[0].data));
	memset(localbuf[1].data, 0, sizeof(localbuf[1].data));

	if (thread_number < num_streams) {
		i = num_streams - thread_number - 1;
		streams[i].turn_counter = thread_number + 1;
		my_stream = (i + 1) % num_streams;
	}
	else
		my_stream = 0;

	/* Wait for all threads to be up and running before continuing */
	while ( all_threads_started != BSYNC_INIT ) { sleep(1); }
	arg->status = BSYNC_INIT;
	clflush(&arg->status);
	while ( all_threads_started != BSYNC_READY) {}

	for( i = 0; i < NUM_COPY; i++ ) {

		idle_count = 0;
		idle_time = read_tsc();
		while( (streams[my_stream].turn_counter % boards) != thread_number ) {
			if (++idle_count > IDLE_CHECK_COUNT) {
				after = read_tsc();
				if ((after - idle_time) * cpu_period > IDLE_CHECK_TIME) {
					fprintf(stderr, "P%d (cpu %d) thread %d waiting for CPT stream %d (at %d) ->%d\n",
						getpid(), cpu_map[chain->cpu], thread_number, my_stream,
						streams[my_stream].turn_counter % boards, i);
					idle_time = after;
					if (stuck_count++ > IDLE_MAX_STUCK) {
						got_stuck = 1;
						break;
					}
				}
				idle_count = 0;
			}
		}

		if (got_stuck)
			break;

		stuck_count = 0;

		board_sync_barrier(chain->cpu, thread_number);

		/* Measure CPT speed */
		before = read_tsc();
		my_copy(localbuf[1].data, remotebuf->data, NUM_PAGES);
		after = read_tsc();
		localres->c_raw[i] = after - before;

		streams[my_stream].turn_counter++;
		clflush(&streams[my_stream].turn_counter);
		my_stream = (my_stream + 1) % num_streams;
	}

	memcpy(c_times + thread_number, localres, sizeof(*localres));

	board_sync_done(chain->cpu, thread_number);

	free(localres);
}

/* Thread distribution */

void test_once(chain_t *chains)
{
	void *voidp;
	pthread_attr_t attr;
	pthread_t thread_arr[MAX_BOARDS*MAX_CPUS];
	thread_data_t* args;

	int i,j,k,ptrc;

	pthread_attr_init(&attr);
	pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
	pthread_attr_setstacksize(&attr, 16*1024*1024);

	args = calloc(MAX_BOARDS*MAX_CPUS+1, sizeof(*args));
	/* Initialize data */
	memset(bsync, 0, sizeof(bsync));
	for (i = 0; i < load_stress; i++) {
		chain_t *chain = chains + i;

		chain->number = i;
		chain->cpu = first_cpu + i;
		chain->times = (results_t *)malloc(boards * sizeof(results_t));
		assert(chain->times);
		memset(chain->times, 0, boards * sizeof(results_t));
		chain->c_times = (c_results_t *)malloc(boards * sizeof(c_results_t));
		assert(chain->c_times);
		memset(chain->c_times, 0, boards * sizeof(c_results_t));
		chain->streams = (page_stream_t *)malloc(num_streams * sizeof(page_stream_t));
		assert(chain->streams);
		memset(chain->streams, 0, num_streams * sizeof(page_stream_t));

		for (j = 0; j < boards; j++) {
			thread_data_t *arg = args + (i * boards + j);
			if (j < num_streams)
				chain->streams[j].turn_counter = j;
			arg->allargs = args;
			arg->chain = chain;
			arg->board = j;
			arg->local = (page_stream_t *)malloc(2 * sizeof(page_stream_t));
			assert(arg->local);
			memset(arg->local, 0, 2 * sizeof(page_stream_t));
			if (j > 0)
				arg->remote = args[i * boards + j - 1].local;
			arg->wait_time = 0;
			arg->sync_time = 0;
			arg->active_time = 0;
		}
		args[i * boards].remote = args[i * boards + j - 1].local;
	}

	/* DSRAM measurement threading */

	for (i = 0; i < load_stress * boards; i++) {
		ptrc = pthread_create( &thread_arr[i], &attr, thread_dsram_routine, (void *)(args + i));
		assert(ptrc == 0);
	}

	all_threads_started = BSYNC_INIT;
	clflush(&all_threads_started);
	do {
		j = 0;
		for (i = 0; i < load_stress * boards; i++)
			if (args[i].status == BSYNC_INIT)
				j++;
	} while (j < load_stress * boards);
	all_threads_started = BSYNC_READY;
	clflush(&all_threads_started);

	start_time = timeofday();

	for (i = 0; i < load_stress * boards; i++) {
		pthread_join( thread_arr[i], &voidp );
	}

	end_time = timeofday();

	/* CPT measurement threading */
	if (do_cpt) {
		memset(bsync, 0, sizeof(bsync));

		for (i = 0; i < load_stress; i++) {
			chain_t *chain = chains + i;
			for (j = 0; j < boards; j++) {
				if (j < num_streams)
					chain->streams[j].turn_counter = j;
				args[i * boards + j].status = BSYNC_UNKNOWN;
			}
		}

		for (i = 0; i < load_stress * boards; i++) {
			ptrc = pthread_create( &thread_arr[i], &attr, thread_cpt_routine, (void *)(args + i));
			assert(ptrc == 0);
		}

		all_threads_started = BSYNC_INIT;
		clflush(&all_threads_started);
		do {
			j = 0;
			for (i = 0; i < load_stress * boards; i++)
				if (args[i].status == BSYNC_INIT)
					j++;
		} while (j < load_stress * boards);

		all_threads_started = BSYNC_READY;
		clflush(&all_threads_started);

		c_start_time = timeofday();

		for (i = 0; i < load_stress * boards; i++) {
			pthread_join( thread_arr[i], &voidp );
		}

		c_end_time = timeofday();
	}

	free(args);
}

/* Calculate statistics and dump */

void process_and_write(FILE *fp)
{
	int i,j,k,b;
	long int sum;
	double delta;
	results_t *global;
	results_t *local;
	c_results_t *cglobal;
	c_results_t *clocal;
	double minmin,maxmin,minmax,maxmax,minavg,maxavg;

	global = calloc(1, sizeof(*global));
	cglobal = calloc(1, sizeof(*cglobal));

	minmin = minmax = minavg = global->min = cglobal->c_min = 9999999999;
	maxmin = maxmax = maxavg = 0;
	for (i = 0; i < load_stress; i++) {
		for (j = 0; j < boards; j++) {
			local = &chains[i].times[j];
			clocal = &chains[i].c_times[j];
			local->min = clocal->c_min = 9999999999;
			for (k = 0; k < NUM_SAMPLES; k++) {
				if (local->raw[k] != 0) {
					delta = cpu_period * local->raw[k];
					b = bucket_number(delta);
					local->bucket[b]++;
					global->bucket[b]++;
					if (b < BUCKETS-1) {
						local->sum += delta;
						global->sum += delta;
						local->sq_sum += delta * delta;
						global->sq_sum += delta * delta;
						if (local->min > delta) local->min = delta;
						if (global->min > delta) global->min = delta;
						if (local->max < delta) local->max = delta;
						if (global->max < delta) global->max = delta;
						local->count++;
						global->count++;
					}
				}
			}
			for (k = 0; k < NUM_COPY; k++) {
				if (clocal->c_raw[k] != 0) {
					delta = cpu_period * clocal->c_raw[k];
					clocal->c_sum += delta;
					cglobal->c_sum += delta;
					if (clocal->c_min > delta) clocal->c_min = delta;
					if (cglobal->c_min > delta) cglobal->c_min = delta;
					if (clocal->c_max < delta) clocal->c_max = delta;
					if (cglobal->c_max < delta) cglobal->c_max = delta;
					clocal->c_count++;
					cglobal->c_count++;
				}
			}
			if (local->count > 0) {
				local->avg = local->sum / local->count;
				local->var = local->sq_sum / local->count - local->avg * local->avg;
        			local->conf = 1.96 * sqrt(local->var / local->count);
				local->stddev = sqrt(local->var);
				if (local->min < minmin) minmin = local->min;
				if (local->min > maxmin) maxmin = local->min;
				if (local->max < minmax) minmax = local->max;
				if (local->max > maxmax) maxmax = local->max;
				if (local->avg < minavg) minavg = local->avg;
				if (local->avg > maxavg) maxavg = local->avg;
				sum = 0;
				for (b = 0; b < BUCKETS; b++) {
					if ((sum += 2*local->bucket[b]) >= local->count) {
						local->mean = bucket_break[b];
						break;
					}
				}
				sum = 0;
				for (b = 0; b < BUCKETS; b++) {
					if ((sum += 5*local->bucket[b]) >= 4*local->count) {
						local->eighty = bucket_break[b];
						break;
					}
				}
			}
			else
				local->min = 0;
			if (clocal->c_count > 0) {
				clocal->c_avg = clocal->c_sum / clocal->c_count;
			}
			else
				clocal->c_min = 0;
		}
	}
	if (global->count > 0) {
		global->avg = global->sum / global->count;
		global->var = global->sq_sum / global->count - global->avg * global->avg;
		global->conf = 1.96 * sqrt(global->var / global->count);
		global->stddev = sqrt(global->var);
		sum = 0;
		for (b = 0; b < BUCKETS; b++) {
			if ((sum += 2*global->bucket[b]) >= global->count) {
				global->mean = bucket_break[b];
				break;
			}
		}
		sum = 0;
		for (b = 0; b < BUCKETS; b++) {
			if ((sum += 5*global->bucket[b]) >= 4*global->count) {
				global->eighty = bucket_break[b];
				break;
			}
		}
	}
	else
		global->min = minavg = minmin = minmax = 0;
	if (cglobal->c_count > 0) {
		cglobal->c_avg = cglobal->c_sum / cglobal->c_count;
	}
	else
		cglobal->c_min = 0;


	char* host_title = "Host";
	int host_name_pad = strlen(get_host());
	if (host_name_pad < strlen(host_title)) host_name_pad = strlen(host_title);

	fprintf(fp, "\n\nSystem Level Summary:\n");
	fprintf(fp, "sls:\t%-*s\tStress\tStreams\tvDSM\tMB/s\tAvg\tMean\tStdDev\t"
		"min Avg\tmax Avg\tmin Min\tmax Min\tmin Max\tmax Max\t80%%", host_name_pad, host_title);
	if (cglobal->c_count > 0)
		fprintf(fp, "\tCPT:\tMB/s\tAvg\tMin\tMax");
	fprintf(fp, "\nsls:\t%-*s\t%d\t%d\t%s\t%.1f\t%.1f\t%d\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%d",
		host_name_pad, get_host(), load_stress, num_streams, "N/A" /* get_cpus() != get_vsmp_cpus() ? "ON" : "OFF" */,
		PAGE_SIZE / 1024.0 / 1024.0 * load_stress * boards * NUM_SAMPLES / (end_time - start_time),
		global->avg, global->mean, global->stddev, minavg, maxavg, minmin, maxmin, minmax, maxmax, global->eighty);
	fprintf(fp, "\t\t%.1f\t%.1f\t%.1f\t%.1f",
		PAGE_SIZE / 1024.0 / 1024.0 * load_stress * boards * NUM_PAGES * NUM_COPY / (c_end_time - c_start_time),
		cglobal->c_avg / NUM_PAGES, cglobal->c_min / NUM_PAGES, cglobal->c_max / NUM_PAGES);

	fprintf(fp, "\n\nSystem Level Histogram:\n");
	fprintf(fp, "slh:\tCount:\t%ld\n", global->count);
	fprintf(fp, "slh:\tbucket\tGlobal\t%%\tAcc%%\n");

	if (global->count == 0)
		return;

	sum = 0;
	for (k = 0; k < BUCKETS; k++) {
		sum += global->bucket[k];
		fprintf(fp, "slh:\t%d\t%d\t%.1f%%\t%.1f%%\n", bucket_break[k], global->bucket[k],
			100.0 * global->bucket[k] / global->count, 100.0 * sum / global->count);
	}

	fprintf(fp, "\nCPU Level Summary:\n");
	fprintf(fp, "cls:\tSrc\tDest\tAvg\tMean\tMax\tMin\tVar\tConf\tStdDev\t80%%\n");
	for (i = 0; i < load_stress; i++)
		for( j = 0; j < boards; j++ ) {
			fprintf(fp, "cls:\t%-3d\t%-3d\t%-4.1f\t%-2d\t%4.1f\t%-4.1f\t%-.1f\t%.4f\t%.2f\t%-2d\n",
				cpu_map[chains[i].times[j].from], cpu_map[chains[i].times[j].to],
				chains[i].times[j].avg , chains[i].times[j].mean,
				chains[i].times[j].max , chains[i].times[j].min,
				chains[i].times[j].var , chains[i].times[j].conf,
				chains[i].times[j].stddev, chains[i].times[j].eighty                );
		}

	fprintf(fp, "\nCPU Level Histograms:\n");
	fprintf(fp, "clh:\tTotal");
	for (i = 0; i < load_stress; i++)
		for (j = 0; j < boards; j++)
			fprintf(fp, "\t%ld", chains[i].times[j].count);
	fprintf(fp, "\nclh:\tbucket");
	for (i = 0; i < load_stress; i++)
		for (j = 0; j < boards; j++)
			fprintf(fp, "\t%d->%d", cpu_map[chains[i].times[j].from], cpu_map[chains[i].times[j].to]);
	for (k = 0; k < BUCKETS; k++) {
		fprintf(fp, "\nclh:\t%d", bucket_break[k]);
		for (i = 0; i < load_stress; i++)
			for( j = 0; j < boards; j++ )
				fprintf(fp, "\t%d", chains[i].times[j].bucket[k]);
	}
	fprintf(fp, "\n");

	if (debug_mode == DEBUG_MAXIMUM) {
		fprintf(fp, "\nCPT Detailed Report:\n");
		fprintf(fp,"cdr:\tsample");
		for (i = 0; i < load_stress; i++)
			for (j = 0; j < boards; j++)
				fprintf(fp, "\t%d->%d", cpu_map[chains[i].times[j].from], cpu_map[chains[i].times[j].to]);
		for (k = 0; k < NUM_COPY; k++) {
			fprintf(fp, "\ncdr:\t%d", k);
			for (i = 0; i < load_stress; i++)
				for( j = 0; j < boards; j++ )
					fprintf(fp, "\t%.0f", cpu_period * chains[i].c_times[j].c_raw[k]);
		}
		fprintf(fp, "\n");
	}

	free(global);
	free(cglobal);
}

/* Main program ... */

void main( int argc, char *argv[] )
{
	FILE *fp;
	int i,j,k,option;

	first_cpu=0;
	num_streams = 1;
	load_stress = 1;
	fp = stdout;

	opterr = 0;
	while ((option = getopt(argc, argv, "b:c:l:m:n:o:s:hpvt")) != -1) {
		switch (option) {
		case 'b':
			use_boards = atol(optarg);
			break;
		case 'c':
			first_cpu = atol(optarg);
			cpu_specified = 1;
			break;
		case 'l':
			load_stress = atol(optarg);
			break;
		case 'm':
			cpus_per_board = atol(optarg);
			break;
		case 'n':
			ncpus = atol(optarg);
			break;
		case 'o':
			fp = fopen(optarg, "w");
			break;
		case 's':
			num_streams = atol(optarg);
			break;
		case 'p':
			prefetch_order = 1;
			break;
		case 'h':
		case '?':
			printf("Usage: Bench_RR [-c 1st_cpu] [-o output_file] [-s #streams] [-l load] [-b #boards] [-t]\n");
			exit(1);
			break;
		case 't':
			ignore_threads = 1;
			break;
		case 'v':
			display_topology = 1;
			break;
		}
	}

	setbuf(stdout, 0);

	if (!is_vsmp_foundation()) {
        	fprintf(stderr, "ERROR: Not running on a vSMP Foundation system.\n");
		exit(1);
	}
	boards = parse_boards(); // Get NUMA topology

	/* Check for topology override */
	if ( use_boards > 0 && cpus_per_board > 0 ) {
		boards = use_boards;
		ncpus = boards * cpus_per_board;
	}
	else if ( use_boards > 0 && ncpus > 0 ) {
		boards = use_boards;
		cpus_per_board = ncpus / boards;
	}
	else if ( cpus_per_board > 0 && ncpus > 0 ) {
		boards = ncpus / cpus_per_board;
	}
	else {
        	boards = numa_boards;
		cpus_per_board = numa_cpus_per_board;
       		ncpus = boards * cpus_per_board;
	}
	if ( boards == 0 ) {
		fprintf(stderr, "Unable to determine number of boards\n");
		exit(1);
	}
	if ( boards == 1 ) {
		fprintf(stderr, "Only one board found / selected. Test requires at least two.\n");
		exit(1);
	}
	build_buckets();
	build_permutation_table();

	/* old - obsolete:
	fprintf(fp, "System:\t%s\nvSMP version:\t%s\nKernel version:\t%s\nBoards:\t%d\n"
		"CPUs:\t%d x %s\nMemory:\t%s / %s\nCPU Speed (Mhz):\t%f\n\n",
		get_host(), get_vsmpversion(), get_kernel(), true_boards, true_cpus,
	        get_cpu_string(), get_vsmp_memory(), get_vsmp_total_memory(), get_cpu_mhz());
	*/
	fprintf(fp, "System:\t%s\n%s\n", get_host(), get_vsmp_longversion());

	/* Observe limits */
	if (boards > MAX_BOARDS)
		boards = MAX_BOARDS;
	if (use_boards > 0 && use_boards < boards)
		boards = use_boards;
	if (boards < num_streams)
		num_streams = boards;
	if (load_stress > MAX_CPUS)
		load_stress = MAX_CPUS;
	if (cpus_per_board < (first_cpu % cpus_per_board) + load_stress)
		load_stress = cpus_per_board - (first_cpu % cpus_per_board);

	fprintf(fp, "Test config:\tBoards:\t%d\t1st CPU:\t%d\tCPUs/Board:\t%d\tPageSets:\t%d\n\n",
		boards, first_cpu, load_stress, num_streams);

	memset(&bsync, 0, sizeof(bsync));
	chains = (chain_t *)calloc(load_stress, sizeof(chain_t));
	assert(chains);

	cpu_period = 1.0 / get_cpu_mhz();

	test_once(chains);

	fprintf(fp, "DSRAM\tRuntime:\t%.3f\tBandwidth:\t%.3f MB/s\tDSRAM every %.1f us\n", end_time - start_time,
		PAGE_SIZE / 1024.0 / 1024.0 * load_stress * boards * NUM_SAMPLES / (end_time - start_time),
		(end_time - start_time) / load_stress / boards / NUM_SAMPLES * 1000000);
	if (c_start_time)
		fprintf(fp, "CPT\tRuntime:\t%.3f\tBandwidth:\t%.3f MB/s\t=\t%.1f us/page\n", c_end_time - c_start_time,
		PAGE_SIZE / 1024.0 / 1024.0 * load_stress * boards * NUM_PAGES * NUM_COPY / (c_end_time - c_start_time),
		(c_end_time - c_start_time) * 1000000 / load_stress / boards / NUM_PAGES / NUM_COPY);

	process_and_write(fp);

	fclose(fp);
}


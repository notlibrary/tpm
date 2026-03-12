/*
	TPM Toothpaste Picking Manager source code 0BSD license
*/
#ifndef TPM_H
#define TPM_H
#ifdef __cplusplus
extern "C" {
#endif /*__cplusplus*/

#define TPM_STRING "tpm"
#define TPM_VERSION_MAJOR 0
#define TPM_VERSION_MINOR 4
#define TPM_VERSION_PATCH 2

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>
#include <ctype.h>

#include "prng64_xrp32.h"
#include "cfg_parse.h"

#ifdef _WIN32
#include <windows.h>
#include <winbase.h>
#include <shlobj.h>
#include <direct.h>
#include <Lmcons.h>
#define STATIC_GETOPT
#include "getopt.h"
#include "getopt.c"
#pragma comment(lib, "advapi32.lib")
#else
#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>
#endif

#define TPM
#define TOTAL_TOOTHPASTES 3
#define TOTAL_DAYS_OF_WEEK 7
#define TOTAL_TIMES_OF_DAY 4
#define SECONDS_PER_DAY 86400
#define SECONDS_PER_HOUR 3600
#define PICK_TIMEOUT_SECONDS 300
#define TOOTHBRUSH_TIMESPAN_DAYS 180
#define MAX_PATH 256
#define MAX_LINE_LENGTH 1024
#define COMMENT_CHAR '#'
#ifndef UNLEN
#define UNLEN 256
#endif
#define OUTPUT_BLOCK_SIZE 4096
#define TOTAL_PICK_TYPE_STRINGS 8
#define MAX_TIMEZONE_DELTA 11
#define MAX_RECURSION 128
#define SYSTEM_PAUSE 1
#define NO_SYSTEM_PAUSE 0
#define MAX_TOOTHPASTE_LINE 128

typedef enum
{
	PICK_DEFAULT,
	PICK_RANDOM,
	PICK_BY_INDEX,
	PICK_BY_BRAND,
	PICK_MAX_RATING,
	PICK_MAX_MASS,
	PICK_MIN_RATING,
	PICK_MIN_MASS

}pick_type_t;

typedef struct
{
	time_t last_pick_time;
	unsigned int total_picks;
}toothpaste_pick_stats_t;


typedef struct {
    unsigned int index;
	char toothpaste_brand[50];
	unsigned int tube_mass_g;
	unsigned int rating;
} toothpaste_data_t;

	
typedef struct list_node_t {
    toothpaste_data_t data;
    struct list_node_t *next;
} list_node_t;

typedef struct {
	pick_type_t ptype;
	int verbose;
	int lat_flag;
	int json_flag;
	int output_to_file;
	unsigned int pick_by_index_index;
	const char* username;
	const char* brand_string;
}toothpaste_pick_options_t;

typedef struct {
	const char* who;
	toothpaste_data_t what;
	list_node_t* where;
	unsigned int total_toothpastes;	
	time_t when;
	toothpaste_pick_stats_t stats;
	unsigned int toothpaste_pick_index;
	char* message;
	char* JSON;
	toothpaste_pick_options_t opts;
}toothpaste_pick_t;

TPM list_node_t* tpm_load_list_from_file(const char* filename);
TPM toothpaste_pick_t* tpm_pick_toothpaste(list_node_t* head,toothpaste_pick_options_t topts);
TPM char* tpm_get_toothpaste_picking_message(toothpaste_pick_t* pick);
TPM char* tpm_get_toothpaste_picking_JSON(toothpaste_pick_t* pick);
TPM int tpm_free_toothpaste_pick(toothpaste_pick_t* pick);

static list_node_t* create_node(toothpaste_data_t p_data);
static list_node_t* add_to_list(list_node_t* head, toothpaste_data_t p_data);
static void rtrim(char *s); 
static void display_list(list_node_t* head, toothpaste_pick_t* pick);  
static unsigned int count_list(list_node_t* head);
static toothpaste_data_t get_item_by_index(list_node_t* head,unsigned int i);
static toothpaste_data_t get_item_by_brand_string(list_node_t* head,const char* str); 
static toothpaste_data_t find_item_with_max_mass(list_node_t* where);
static toothpaste_data_t find_item_with_min_mass(list_node_t* where);
static toothpaste_data_t find_item_with_max_rating(list_node_t* where);
static toothpaste_data_t find_item_with_min_rating(list_node_t* where);
static void free_list(list_node_t* head);
static int reset_counters(void);
static int set_counters(void* optarg);
static int get_counters(toothpaste_pick_stats_t* stats);
static int list_available_toothpastes(toothpaste_pick_t* pick);
static int write_counters(toothpaste_pick_stats_t stats);
static void stop_system(void);
static int finish(int flag,toothpaste_pick_t* pick);
static char* get_user_home_dir(void);
static int get_current_username(char* buffer, size_t buffer_size);
static void version(void);
const char* cfg_get_rec(const struct cfg_struct* cfg, const char* key);
static toothpaste_pick_options_t read_config(const char* src);

#ifdef __cplusplus
}
#endif /*__cpluplus*/
#endif /*TPM_H */
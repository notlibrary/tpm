/*
	TPM Toothpaste Picking Manager source code 0BSD license
*/
#define TPM_STRING "tpm"
#define TPM_VERSION_MAJOR 0
#define TPM_VERSION_MINOR 4
#define TPM_VERSION_PATCH 2

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>
#include <ctype.h>

#include "prng64_xrp32.c"
#include "prng64_xrp32.h"
#include "cfg_parse.h"
#include "cfg_parse.c"

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
	int pick_by_index_index;
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

pick_type_t pick_type = PICK_DEFAULT;
list_node_t* toothpastes_list;

static const toothpaste_data_t toothpastes[TOTAL_TOOTHPASTES]={
	{0,"LACALUT",75,90},
	{1,"SENSODYNE",150,100},
	{2,"Nothing",0,0}
};
static const char* pick_type_strings[TOTAL_PICK_TYPE_STRINGS]={
	"Pick type: Default",
	"Pick type: Random",
	"Pick type: By index",
	"Pick type: By brand",
	"Pick type: Max rating",
	"Pick type: Max tube mass",
	"Pick type: Min rating",
	"Pick type: Min tube mass"
};
static const char* days_of_week[TOTAL_DAYS_OF_WEEK]={
	"Thursday", /*1 jan 1970 epoch start is Thursday*/
	"Friday",
	"Saturday",
	"Sunday",	
	"Monday",
	"Tuesday",
	"Wednesday"
	
};	
static const char* times_of_day[TOTAL_TIMES_OF_DAY]={
	"Night", /*1 jan 1970 epoch start is Thursday*/
	"Morning",
	"Day",
	"Evening"
	
};	

static const char stats_file_name[MAX_PATH]="pickstats";
static const char toothpastes_file_name[MAX_PATH]="toothpastes";
static const char output_file_name[MAX_PATH]="last_pick";
static const char config_file_name[MAX_PATH]="tpm.conf";

static char stats_file_path_final[MAX_PATH];
static char toothpastes_file_path_final[MAX_PATH];
static char output_file_path_final[MAX_PATH];
static char config_file_path_final[MAX_PATH];

static int verbose = 1;
static int lat_flag=0;
static int json_flag=0;
static int output_to_file=0;
static int pick_by_index_index = 0;
static char* brand_string = NULL;

static list_node_t* 
create_node(toothpaste_data_t p_data) 
{
    list_node_t* new_node = (list_node_t*)malloc(sizeof(list_node_t));
    if (new_node == NULL) {
        perror("Memory allocation failed");
        exit(EXIT_FAILURE);
    }
    new_node->data = p_data;
    new_node->next = NULL;
    return new_node;
}

static list_node_t* 
add_to_list(list_node_t* head, toothpaste_data_t p_data) 
{
    list_node_t* new_node = create_node(p_data);
    if (head == NULL) {
        return new_node;
    }
    list_node_t* current = head;
    while (current->next != NULL) {
        current = current->next;
    }
    current->next = new_node;
    return head;
}

static void
rtrim(char *s) 
{
    int i = strlen(s) - 1; 

    while (i >= 0 && isspace((unsigned char)s[i])) {
        i--;
    }

  
    s[i + 1] = '\0';
}

static list_node_t* 
tpm_load_list_from_file(const char* filename) 
{
	int i;
    FILE* file = fopen(toothpastes_file_path_final, "r");
	list_node_t* head = NULL;
    toothpaste_data_t temp_data;
	char line[MAX_LINE_LENGTH];
	char* current = line;
	
    if (file == NULL) {
        perror("Error opening toothpastes file falling back to default");
		for (i=0;i<TOTAL_TOOTHPASTES;i++)
		{
		  temp_data=toothpastes[i];
		  head = add_to_list(head, temp_data);	
		}
		return head;
    }
	
    while (fgets(line, sizeof(line), file) != NULL) {
        
        while (isspace((unsigned char)*current)) {
            current++;
        }

        if (*current == '\0' || *current == COMMENT_CHAR) {
            continue; 
        }
		if (sscanf(current, "%u, %[^,],%u,%u\n", &temp_data.index,temp_data.toothpaste_brand ,&temp_data.tube_mass_g,&temp_data.rating) == 4) {
			rtrim(temp_data.toothpaste_brand);
			head = add_to_list(head, temp_data);	
		}		
    }
    fclose(file);
    return head;
}

static void 
display_list(list_node_t* head, toothpaste_pick_t* pick) 
{
    list_node_t* current = head;
	char line[128];
	
	memset(line,0,128);
	memset(pick->message,0,OUTPUT_BLOCK_SIZE);
	
	sprintf(pick->message,"Index | Brand | Tube Mass | Rating\n");
	while (current != NULL) {
        sprintf(line,"%d %s %d %d\n", current->data.index, current->data.toothpaste_brand, current->data.tube_mass_g, current->data.rating);
        strcat(pick->message,line);
		current = current->next;
    }
}

static unsigned int 
count_list(list_node_t* head) 
{
    unsigned int i=0;
	
	list_node_t* current = head;
    while (current != NULL) {
        i++;
        current = current->next;
	}
	return i;
}

static toothpaste_data_t 
get_item_by_index(list_node_t* head,unsigned int i) 
{
   toothpaste_data_t empty ={0,"None",0}; 
	list_node_t* current = head;
    while (current != NULL) {
        if (current->data.index==i)
		{
			return current->data;
        }
		current = current->next;
    }
	return empty;
}

static toothpaste_data_t 
get_item_by_brand_string(list_node_t* head,char* str) 
{
    toothpaste_data_t empty ={0,"None",0}; 
	list_node_t* current = head;
    while (current != NULL) {
        if (0==strcmp(str,current->data.toothpaste_brand))
		{
			return current->data;
        }
		current = current->next;
    }
	return empty;
}

static toothpaste_data_t 
find_item_with_max_mass(list_node_t* where)
{
		list_node_t* current = where;
		unsigned int max_mass=0;
		unsigned int max_index=0;		
			
		while (current != NULL) 
		{
			if (current->data.tube_mass_g>max_mass)
			{
				max_index =	current->data.index;
				max_mass =	current->data.tube_mass_g;
			}
		current = current->next;
		}
		return get_item_by_index(where,max_index);
}

static toothpaste_data_t 
find_item_with_min_mass(list_node_t* where)
{
		list_node_t* current = where;
		unsigned int min_mass=100000;
		unsigned int min_index=0;		
			
		while (current != NULL) 
		{
			if (current->data.tube_mass_g<min_mass)
			{
				min_index =	current->data.index;
				min_mass =	current->data.tube_mass_g;
			}
		current = current->next;
		}
		return get_item_by_index(where,min_index);
}

static toothpaste_data_t 
find_item_with_max_rating(list_node_t* where)
{
		list_node_t* current = where;
		unsigned int max_rating=0;
		unsigned int max_index=0;		
			
		while (current != NULL) 
		{
			if (current->data.tube_mass_g>max_rating)
			{
				max_index =	current->data.index;
				max_rating =current->data.rating;
			}
		current = current->next;
		}
		return get_item_by_index(where,max_index);	
}

static toothpaste_data_t 
find_item_with_min_rating(list_node_t* where)
{
		list_node_t* current = where;
		unsigned int min_rating=100;
		unsigned int min_index=0;		
			
		while (current != NULL) 
		{
			if (current->data.tube_mass_g<min_rating)
			{
				min_index =	current->data.index;
				min_rating =current->data.rating;
			}
		current = current->next;
		}
		return get_item_by_index(where,min_index);	
}

static void 
free_list(list_node_t* head) 
{
    list_node_t* temp;
    while (head != NULL) {
        temp = head;
        head = head->next;
        free(temp);
    }
}


static int 
reset_counters(void) 
{
	FILE* file_ptr;
	unsigned int zero=0;
	time_t zero_time =0;
	
	file_ptr = fopen(stats_file_path_final, "wb");
		if (file_ptr == NULL) {
			perror("Error opening pickstats file for writing");
			return 1;
		}	

		fwrite(&zero, sizeof(int), 1, file_ptr);
		fwrite(&zero_time, sizeof(time_t), 1, file_ptr);
		fclose(file_ptr);
		printf("%s", "Pick counter clear\n"); 
		return 0;
}

static int 
set_counters(void* optarg) 
{
	FILE* file_ptr;
	unsigned int zero=0;
	time_t zero_time =0;
	time_t total_seconds=time(NULL);
	unsigned char* counter=	(unsigned char*) (optarg);
	zero = atoi(optarg);
	file_ptr = fopen(stats_file_path_final, "wb");
		if (file_ptr == NULL) {
			perror("Error opening pickstats file for writing");
			return 1;
		}	
	

		fwrite(&zero, sizeof(int), 1, file_ptr);
		fwrite(&total_seconds, sizeof(time_t), 1, file_ptr);
		fclose(file_ptr);
		printf("%s", "Pick counter set\n"); 
		return 0;
}

static int
get_counters(toothpaste_pick_stats_t* stats)
{
	FILE* file_ptr;
	
	stats->total_picks=0;
	stats->last_pick_time=0;
	
	file_ptr = fopen(stats_file_path_final, "rb");
    if (file_ptr == NULL) {
        perror("Error opening pickstats file for reading");
        return 1;
    }

   fread(&stats->total_picks, sizeof(unsigned int), 1, file_ptr);
   fread(&stats->last_pick_time, sizeof(time_t), 1, file_ptr);
   
    fclose(file_ptr);	
	return 0;
}

static int
list_available_toothpastes(toothpaste_pick_t* pick)
{
	display_list(pick->where,pick);
	return 0;
}

static int
write_counters(toothpaste_pick_stats_t stats)
{
	FILE* file_ptr;
	file_ptr = fopen(stats_file_path_final, "wb");
		if (file_ptr == NULL) {
			perror("Error opening pickstats file for writing");
			return 1;
    }
	fwrite(&stats.total_picks, sizeof(int), 1, file_ptr);
	fwrite(&stats.last_pick_time, sizeof(time_t), 1, file_ptr);
	fclose(file_ptr);
	return 0;
}

static void 
stop_system() 
{
    int c;
	
    printf("Press Enter to continue...");
    while ((c = getchar()) != EOF && c != '\n');
    getchar(); 
}

static int 
tpm_free_toothpaste_pick(toothpaste_pick_t* pick)
{
	free(pick->message);
	free(pick->JSON);
	free_list(pick->where);
	return 0;
}

static int 
finish(int flag,toothpaste_pick_t* pick)
{
	tpm_free_toothpaste_pick(pick);
	if (flag) {
#ifdef _WIN32
	system("pause");
#else
	stop_system();
#endif
	}
	return 0;
}

static char* 
get_user_home_dir() 
{
    char* home_dir = NULL;

#ifdef _WIN32
    const char* user_profile_env = getenv("USERPROFILE");
    if (user_profile_env != NULL) {
        home_dir = _strdup(user_profile_env); 
    } else {
        const char* home_drive = getenv("HOMEDRIVE");
        const char* home_path = getenv("HOMEPATH");
        if (home_drive != NULL && home_path != NULL) {
            size_t len = strlen(home_drive) + strlen(home_path) + 1;
            home_dir = malloc(len);
            if (home_dir != NULL) {
                snprintf(home_dir, len, "%s%s", home_drive, home_path);
            }
        }
    }
#else
    const char* home_env = getenv("HOME");
    if (home_env != NULL) {
        home_dir = strdup(home_env);
    } else {
        struct passwd *pwd;
        uid_t uid = getuid();
        pwd = getpwuid(uid);
        if (pwd != NULL) {
            home_dir = strdup(pwd->pw_dir);
        }
    }
#endif

    return home_dir;
}

static int 
get_current_username(char* buffer, size_t buffer_size) {
#ifdef _WIN32
    DWORD len = (DWORD)buffer_size;
	
    if (GetUserName(buffer, &len)) {
        return 0; 
    }
    return -1; 
#else
    uid_t uid = geteuid();
    struct passwd *pw = getpwuid(uid);
	const char* user_env = getenv("LOGNAME");
	
    if (pw != NULL) {
        strncpy(buffer, pw->pw_name, buffer_size);
        buffer[buffer_size - 1] = '\0';
        return 0; 
    }
    

    if (user_env == NULL) {
        user_env = getenv("USER");
    }
    if (user_env != NULL) {
        strncpy(buffer, user_env, buffer_size);
        buffer[buffer_size - 1] = '\0';
        return 0;
    }
    return -1; 
#endif
}

static void
version()
{
	printf("%s %u.%u.%u \n",TPM_STRING,TPM_VERSION_MAJOR,TPM_VERSION_MINOR,TPM_VERSION_PATCH);
	exit(EXIT_FAILURE);
}

static char* 
tpm_get_toothpaste_picking_message(toothpaste_pick_t* pick)
{
	return pick->message;
}

static char*
tpm_get_toothpaste_picking_JSON(toothpaste_pick_t* pick)
{
	return pick->JSON;	
}

static toothpaste_pick_t* tpm_pick_toothpaste(list_node_t* head,toothpaste_pick_options_t topts)
{
	int i,j;
	static toothpaste_pick_t pick;
	time_t total_seconds = time(NULL);
	unsigned int day;
	char username[UNLEN + 1];
	char line[MAX_LINE_LENGTH];
	
	memset(line,0,MAX_LINE_LENGTH);
	memset(username,0,UNLEN+1);
	pick.message=malloc(OUTPUT_BLOCK_SIZE);
	pick.JSON=malloc(OUTPUT_BLOCK_SIZE);
	
	memset(pick.JSON,0,OUTPUT_BLOCK_SIZE);	
	memset(pick.message,0,OUTPUT_BLOCK_SIZE);
	
	if (get_current_username(username, sizeof(username)) == 0) 
	{
		if (topts.username == NULL)
		{topts.username =username;}
		pick.who=topts.username;
    }
	else 
	{
        pick.who="Anonymous";
    }
	
	pick.total_toothpastes = count_list(head);
	if (0==pick.total_toothpastes) 
	{
			perror("No toothpastes file loaded");
	}
	get_counters(&pick.stats);
	pick.toothpaste_pick_index=pick.stats.total_picks;
	pick.when=total_seconds;
	i=(total_seconds)/(SECONDS_PER_DAY/TOTAL_TIMES_OF_DAY)%(TOTAL_TIMES_OF_DAY);
	
	if (topts.verbose)
	{
		
		sprintf(line,"Good %s %s %s \n", times_of_day[i],pick.who ,"Welcome to the toothpaste picking manager");
		strcat(pick.message,line);
	}
	
	day = total_seconds/SECONDS_PER_DAY;
	
	i=day%pick.total_toothpastes;
	if (topts.ptype==PICK_BY_INDEX) 
	{
		i=topts.pick_by_index_index;
	}
	if (topts.ptype==PICK_RANDOM) 
	{
		seed_xrp32(total_seconds);
		i=(prng64_xrp32()%pick.total_toothpastes);
	}
	if (topts.ptype==PICK_BY_BRAND) 
	{
		pick.what = get_item_by_brand_string(toothpastes_list,topts.brand_string);
	}
	else
	{
		pick.what = get_item_by_index(toothpastes_list,i);
	}
	pick.where=toothpastes_list;
	if (topts.ptype==PICK_MAX_RATING)
	{
		pick.what=find_item_with_max_rating(pick.where);
	}
	if (topts.ptype==PICK_MAX_MASS)
	{
		pick.what=find_item_with_max_mass(pick.where);
	}
		if (topts.ptype==PICK_MIN_RATING)
	{
		pick.what=find_item_with_min_rating(pick.where);
	}
	if (topts.ptype==PICK_MIN_MASS)
	{
		pick.what=find_item_with_min_mass(pick.where);
	}
	
	j=(day)%TOTAL_DAYS_OF_WEEK;
	
	if ((total_seconds - pick.stats.last_pick_time) > (SECONDS_PER_DAY-PICK_TIMEOUT_SECONDS)) {
		if (topts.verbose) 
		{
			sprintf(line,"%s", "New next pick stats updated \n");
			strcat(pick.message,line);
		
		}
		
		pick.stats.total_picks++;
		pick.stats.last_pick_time=total_seconds;
		write_counters(pick.stats);
		
		if (pick.stats.total_picks % TOOTHBRUSH_TIMESPAN_DAYS ==0)
		{
			 if (topts.verbose) 
			 { 
					sprintf(line,"%s", "180 days toothbrush time span over swap the toothbrush(or order new one) \n"); 
					strcat(pick.message,line);
			 }
		}
	}
	else if (topts.verbose) 
	{
			sprintf(line,"%s", "Already picked today \n");
			strcat(pick.message,line);	
		
	}
	if (topts.verbose) 
	{
		sprintf(line,"%s\n", pick_type_strings[topts.ptype] );
		strcat(pick.message,line);
	}
	if (topts.verbose)
	{		
		sprintf(line,"%s %s %s (%ug) [%u/100] %s %s %s %u %s %u/%u \n", "Toothpaste:", ">>>", pick.what.toothpaste_brand, pick.what.tube_mass_g, pick.what.rating, "<<<", "Day:" ,days_of_week[j],day, "Toothpaste index:",i,pick.total_toothpastes);
		strcat(pick.message,line);
		

		sprintf(line,"%s %u %s %llu  \n", "Total picks:", pick.stats.total_picks, "Last pick time:" ,pick.stats.last_pick_time);
		strcat(pick.message,line);
	
	}
	else 
	{
		sprintf(pick.message,"%s (%ug) [%u/100] \n", pick.what.toothpaste_brand,pick.what.tube_mass_g, pick.what.rating);	
	}
	
	sprintf(pick.JSON,"{\n\t \"who\":\"%s\",\n\t \"toothpaste\":\"%s\",\n\t \"tube_mass_g\":%u,\n\t \"rating\":%u \n}",pick.who,pick.what.toothpaste_brand,pick.what.tube_mass_g,pick.what.rating);
	
	if (topts.lat_flag) {
		list_available_toothpastes(&pick);
	}	
	return &pick;
}


static toothpaste_pick_options_t
read_config(char* src)
{
	toothpaste_pick_options_t opts;
	struct cfg_struct* cfg;
	int reset_counters_v=0;
	int set_counters_v=0;
	const char* value = NULL;
	
	opts.ptype=pick_type;
	opts.verbose=verbose;
	opts.lat_flag=lat_flag;
	opts.json_flag=json_flag;
	opts.output_to_file=output_to_file;
	opts.pick_by_index_index=pick_by_index_index;
	opts.brand_string=brand_string;
	
	cfg = cfg_init();
	if (cfg_load(cfg, src) < 0)
	{
		fprintf(stderr, "Unable to load config ~tpm/tpm.conf\n");
		return opts;
    }
	opts.username = cfg_get(cfg, "USERNAME");
	

	value = cfg_get(cfg, "PICK_TYPE");
	if (value!=NULL) opts.ptype =  atoi(value);
	value = cfg_get(cfg, "VERBOSE");
	if (value!=NULL) opts.verbose =  atoi(value);
	value = cfg_get(cfg, "LIST_TOOTHPASTES");
	if (value!=NULL) opts.lat_flag =  atoi(value);
	value = cfg_get(cfg, "OUTPUT_JSON");
	if (value!=NULL) opts.json_flag =  atoi(value);
	value = cfg_get(cfg, "OUTPUT_FILE");
	if (value!=NULL) opts.output_to_file =  atoi(value);
	value = cfg_get(cfg, "PICK_INDEX");
	if (value!=NULL) opts.pick_by_index_index =  atoi(value);
	value = cfg_get(cfg, "BRAND");
	if (value!=NULL) opts.brand_string = (value);
	value = cfg_get(cfg, "RESET_COUNTER");
	if (value!=NULL) {reset_counters_v=atoi(cfg_get(cfg, "RESET_COUNTER"));}
	if (reset_counters_v){ reset_counters();}
	value = cfg_get(cfg, "SET_COUNTER");
	if (value!=NULL) {set_counters_v=atoi(cfg_get(cfg, "SET_COUNTER"));}
	if (set_counters_v) set_counters(&set_counters_v);
	return opts;
}

int
main(int argc, char* argv[])
{

	int opt;
	FILE* output_file;
	toothpaste_pick_t* pick;
	char* user_home_dir=get_user_home_dir();
	toothpaste_pick_options_t topts;
	
#ifdef _WIN32
	strcat(user_home_dir,"\\tpm\\");
#else
	strcat(user_home_dir,"/tpm/");
#endif
	strcpy(stats_file_path_final,user_home_dir);
	strcat(stats_file_path_final,stats_file_name);
	
	strcpy(toothpastes_file_path_final,user_home_dir);
	strcat(toothpastes_file_path_final,toothpastes_file_name);
	
	strcpy(output_file_path_final,user_home_dir);
	strcat(output_file_path_final,output_file_name);

	strcpy(config_file_path_final,user_home_dir);
	strcat(config_file_path_final,config_file_name);
	
	free(user_home_dir);
	topts=read_config(config_file_path_final);
	while ((opt = getopt(argc, argv, "awojvxqlrs:p:i:b:")) != -1) {
        switch (opt) {
		case 'a':
		topts.ptype = PICK_MAX_RATING;
        break;
		case 'w':
		topts.ptype = PICK_MAX_MASS;
        break;
		case 'o':
		topts.output_to_file=1;
        break;
		case 'j':
		topts.json_flag=1;
        break;
		case 'v':
        version();
        break;
        case 'x':
        topts.ptype = PICK_RANDOM;
        break;		
        case 'q':
        topts.verbose = 0;
        break;
        case 'l':
		topts.lat_flag=1;
        break;
        case 'r':
		reset_counters();
        break;
 		case 's':
			set_counters(optarg);
		break;
		case 'p':
			topts.ptype=atoi(optarg);
		break; 	
		case 'i':
			topts.ptype=PICK_BY_INDEX;
			topts.pick_by_index_index=atoi(optarg);
		break;
		case 'b':
			topts.ptype=PICK_BY_BRAND;
			topts.brand_string=optarg;
		break; 				
		case '?': 
            fprintf(stderr, "Usage: %s [-awojvxqlr] [-s total_picks value] [-p pick_type_value] [-i toothpaste_index] [-b brand_string] \n", argv[0]);
            exit(EXIT_FAILURE);
        default:
			break;
        }
    }
		
	if (output_to_file)
	{
		printf("%s %s \n","Output pick to file ",output_file_path_final);
		output_file=fopen(output_file_path_final,"w");
		if (output_file == NULL) {
			perror("Error opening last_pick file for writing");

			}		
	}
	else
	{
		output_file=stdout;
	}
	toothpastes_list=tpm_load_list_from_file(toothpastes_file_path_final);
	pick=tpm_pick_toothpaste(toothpastes_list,topts);
	if (json_flag)
		fprintf(output_file,"%s \n",tpm_get_toothpaste_picking_JSON(pick));
	else
		fprintf(output_file,"%s \n",tpm_get_toothpaste_picking_message(pick));
	
if (json_flag)
	finish(0,pick);
else
	finish(1,pick);

}

	
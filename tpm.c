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
	char* who;
	toothpaste_data_t what;
	list_node_t* where;
	unsigned int total_toothpastes;	
	time_t when;
	toothpaste_pick_stats_t stats;
	unsigned int toothpaste_pick_index;
	char* message;
	char* JSON;
	
}toothpaste_pick_t;

TPM list_node_t* tpm_load_list_from_file(const char* filename);
TPM toothpaste_pick_t* tpm_pick_toothpaste(list_node_t* head);
TPM char* tpm_get_toothpaste_pick_message(toothpaste_pick_t* pick);
TPM char* tpm_get_toothpaste_pick_JSON(toothpaste_pick_t* pick);

list_node_t* toothpastes_list;
static const toothpaste_data_t toothpastes[TOTAL_TOOTHPASTES]={
	{0,"LACALUT",75,90},
	{1,"SENSODYNE",150,100},
	{2,"Nothing",0,0}
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

static char stats_file_path_final[MAX_PATH];
static char toothpastes_file_path_final[MAX_PATH];
static char output_file_path_final[MAX_PATH];

static int verbose = 1;
static int pick_random =0;
static int lat_flag=0;
static int json_flag=0;
static int output_to_file=0;


list_node_t* 
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

list_node_t* 
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

list_node_t* 
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
		if (sscanf(current, "%u,%[^,],%u,%u\n", &temp_data.index,temp_data.toothpaste_brand ,&temp_data.tube_mass_g,&temp_data.rating) == 4) {
			head = add_to_list(head, temp_data);
		}		
    }
    fclose(file);
    return head;
}


void 
display_list(list_node_t* head) 
{
    list_node_t* current = head;
    printf("Index | Brand | Tube Mass | Rating\n");
	while (current != NULL) {
        printf("%d %s %d %d\n", current->data.index, current->data.toothpaste_brand, current->data.tube_mass_g, current->data.rating);
        current = current->next;
    }
}

unsigned int 
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


toothpaste_data_t 
get_item_by_index(list_node_t* head,unsigned int i) {
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

void 
free_list(list_node_t* head) 
{
    list_node_t* temp;
    while (head != NULL) {
        temp = head;
        head = head->next;
        free(temp);
    }
}


int 
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

int 
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


int
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

int
list_available_toothpastes(void)
{
	display_list(toothpastes_list);
	return 0;
}

int
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

void 
stop_system() {
    printf("Press Enter to continue...");
    int c;
    while ((c = getchar()) != EOF && c != '\n');
    getchar(); 
}

int 
finish(int flag,toothpaste_pick_t* pick)
{
	free_list(toothpastes_list);
	free(pick->message);
	free(pick->JSON);
	if (flag) {
#ifdef _WIN32
	system("pause");
#else
	stop_system();
#endif
	}
	return 0;
}

char* 
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

int 
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
    if (pw != NULL) {
        strncpy(buffer, pw->pw_name, buffer_size);
        buffer[buffer_size - 1] = '\0';
        return 0; 
    }
    
	const char* user_env = getenv("LOGNAME");
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

void
version()
{
	printf("%s %u.%u.%u \n",TPM_STRING,TPM_VERSION_MAJOR,TPM_VERSION_MINOR,TPM_VERSION_PATCH);
	exit(EXIT_FAILURE);
}

char* 
tpm_get_toothpaste_pick_message(toothpaste_pick_t* pick)
{
	return pick->message;
}

char*
tpm_get_toothpaste_pick_JSON(toothpaste_pick_t* pick)
{
	return pick->JSON;	
}

toothpaste_pick_t* tpm_pick_toothpaste(list_node_t* head)
{
	int i,j,k;
	static toothpaste_pick_t pick;
	time_t total_seconds = time(NULL);
	unsigned int day;
	char username[UNLEN + 1];
	char line[MAX_LINE_LENGTH];
	memset(line,0,MAX_LINE_LENGTH);
	
	pick.message=malloc(OUTPUT_BLOCK_SIZE);
	pick.JSON=malloc(OUTPUT_BLOCK_SIZE);
	
	memset(pick.JSON,0,OUTPUT_BLOCK_SIZE);	
	memset(pick.message,0,OUTPUT_BLOCK_SIZE);
	
	if (get_current_username(username, sizeof(username)) == 0) 
	{
		pick.who=username;
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
	
	if (verbose)
	{
		
		sprintf(line,"Good %s %s %s \n", times_of_day[i],pick.who ,"Welcome to the toothpaste picking manager");
		strcat(pick.message,line);
	}
	
	day = total_seconds/SECONDS_PER_DAY;
	
	i=day%pick.total_toothpastes;
	if (pick_random) 
	{
		seed_xrp32(total_seconds);
		i=(prng64_xrp32()%pick.total_toothpastes);
	
		if (verbose) 
		{
			sprintf(line,"%s", "Picking RANDOM toothpaste \n");
			strcat(pick.message,line);
		}
	}
	pick.what = get_item_by_index(toothpastes_list,i);
	pick.where=toothpastes_list;
	j=(day)%TOTAL_DAYS_OF_WEEK;
	
	if ((total_seconds - pick.stats.last_pick_time) > (SECONDS_PER_DAY-PICK_TIMEOUT_SECONDS)) {
		if (verbose) 
		{
			sprintf(line,"%s", "New next pick stats updated \n");
			strcat(pick.message,line);
		
		}
		
		pick.stats.total_picks++;
		pick.stats.last_pick_time=total_seconds;
		write_counters(pick.stats);
		
		if (pick.stats.total_picks % TOOTHBRUSH_TIMESPAN_DAYS ==0)
		{
			 if (verbose) 
			 { 
					sprintf(line,"%s", "180 days toothbrush time span over swap the toothbrush(or order new one) \n"); 
					strcat(pick.message,line);
			 }
		}
	}
	if (verbose) 
	{
			sprintf(line,"%s", "Already picked today \n");
			strcat(pick.message,line);	
		
	}
	if (verbose)
	{		
		sprintf(line,"%s %s %s (%ug) [%u/100] %s %s %s %u %s %u \n", "Toothpaste:", ">>>", pick.what.toothpaste_brand, pick.what.tube_mass_g, pick.what.rating, "<<<", "Day:" ,days_of_week[j],day, "Toothpaste index:",i);
		strcat(pick.message,line);
		

		sprintf(line,"%s %u %s %llu  \n", "Total picks:", pick.stats.total_picks, "Last pick time:" ,pick.stats.last_pick_time);
		strcat(pick.message,line);
	
	}
	else 
	{
		sprintf(pick.message,"%s (%ug) [%u/100] \n", pick.what.toothpaste_brand,pick.what.tube_mass_g, pick.what.rating);	
	}
	
	sprintf(pick.JSON,"{\n\t \"who\":\"%s\",\n\t \"toothpaste\":\"%s\",\n\t \"tube_mass_g\":%u,\n\t \"rating\":%u \n}",pick.who,pick.what.toothpaste_brand,pick.what.tube_mass_g,pick.what.rating);
	
	return &pick;
}

int
main(int argc, char* argv[])
{

	int opt;
	FILE* output_file;
	toothpaste_pick_t* pick;
	char* user_home_dir=get_user_home_dir();

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
	
	free(user_home_dir);				
	while ((opt = getopt(argc, argv, "ojvxqlrs:")) != -1) {
        switch (opt) {
		case 'o':
		output_to_file=1;
        break;
		case 'j':
		json_flag=1;
        break;
		case 'v':
        version();
        break;
        case 'x':
        pick_random = 1;
        break;		
        case 'q':
        verbose = 0;
        break;
        case 'l':
		lat_flag=1;
	
        break;
        case 'r':
		reset_counters();
        break;
 		case 's':
			set_counters(optarg);
		break;       
		case '?': 
            fprintf(stderr, "Usage: %s [-ojvxqlr] [-s total_picks value] [other arguments]\n", argv[0]);
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
	pick=tpm_pick_toothpaste(toothpastes_list);	
	if (json_flag)
		fprintf(output_file,"%s \n",tpm_get_toothpaste_pick_JSON(pick));
	else
		fprintf(output_file,"%s \n",tpm_get_toothpaste_pick_message(pick));
	if (lat_flag) {
		list_available_toothpastes();
		return finish(1,pick);
	}
if (json_flag)
	finish(0,pick);
else
	finish(1,pick);

}

	
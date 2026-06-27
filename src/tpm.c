/*
	TPM Toothpaste Picking Manager source code 0BSD license
*/
#include "tpm.h"

#define	TPM_NO_ERROR 0
#define	OPTS_IS_NULL 1
#define	MALLOC_FAILED 2
#define	TOOTHPASTES_FAILED 3
#define	PICKSTATS_WRITE_FAILED 4
#define	PICKSTATS_READ_FAILED 5
#define	NO_TOOTHPASTES_LOADED 6
#define	CONFIG_LOAD_FAILED 7
#define	LAST_PICK_WRITING_FAILED 8
#define PICK_NULL 9
#define	NO_TOOTHPASTES_AVAILBLE 10
#define	NULL_CONTEXT 11



static const toothpaste_data_t toothpastes[TOTAL_TOOTHPASTES]={
	{PASTE_BUILTIN,0,"BUILTIN TOOTHPASTE 1",75,90,"White", "Builtin Toothbrush 1",20,50},
	{PASTE_BUILTIN,1,"BUILTIN TOOTHPASTE 2",150,100,"Black", "Builtin Toothbrush 2",25,75},
	{PASTE_BUILTIN,2,"BUILTIN TOOTHPASTE 3",50,80,"Pink", "Builtin Toothbrush 3",20,50}
};
static const char* pick_type_strings[TOTAL_PICK_TYPE_STRINGS]={
	"Default",
	"Random",
	"By index",
	"By brand",
	"Max rating",
	"Max tube mass",
	"Min rating",
	"Min tube mass"
};
static const char* toothpaste_type_strings[TOTAL_TOOTHPASTE_TYPES]={
	"Random", 
	"Nothing",
	"Unknown",
	"0-paste",
	"Builtin"
	
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
	"Night",
	"Morning",
	"Day",
	"Evening"
};
static const char* error_strings[TOTAL_ERROR_MESSAGES]={
	"Error 0: No error.",
	"Error 101: opts is NULL",
	"Error 102: Memory allocation failed.",
	"Error 103: Opening toothpastes file falling back to default.",
	"Error 104: Opening pickstats file for writing",
	"Error 105: Opening pickstats file for reading",
	"Error 106: No toothpastes file loaded",
	"Error 107: Unable to load config ~tpm/tpm.conf\n",
	"Error 108: Opening last_pick file for writing",
	"Error 109: Pick is NULL perform pick first",
	"Error 110: No toothpastes available.",
	"Error 111: NULL context",
};
static const char* user_strings[TOTAL_USER_MESSAGES]={
	"Pick counter clear",
	"# Index | Brand | Tube Mass | Rating",
	"# Index | Brand | Tube Mass | Rating | Toothbrush Color | Toothbrush Brand | Toothbrush Length | Toothbrush Hardness",
	"Pick counter set",
	"Welcome to the toothpaste picking manager",
	"New next pick stats updated",
	"Toothbrush time span over swap the toothbrush(or order new one)",
	"Time span over please visit dentist",
	"Already picked today",
	"Pick type",
	"Toothpaste:",
	"Toothbrush:",
	"Toothpaste index:",
	"Toothpaste type:",
	"Dental Formula:",
	"Day:",
	"Total picks:",
	"Tubes wasted:",
	"Source:",
	"Meme:",
	"Last pick time:",
	"Good",
	"Press Enter to continue...",
	"Compiler:",
	"Compiled on:",
	"Anonymous",
	"Output pick to file ",
	"Usage:",
	"BUILTIN TOOTHPASTE 1",
	"BUILTIN TOOTHPASTE 2",
	"BUILTIN TOOTHPASTE 3"
};

static const char left_armour[TOTAL_USER_ARMOUR]={"<<<"};
static const char right_armour[TOTAL_USER_ARMOUR]={">>>"};


static const char stats_file_name[MAX_PATH] ="pickstats";
static const char toothpastes_file_name[MAX_PATH] ="toothpastes";
static const char output_file_name[MAX_PATH] ="last_pick";
static const char config_file_name[MAX_PATH] ="tpm.conf";

int 
init_tpm_locale(char* locale_id, toothpaste_pick_options_t* opts)
{
    setlocale(LC_ALL, opts->tpm_locale);

#if defined(_WIN32) || defined(_WIN64)
    char exe_path[MAX_PATH];
    char locale_path[MAX_PATH];
    
    GetModuleFileNameA(NULL, exe_path, MAX_PATH);
    
    char *last_slash = strrchr(exe_path, '\\');
    if (last_slash) *last_slash = '\0';
    
    snprintf(locale_path, sizeof(locale_path), "%s\\locale", exe_path);
    
    bindtextdomain("tpm", locale_path);
#else	
#ifdef LOCALEDIR
    bindtextdomain("tpm", LOCALEDIR);
#else
    bindtextdomain("tpm", "/usr/local/share/locale");
#endif
#endif
    textdomain("tpm");
	return 0;
}

TPM int 
tpm_init_context(toothpaste_pick_options_t* opts) 
{
    if (opts == NULL) return NULL_CONTEXT;

    memset(opts, 0, sizeof(toothpaste_pick_options_t));

 
    opts->ptype = PICK_DEFAULT;
    opts->verbose = 1;         
    opts->lat_flag = 0;
    opts->json_flag = 0;
    opts->csv_flag = 0;
    opts->fake_stats = 0;
    opts->output_to_file = 0;
    opts->upper_brands = 0;
	opts->formula = (dental_formula_t) {2,2,2,2};
    opts->delta_days = 0;
    opts->delta_hours = 0;
    opts->config_load_failure = 0;
    opts->toothpastes_list = NULL;
    opts->username = NULL;     

    opts->meme_payload = (char*)malloc(MAX_TOOTHPASTE_LINE);
    opts->tpm_template = (char*)malloc(TOTAL_OUTPUT_STRINGS + 1);
	
	opts->stats_file_path_final = (char*)malloc(MAX_PATH);
    opts->toothpastes_file_path_final= (char*)malloc(MAX_PATH);
    opts->output_file_path_final= (char*)malloc(MAX_PATH);
    opts->config_file_path_final= (char*)malloc(MAX_PATH);

    if (!opts->meme_payload || !opts->tpm_template) 
    {
        free(opts->meme_payload);
        free(opts->tpm_template);
        return MALLOC_FAILED;
    }

    memset(opts->meme_payload, 0, MAX_TOOTHPASTE_LINE);
    memset(opts->tpm_template, 0, TOTAL_OUTPUT_STRINGS + 1);
	
	
	if (!opts->stats_file_path_final || !opts->toothpastes_file_path_final || 
		!opts->output_file_path_final || !opts->config_file_path_final) 
	{
		free(opts->stats_file_path_final);
		free(opts->toothpastes_file_path_final);
		free(opts->output_file_path_final);
		free(opts->config_file_path_final);
		
		return MALLOC_FAILED; 
	}
	
	memset(opts->stats_file_path_final,0,MAX_PATH);
    memset(opts->toothpastes_file_path_final,0,MAX_PATH);
    memset(opts->output_file_path_final,0,MAX_PATH);
    memset(opts->config_file_path_final,0,MAX_PATH);
	
	

    opts->tpm_template[0] = '*'; 
    opts->tpm_template[1] = '\0';

    char* user_home_dir = get_user_home_dir();
    char user_home_dir_static[MAX_PATH];
    
    if (user_home_dir != NULL) 
    {
        strncpy(user_home_dir_static, user_home_dir, MAX_PATH - 1);
        user_home_dir_static[MAX_PATH - 1] = '\0';
        free(user_home_dir);
    } 
    else 
    {
        strncpy(user_home_dir_static, ".", MAX_PATH - 1);
    }

#ifdef _WIN32
    strncat(user_home_dir_static, "\\tpm\\", MAX_PATH / 2);
#else
    strncat(user_home_dir_static, "/tpm/", MAX_PATH / 2);
#endif

    strncpy(opts->stats_file_path_final, user_home_dir_static, MAX_PATH - 1);
    strncat(opts->stats_file_path_final, stats_file_name, MAX_PATH / 2);
	
    strncpy(opts->toothpastes_file_path_final, user_home_dir_static, MAX_PATH - 1);
    strncat(opts->toothpastes_file_path_final, toothpastes_file_name, MAX_PATH / 2);
	
    strncpy(opts->output_file_path_final, user_home_dir_static, MAX_PATH - 1);
    strncat(opts->output_file_path_final, output_file_name, MAX_PATH / 2);

    strncpy(opts->config_file_path_final, user_home_dir_static, MAX_PATH - 1);
    strncat(opts->config_file_path_final, config_file_name, MAX_PATH / 2);
	
	memset(opts->tpm_locale, 0, MAX_LOCALE_CODE + 1);
    init_tpm_locale(opts->tpm_locale,opts); 
	return TPM_NO_ERROR; 
}

static void 
free_context(toothpaste_pick_options_t* opts) 
{
    if (opts == NULL) return;
    
    free(opts->meme_payload);
    free(opts->tpm_template);
    free(opts->username);
	free(opts->stats_file_path_final);
	free(opts->toothpastes_file_path_final);
	free(opts->output_file_path_final);
	free(opts->config_file_path_final);	
    
   
}


static list_node_t* 
create_node(toothpaste_data_t p_data) 
{
    list_node_t* new_node = (list_node_t*)malloc(sizeof(list_node_t));
    
	if (new_node == NULL) 
	{
        perror(_(error_strings[MALLOC_FAILED]));
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
    list_node_t* current = head;
	
	if (head == NULL) 
	{
        return new_node;
    }
    while (current->next != NULL) 
	{
        current = current->next;
    }
    current->next = new_node;
    return head;
}

static char*
rtrim(char *s) 
{
    int i = strlen(s) - 1; 

    while (i >= 0 && isspace((unsigned char)s[i])) 
	{
        i--;
    }

  
    s[i + 1] = '\0';
	
	return s;
}

static void
ltrim(char *s) 
{
    char* tmp = s;

	while (isspace(*tmp)) 
	{
		++tmp;
	}

    memmove(s, tmp, tmp - s); 
                               
	return;
}

static int
check_enhanced_toothpastes(const char* filename)
{
	FILE* file; 
	char line[MAX_LINE_LENGTH];
	int i = 0;
	int total_comas = 0;
	int found_valid_line = 0; 
	
	file = fopen(filename, "r");
	if (file == NULL) 
	{
		return 0;
	}
	

	memset(line, 0, sizeof(line));
	
	while (fgets(line, sizeof(line), file) != NULL) 
	{
		char* current = line; 

		while (isspace((unsigned char)*current)) 
		{
			current++;
		}

		if (*current == '\0' || *current == COMMENT_CHAR) 
		{
			continue; 
		}


		found_valid_line = 1;
		total_comas = 0; 


		for (i = 0; i < MAX_LINE_LENGTH; i++)
		{	
			if (line[i] == ',') total_comas++;	
			if (line[i] == '\0') break;
		}
		
	
		break; 
	}

	fclose(file); 


	if (!found_valid_line)
	{
		return 0;
	}

	if (total_comas == ENHANCED_MODE_COMAS) 
	{
		return 1;
	}
	else 
	{
		return 0;		
	}
}


int 
tpm_load_list_from_file(const char* filename,toothpaste_pick_options_t* opts,list_node_t** head) 
{
    unsigned int i;
    unsigned int cnt = 0;
    FILE* file; 
    toothpaste_data_t temp_data;
    char line[MAX_LINE_LENGTH];
    char long_line[4 * MAX_LINE_LENGTH];
    size_t copy_len=0;

    file = fopen(filename, "r");
    
    if (file == NULL) 
    {
        perror(_(error_strings[TOOTHPASTES_FAILED]));
        for (i = 0; i < TOTAL_TOOTHPASTES; i++)
        {
            memset(&temp_data, 0, sizeof(toothpaste_data_t));
            temp_data = toothpastes[i];
            
            temp_data.toothpaste_brand = toothpastes[i].toothpaste_brand ? strdup(toothpastes[i].toothpaste_brand) : NULL;
            temp_data.toothbrush_brand = toothpastes[i].toothbrush_brand ? strdup(toothpastes[i].toothbrush_brand) : NULL;
            temp_data.toothbrush_color = toothpastes[i].toothbrush_color ? strdup(toothpastes[i].toothbrush_color) : NULL;
            
            *head = add_to_list(*head, temp_data);    
        }
        return TOOTHPASTES_FAILED;
    }
    
	opts->enhanced_toothpastes = check_enhanced_toothpastes(filename);
	
    while (fgets(line, sizeof(line), file) != NULL) 
    {

        char* current = line;

        while (isspace((unsigned char)*current)) 
        {
            current++;
        }

        if (*current == '\0' || *current == COMMENT_CHAR) 
        {
            continue; 
        }
        
        temp_data.toothpaste_brand = malloc(MAX_TOOTHPASTE_LINE);
        temp_data.toothbrush_brand = malloc(MAX_TOOTHPASTE_LINE);
        temp_data.toothbrush_color = malloc(MAX_TOOTHBRUSH_COLOR);
        
        if (!temp_data.toothpaste_brand || !temp_data.toothbrush_brand || !temp_data.toothbrush_color) {
            perror(_(error_strings[MALLOC_FAILED]));
            free(temp_data.toothpaste_brand);
            free(temp_data.toothbrush_brand);
            free(temp_data.toothbrush_color);
            fclose(file);
            return MALLOC_FAILED;
        }
        
        memset(temp_data.toothpaste_brand, 0, MAX_TOOTHPASTE_LINE);
        memset(temp_data.toothbrush_brand, 0, MAX_TOOTHPASTE_LINE);
        memset(temp_data.toothbrush_color, 0, MAX_TOOTHBRUSH_COLOR);
        memset(long_line, 0, sizeof(long_line));
        
        int parsed_items = 0;

        if (!opts->enhanced_toothpastes) {
            parsed_items = sscanf(current, "%u, %4095[^,],%u,%u\n", 
                                  &temp_data.index, long_line, &temp_data.tube_mass_g, &temp_data.rating);
            if (parsed_items == 4) {
                strncpy(temp_data.toothbrush_color, toothpastes[0].toothbrush_color, MAX_TOOTHBRUSH_COLOR - 1);
                strncpy(temp_data.toothbrush_brand, toothpastes[0].toothbrush_brand, MAX_TOOTHPASTE_LINE - 1);
                temp_data.toothbrush_length_cm = toothpastes[0].toothbrush_length_cm;
                temp_data.toothbrush_hardness = toothpastes[0].toothbrush_hardness;
            }
        }
        else {
            parsed_items = sscanf(current, "%u, %4095[^,],%u,%u,%32[^,],%128[^,],%u,%u\n", 
                                  &temp_data.index, long_line, &temp_data.tube_mass_g, &temp_data.rating,
                                  temp_data.toothbrush_color, temp_data.toothbrush_brand, 
                                  &temp_data.toothbrush_length_cm, &temp_data.toothbrush_hardness);
        }
        
        if ((!opts->enhanced_toothpastes && parsed_items == 4) || (opts->enhanced_toothpastes && parsed_items == 8)) 
        {
    
			copy_len = strlen(long_line);
			memcpy(temp_data.toothpaste_brand, long_line, copy_len);
			temp_data.toothpaste_brand[copy_len] = '\0';
            ltrim(rtrim(temp_data.toothpaste_brand));
            
            temp_data.type = PASTE_RANNDOM;
            if (0 == strcmp(toothpaste_type_strings[1], temp_data.toothpaste_brand))
            {
                temp_data.type = PASTE_NOTHING;
            }
            
            if (0 == strcmp(toothpaste_type_strings[2], temp_data.toothpaste_brand))
            {
                temp_data.type = PASTE_UNKNOWN;    
            }        
            
            *head = add_to_list(*head, temp_data);    
            cnt++;
            if (cnt > MAX_TOOTHPASTE_LINES) { break; }
        } 
        else 
        {
         
            free(temp_data.toothpaste_brand);
            free(temp_data.toothbrush_brand);
            free(temp_data.toothbrush_color);
        }
    }
    
    if (cnt == 1 && *head != NULL) {
        (*head)->data.type = PASTE_NULL;
    }
    
    if (cnt == 0)
    {
        for (i = 0; i < TOTAL_TOOTHPASTES; i++)
        {
            temp_data = toothpastes[i];
			*head = add_to_list(*head, temp_data);    
        }
    }
    
    fclose(file);
    return TPM_NO_ERROR;
}

static void 
display_list(list_node_t* head, toothpaste_pick_t* pick) 
{
	unsigned int cnt=0;
    list_node_t* current = head;
	char line[4*MAX_TOOTHPASTE_LINE];
	int i = 0;
	unsigned int len =0;
	
	memset(line,0,4*MAX_TOOTHPASTE_LINE);
	memset(pick->message,0,OUTPUT_BLOCK_SIZE);
	
		if (!pick->opts->enhanced_toothpastes)
		{
			snprintf(pick->message,MAX_TOOTHPASTE_LINE,"%s \n",_(user_strings[MSG_COMMENT]));
		}
		else
		{
			snprintf(pick->message,MAX_TOOTHPASTE_LINE,"%s \n",_(user_strings[MSG_ENHANCED_COMMENT]));
		}
	while (current != NULL) 
	{
        if (pick->opts->upper_brands)
		{
			len = strlen(current->data.toothpaste_brand);
			for (i =0; i<len; i++)
			{
				current->data.toothpaste_brand[i]=toupper(current->data.toothpaste_brand[i]);
			}
		}
		if (!pick->opts->enhanced_toothpastes)
		{
			snprintf(line,MAX_TOOTHPASTE_LINE,"%d,%.120s,%d,%d\n", current->data.index, current->data.toothpaste_brand, current->data.tube_mass_g, current->data.rating);
		}
		else
		{
			snprintf(line,4*MAX_TOOTHPASTE_LINE,"%d,%.120s,%d,%d,%.30s,%.120s,%u,%u\n", current->data.index, current->data.toothpaste_brand, current->data.tube_mass_g, current->data.rating, current->data.toothbrush_color, current->data.toothbrush_brand, current->data.toothbrush_length_cm, current->data.toothbrush_hardness);
		}
		
        strncat(pick->message,line,MAX_LINE_LENGTH);
		current = current->next;
		cnt++;
		if (cnt>MAX_TOOTHPASTE_LINES){break;}
	}
	return;
}

static unsigned int 
count_list(list_node_t* head) 
{
    unsigned int i=0;
	list_node_t* current = head;
	
    while (current != NULL) 
	{
        i++;
        current = current->next;
	}
	return i;
}

static toothpaste_data_t 
get_item_by_index(list_node_t* head,unsigned int i) 
{
 
    toothpaste_data_t empty ={PASTE_RANNDOM,0,NULL,0,0,NULL,NULL,0,0}; 
	list_node_t* current = head;
	
    while (current != NULL) 
	{
        if (current->data.index==i)
		{
			return current->data;
        }
		current = current->next;
    }
	return empty;
}

static toothpaste_data_t 
get_item_by_brand_string(list_node_t* head,const char* str) 
{
    toothpaste_data_t empty ={PASTE_RANNDOM,0,NULL,0,0,NULL,NULL,0,0}; ; 
	list_node_t* current = head;
	
    while (current != NULL) 
	{
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
	
    while (head != NULL) 
	{
        temp = head;
        head = head->next;
        free(temp->data.toothpaste_brand);
	    free(temp->data.toothbrush_color);
		free(temp->data.toothbrush_brand);
		free(temp);
		
    }
	return;
}


static int 
reset_counters(toothpaste_pick_options_t* opts) 
{
	FILE* file_ptr;
	unsigned int zero=0;
	time_t zero_time =0;
	
	file_ptr = fopen(opts->stats_file_path_final, "wb");
	if (file_ptr == NULL) 
	{
		perror(_(error_strings[PICKSTATS_WRITE_FAILED]));
		return 3;
	}	

	fwrite(&zero, sizeof(unsigned int), 1, file_ptr);
	fwrite(&zero_time, sizeof(time_t), 1, file_ptr);
	fclose(file_ptr);
	printf("%s \n", _(user_strings[MSG_PICK_COUNTER_C])); 
	return 0;
}

static int 
set_counters(void* optarg,toothpaste_pick_options_t* opts) 
{
	FILE* file_ptr;
	unsigned int zero=0;
	time_t total_seconds=time(NULL)+opts->delta_hours*SECONDS_PER_HOUR;
	
	zero = atoi(optarg);
	file_ptr = fopen(opts->stats_file_path_final, "wb");
	if (file_ptr == NULL) 
	{
		perror(_(error_strings[PICKSTATS_WRITE_FAILED]));
		return 3;
	}	


	fwrite(&zero, sizeof(unsigned int), 1, file_ptr);
	fwrite(&total_seconds, sizeof(time_t), 1, file_ptr);
	fclose(file_ptr);
	printf("%s \n", _(user_strings[MSG_PICK_COUNTER_S])); 

	return 0;
}

static unsigned int
read_counters(toothpaste_pick_stats_t* stats,int fake_stats,toothpaste_pick_options_t* opts)
{
	FILE* file_ptr;
	unsigned int nbytes=0;
	
	stats->total_picks=0;
	stats->last_pick_time=0;
	if (!fake_stats)
	{	
		file_ptr = fopen(opts->stats_file_path_final, "rb");
		if (file_ptr == NULL) 
		{
			perror(_(error_strings[PICKSTATS_READ_FAILED]));
			return 4;
		}

		nbytes=fread(&(stats->total_picks), sizeof(unsigned int), 1, file_ptr);
		nbytes+=fread(&(stats->last_pick_time), sizeof(time_t), 1, file_ptr);
	   
		fclose(file_ptr);	
	}
	else 
	{
		seed_xrp32(time(NULL));
		stats->total_picks=rand_range(0,BRUSHES_PER_LIFETIME);
		stats->last_pick_time=time(NULL)-SECONDS_PER_DAY+opts->delta_hours*SECONDS_PER_HOUR;
	}
	return nbytes;
}

static int
list_available_toothpastes(toothpaste_pick_t* pick)
{
	display_list(pick->where,pick);
	return 0;
}

static int
write_counters(toothpaste_pick_stats_t stats,int fake_stats,toothpaste_pick_options_t* opts)
{
	FILE* file_ptr;
	if (!fake_stats)
	{
		file_ptr = fopen(opts->stats_file_path_final, "wb");
		if (file_ptr == NULL) 
		{
			perror(_(error_strings[PICKSTATS_WRITE_FAILED]));
			return 3;
		}
		fwrite(&stats.total_picks, sizeof(unsigned int), 1, file_ptr);
		fwrite(&stats.last_pick_time, sizeof(time_t), 1, file_ptr);
		fclose(file_ptr);
	}
	return 0;
}

static void 
stop_system(void) 
{
    int c;
	
    printf("%s",_(user_strings[MSG_PAUSE]));
    while ((c = getchar()) != EOF && c != '\n');
    getchar(); 
	
	return;
}

TPM int 
tpm_free_toothpaste_pick(toothpaste_pick_t* pick)
{
	if (pick!=NULL)
	{
		free(pick->who);
		free(pick->message);
		free(pick->JSON);
		free(pick->CSV);
		free(pick->waste_report);
		free_list(pick->where);
		free_context(pick->opts);
		return TPM_NO_ERROR;
	}
	else 
	{
		perror(_(error_strings[PICK_NULL]));
		return PICK_NULL;
	}
}

static int 
finish(int flag,toothpaste_pick_t* pick)
{
	tpm_free_toothpaste_pick(pick);
	if (flag) 
	{
#ifdef _WIN32
	system("pause");
#else
	stop_system();
#endif
	}
	return 0;
}

static char* 
get_user_home_dir(void) 
{
    char* home_dir = NULL;

#ifdef _WIN32
    const char* user_profile_env = getenv("USERPROFILE");
	const char* home_drive;
    const char* home_path;
	size_t len; 
	
    if (user_profile_env != NULL) 
	{
        home_dir = _strdup(user_profile_env); 
    } 
	else {
		home_drive = getenv("HOMEDRIVE");
		home_path = getenv("HOMEPATH");
		if (home_drive != NULL && home_path != NULL) 
		{
			len = strlen(home_drive) + strlen(home_path) + 1;
			home_dir = malloc(len);
			if (home_dir != NULL) 
			{
				snprintf(home_dir, len, "%s%s", home_drive, home_path);
			}
		}
    }
#else
    const char* home_env = getenv("HOME");
    struct passwd *pwd;
    uid_t uid;
	
    if (home_env != NULL) 
	{
        home_dir = strdup(home_env);
    } 
	else 
	{
        uid = getuid();
		pwd = getpwuid(uid);
        if (pwd != NULL) {
            home_dir = strdup(pwd->pw_dir);
        }
    }
#endif
    return home_dir;
}

static int 
get_current_username(char* buffer, size_t buffer_size) 
{
#ifdef _WIN32
    DWORD len = (DWORD)buffer_size;
	
    if (GetUserName(buffer, &len)) 
	{
        return 0; 
    }
    return -1; 
#else
    uid_t uid = geteuid();
    struct passwd *pw = getpwuid(uid);
	const char* user_env = getenv("LOGNAME");
	
    if (pw != NULL) 
	{
        strncpy(buffer, pw->pw_name, buffer_size-1);
        buffer[buffer_size - 1] = '\0';
        return 0; 
    }
    

    if (user_env == NULL) 
	{
        user_env = getenv("USER");
    }
    if (user_env != NULL) 
	{
        strncpy(buffer, user_env, buffer_size-1);
        buffer[buffer_size - 1] = '\0';
        return 0;
    }
    return -1; 
#endif
}

static void
version(void)
{
	printf("%s %u.%u.%u \n",TPM_STRING,TPM_VERSION_MAJOR,TPM_VERSION_MINOR,TPM_VERSION_PATCH);
	printf("%s %s at %s\n",_(user_strings[MSG_COMPILED]) , __DATE__, __TIME__);
#if defined(__clang__)
    printf("%s Clang/LLVM %d.%d \n",_(user_strings[MSG_COMPILER]),__clang_major__,__clang_minor__);
#elif defined(__GNUC__) || defined(__GNUG__)
    printf("%s GCC %d.%d \n", _(user_strings[MSG_COMPILER]), __GNUC__,__GNUC_MINOR__);
#elif defined(_MSC_VER)
    printf("%s Microsoft Visual Studio %d\n",_(user_strings[MSG_COMPILER]),_MSC_VER);
#elif defined(__INTEL_COMPILER)
    printf("%s Intel ICC %d \n",_(user_strings[MSG_COMPILER]),__INTEL_COMPILER);
#elif defined(__TINYC__ )
    printf("%s Tiny CC %d \n",_(user_strings[MSG_COMPILER]),__TINYC__);
#elif defined(__EMSCRIPTEN__)
    printf("%s Emscripten %d.%d \n",_(user_strings[MSG_COMPILER]),__EMSCRIPTEN_major__, __EMSCRIPTEN_minor__);	
#else
    printf("%s %s","%s\n",_(user_strings[MSG_COMPILER]),user_strings[MSG_COMPILER_UNKNOWN]);
#endif
	exit(EXIT_FAILURE);
	return;
}

TPM int 
tpm_get_toothpaste_picking_message(toothpaste_pick_t* pick, char** dest)
{
	if (pick==NULL) 
	{
		perror(_(error_strings[PICK_NULL]));
		*dest = NULL;
		return PICK_NULL;
	}
	*dest = pick->message;
	return TPM_NO_ERROR;
}

TPM int
tpm_get_toothpaste_picking_JSON(toothpaste_pick_t* pick, char** dest)
{
	if (pick==NULL) 
	{
		perror(_(error_strings[PICK_NULL]));
		*dest = NULL;
		return PICK_NULL;
	}
	*dest = pick->JSON;
	return TPM_NO_ERROR;
}

TPM int
tpm_get_toothpaste_picking_CSV(toothpaste_pick_t* pick, char** dest)
{
	if (pick==NULL) 
	{
		perror(_(error_strings[PICK_NULL]));
		*dest=NULL;
		return PICK_NULL;
	}
	*dest = pick->CSV;
	return TPM_NO_ERROR;
}
/*[min,max)*/
static uint64_t
rand_range(uint64_t min, uint64_t max)
{
    int r;
    uint64_t range = max - min;
    uint64_t buckets = XRP_MAX / range;
    uint64_t limit = buckets * range;
	
	if (min == max) 
	{
		return min; 
	}
    if (min>max) 
	{
		SWAP(min,max); 
	}
    do 
	{
        r = prng64_xrp32();
    } 
	while (r >= limit);

    return (r % (max - min)) + min; 
}

static char* 
report_wasted_tubes(list_node_t* head,toothpaste_pick_stats_t* stats)
{
	char* report;
	unsigned int* rip_tubes;
	unsigned int total_toothpastes=count_list(head);
	int i=0;
	unsigned int total_wasted=0;
	char report_term[MAX_REPORT_TERM];
	unsigned int total_nulls=0;
	toothpaste_pick_stats_t real_stats;
	
	memset(report_term,0,MAX_REPORT_TERM);
	rip_tubes=malloc(sizeof(unsigned int)*total_toothpastes);
	memset(rip_tubes,0,sizeof(unsigned int)*total_toothpastes);
	report=malloc(total_toothpastes*MAX_REPORT_TERM);
	memset(report,0,total_toothpastes*MAX_REPORT_TERM);
	list_node_t* current = head;
	
	
	
    while (current != NULL) 
	{
		if (current->data.type==PASTE_NOTHING) 
		{
			rip_tubes[total_nulls]=0;
			total_nulls++;
		}	
		current = current->next;	
	}
	if (total_toothpastes==total_nulls)
		real_stats.total_picks=stats->total_picks;
	else
		real_stats.total_picks=stats->total_picks*(total_toothpastes-total_nulls)/total_toothpastes;
	current = head;
	while (current != NULL) 
	{
		 if (current->data.type==PASTE_NOTHING) 
		 {	
			rip_tubes[i]=0;
		 }
		 else
		 {
			if (total_toothpastes==total_nulls)
				rip_tubes[i]=0;
			else
				rip_tubes[i]=(real_stats.total_picks/(total_toothpastes-total_nulls))*GRAMS_PER_NURDLE/current->data.tube_mass_g;
		 }       
		
        total_wasted+=rip_tubes[i];
		current = current->next;
		i++;		
	}
	for (i=0;i<total_toothpastes;i++)
	{
		if (i==total_toothpastes-1)
		{
			snprintf(report_term,MAX_REPORT_TERM,"%u=%u",rip_tubes[i],total_wasted);
		}
		else
		{
			snprintf(report_term,MAX_REPORT_TERM,"%u+",rip_tubes[i]);
		}	
		strncat(report,report_term,MAX_REPORT_TERM);
	}
	
	free(rip_tubes);
	return report;
}

static int
eval_total_toothpastes(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	if (topts==NULL || pick == NULL) return 1;
	pick->total_toothpastes = count_list(pick->head);
	if (0==pick->total_toothpastes) 
	{
			perror(_(error_strings[NO_TOOTHPASTES_LOADED]));
	}
	return 0;
}


static int
eval_username(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char username[UNLEN + 1];
	if (topts==NULL || pick == NULL) return 1;
	pick->who=malloc(UNLEN);
	memset(username,0,UNLEN);
	memset(pick->who,0,UNLEN);
	
	
	if (get_current_username(username, sizeof(username)) == 0) 
	{
		strncpy(pick->who,topts->username,UNLEN);
    }
	else 
	{
        strncpy(pick->who,user_strings[MSG_ANON],UNLEN);
    }
	return 0;
}

static char*
str_good_day(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_TOOTHPASTE_LINE);
	if (topts==NULL || pick == NULL) return NULL;	
	memset(line,0,MAX_TOOTHPASTE_LINE);
	snprintf(line,MAX_TOOTHPASTE_LINE,"%s %s ", _(user_strings[MSG_GOOD]), _(times_of_day[topts->time_of_day_ind]));

	return line;
}

static char*
str_anon_username(toothpaste_pick_t* pick, toothpaste_pick_options_t* topts)
{
    
    size_t buffer_size = UNLEN + 2; 
    char* line = malloc(buffer_size);
    if (line == NULL) return NULL;

    snprintf(line, buffer_size, "%s ", pick->who);
	
    return line;
}

static char*
str_welcome(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_TOOTHPASTE_LINE);
	if (topts==NULL || pick == NULL) return NULL;	
	memset(line,0,MAX_TOOTHPASTE_LINE);
	snprintf(line,MAX_TOOTHPASTE_LINE,"%s \n" ,_(user_strings[MSG_WELCOME]));
	
	return line;
}

static char*
str_next_pick(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_TOOTHPASTE_LINE);
	if (topts==NULL || pick == NULL) return NULL;	
	memset(line,0,MAX_TOOTHPASTE_LINE);
	snprintf(line,MAX_TOOTHPASTE_LINE,"%s \n", _(user_strings[MSG_NEXT_PICK]));
	
	return line;
}

static char*
str_new_toothbrush(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_TOOTHPASTE_LINE);
	if (topts==NULL || pick == NULL) return NULL;	
	memset(line,0,MAX_TOOTHPASTE_LINE);	
	snprintf(line,MAX_TOOTHPASTE_LINE,"%s \n", _(user_strings[MSG_SWAP_TOOTHBRUSH]));
	
	return line;
}

static char*
str_visit_dentist(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_TOOTHPASTE_LINE);
	if (topts==NULL || pick == NULL) return NULL;		
	memset(line,0,MAX_TOOTHPASTE_LINE);	
	snprintf(line,MAX_TOOTHPASTE_LINE,"%s \n", _(user_strings[MSG_DENTIST]));
		
	return line;
}

static char*
str_already_picked(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_TOOTHPASTE_LINE);
	if (topts==NULL || pick == NULL) return NULL;		
	memset(line,0,MAX_TOOTHPASTE_LINE);	
	snprintf(line,MAX_TOOTHPASTE_LINE,"%s \n", _(user_strings[MSG_ALREADY]));
		
	return line;
}

static char*
str_pick_type(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_TOOTHPASTE_LINE);
	if (topts==NULL || pick == NULL) return NULL;		
	memset(line,0,MAX_TOOTHPASTE_LINE);	
	snprintf(line,MAX_TOOTHPASTE_LINE,"%s: %s\n", _(user_strings[MSG_PICK_TYPE]), pick_type_strings[topts->ptype]);
		
	return line;
}

static char*
str_toothpaste(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_LINE_LENGTH);
	if (topts==NULL || pick == NULL) return NULL;		
	memset(line,0,MAX_LINE_LENGTH);	
	snprintf(line,MAX_LINE_LENGTH,"%s %s %.127s (%ug) [%u/100] %s \n", _(user_strings[MSG_TOOTHPASTE]), right_armour, pick->what.toothpaste_brand, pick->what.tube_mass_g, pick->what.rating, left_armour);
		
	return line;
}

static char*
str_toothbrush(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_LINE_LENGTH);
	if (topts==NULL || pick == NULL) return NULL;		
	memset(line,0,MAX_LINE_LENGTH);
	
	if (topts->enhanced_toothpastes)
	{
		snprintf(line,MAX_LINE_LENGTH,"%s %s %s %u %u\n", _(user_strings[MSG_TOOTHBRUSH]), pick->what.toothbrush_color, pick->what.toothbrush_brand, pick->what.toothbrush_length_cm, pick->what.toothbrush_hardness);
	}	
	else {
		snprintf(line, 1,"%s","\0");
	}
	return line;
}

static char*
str_toothpaste_index(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_TOOTHPASTE_LINE);
	if (topts==NULL || pick == NULL) return NULL;		
	memset(line,0,MAX_TOOTHPASTE_LINE);	
	snprintf(line,MAX_TOOTHPASTE_LINE,"%s %u/%u \n", _(user_strings[MSG_TOOTHPASTE_I]),pick->toothpaste_pick_index,pick->total_toothpastes);
		
	return line;
}

static char*
str_toothpaste_type(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_TOOTHPASTE_LINE);
	if (topts==NULL || pick == NULL) return NULL;		
	memset(line,0,MAX_TOOTHPASTE_LINE);		
	snprintf(line,MAX_TOOTHPASTE_LINE,"%s %s \n", _(user_strings[MSG_TOOTHPASTE_T]),toothpaste_type_strings[pick->what.type]);
		
	return line;
}

static char*
str_dental_formula(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_TOOTHPASTE_LINE);
	if (topts==NULL || pick == NULL) return NULL;		
	memset(line,0,MAX_TOOTHPASTE_LINE);		
	snprintf(line,MAX_TOOTHPASTE_LINE,"%s %u-%u-%u-%u \n", _(user_strings[MSG_DENTAL]) , topts->formula.brush_times_per_day ,topts->formula.minutes_per_brush , topts->formula.swap_toothbrush_times_per_year , topts->formula.visit_dentist_times_per_year);
		
	return line;
}

static char*
str_day_of_the_week(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_LINE_LENGTH);
	if (topts==NULL || pick == NULL) return NULL;		
	memset(line,0,MAX_LINE_LENGTH);	
	snprintf(line,MAX_LINE_LENGTH,"%s %s %u \n", _(user_strings[MSG_DAY]) ,days_of_week[pick->j],pick->day);
		
	return line;
}

static char*
str_total_picks(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_TOOTHPASTE_LINE);
	if (topts==NULL || pick == NULL) return NULL;	
		memset(line,0,MAX_TOOTHPASTE_LINE);		
		if (topts->fake_stats)
			snprintf(line,MAX_TOOTHPASTE_LINE,"%s ~%u \n", _(user_strings[MSG_TOTAL_PICKS]), pick->stats.total_picks);
		else
			snprintf(line,MAX_TOOTHPASTE_LINE,"%s %u \n", _(user_strings[MSG_TOTAL_PICKS]), pick->stats.total_picks);
		
	return line;
}

static char*
str_last_pick_time(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_TOOTHPASTE_LINE);
	if (topts==NULL || pick == NULL) return NULL;		
	memset(line,0,MAX_TOOTHPASTE_LINE);			
	snprintf(line,MAX_TOOTHPASTE_LINE-2,"%s %s", _(user_strings[MSG_LAST_PICK_TIME]) ,ctime(&pick->stats.last_pick_time));
		
	return line;
}

static char*
str_tubes_wasted(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_TOOTHPASTE_LINE);
	if (topts==NULL || pick == NULL) return NULL;		
	memset(line,0,MAX_TOOTHPASTE_LINE);			
	snprintf(line,MAX_TOOTHPASTE_LINE-2,"%s %s \n", _(user_strings[MSG_TUBES_WASTED]), pick->waste_report);
		
	return line;
}

static char*
str_source(toothpaste_pick_t* pick, toothpaste_pick_options_t* topts)
{
    if (topts == NULL || pick == NULL) return NULL;		
    
    const char* source_str = user_strings[MSG_SOURCE];
    const char* path_str = topts->toothpastes_file_path_final;

    size_t needed = strlen(source_str) + strlen(path_str) + 4;

    char* line = malloc(needed);
    if (line == NULL) return NULL; 
    
    sprintf(line, "%s %s \n", source_str, path_str);
		
    return line;
}

static char*
str_meme(toothpaste_pick_t* pick, toothpaste_pick_options_t* topts)
{
    if (topts == NULL || pick == NULL) return NULL;	


    size_t needed = strlen(user_strings[MSG_MEME]) + strlen(topts->meme_payload) + 3;

    char* line = malloc(needed);
    if (line == NULL) return NULL;
    

    snprintf(line, needed, "%s %s\n", _(user_strings[MSG_MEME]), topts->meme_payload);
    
    return line;
}

static char*
str_quiet(toothpaste_pick_t* pick,toothpaste_pick_options_t* topts)
{
	char* line = malloc(MAX_TOOTHPASTE_LINE);
	
	if (topts==NULL || pick == NULL) return NULL;	
	memset(line,0,MAX_TOOTHPASTE_LINE);			
	snprintf(line,MAX_TOOTHPASTE_LINE,"%.94s (%ug) [%u/100] \n", pick->what.toothpaste_brand,pick->what.tube_mass_g, pick->what.rating);
	return line;
}

static int 
check_visibility(int input_id, int new_pick_flag, int toothbrush_flag, int dentist_flag,int verbose)
{
		if ((input_id ==19)&& verbose) {
			return 0;
		}
	
	if (verbose)
	{
		if ((input_id >=7) || (input_id <=2))
			return 1;
		if ((input_id==3) && (new_pick_flag))
			return 1;
		if ((input_id==4) && (toothbrush_flag))
			return 1;
		if ((input_id==5) && (dentist_flag))
			return 1;
		if ((input_id==6) && (!new_pick_flag)) {
			return 1;
		}
	}
	if ((input_id ==19)&& !verbose) {
		return 1;
	}
	
	return 0;
}
static int
char_to_strnum(char input)
{
	switch(input)
	{
		case 'g':
		return 0;
		break;
		case 'u':
		return 1;
		break;
		case 'w':
		return 2;
		break;
		case 'n':
		return 3;
		break;
		case 't':
		return 4;
		break;
		case 'd':
		return 5;
		break;
		case 'a':
		return 6;
		break;	
		case 'p':
		return 7;
		break;
		case 'o':
		return 8;
		break;
		case 'b':
		return 9;
		break;
		case 'i':
		return 10;
		break;
		case 'T':
		return 11;
		break;		
		case 'f':
		return 12;
		break;		
		case 'W':
		return 13;
		break;		
		case 'P':
		return 14;
		break;		
		case 'l':
		return 15;
		break;		
		case 'U':
		return 16;
		break;		
		case 's':
		return 17;
		break;		
		case 'm':
		return 18;
		break;
		case 'I':
		return 19;
		break;			
		
		default:
			return -1;
			break;
	}
	return -1;
}


TPM int 
tpm_pick_toothpaste(list_node_t* head, toothpaste_pick_options_t* topts, toothpaste_pick_t* pick)
{
    int i = 0, k, ti;
    time_t total_seconds = time(NULL) + topts->delta_days * SECONDS_PER_DAY + topts->delta_hours * SECONDS_PER_HOUR;
    char line[MAX_LINE_LENGTH];
    int new_pick_flag = 0;
    int dentist_flag = 0;
    int toothbrush_flag = 0;
    unsigned int brand_len;
    char* toothpaste_strings[TOTAL_OUTPUT_STRINGS];
	char current_char;
	int str_num = 0;
	int interval;
    size_t current_len;
	size_t remaining_space;
	
    pick->opts = topts;
    memset(line, 0, MAX_LINE_LENGTH);


    pick->message = malloc(OUTPUT_BLOCK_SIZE);
    pick->JSON = malloc(OUTPUT_BLOCK_SIZE);
    pick->CSV = malloc(OUTPUT_BLOCK_SIZE);
    pick->waste_report = NULL;
    pick->head = head;
    
    if (!pick->message || !pick->JSON || !pick->CSV) {

        free(pick->message); free(pick->JSON); free(pick->CSV);
        return MALLOC_FAILED; 
    }
    
    memset(pick->JSON, 0, OUTPUT_BLOCK_SIZE);    
    memset(pick->message, 0, OUTPUT_BLOCK_SIZE);
    memset(pick->CSV, 0, OUTPUT_BLOCK_SIZE);    
    
    eval_username(pick, topts);
    eval_total_toothpastes(pick, topts);
    

    if (pick->total_toothpastes <= 0) {
        snprintf(pick->message, OUTPUT_BLOCK_SIZE,"%s", _(error_strings[NO_TOOTHPASTES_AVAILBLE]));
        return NO_TOOTHPASTES_AVAILBLE; 
    }

    read_counters(&pick->stats, pick->opts->fake_stats,pick->opts);
    pick->waste_report = report_wasted_tubes(head, &pick->stats);
    pick->toothpaste_pick_index = pick->stats.total_picks;
    pick->when = total_seconds;


    if (TOTAL_TIMES_OF_DAY > 0 && (SECONDS_PER_DAY / TOTAL_TIMES_OF_DAY) > 0) {
        topts->time_of_day_ind = (total_seconds) / (SECONDS_PER_DAY / TOTAL_TIMES_OF_DAY) % (TOTAL_TIMES_OF_DAY);
    } else {
        topts->time_of_day_ind = 0;
    }
    
    pick->day = total_seconds / SECONDS_PER_DAY;
    

    i = pick->day % pick->total_toothpastes;
    

    if (topts->ptype == PICK_BY_INDEX) 
    {
        if (topts->pick_by_index_index >= pick->total_toothpastes) {
            i = pick->total_toothpastes - 1;
        } else {
            i = topts->pick_by_index_index;
        }
    }
    else if (topts->ptype == PICK_RANDOM) 
    {
        seed_xrp32(total_seconds);
        i = rand_range(0, pick->total_toothpastes);
    }

  
    if (i < 0 || i >= pick->total_toothpastes) {
        i = 0; 
    }

    if (topts->ptype == PICK_BY_BRAND) 
    {
       pick->what = get_item_by_brand_string(head, topts->brand_string);
    }
    else if (topts->ptype == PICK_MAX_RATING)
    {
        pick->what = find_item_with_max_rating(pick->where);
    }
    else if (topts->ptype == PICK_MAX_MASS)
    {
        pick->what = find_item_with_max_mass(pick->where);
    }
    else if (topts->ptype == PICK_MIN_RATING)
    {
        pick->what = find_item_with_min_rating(pick->where);
    }
    else if (topts->ptype == PICK_MIN_MASS)
    {
        pick->what = find_item_with_min_mass(pick->where);
    }
    else
    {
                pick->what = get_item_by_index(head, i);
    }
    
    pick->where = head;
    
    if (pick->what.toothpaste_brand == NULL) {

        pick->what.toothpaste_brand = "Unknown"; 
    }
    
    brand_len = strlen(pick->what.toothpaste_brand);
    if (topts->upper_brands)
    {    
        for (k = 0; k < brand_len; k++)
        {
            pick->what.toothpaste_brand[k] = toupper((unsigned char)pick->what.toothpaste_brand[k]);
        }
    }
    
    brand_len = strlen(pick->what.toothpaste_brand);
    if (topts->upper_brands)
    {    
        for (k = 0; k < brand_len; k++)
        {
            pick->what.toothpaste_brand[k] = toupper((unsigned char)pick->what.toothpaste_brand[k]);
        }
    }
    
    pick->j = (pick->day) % TOTAL_DAYS_OF_WEEK;
    
    if ((total_seconds - pick->stats.last_pick_time) > (SECONDS_PER_DAY - PICK_TIMEOUT_SECONDS)) 
    {
        new_pick_flag = 1;
        pick->stats.total_picks++;
        pick->stats.last_pick_time = total_seconds;
        write_counters(pick->stats, pick->opts->fake_stats,pick->opts);
        
      
        if (topts->formula.swap_toothbrush_times_per_year > 0) {
            interval = DAYS_PER_YEAR / topts->formula.swap_toothbrush_times_per_year;
            if (interval > 0 && pick->stats.total_picks % interval == 0) {
                toothbrush_flag = 1;
            }
        }
        
        
        if (topts->formula.visit_dentist_times_per_year > 0) {
            interval = DAYS_PER_YEAR / topts->formula.visit_dentist_times_per_year;
            if (interval > 0 && pick->stats.total_picks % interval == 0) {
                dentist_flag = 1;
            }
        }
    }
    

    pick->toothpaste_pick_index = i;
	
	toothpaste_strings[0] = 	str_good_day(pick,topts);
	toothpaste_strings[1] = 	str_anon_username(pick,topts);
	toothpaste_strings[2] = 	str_welcome(pick,topts);
	toothpaste_strings[3] = 	str_next_pick(pick,topts);
	toothpaste_strings[4] = 	str_new_toothbrush(pick,topts);
	toothpaste_strings[5] = 	str_visit_dentist(pick,topts);
	toothpaste_strings[6] = 	str_already_picked(pick,topts);
	toothpaste_strings[7] = 	str_pick_type(pick,topts);
	toothpaste_strings[8] = 	str_toothpaste(pick,topts);
	toothpaste_strings[9] =		str_toothbrush(pick,topts);
	toothpaste_strings[10] = 	str_toothpaste_index(pick,topts);
	toothpaste_strings[11] = 	str_toothpaste_type(pick,topts);
	toothpaste_strings[12] = 	str_dental_formula(pick,topts);
	toothpaste_strings[13] = 	str_day_of_the_week(pick,topts);
	toothpaste_strings[14] = 	str_total_picks(pick,topts);
	toothpaste_strings[15] = 	str_last_pick_time(pick,topts);
	toothpaste_strings[16] = 	str_tubes_wasted(pick,topts);
	toothpaste_strings[17] = 	str_source(pick,topts);
	toothpaste_strings[18] = 	str_meme(pick,topts);
	toothpaste_strings[19] = 	str_quiet(pick,topts);
	
	ti=0;
   if (topts->tpm_template[0] == '*' && topts->tpm_template[1] == '\0') 
    {
        snprintf(topts->tpm_template, TOTAL_OUTPUT_STRINGS+1, "%s", DEFAULT_OUTPUT_TEMPLATE);
    }

    pick->message[0] = '\0'; 

    ti = 0;
    while (topts->tpm_template[ti] != '\0') 
    {
        current_char = topts->tpm_template[ti++];
        str_num = char_to_strnum(current_char);

       
        if (str_num >= 0 && str_num < TOTAL_OUTPUT_STRINGS) 
        {
 
            if (check_visibility(str_num, new_pick_flag, toothbrush_flag, dentist_flag, topts->verbose)) 
            {
                if (toothpaste_strings[str_num] != NULL) 
                {
                    
                    current_len = strlen(pick->message);
                    if (current_len + 1 < OUTPUT_BLOCK_SIZE) 
                    {
                        remaining_space = OUTPUT_BLOCK_SIZE - current_len - 1;
                        
                       
                        strncat(pick->message, toothpaste_strings[str_num], remaining_space);
                    } 
                    else 
                    {
                       
                        break; 
                    }
                }
            }
        }
    }

    for (ti = 0; ti < TOTAL_OUTPUT_STRINGS; ti++) 
    {
        if (toothpaste_strings[ti] != NULL) 
        {
            free(toothpaste_strings[ti]);
            toothpaste_strings[ti] = NULL; 
        }
    }
	
	
    if (pick->who == NULL) {
        pick->who = "Anonymous";
    }
    if (pick->what.toothpaste_brand == NULL) {
        pick->what.toothpaste_brand = "Unknown";
    }
    if (pick->what.toothbrush_color == NULL) {
        pick->what.toothbrush_color = "Unknown";
    }
    if (pick->what.toothbrush_brand == NULL) {
        pick->what.toothbrush_brand = "Unknown";
    }

    snprintf(pick->JSON, OUTPUT_BLOCK_SIZE, 
        "{\n"
        "\t \"who\":\"%s\",\n"
        "\t \"toothpaste\":\"%.127s\",\n"
        "\t \"tube_mass_g\":%u,\n"
        "\t \"rating\":%u,\n"
        "\t \"meme\":\"%s\" \n"
        "}", 
        pick->who, 
        pick->what.toothpaste_brand, 
        pick->what.tube_mass_g, 
        pick->what.rating, 
        topts->meme_payload
    );
		
    char* csv_ptr = pick->CSV;
    size_t csv_rem = OUTPUT_BLOCK_SIZE;
    int written = 0;


    written = snprintf(csv_ptr, csv_rem, "%s,%s,%d,%d,%d,", 
                       pick->who, pick_type_strings[topts->ptype], 
                       new_pick_flag, toothbrush_flag, dentist_flag);
    if (written > 0 && (size_t)written < csv_rem) { csv_ptr += written; csv_rem -= written; }


    written = snprintf(csv_ptr, csv_rem, "%s,%d,%d,", 
                       pick->what.toothpaste_brand, pick->what.tube_mass_g, pick->what.rating);
    if (written > 0 && (size_t)written < csv_rem) { csv_ptr += written; csv_rem -= written; }


    written = snprintf(csv_ptr, csv_rem, "%s,%s,%d,%d,", 
                       pick->what.toothbrush_color, pick->what.toothbrush_brand, 
                       pick->what.toothbrush_length_cm, pick->what.toothbrush_hardness);
    if (written > 0 && (size_t)written < csv_rem) { csv_ptr += written; csv_rem -= written; }


    written = snprintf(csv_ptr, csv_rem, "%d,%d,%s,", 
                       i, pick->total_toothpastes, toothpaste_type_strings[pick->what.type]);
    if (written > 0 && (size_t)written < csv_rem) { csv_ptr += written; csv_rem -= written; }


    written = snprintf(csv_ptr, csv_rem, "%u-%u-%u-%u,%s,%u,", 
                       topts->formula.brush_times_per_day, topts->formula.minutes_per_brush, 
                       topts->formula.swap_toothbrush_times_per_year, topts->formula.visit_dentist_times_per_year,
                       days_of_week[pick->j], pick->day);
    if (written > 0 && (size_t)written < csv_rem) { csv_ptr += written; csv_rem -= written; }

   
    written = snprintf(csv_ptr, csv_rem, LINE_FORMAT_CSV, 
                       pick->stats.total_picks, pick->stats.last_pick_time, 
                       pick->waste_report, topts->toothpastes_file_path_final, topts->meme_payload);
    

    if (written >= (int)csv_rem) 
	{

    }

	
	if (topts->lat_flag) 
	{
		list_available_toothpastes(pick);
	}	
	return TPM_NO_ERROR;
}

static void 
save_default_config(struct cfg_struct* cfg,toothpaste_pick_options_t* opts)
{
	char brand[MAX_TOOTHPASTE_LINE];
	char username[UNLEN];
	
	cfg_set(cfg, "TIMEZONE","0");
	snprintf(username, UNLEN, "%s%s%s", "\"" ,_(user_strings[MSG_ANON]), "\"" );
	snprintf(brand, MAX_TOOTHPASTE_LINE, "%s%s%s", "\"" ,_(toothpaste_type_strings[PASTE_UNKNOWN]), "\"" );
	cfg_set(cfg,"USERNAME",username);
	cfg_set(cfg,"DELTA_DAYS","0");
	cfg_set(cfg,"PICK_TYPE","0");
	cfg_set(cfg,"DENTAL_FORMULA","\"2-2-2-2\"");
	cfg_set(cfg,"VERBOSE","1");
	cfg_set(cfg,"LIST_TOOTHPASTES","0");
	cfg_set(cfg,"OUTPUT_JSON","0");
	cfg_set(cfg,"OUTPUT_CSV","0");
	cfg_set(cfg,"FAKE_STATS","0");	
	cfg_set(cfg,"OUTPUT_FILE","0");
	cfg_set(cfg,"PICK_INDEX","0");
	cfg_set(cfg,"BRAND",brand);
	cfg_set(cfg,"UPPER_BRANDS","0");
	cfg_set(cfg,"SET_COUNTER","0");
	cfg_set(cfg,"RESET_COUNTER","0");
	cfg_set(cfg,"PICK_STATS",opts->stats_file_path_final);
	cfg_set(cfg,"LAST_PICK",opts->output_file_path_final);
	cfg_set(cfg,"TOOTHPASTES",opts->toothpastes_file_path_final);
	cfg_set(cfg,"LOAD_CONFIG",opts->config_file_path_final);
	cfg_set(cfg,"MEME","42");
	cfg_set(cfg,"TEMPLATE",DEFAULT_OUTPUT_TEMPLATE);
	cfg_set(cfg,"LOCALE","en");
	cfg_save(cfg,opts->config_file_path_final);
	
	return;
}


static const
char* cfg_get_rec(const struct cfg_struct* cfg, const char* key)
{
	const char* val;
	unsigned int i=0;
	
	do
	{
		val = cfg_get(cfg,key);
		if ((val==NULL) || (i>MAX_RECURSION)) {if (i==0)key=NULL;break;}

		key=val;
		i++;
		if ((val==NULL)&&(i==1)) return NULL;
	}
	while (val!=NULL);
	return key;
	
}

static int 
file_exists_fopen(const char *filename) 
{
    FILE *file;
	
    if ((file = fopen(filename, "r"))) 
	{
        fclose(file);
        return 1;
    } 
	else 
	{
        return 0;
    }
}

static dental_formula_t
parse_dental_formula(const char* formula_str)
{
	dental_formula_t formula={2,2,2,2};
	if (formula_str==NULL) { return formula; }
	
	sscanf(formula_str,"%u-%u-%u-%u",&(formula.brush_times_per_day),&(formula.minutes_per_brush),&(formula.swap_toothbrush_times_per_year),&(formula.visit_dentist_times_per_year));
	
	if (formula.swap_toothbrush_times_per_year ==0) { formula.swap_toothbrush_times_per_year=1; }
	
	if (formula.visit_dentist_times_per_year ==0) { formula.visit_dentist_times_per_year=1; }
	
	return formula;
}

static int
read_config(const char* src,toothpaste_pick_options_t* opts)
{
	struct cfg_struct* cfg;
	int reset_counters_v=0;
	int set_counters_v=0;
	const char* value = NULL;
	static int recursion =0;

	int result = 0;
	
	cfg = cfg_init();
	if (cfg_load(cfg, src) < 0)
	{
		fprintf(stderr,"%s", _(error_strings[CONFIG_LOAD_FAILED]));
		opts->config_load_failure=1;
		return -1;
    }
	value = cfg_get_rec(cfg, "LOAD_CONFIG");
	if ((value!=NULL) && (strcmp(src,value)==0) && (recursion < MAX_CONFIG_RECURSION)) 		
	{
		recursion++;
		result=read_config(value,opts);
	}
	opts->username=malloc(UNLEN);
	memset(opts->username,0,UNLEN);
	value = cfg_get_rec(cfg, "USERNAME");
	if (value!=NULL)
	{		
		strncpy(opts->username, value,UNLEN); 
	}	
	value = cfg_get_rec(cfg,"DENTAL_FORMULA");
	if (value!=NULL)
	{		
		opts->formula=parse_dental_formula(value); 
	}
	
	value = cfg_get_rec(cfg, "TIMEZONE");
	if ((value!=NULL) && atoi(value)>=-MAX_TIMEZONE_DELTA && atoi(value)<=MAX_TIMEZONE_DELTA) 
	{
		opts->delta_hours=atoi(value);
	}
	value = cfg_get_rec(cfg, "DELTA_DAYS");
	if (value!=NULL)
	{	
		opts->delta_days = atoi(value);
	}
	
	value = cfg_get_rec(cfg, "MEME");
	if (value!=NULL)
	{	
		strncpy(opts->meme_payload,value,MAX_TOOTHPASTE_LINE-1);
	}

	value = cfg_get_rec(cfg, "TEMPLATE");
	if (value!=NULL)
	{	
		strncpy(opts->tpm_template,value,TOTAL_OUTPUT_STRINGS+1);
	}
	
	value = cfg_get_rec(cfg, "LOCALE");
	if (value!=NULL)
	{	
		strncpy(opts->tpm_locale,value,MAX_LOCALE_CODE);
		init_tpm_locale(opts->tpm_locale,opts); 
	}
	
	value = cfg_get_rec(cfg, "PICK_TYPE");
	if ((value!=NULL) && atoi(value)>=0 && atoi(value)<TOTAL_PICK_TYPE_STRINGS)
	{
		opts->ptype =  atoi(value);
	}
	value = cfg_get_rec(cfg, "VERBOSE");
	if (value!=NULL)
	{
		opts->verbose = atoi(value);
	}		
	value = cfg_get_rec(cfg, "TOOTHPASTES");
	if (value!=NULL)
	{
		strncpy(opts->toothpastes_file_path_final,value,MAX_PATH); 
	}
	value = cfg_get_rec(cfg, "LAST_PICK");
	if (value!=NULL) 
	{
		strncpy(opts->output_file_path_final,value,MAX_PATH);
	}	
	value = cfg_get_rec(cfg, "PICK_STATS"); 
	if (value!=NULL) 
	{
		strncpy(opts->stats_file_path_final,value,MAX_PATH); 
	}
	value = cfg_get_rec(cfg, "LIST_TOOTHPASTES");
	if (value!=NULL) 
	{
		opts->lat_flag =  atoi(value);
	}
	value = cfg_get_rec(cfg, "OUTPUT_JSON");
	if (value!=NULL) 
	{
		opts->json_flag =  atoi(value);
	}
	value = cfg_get_rec(cfg, "OUTPUT_CSV");
	if (value!=NULL) 
	{
		opts->csv_flag =  atoi(value);
	}
	value = cfg_get_rec(cfg, "FAKE_STATS");
	if (value!=NULL) 
	{
		opts->fake_stats =  atoi(value);
	}
	value = cfg_get_rec(cfg, "OUTPUT_FILE");
	if (value!=NULL) 
	{
		opts->output_to_file =  atoi(value);
	}
	value = cfg_get_rec(cfg, "PICK_INDEX");
	if (value!=NULL) 
	{
		opts->pick_by_index_index =  atoi(value);
	}
	value = cfg_get_rec(cfg, "BRAND");
	if (value!=NULL) 
	{
		opts->brand_string = (value);
	}
	value = cfg_get_rec(cfg, "UPPER_BRANDS");
	if (value!=NULL) 
	{
		opts->upper_brands = atoi(value);
	}
	value = cfg_get_rec(cfg, "RESET_COUNTER");
	if (value!=NULL) 
	{
		reset_counters_v=atoi(cfg_get_rec(cfg, "RESET_COUNTER"));
	}
	if (reset_counters_v)
	{
		reset_counters(opts);
	}
	value = cfg_get_rec(cfg, "SET_COUNTER");
	if (value!=NULL) 
	{
		set_counters_v=atoi(cfg_get_rec(cfg, "SET_COUNTER"));
	}
	if (set_counters_v)
	{ 
		set_counters(&set_counters_v,opts);
	}
	cfg_free(cfg);
	return result;
}

#ifdef HAVE_MAIN
TPM int
main(int argc, char* argv[])
#else
TPM int
do_not_test_me(int argc, char* argv[])	
#endif
{

	int result;
	int opt;
	FILE* output_file;
	toothpaste_pick_options_t topts;
	struct cfg_struct* cfg;
	int option_index = 0;
	toothpaste_pick_t pick;
	char* out_msg=NULL;
	char* out_JSON=NULL;
	char* out_CSV=NULL;
	
		struct option long_options[] = {
    {"rating",     no_argument, 0, 'a'},
    {"weight",  no_argument,       0, 'w'},
    {"json",  no_argument, 0, 'j'},
    {"csv",  no_argument, 0, 'C'},
    {"version", no_argument,       0, 'v'},
    {"random", no_argument,       0, 'x'},
    {"quiet", no_argument,       0, 'q'},
    {"list", no_argument,       0, 'l'},
	{"reset", no_argument,       0, 'r'},
	{"fake_stats", no_argument,       0, 'F'},
    {"formula", required_argument, 0, 'f'},
	{"output", required_argument,0, 'o'},
	{"config", required_argument,0, 'c'},		
	{"stats", required_argument,0, 't'},			
	{"counter", required_argument,0, 's'},	
	{"index", required_argument,0, 'i'},
	{"type", required_argument,0, 'p'},	
	{"UPPER", required_argument,0, 'U'},		
	{"brand", required_argument,0, 'b'},	
	{"delta", required_argument,0, 'd'},
	{"timezone", required_argument,0, 'z'},
	{"meme", required_argument,0, 'm'},	
	{"template", required_argument,0, 'T'},	
	{"locale", required_argument,0, 'L'},	
    {0, 0, 0, 0} 
};		
	tpm_init_context(&topts); 
	
	result=read_config(topts.config_file_path_final,&topts);
	if (result<0);
	topts.config_load_failure=!file_exists_fopen(topts.config_file_path_final);
	while ((opt = getopt_long(argc, argv, "awjCvxqlrUFf:t:o:c:s:p:i:b:z:d:m:T:L:",long_options,&option_index)) != -1) 
	{
        switch (opt) 
		{
			case 'a':
			topts.ptype = PICK_MAX_RATING;
			break;
			case 'w':
			topts.ptype = PICK_MAX_MASS;
			break;
			case 'j':
			topts.json_flag=1;
			break;
			case 'C':
			topts.csv_flag=1;
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
			case 'U':
			topts.upper_brands=1;
			break;
			case 'r':
			reset_counters(&topts);
			break;
			case 'F':
			topts.fake_stats=1;
			break;
			case 'f':
			topts.formula=parse_dental_formula(optarg);
			break;
			case 'c':
				read_config(optarg,&topts);
			break;
			case 'o':
				topts.output_to_file=1;
				if (optarg!=NULL)
					strncpy(topts.output_file_path_final,optarg, MAX_PATH-1);
			break;
			case 't':
				strncpy(topts.stats_file_path_final,optarg, MAX_PATH-1);
			break;
			case 's':
				set_counters(optarg,&topts);
			break;
			case 'p':
				if (atoi(optarg)>=0 && atoi(optarg)<TOTAL_PICK_TYPE_STRINGS)
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
			case 'z':
			if ( atoi(optarg)>=-MAX_TIMEZONE_DELTA && atoi(optarg)<=MAX_TIMEZONE_DELTA) topts.delta_hours=atoi(optarg);
			break; 		
			case 'd':
				topts.delta_days=atoi(optarg);
			break; 	
			case 'm':
                snprintf(topts.meme_payload, MAX_TOOTHPASTE_LINE, "%s", optarg);
                break;
            case 'T':
                snprintf(topts.tpm_template, TOTAL_OUTPUT_STRINGS + 1, "%s", optarg);
            break;
			case 'L':
				snprintf(topts.tpm_locale, MAX_LOCALE_CODE + 1, "%s", optarg);
				init_tpm_locale(topts.tpm_locale,&topts); 
			break;
			case '?': 
				fprintf(stderr, "%s %s [-awjCvxqlrUF] [-f dental-formula] [-c config_file] [-o pick output file] [-t stats file] [-s total_picks value] [-p pick_type_value] [-i toothpaste_index] [-b brand_string [-z delta_hours] [-d delta_days] [-m meme_payload] [-T output_template] -L locale_code [toothpastes_file] \n",user_strings[MSG_USAGE], argv[0]);
				exit(EXIT_FAILURE);
			default:
				break;
        }
	}
	if (argv[optind]!=NULL)
	{
		strncpy(topts.toothpastes_file_path_final,argv[optind],MAX_PATH-1);
	}	
	if (topts.output_to_file)
	{
		printf("%s %s \n",_(user_strings[MSG_PICK_FILE]),topts.output_file_path_final);
		if (topts.csv_flag) 
		{
			output_file=fopen(topts.output_file_path_final,"a");
		}
		else
		{
			output_file=fopen(topts.output_file_path_final,"w");
		}
		if (output_file == NULL) 
		{
			perror(_(error_strings[LAST_PICK_WRITING_FAILED]));

		}		
	}
	else
	{
		output_file=stdout;
	}
	tpm_load_list_from_file(topts.toothpastes_file_path_final,&topts,&topts.toothpastes_list);
	tpm_pick_toothpaste(topts.toothpastes_list,&topts,&pick);
	
	if (topts.json_flag)
	{
		tpm_get_toothpaste_picking_JSON(&pick,&out_JSON);
		fprintf(output_file,"%s \n",out_JSON);
	}
	else if (topts.csv_flag)
	{
		tpm_get_toothpaste_picking_CSV(&pick,&out_CSV);
		fprintf(output_file,"%s \n",out_CSV);
	}
	else		
	{
		tpm_get_toothpaste_picking_message(&pick,&out_msg);
		fprintf(output_file,"%s \n",out_msg);
	}
	if (topts.config_load_failure) 
	{
		cfg=cfg_init(); 
		save_default_config(cfg,&topts);
		cfg_free(cfg);
	}
	if ((output_file)!=stdout)
	{
		fclose(output_file);
	}
	
	
	if ((topts.json_flag) || (topts.csv_flag)) 
	{
		finish(NO_SYSTEM_PAUSE,&pick);
	}
	else
	{
		finish(SYSTEM_PAUSE,&pick);
	}
	
	exit(EXIT_SUCCESS);
	return 0;
}

/*
	TPM Toothpaste Picking Manager source code 0BSD license
*/
#include "tpm.h"

static pick_type_t pick_type =PICK_DEFAULT;
static list_node_t* toothpastes_list;

static const toothpaste_data_t toothpastes[TOTAL_TOOTHPASTES]={
	{0,"Builtin Toothpaste 1",75,90},
	{1,"Builtin Toothpaste 2",150,100},
	{2,"Builtin Toothpaste 3",50,80}
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
	"Night",
	"Morning",
	"Day",
	"Evening"
	
};

static struct option long_options[] = {
    {"rating",     no_argument, 0, 'a'},
    {"weight",  no_argument,       0, 'w'},
    {"json",  no_argument, 0, 'j'},
    {"version", no_argument,       0, 'v'},
    {"random", no_argument,       0, 'x'},
    {"quiet", no_argument,       0, 'q'},
    {"list", no_argument,       0, 'l'},
	{"reset", no_argument,       0, 'r'},	
	{"output", required_argument,0, 'o'},
	{"config", required_argument,0, 'c'},		
	{"stats", required_argument,0, 't'},			
	{"counter", required_argument,0, 's'},	
	{"index", required_argument,0, 'i'},
	{"type", required_argument,0, 'p'},	
	{"brand", required_argument,0, 'b'},	
	{"delta", required_argument,0, 'd'},
	{"timezone", required_argument,0, 'z'},		
    {0, 0, 0, 0} 
};	

static const char stats_file_name[MAX_PATH] ="pickstats";
static const char toothpastes_file_name[MAX_PATH] ="toothpastes";
static const char output_file_name[MAX_PATH] ="last_pick";
static const char config_file_name[MAX_PATH] ="tpm.conf";

static char stats_file_path_final[MAX_PATH];
static char toothpastes_file_path_final[MAX_PATH];
static char output_file_path_final[MAX_PATH];
static char config_file_path_final[MAX_PATH];

static int verbose =1;
static int lat_flag =0;
static int json_flag =0;
static int output_to_file =0;
static int pick_by_index_index =0;
static char* brand_string =NULL;

static int delta_days =0;
static int delta_hours =0;

static int config_load_failure =0;

static list_node_t* 
create_node(toothpaste_data_t p_data) 
{
    list_node_t* new_node = (list_node_t*)malloc(sizeof(list_node_t));
    
	if (new_node == NULL) 
	{
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

TPM list_node_t* 
tpm_load_list_from_file(const char* filename) 
{
	unsigned int i;
	unsigned int cnt=0;
    FILE* file = fopen(toothpastes_file_path_final, "r");
	list_node_t* head = NULL;
    toothpaste_data_t temp_data;
	char line[MAX_LINE_LENGTH];
	char* current = line;
	
    if (file == NULL) 
	{
        perror("Error opening toothpastes file falling back to default");
		for (i=0;i<TOTAL_TOOTHPASTES;i++)
		{
		  temp_data=toothpastes[i];
		  head = add_to_list(head, temp_data);	
		}
		return head;
    }
	
    while (fgets(line, sizeof(line), file) != NULL) 
	{
        
        while (isspace((unsigned char)*current)) 
		{
            current++;
        }

        if (*current == '\0' || *current == COMMENT_CHAR) 
		{
            continue; 
        }
		if (sscanf(current, "%u, %[^,],%u,%u\n", &temp_data.index,temp_data.toothpaste_brand ,&temp_data.tube_mass_g,&temp_data.rating) == 4) 
		{
			ltrim(rtrim(temp_data.toothpaste_brand));
			head = add_to_list(head, temp_data);	
			cnt++;
			if (cnt>MAX_TOOTHPASTE_LINES){break;}
		}		
    }
    fclose(file);
    return head;
}

static void 
display_list(list_node_t* head, toothpaste_pick_t* pick) 
{
	unsigned int cnt=0;
    list_node_t* current = head;
	char line[MAX_TOOTHPASTE_LINE];
	
	memset(line,0,MAX_TOOTHPASTE_LINE);
	memset(pick->message,0,OUTPUT_BLOCK_SIZE);
	
	snprintf(pick->message,MAX_TOOTHPASTE_LINE,"Index | Brand | Tube Mass | Rating\n");
	while (current != NULL) 
	{
        snprintf(line,2*MAX_TOOTHPASTE_LINE,"%d %s %d %d\n", current->data.index, current->data.toothpaste_brand, current->data.tube_mass_g, current->data.rating);
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
    toothpaste_data_t empty ={0,"None",0}; 
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
    toothpaste_data_t empty ={0,"None",0}; 
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
        free(temp);
    }
	return;
}


static int 
reset_counters(void) 
{
	FILE* file_ptr;
	unsigned int zero=0;
	time_t zero_time =0;
	
	file_ptr = fopen(stats_file_path_final, "wb");
	if (file_ptr == NULL) 
	{
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
	time_t total_seconds=time(NULL)+delta_hours*SECONDS_PER_HOUR;
	
	zero = atoi(optarg);
	file_ptr = fopen(stats_file_path_final, "wb");
	if (file_ptr == NULL) 
	{
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
    if (file_ptr == NULL) 
	{
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
	if (file_ptr == NULL) 
	{
		perror("Error opening pickstats file for writing");
		return 1;
	}
	fwrite(&stats.total_picks, sizeof(int), 1, file_ptr);
	fwrite(&stats.last_pick_time, sizeof(time_t), 1, file_ptr);
	fclose(file_ptr);
	
	return 0;
}

static void 
stop_system(void) 
{
    int c;
	
    printf("Press Enter to continue...");
    while ((c = getchar()) != EOF && c != '\n');
    getchar(); 
	
	return;
}

TPM int 
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
        strncpy(buffer, pw->pw_name, buffer_size);
        buffer[buffer_size - 1] = '\0';
        return 0; 
    }
    

    if (user_env == NULL) 
	{
        user_env = getenv("USER");
    }
    if (user_env != NULL) 
	{
        strncpy(buffer, user_env, buffer_size);
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
	exit(EXIT_FAILURE);
	return;
}

TPM char* 
tpm_get_toothpaste_picking_message(toothpaste_pick_t* pick)
{
	return pick->message;
}

TPM char*
tpm_get_toothpaste_picking_JSON(toothpaste_pick_t* pick)
{
	return pick->JSON;	
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

TPM toothpaste_pick_t*
tpm_pick_toothpaste(list_node_t* head,toothpaste_pick_options_t topts)
{
	int i,j;
	static toothpaste_pick_t pick;
	time_t total_seconds = time(NULL)+delta_days*SECONDS_PER_DAY+delta_hours*SECONDS_PER_HOUR;
	unsigned int day;
	char username[UNLEN + 1];
	char line[MAX_LINE_LENGTH];
	int new_pick_flag =0;
	
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
		
		snprintf(line,MAX_TOOTHPASTE_LINE,"Good %s %s %s \n", times_of_day[i],pick.who ,"Welcome to the toothpaste picking manager");
		strncat(pick.message,line,MAX_LINE_LENGTH);
	}
	
	day = total_seconds/SECONDS_PER_DAY;
	
	i=day%pick.total_toothpastes;
	if (topts.ptype==PICK_BY_INDEX) 
	{
	    if (topts.pick_by_index_index>=pick.total_toothpastes)
		{i=pick.total_toothpastes-1;}else{i=topts.pick_by_index_index;}
	}
	if (topts.ptype==PICK_RANDOM) 
	{
		seed_xrp32(total_seconds);
		i=rand_range(0,pick.total_toothpastes);
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
	
	if ((total_seconds - pick.stats.last_pick_time) > (SECONDS_PER_DAY-PICK_TIMEOUT_SECONDS)) 
	{
		if (topts.verbose) 
		{
			snprintf(line,MAX_TOOTHPASTE_LINE,"%s", "New next pick stats updated \n");
			strncat(pick.message,line,MAX_LINE_LENGTH);
		}
		new_pick_flag=1;
		pick.stats.total_picks++;
		pick.stats.last_pick_time=total_seconds;
		write_counters(pick.stats);
		
		if (pick.stats.total_picks % TOOTHBRUSH_TIMESPAN_DAYS ==0)
		{
			 if (topts.verbose) 
			 { 
					snprintf(line,MAX_TOOTHPASTE_LINE,"%s", "180 days toothbrush time span over swap the toothbrush(or order new one) \n"); 
					strncat(pick.message,line,MAX_LINE_LENGTH);
			 }
		}
	}
	if (topts.verbose) 
	{
		if (new_pick_flag==0)
		{	
			snprintf(line,MAX_TOOTHPASTE_LINE,"%s", "Already picked today \n");
			strncat(pick.message,line,MAX_LINE_LENGTH);	
		}
		snprintf(line,MAX_TOOTHPASTE_LINE,"%s\n", pick_type_strings[topts.ptype] );
		strncat(pick.message,line,MAX_LINE_LENGTH);
		
		snprintf(line,MAX_LINE_LENGTH,"%s %s %s (%ug) [%u/100] %s %s %s %u %s %u/%u \n", "Toothpaste:", ">>>", pick.what.toothpaste_brand, pick.what.tube_mass_g, pick.what.rating, "<<<", "Day:" ,days_of_week[j],day, "Toothpaste index:",i,pick.total_toothpastes);
		strncat(pick.message,line,MAX_LINE_LENGTH);
		snprintf(line,MAX_LINE_LENGTH,LINE_FORMAT, "Total picks:", pick.stats.total_picks, "Last pick time:" ,pick.stats.last_pick_time);
		strncat(pick.message,line,MAX_LINE_LENGTH);
	
	}
	else 
	{
		snprintf(pick.message,2*MAX_TOOTHPASTE_LINE,"%s (%ug) [%u/100] \n", pick.what.toothpaste_brand,pick.what.tube_mass_g, pick.what.rating);	
	}
	
	snprintf(pick.JSON,MAX_LINE_LENGTH,"{\n\t \"who\":\"%s\",\n\t \"toothpaste\":\"%s\",\n\t \"tube_mass_g\":%u,\n\t \"rating\":%u \n}",pick.who,pick.what.toothpaste_brand,pick.what.tube_mass_g,pick.what.rating);
	
	if (topts.lat_flag) {
		list_available_toothpastes(&pick);
	}	
	return &pick;
}

static void 
save_default_config(struct cfg_struct* cfg)
{
	cfg_set(cfg, "TIMEZONE","0");
	cfg_set(cfg,"USERNAME","\"Anonymous\"");
	cfg_set(cfg,"DELTA_DAYS","0");
	cfg_set(cfg,"PICK_TYPE","0");
	cfg_set(cfg,"VERBOSE","1");
	cfg_set(cfg,"LIST_TOOTHPASTES","0");
	cfg_set(cfg,"OUTPUT_JSON","0");
	cfg_set(cfg,"OUTPUT_FILE","0");
	cfg_set(cfg,"PICK_INDEX","0");
	cfg_set(cfg,"BRAND","\"Unknown\"");
	cfg_set(cfg,"SET_COUNTER","0");
	cfg_set(cfg,"RESET_COUNTER","0");
	cfg_set(cfg,"PICK_STATS",stats_file_path_final);
	cfg_set(cfg,"LAST_PICK",output_file_path_final);
	cfg_set(cfg,"TOOTHPASTES",toothpastes_file_path_final);
	cfg_set(cfg,"LOAD_CONFIG",config_file_path_final);
	
	cfg_save(cfg,config_file_path_final);
	
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

static toothpaste_pick_options_t
read_config(const char* src)
{
	toothpaste_pick_options_t opts;
	struct cfg_struct* cfg;
	int reset_counters_v=0;
	int set_counters_v=0;
	const char* value = NULL;
	static int recursion =0;
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
		config_load_failure=1;
		return opts;
    }
	value = cfg_get_rec(cfg, "LOAD_CONFIG");
	
	if ((value!=NULL) && (strcmp(src,value)==0) && (recursion < MAX_CONFIG_RECURSION)) 		
	{
		recursion++;
		opts=read_config(value);
	}
	
	opts.username = (cfg_get_rec(cfg, "USERNAME"));
	value = cfg_get_rec(cfg, "TIMEZONE");
	if ((value!=NULL) && atoi(value)>=-MAX_TIMEZONE_DELTA && atoi(value)<=MAX_TIMEZONE_DELTA) 
	{
		delta_hours=atoi(value);
	}
	value = cfg_get_rec(cfg, "DELTA_DAYS");
	if (value!=NULL)
	{	
		delta_days = atoi(value);
	}
	value = cfg_get_rec(cfg, "PICK_TYPE");
	if ((value!=NULL) && atoi(value)>=0 && atoi(value)<TOTAL_PICK_TYPE_STRINGS)
	{
		opts.ptype =  atoi(value);
	}
	value = cfg_get_rec(cfg, "VERBOSE");
	if (value!=NULL)
	{
		opts.verbose = atoi(value);
	}		
	else 
	{
		opts.verbose=verbose;
	}
	value = cfg_get_rec(cfg, "TOOTHPASTES");
	if (value!=NULL)
	{
		strncpy(toothpastes_file_path_final,value,MAX_PATH); 
	}
	value = cfg_get_rec(cfg, "LAST_PICK");
	if (value!=NULL) 
	{
		strncpy(output_file_path_final,value,MAX_PATH);
	}	
	value = cfg_get_rec(cfg, "PICK_STATS"); 
	if (value!=NULL) 
	{
		strncpy(stats_file_path_final,value,MAX_PATH); 
	}
	value = cfg_get_rec(cfg, "LIST_TOOTHPASTES");
	if (value!=NULL) 
	{
		opts.lat_flag =  atoi(value);
	}
	value = cfg_get_rec(cfg, "OUTPUT_JSON");
	if (value!=NULL) 
	{
		opts.json_flag =  atoi(value);
	}
	value = cfg_get_rec(cfg, "OUTPUT_FILE");
	if (value!=NULL) 
	{
		opts.output_to_file =  atoi(value);
	}
	value = cfg_get_rec(cfg, "PICK_INDEX");
	if (value!=NULL) 
	{
		opts.pick_by_index_index =  atoi(value);
	}
	value = cfg_get_rec(cfg, "BRAND");
	if (value!=NULL) 
	{
		opts.brand_string = (value);
	}
	value = cfg_get_rec(cfg, "RESET_COUNTER");
	if (value!=NULL) 
	{
		reset_counters_v=atoi(cfg_get_rec(cfg, "RESET_COUNTER"));
	}
	if (reset_counters_v)
	{
		reset_counters();
	}
	value = cfg_get_rec(cfg, "SET_COUNTER");
	if (value!=NULL) 
	{
		set_counters_v=atoi(cfg_get_rec(cfg, "SET_COUNTER"));
	}
	if (set_counters_v)
	{ 
		set_counters(&set_counters_v);
	}
	
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
	struct cfg_struct* cfg;
	int option_index = 0;
	
#ifdef _WIN32
	strncat(user_home_dir,"\\tpm\\",MAX_PATH);
#else
	strncat(user_home_dir,"/tpm/",MAX_PATH);
#endif
	strncpy(stats_file_path_final,user_home_dir,MAX_PATH);
	strncat(stats_file_path_final,stats_file_name,MAX_PATH/2);
	
	strncpy(toothpastes_file_path_final,user_home_dir,MAX_PATH);
	strncat(toothpastes_file_path_final,toothpastes_file_name,MAX_PATH/2);
	
	strncpy(output_file_path_final,user_home_dir,MAX_PATH);
	strncat(output_file_path_final,output_file_name,MAX_PATH/2);

	strncpy(config_file_path_final,user_home_dir,MAX_PATH);
	strncat(config_file_path_final,config_file_name,MAX_PATH/2);
	
	free(user_home_dir);
	topts=read_config(config_file_path_final);
	config_load_failure=!file_exists_fopen(config_file_path_final);
	while ((opt = getopt_long(argc, argv, "awjvxqlrt:o:c:s:p:i:b:z:d:",long_options,&option_index)) != -1) 
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
			case 'c':
				topts=read_config(optarg);
			break;
			case 'o':
				topts.output_to_file=1;
				strncpy(output_file_path_final,optarg, MAX_PATH);
			case 't':
				strncpy(stats_file_path_final,optarg, MAX_PATH);
			break;
			case 's':
				set_counters(optarg);
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
			if ( atoi(optarg)>=-MAX_TIMEZONE_DELTA && atoi(optarg)<=MAX_TIMEZONE_DELTA) delta_hours=atoi(optarg);
			break; 		
			case 'd':
				delta_days=atoi(optarg);
			break; 	
			case '?': 
				fprintf(stderr, "Usage: %s [-awjvxqlr] [-c config_file] [-o pick output file] [-t stats file] [-s total_picks value] [-p pick_type_value] [-i toothpaste_index] [-b brand_string -z delta_hours -d delta_days] [toothpastes_file] \n", argv[0]);
				exit(EXIT_FAILURE);
			default:
				break;
        }
	}
	if (argv[optind]!=NULL)
	{
		strncpy(toothpastes_file_path_final,argv[optind],MAX_PATH);
	}	
	if (output_to_file)
	{
		printf("%s %s \n","Output pick to file ",output_file_path_final);
		output_file=fopen(output_file_path_final,"w");
		if (output_file == NULL) 
		{
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
	{
		fprintf(output_file,"%s \n",tpm_get_toothpaste_picking_JSON(pick));
	}
	else
	{
		fprintf(output_file,"%s \n",tpm_get_toothpaste_picking_message(pick));
	}
	if (config_load_failure) 
	{
		cfg=cfg_init(); 
		save_default_config(cfg);
	}
	if ((output_file)!=stdout)
	{
		fclose(output_file);
	}
	
	
	if (json_flag) 
	{
		finish(NO_SYSTEM_PAUSE,pick);
	}
	else
	{
		finish(SYSTEM_PAUSE,pick);
	}
}

	

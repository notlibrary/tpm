## TPM Toothpaste Picking Manager
Let me pick the toothpaste for you(or how to brush your teeth admins way)

0. Clone the repository to `~/tpm` and make it:

`git clone https://github.com/notlibrary/tpm.git`

Linux(Ubuntu):
`make`

Windows:
`nmake.exe /f .\Makefile.msc`

1. Define the available(what is in the bathroom) toothpastes in the CSV format file with path `~/tpm/toothpastes`
see `~/tpm/toothpastes.sample` below for format details
2. Put TPM in the daily crontab or task scheduler task to run it daily(or twice a day)

Windows:
`schtasks /create /tn "TPM" /tr "C:\Program Files\tpm\tpm.exe" /sc daily /st 09:00`

Linux(Ubuntu):
There are 3 ways to bring cron task to the foreground
depending of what are you expecting as foreground

- Identify and redirect output to the active TTY 

Identify the TTY

`tty`

/dev/pts/1

Add the task with redirect to /dev/pts/1

`cronrtab -e` append

`00 9 * * * ( echo && /usr/local/bin/tpm ) > /dev/pts/1 2>&1`

- Create the tmux session

`cronrtab -e` append

`00 9 * * * /usr/bin/tmux new-session -d -s "tpm" "/usr/local/bin/tpm"`

Attach the session later

`tmux attach-session -t tpm`

- Open the default X windows terminal

`cronrtab -e` append

`00 9 * * * DISPLAY=:0 xterm -e /usr/local/bin/tpm`

- Finally with the simple crontab and configured MTA you can read cron mail with the tpm output

`crontab -e` append

`00 9 * * * /usr/local/bin/tpm`

I don't do this step automatically from code because cron is not portable solution
and each user has different brush time different timezone and different terminal
it's users who should spent 5 minutes to figure things out and schedule the underlying 
task as they wish it's simple enough operation for most systems

If setting the cron job is too hard another tactic is to make a new special dummy user which runs `tpm` on login
I left this to an auditory as an exercise

Spoiler add this to `~/.bashrc` to auto attach cron session on login via SSH

```
if [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]]; then
    tmux attach-session -t tpm || tmux new-session -s ssh_tmux
fi
```

3. Enjoy the machine doing it for you 

Tiny simple terminal console C program with maximum utility
and zero maintenance burden

What if Chekhov is alive and is a C programmer?

Linux build also has `tpm.1` manual included

## Sample terminal output from verbose mode:
```
Good Morning Serenity Welcome to the toothpaste picking manager
Already picked today
Pick type: Default
Toothpaste: >>> SENSODYNE (150g) [100/100] <<< Day: Saturday 20512 Toothpaste index: 1/3
Dental Formula: 1-10-2-2
Total picks: 7 Last pick time: 1772266460

Press any key to continue . . .
```
## Sample JSON output:
```
{
         "who":"Anonymous",
         "toothpaste":"Unknown",
         "tube_mass_g":666,
		 "rating":50
}
```
Because working with JSON without the special library is complicated it outputs only 4 fields JSON

Basically it automatically answers the question "Which toothpaste I should use today?"
by picking it from the predefined available toothpastes linked list using total epoch days mod total available toothpastes as the list index
I started coding it when found 3 different toothpaste tubes in the bathroom

It supports 8 toothpaste picking methods calling picking types: 
`Default, Random, By index, By Brand, Max rating, Max tube mass, Min rating, Min tube mas`

Here is the analog sqlite query that do default picking type:

```sql
SELECT * FROM toothpastes WHERE id=mod((SELECT CAST(unixepoch('now') / 86400 AS INTEGER)), (SELECT COUNT(*) FROM toothpastes)) LIMIT 1;
```

Also the `pick.sql` contains other sql queries for different picking types.

The point is in fact you do not need sqlite postgres or lmdb to perform a single pick operation
and sometimes even the single pick is more than enough

How many sqliters does it take to pick the toothpaste? `NULL`

It ubiquitous portability is rather the feature than a bug

It will be trying to use local computer terminals to pick up the toothpaste long after you die
till the heat death of Universe probably

Moreover it does not even care about the download counter if you do not brush your teeth
you end with dental rot plague sad but true software nerds has little to offer here

To cope you may try to treat it as a hobby bird watching butterfly collecting fishing toothpaste picking
still better than being stereotypical rotten teeth open source bum

## Dental formula
The dental formula is an expression with format `W-X-Y-Z` where 

`W` toothbrushes times per day 

`X` minutes per toothbrush 

`Y` toothbrushes swaps per year

`Z` dentist visits per year  

So default conventional formulas are `2-2-2-2` and `1-10-2-2`

Also sometimes is possible to add 5th term toothpaste grams per nurdle but this program do not support it

## Command line options
`-a --rating` pick the toothpaste with highest rating

`-w --weight` pick the toothpaste with highest tube weight

`-j --json` output the JSON with last pick info instead toothpaste picking string

`-v --version` show the toothpaste picking manager version

`-x --random` perform a random toothpaste pick

`-q --quiet` the quiet toothpaste pick

`-l --list` list the available toothpastes

`-r --reset` reset the total toothpaste picks counter

`-f --formula` set the dental formula `dental_formula`

`-o --output pick_output_file` output toothpaste picking string or JSON to the text file `pick_output_file`

`-c --config config_file` load the custom configuration file `config file`

`-t --stats pick_stats` output the pick stats to `pick_stats` file

`-s --counter [counter_value]` set the total toothpaste picks counter

`-p --type [toothpaste_pick_type_value]` set the toothpaste pick type value

`-i --index [toothpaste_index]` pick the toothpaste by index

`-b --brand [toothpaste_brand]` pick the toothpaste by brand

`-z --timezone [delta_hours]` set the timezone hours [-11,11] lag manually

`-d --delta [delta_days]` pick the toothpaste with default method in the future or the past

`toothpastes_path` path to the toothpastes CSV file

## Configuration file options
The configuration is located in `~/tpm/tpm.conf` file
It's options:

`LOAD_CONFIG` loads the configuration file `tpm.conf` from specific path

`USERNAME` override the username

`PICK_TYPE` set the toothpaste pick type [0,7] number for `Default, Random, By index, By brand, Max rating, Max tube mass, Min rating, Min tube mas`

`DENTAL_FORMULA` set the dental formula eg. "2-2-2-2"

`VERBOSE` 0 for the quiet toothpaste pick

`TOOTHPASTES` the toothpastes list CSV full file name

`LAST_PICK` the last pick file location

`PICK_STATS` the pick stats file location

`LIST_TOOTHPASTES` 1 to list the available toothpastes

`OUTPUT_JSON` 1 to output the JSON with toothpaste pick

`OUTPUT_FILE` 1 to output to the file `~tpm/last_pick`

`PICK_INDEX` pick the toothpaste by this index if `PICK_TYPE=2`

`BRAND` pick the toothpaste by this brand if `PICK_TYPE=3`

`RESET_COUNTER` 1 to reset the toothpaste pick counter

`SET_COUNTER` not 0 to set the toothpaste pick counter

`TIMEZONE` set the timezone hours [-11,11] lag manually

`DELTA_DAYS` pick the toothpaste with default method in the future or the past

## TPM Toothpastes Picking Manager Configuration Sample
```
[CONSTANTS]
LOAD_CONFIG="C:\Users\Anonymous\tpm\tpm.conf"
DEFAULT=0
TRUE=1
FALSE=0
[GENERAL]
USERNAME="Anonymous"
PICK_TYPE=DEFAULT
DENTAL_FORMULA="2-2-2-2"
VERBOSE=TRUE
TOOTHPASTES="C:\Users\Anonymous\tpm\toothpastes"
LAST_PICK="C:\Users\Anonymous\tpm\last_pick"
PICK_STATS="C:\Users\Anonymous\tpm\pickstats"
LIST_TOOTHPASTES=FALSE
OUTPUT_JSON=FALSE
OUTPUT_FILE=FALSE
PICK_INDEX=0
RESET_COUNTER=FALSE
SET_COUNTER=0
BRAND="Unknown"
TIMEZONE=0
DELTA_DAYS=0
```

## TPM The Toothpastes Picking Manager Files List
`~/tpm/toothpastes` the CSV toothpastes list

`~/tpm/tpm.conf` the TPM configuration file

`~/tpm/pickstats` the toothpaste pick stats binary file

`~/tpm/last_pick` the last toothpaste pick output message string or JSON file

## TPM The Toothpastes Picking Manager Toothpastes List CSV format sample
```
#Index,Brand string,Tube mass grams,Rating
0,Random Toothpaste 1,100,85
1,Random Toothpaste 2,50,90
2,Random Toothpaste 3,150,100
3,Random Toothpaste 4,50,100
4,Nothing,0,0
```
Sure you can pick anything this way not only toothpastes
Food beverages clothes gym exercises meds even linux commands
moreover you can recursively pick the toothpaste pick type(method) itself
but there is no meaning in it `pick the toothpaste in the bathroom` is obvious useful
default solution for most people

The default guardian line limit is set to 1024

The max brand string length is 128

## The biggest dental lie on the planet
Here we go do some math again

mass = ( world population * brshes per lifetime * grams per nurdle ) / grams in kg

$$
M = ( 8000000000 * 60000 * 2 ) / 1000 kg = 960000000000 kg
$$

volume = mass/density 

$$
V = 960000000000 kg/3000 kg/m^3 = 320000000 m^3
$$

linear size m = cbroot(volume)

$$
L = \sqrt[3]{320000000} m^3 ~= 684 m
$$

So you need the cube with the edge 684 meters filled with the toothpaste to brush them all for rest of their lives

Good luck with that

## Per component reverse engineering and pick by AI
This is the advanced topic the key point is that make a new toothpaste is cheaper
than reverse engineer the old one so AI simply has not enough data to base on 
and thus it's picking in the best case is no better than random 
even with carefully designed system prompts

Another approach is to treat anything as toothpaste component then store the empirically successful compounds
in the special database again agent without access to this db means it can't produce useful pick

Or you can hold the master chemistry technology degree and have 20 years of practical experience
so you just know what toothpaste components are in reality then my question is what the hell are you doing with my repo sir?
Am I good?

So open source toothpaste is just a daydream

## Why use this program at all?
Nice try 

It takes the single cron slot and list of toothpastes one single time

It gives the long string about happening toothpaste picking process for a lifetime for free

Judge for yourself if this is a good deal or not and why

- It works on low level in harsh environments when the internet is down unavailable or blocked by the government firewall
- Of course it runs on the toaster with zero system requirements
- It serves the basic crucial user need independently OS type SQL support just does not matter
- It helps utilize the 5$ VPSes and old computers including SBCs by running on them useful payload
- It has perfectly fine sane regular ordinary usual predictable behavior(almost pedantic) that makes perfect sense 
- And finally it's the tiny size less than 32KB almost two times smaller than LMDB (Windows .exe however has 200KB builtin .ico)

OK program is good users are bad what now?
You are getting it just pick again you have ~30000 tries per lifetime
Also this program itself defines the whole new software genre "toothpaste picking managers" like file managers window managers database managers
device managers etc

I'm not joking if you know how to do it better make the pull request thread and show me the code

P.S. Do not forget to brush your hard disk with `dd` and `rm -rf /` toothpastes twice a day

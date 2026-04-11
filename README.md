## TPM Toothpaste Picking Manager
Let me pick the toothpaste for you(or how to brush your teeth admins way)

0. Clone repository to `~/tpm` and make it:

`git clone https://github.com/notlibrary/tpm.git`

Unix(Ubuntu):
`make`

Windows:
`nmake.exe /f .\Makefile.msc`

1. Define available(what is in the bathroom) toothpastes in CSV format file with path `~/tpm/toothpastes`
see `~/tpm/toothpastes.sample` below for format details
2. Put TPM in the daily crontab or task scheduler task to run it daily(or twice a day)

Windows:
`schtasks /create /tn "TPM" /tr "C:\Program Files\tpm\tpm.exe" /sc daily /st 09:00`

Unix(Ubuntu):
`crontab -e` 
then add this line:
`00 9 * * * /usr/local/bin/tpm`

I don't do this step automatically from code because cron is not portable solution
and each user has different brush time different timezone and different terminal
it's users who should spent 5 minutes to figure things out and schedule the underlying 
task as they wish it's simple enough operation for most systems

3. Enjoy machine doing it for you

Tiny simple terminal console C program with maximum utility
and zero maintenance burden
## Sample terminal output from verbose mode:
```
Good Morning Serenity Welcome to the toothpaste picking manager
Already picked today
Pick type: Default
Toothpaste: >>> SENSODYNE (150g) [100/100] <<< Day: Saturday 20512 Toothpaste index: 1/3
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
Because working with JSON without special library is complicated it outputs only 4 fields JSON

Basically it automatically answers the question "Which toothpaste I should use today?"
by picking it from predefined available toothpastes linked list using total epoch days mod total available toothpastes as list index
I started coding it when found 3 different toothpaste tubes in the bathroom

It supports 8 toothpaste picking methods calling picking types: 
`Default, Random, By index, By Brand, Max rating, Max tube mass, Min rating, Min tube mas`

Here is analog sqlite query that do default picking type:

```sql
SELECT * FROM toothpastes WHERE id=mod((SELECT CAST(unixepoch('now') / 86400 AS INTEGER)), (SELECT COUNT(*) FROM toothpastes)) LIMIT 1;
```

Also `pick.sql` contains other sql queries for different pick methods.

The point is in fact you do not need sqlite postgres or lmdb to perform a single pick operation
and sometimes even the single pick is more than enough

How many sqliters does it take to pick the toothpaste? `NULL`

It ubiquitous portability is rather the feature than a bug

It will be trying to use local computer terminals to pick up the toothpaste long after you die
till the heat death of Universe probably

Moreover it does not even care about download counter if you do not brush your teeth
you end with dental rot plague sad but true software nerds has little to offer here


## Command line options
`-a` pick toothpaste with highest rating

`-w` pick toothpaste with highest tube weight

`-j` output JSON with last pick info instead toothpaste picking string

`-v` show toothpaste picking manager version

`-x` perform random toothpaste pick

`-q` more quiet toothpaste pick

`-l` list available toothpastes

`-r` reset total toothpaste picks counter

`-o pick_output_file` output toothpaste picking string or JSON to text file `pick_output_file`

`-c config_file` load custom configuration file `config file`

`-t pick_stats` output pick stats to `pick_stats` file

`-s [counter_value]` set total toothpaste picks counter

`-p [toothpaste_pick_type_value]` set toothpaste pick type value

`-i [toothpaste_index]` pick toothpaste by index

`-b [toothpaste_brand]` pick toothpaste by brand

`-z [delta_hours]` set the timezone hours [-11,11] lag manually

`-d [delta_days]` pick toothpaste with default method in the future or the past

`toothpastes_path` path to toothpastes CSV file

## Configuration file options
Configuration is located in `~/tpm/tpm.conf` file
It's options:

`LOAD_CONFIG` loads configuration file `tpm.conf` from specific path

`USERNAME` override username

`PICK_TYPE` set toothpaste pick type [0,7] number for `Default, Random, By index, By brand, Max rating, Max tube mass, Min rating, Min tube mas`

`VERBOSE` 0 for quiet toothpaste pick

`TOOTHPASTES` toothpastes list CSV full file name

`LAST_PICK` last pick file location

`PICK_STATS` pick stats file location

`LIST_TOOTHPASTES` 1 to list available toothpastes

`OUTPUT_JSON` 1 to output JSON with toothpaste pick

`OUTPUT_FILE` 1 to output to file `~tpm/last_pick`

`PICK_INDEX` pick toothpaste by this index if `PICK_TYPE=2`

`BRAND` pick toothpaste by this brand if `PICK_TYPE=3`

`RESET_COUNTER` 1 to reset toothpaste pick counter

`SET_COUNTER` not 0 to set toothpaste pick counter

`TIMEZONE` set the timezone hours [-11,11] lag manually

`DELTA_DAYS` pick toothpaste with default method in the future or the past

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

## TPM Toothpastes Picking Manager Files List
`~/tpm/toothpastes` CSV toothpastes list

`~/tpm/tpm.conf` TPM configuration file

`~/tpm/pickstats` toothpaste pick stats binary file

`~/tpm/last_pick` last toothpaste pick output message string or JSON file

## TPM Toothpastes Picking Manager Toothpastes List CSV format sample
```
#Index,Brand string,Tube mass grams,Rating
0,Random Toothpaste 1,100,85
1,Random Toothpaste 2,50,90
2,Random Toothpaste 3,150,100
3,Random Toothpaste 4,50,100
4,Nothing,0,0
```
Sure you can pick anything this way not only toothpastes
Food drink clothes gym exercises meds even linux commands
moreover you can recursively pick the toothpaste pick type(method) itself
but there is no meaning in it `pick toothpaste in the bathroom` is obvious useful
default solution for most people

## Per component reverse engineering and pick by AI
This is the advanced topic the key point is that make a new toothpaste is cheaper
than reverse engineer the old one so AI simply has not enough data to base on 
and thus it's picking in the best case is no better than random 
even with carefully designed system prompts

Another approach is to treat anything as toothpaste component then store empirically successful compounds
in the special database again agent without access to this db means it can't produce useful pick

Or you can hold the master chemistry technology degree and have 20 years of practical experience
so you just know what toothpaste components are in reality then my question is what the hell are you doing with my repo sir?
Am I good?

So open source toothpaste is just a daydream

## Why use this program at all?
Nice point 

It takes single cron slot and list of toothpastes one single time

It gives long string about happening toothpaste picking process for a lifetime for free

Judge for yourself if this is a good deal or not and why

- It works on low level in harsh environments when internet is down unavailable or blocked by government firewall
- Of course it runs on toaster with zero system requirements
- It serves basic crucial user need independently OS type SQL support just does not matter
- It helps utilize 5$ VPSes and old computers including SBC by running on them useful payload
- It has perfectly fine sane regular ordinary usual behavior(almost pedantic) that makes perfect sense 
- And finally it's tiny size less than 32KB almost two times smaller than LMDB (Windows .exe however has 200KB builtin .ico)

P.S. Do not forget to brush your hard disk with `dd` and `rm -rf /` toothpastes twice a day

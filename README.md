## TPM Toothpaste Picking Manager
Let me pick the toothpaste for you

0. Clone repository to `~/tpm` and make it

Unix:
`make`

Windows:
`nmake.exe /f .\Makefile.msc`

1. Define available toothpastes in CSV format file with path `~/tpm/toothpastes`
see `~/tpm/toothpastes.sample` for format details
2. Put TPM in daily crontab or task scheduler task to run it daily(or twice a day)
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

Basically it automatically answers the question "What toothpaste I should use today?"
by picking it from predefined available toothpastes linked list using total epoch days mod total available toothpastes as list index
I started coding it when found 3 different toothpaste tubes in the bathroom

It supports 8 toothpaste picking methods calling picking types: 
`Default, Random, By index, By Brand, Max rating, Max tube mass, Min rating, Min tube mas`

Here is analog sqlite query that do default picking type:

```sql
SELECT * FROM toothpastes WHERE id=mod((SELECT CAST(unixepoch('now') / 86400 AS INTEGER)), (SELECT COUNT(*) FROM toothpastes)) LIMIT 1;
```

Also `pick.sql` contains other sql queries for different pick methods.


## Command line options
`-a` pick toothpaste with highest rating

`-w` pick toothpaste with highest tube weight

`-o` output toothpaste picking string or JSON to text file `~/tpm/last_pick`

`-j` output JSON with last pick info instead toothpaste picking string

`-v` show toothpaste picking manager version

`-x` perform random toothpaste pick

`-q` more quiet toothpaste pick

`-l` list available toothpastes

`-r` reset total toothpaste picks counter

`-s [counter_value]` set total toothpaste picks counter

`-p [toothpaste_pick_type_value]` set toothpaste pick type value

`-i [toothpaste_index]` pick toothpaste by index

`-b [toothpaste_brand]` pick toothpaste by brand

`-z [delta_hours]` set the timezone hours [-11,11] lag manually

`-d [delta_days]` pick toothpaste with default method in the future or the past

## Configuration file options
Configuration is located in `~/tpm/tpm.conf` file
It's options:

`USERNAME` override username

`PICK_TYPE` set toothpaste pick type [0,7] number for `Default, Random, By index, By brand, Max rating, Max tube mass, Min rating, Min tube mas`

`VERBOSE` 0 for quiet toothpaste pick

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
DEFAULT=0
TRUE=1
FALSE=0
[GENERAL]
USERNAME=Anonymous
PICK_TYPE=DEFAULT
VERBOSE=TRUE
LIST_TOOTHPASTES=FALSE
OUTPUT_JSON=FALSE
OUTPUT_FILE=FALSE
PICK_INDEX=0
RESET_COUNTER=FALSE
SET_COUNTER=0
BRAND=Unknown
TIMEZONE=0
DELTA_DAYS=0
```

## TPM Toothpastes Picking Manager Files List
`~/tpm/toothpastes` CSV toothpastes list

`~/tpm/tpm.conf` TPM configuration file

`~/tpm/pickstats` toothpaste pick stats binary file

`~/tpm/last_pick` last toothpaste pick output message string or JSON file
`
## TPM Toothpastes Picking Manager Toothpastes List CSV format sample
```
#Index, Brand string, Tube mass grams, Rating
0,Toothpaste 1,100,85
1,Toothpaste 2,50,90
2,Toothpaste 3,150,100
3,Toothpaste 4,50,100
4,Nothing,0,0
```
Sure you can pick anything this way not only toothpastes
Food drink clothes gym exercises meds even linux commands
moreover you can recursively pick the toothpaste pick type(method) itself
but there is no meaning in it

P.S. Do not forget to brush your hard disk with `dd` and `rm -rf /` toothpastes twice a day

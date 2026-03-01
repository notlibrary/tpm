## TPM Toothpaste Picking Manager
Let me pick the toothpaste for you

0. Clone repository to `~/tpm` and make it
1. Define available toothpastes in CSV format file with path `~/tpm/toothpastes`
see `~/tpm/toothpastes.sample` for format details
2. Put TPM in daily crontab or task scheduler task to run it daily(or twice a day)
3. Enjoy machine doing it for you

Tiny simple terminal console program with maximum utility

## Sample terminal output from verbose mode:
```
Good Morning Welcome to toothpaste picking manager
Already picked today
Toothpaste: >>> SENSODYNE (150g) [100/100] <<< Day: Saturday 20512 Toothpaste index: 1
Total picks: 7 Last pick time: 1772266460
Press any key to continue . . .
```
Basically it automatically answers the question "What toothpaste I should use today?"
by picking it from predefined available toothpastes linked list using total epoch days mod total available toothpastes as list index
 
## Command line options

`-v` more verbose toothpaste pick(default)

`-x` perform random toothpaste pick

`-q` more quiet toothpaste pick

`-l` list available toothpastes

`-r` reset total toothpaste picks counter

`-s [counter value]` set total toothpaste picks counter

## Toothpastes List CSV format sample
```
#Index, Brand string, Tube mass grams, Rating
0,Paste 1,100,85
1,Paste 2,50,90
2,Paste 3,150,100
3,Paste 4,50,100
4,Nothing,0,0
```
Sure you can pick anything this way not only toothpastes
Food drink gym exercises even linux commands

P.S. Do not forgret to brush your harddisk with `dd` and `rm -rf /` toothpastes twice a day

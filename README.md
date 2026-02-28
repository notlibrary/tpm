##TPM Toothpaste Picking Manager
Let me pick the toothpaste for you
0. Clone repository to ~/tpm and make it
1. Define available toothpastes in CSV format file with path `~/tpm/toothpastes`
see `~/tpm/toothpastes.sample` for format details
2. Put TPM in daily crontab or task scheduler task to run it daily(or twice a day)
3. Enjoy machine doing it for you

Tiny simple terminal console program with maximum utility

##Sample terminal output from verbose mode:
```
Good Morning Welcome to toothpaste picking manager
Already picked today
Toothpaste: >>> SENSODYNE (150g) [100/100] <<< Day: Saturday 20512 Toothpaste index: 1
Total picks: 7 Last pick time: 1772266460
Press any key to continue . . .
```
Basically it automatically answers the question "What toothpaste I should use today?"
by picking it from predefined available toothpastes linked list using total epoch days mod total available toothpastes as list index
 
##Command line options
	`-v` more verbose pick(default)
	`-x` perform random pick
	`-q` more quiet pick
	`-l` list available toothpastes
	`-r` reset total picks counter
	`-s [counter value]` set total picks counter


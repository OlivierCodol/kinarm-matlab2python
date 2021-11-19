# kinarm-matlab2python

This is a small set of scripts to convert the .zip file outputs to binary format files. Currently the data is put into pandas dataframes, and saved using the feather package.
There is a commented out line to save files using pickle insted of feather, since pickle is pre-included in most python environments.


## Requirements
The matlab functions from the KINARM platform are necessary to run the matlab script ```kinarmzip2mat.m```. You will 
need to have a valid account to access them. See *Kinarm Analysis Scripts* under the *MATLAB & Compilers* sections at 
this URL address: https://kinarm.com/support/software-downloads/ 

These python packages are necessary to run the python scripts:
- ```pandas```
- ```scipy``` for the ```loadmat``` function.
- ```pyarrow``` if you are using the ```feather``` file format. Install with ```pip install pyarrow```.
 

## How to use
run the ```kinarmzip2mat.m``` file in matab, with as a single argument:
- the full path of the file to convert, or
- the full path of the directory containing the file(s) to convert (supports batch conversion).

This script will create a ```.mat``` file for each ```.zip``` file passed as input.

Then, in python, run ```mat2bin.py``` or ```mat2feather.py``` to create the set of binary files from the ```.mat```
file.
Depending on your choice, the command syntax is:
```
python mat2bin.py -f targetfileordirectory
python mat2feather.py -f targetfileordirectory
```
Where ```targetfileordirectory``` is the only argument and is required. It can be:
- the full path of the file to convert, or
- the full path of the directory containing the file(s) to convert (supports batch conversion).

Running either script will output a set of files together in a new folder named after the original ```.mat``` file.


## Choosing a format
### *mat2bin* or *mat2feather*?

```mat2bin.py``` saves time series data as a ```.feather``` file and the session information as a ```.pickle``` file.
  Session information includes:
  - block table
  - target table
  - load table (if used)
  - trial protocol table
  - trial history
  - event logs
  - session details such as date / time, samplerate, screen refresh rate, task protocol used, task name, etc...

This is possible because pickle files can hold hierarchical data (in a dictionary), while feather files cannot.
The drawback is the pickle format is that data is slower to load. But this doesn't matter here because session 
information data is small so 
loading time are extremely fast anyway. This is *not* true for the time series data, which accounts for the near-
totality of data, which is why I use a ```.feather``` file for the time series.


```mat2feather.py``` saves everything as ```.feather``` files, which yields more than two files, depending on how many
tables you are using for your task. This is because each table cannot be held in a hierarchical structure like in a 
```.pickle``` file.




### binary or ```.mat``` file?
There are advantages and disadvantages in python to directly using ```.mat``` files over binary files:

PROS:
- A single file
- Slightly (barely) smaller disk space usage.

CONS:
- Slower to load. Not a big deal for a single file but likely significant when loading 10s of datasets at once.
- Requires a small script to reorganise the output into a usable format after loading each file. 
  I included it into this repository (see ```loadmat.py```) if people are interested in pursuing this option.
 

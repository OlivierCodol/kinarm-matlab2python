# kinarm-matlab2python

This is a small set of scripts to convert the .zip file outputs to binary format files. Currently the data is put into pandas dataframes, and saved using the feather package.
There is a commented out line to save files using pickle insted of feather, since pickle is pre-included in most python environments.

To install feather, use ```pip install pyarrow```.

### How to use
run the ```kinarmzip2mat.m``` file in matab, with as a single argument:
- the full path of the file to convert, or
- the full path of the directory containing the file(s) to convert (supports batch conversion).
This will create a ```.mat``` file.

Then, in python, run ```mat2bin.py``` to create the set of binary files from the ```.mat``` file. The command syntax is:
```
python mat2bin.py -f targetfileordirectory
```
Where ```targetfileordirectory``` is the only argument and is required. It can be:
- the full path of the file to convert, or
- the full path of the directory containing the file(s) to convert (supports batch conversion).

Running this script will output a set of files together in a new folder named after the original ```.mat``` file.


### binary or ```.mat``` file?
There are advantages and disadvantages in python to using ```.mat``` files over binary:

PROS:
- A single file
- Slightly (barely) smaller disk space usage.

CONS:
- Slower to load. Not a big deal for a single file but likely significant when loading 10s of datasets at once.
- Requires a small script to reorganise the output into a usable format after loading each file. I included it into this repository (see ```loadmat.py```) if people are interested in going down that route.

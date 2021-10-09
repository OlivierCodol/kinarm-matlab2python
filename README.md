# kinarm-matlab2python

This is a small set of scripts to convert the .zip file outputs to binary format files. Currently the data is put into pandas dataframes, and saved using the feather package.
There is a commented out line to save files using pickle insted of feather, since pickle is pre-included in most python environments.

To install feather, use
<pip install pyarrow>

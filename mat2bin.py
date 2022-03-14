import os
import subprocess
import pickle
import pandas as pd
from scipy.io import loadmat
from argparse import ArgumentParser

# -------------------------------
# Sort out arguments
# -------------------------------
help_str = "full path of the target .mat file"
parser = ArgumentParser()
parser.add_argument("-f", "--file", dest="filename", help=help_str, metavar="FILE", required=True)
filename = parser.parse_args().filename

if os.path.isdir(filename):
    files = [filename + os.altsep + file for file in os.listdir(filename) if file.endswith(".mat")]
    for file in files[:-1]:
        subprocess.run(["python", os.path.basename(__file__), "-f", file])
    filename = files[-1]

print('converting ---> ' + filename)


# -------------------------------
# Reformat data
# -------------------------------
def mat2dict(mat_content: dict, struct: str):
    data = mat_content[struct][0][0]
    labels = mat_content[struct][0][0].dtype.names
    return {label: datum.reshape(-1) for datum, label in zip(data, labels)}


MAT = loadmat(filename)
MAT.pop("__header__")
MAT.pop("__version__")
MAT.pop("__globals__")

dataframes_dict = {k: pd.DataFrame(mat2dict(MAT, k)) for k in MAT.keys()}

TMP = dataframes_dict["SESSION_DATA"].to_dict('records')[0]
TABLES = {df_name: df for df_name, df in dataframes_dict.items() if df_name.endswith("_TABLE")}
SESSION_DATA = {**TMP, **TABLES}


# -------------------------------
# Sort out directory paths and output file names
# -------------------------------
rawfilename = os.path.basename(filename)[:-4]  # remove .mat extension
dest = os.path.dirname(filename) + os.path.sep


# -------------------------------
# Save data
# -------------------------------
file_id = open(dest + rawfilename + '.pickle', 'wb')
pickle.dump({"SESSION_DATA": SESSION_DATA, "TRIAL_DATA": dataframes_dict["TRIAL_DATA"]}, file_id)
file_id.close()

dataframes_dict["TIME_SERIES_DATA"].to_feather(dest + rawfilename + '.feather', compression='zstd')

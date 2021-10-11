import os
import subprocess
import pandas as pd
from scipy.io import loadmat
from argparse import ArgumentParser

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


def mat2dict(mat_content: dict, struct: str):
    data = mat_content[struct][0][0]
    labels = mat_content[struct][0][0].dtype.names
    return {label: datum.reshape(-1) for datum, label in zip(data, labels)}


MAT = loadmat(filename)
MAT.pop("__header__")
MAT.pop("__version__")
MAT.pop("__globals__")

dataframes_dict = {k: pd.DataFrame(mat2dict(MAT, k)) for k in MAT.keys()}

rawfilename = os.path.basename(filename)[:-4]  # remove .mat extension
dest = os.path.dirname(filename) + os.altsep + rawfilename + os.altsep
if not os.path.exists(dest):
    os.mkdir(dest)

# If you want to use the feather module (pyarrow package) instead of the pickle base package, use this line
_ = [df.to_feather(dest + rawfilename + '-' + k + '.feather', compression='zstd') for k, df in dataframes_dict.items()]

# If you want to use the pickle base package instead of the feather module (pyarrow package), use this line
#  (can lead to larger files)
# _ = [df.to_pickle(dest + rawfilename + k + '.pkl', compression='infer') for k, df in dataframes_dict.items()]

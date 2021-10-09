import pandas as pd
import scipy.io
# small standalone function to load and reorganize mat file contents if one wants to use .mat files a their persistant
# storage method.


def mat2dict(mat_content: dict, struct: str):
    """Dependency function"""
    data = mat_content[struct][0][0]
    labels = mat_content[struct][0][0].dtype.names
    return {label: datum.reshape(-1) for datum, label in zip(data, labels)}


def loadmat(filename):
    matdata = scipy.io.loadmat(filename)
    matdata.pop("__header__")
    matdata.pop("__version__")
    matdata.pop("__globals__")
    dataframes_dict = {k: pd.DataFrame(mat2dict(matdata, k)) for k in matdata.keys()}
    return dataframes_dict

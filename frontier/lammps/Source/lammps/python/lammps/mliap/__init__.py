
# Check compatiblity of this build with the python shared library.
# If this fails, lammps will segfault because its library will
# try to improperly start up a new interpreter.
import sysconfig
import ctypes
import platform

py_ver = sysconfig.get_config_vars('VERSION')[0]
OS_name = platform.system()

if OS_name == "Linux":
    SHLIB_SUFFIX = '.so'
    library = 'libpython' + py_ver + SHLIB_SUFFIX
elif OS_name == "Darwin":
    SHLIB_SUFFIX = '.dylib'
    library = 'libpython' + py_ver + SHLIB_SUFFIX
elif OS_name == "Windows":
    SHLIB_SUFFIX = '.dll'
    library = 'python' + py_ver + SHLIB_SUFFIX

try:
    pylib = ctypes.CDLL(library)
except Exception as e:
    raise OSError("Unable to locate python shared library") from e

if not pylib.Py_IsInitialized():
    raise RuntimeError("This interpreter is not compatible with python-based mliap for LAMMPS.")

del sysconfig, ctypes, library, pylib

from .loader import load_model, activate_mliappy

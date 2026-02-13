# distutils: language = c++
# distutils: extra_compile_args = ["-std=c++11", "-O3"]

cimport utils  # utils.pxd

from libcpp.string cimport string, npos
from libcpp.vector cimport vector
from libcpp.map cimport map as cmap
from libcpp.pair cimport pair
from libcpp cimport bool as cbool
from libc.stdlib cimport atoi, atof
from cython.operator cimport dereference as deref, preincrement as inc

cimport cython

#+ —— C++ External Definitions ——————

cdef extern from "<algorithm>" namespace "std":
    void replace(string.iterator, string.iterator, char, char)
    string::iterator find(string.iterator, string.iterator, char)

cdef extern from "<cctype>" namespace "std":
    int isspace(int)
    int isdigit(int)
    int toupper(int)
    int tolower(int)

cdef extern from "<string>" namespace "std":
    string to_string(int)
    string to_string(double)


import os
from setuptools import setup, Extension
from Cython.Build import cythonize

# import sys
# if len(sys.argv) == 1:
#     sys.argv.extend(["build_ext", "--inplace"])
# same as executing `python setup.py build_ext --inplace`

# OS specific options
if os.name == "nt":
    # Windows
    extra_compile_args = [
        "/O2",        # optimization level
        "/std:c++14"  # force C++14 (MSVC)
    ]
else:
    # Linux & macOS
    extra_compile_args = [
        "-O3",        # optimization level
        "-std=c++14"  # force C++14 (GCC)
    ]

# Define extensions separately to give the C++ file special instructions
extensions = [
    Extension(
        name               =  "epedit.*",
        sources            = ["src/epedit/*.pyx"],
        extra_compile_args = extra_compile_args,
        language           = "c++",
    ),
]

setup(
    name="epedit",
    packages=["epedit"],
    # version="0.0.1",
    package_dir={"": "src"},  # declare package starting point as src
    package_data={
        "epedit": ["*.pyi", "py.typed"],
    },
    ext_modules=cythonize(
        extensions,
        compiler_directives = {
            'language_level': "3",  # force Python 3
            'boundscheck': False,   #
            'wraparound': False,
        },
        annotate=False,
    ),
    zip_safe=False,
)

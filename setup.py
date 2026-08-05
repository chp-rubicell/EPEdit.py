import os
from setuptools import setup, Extension, find_packages
from setuptools.command.build_ext import build_ext
from Cython.Build import cythonize

# import sys
# if len(sys.argv) == 1:
#     sys.argv.extend(["build_ext", "--inplace"])
# same as executing `python setup.py build_ext --inplace`


# Compiler specific options
class CustomBuildExt(build_ext):
    def build_extensions(self):
        # Get current compiler type ('msvc', 'mingw32', 'unix', ...)
        compiler_type = self.compiler.compiler_type

        if compiler_type == 'msvc':
            # MSVC
            cxx_flags = ["/O2", "/std:c++14"]
        else:
            # GCC, Clang, ...
            cxx_flags = ["-O3", "-std=c++14"]

        for ext in self.extensions:
            ext.extra_compile_args = cxx_flags

        super().build_extensions()


# Define extensions separately to give the C++ file special instructions
extensions = [
    Extension(
        name     =  "epedit.*",
        sources  = ["src/epedit/*.pyx"],
        language = "c++",
    ),
]


setup(
    name="epedit",
    packages=find_packages(where="src"),
    package_dir={"": "src"},  # declare package starting point as src
    package_data={
        "epedit": ["*.pyi", "py.typed"],
    },
    ext_modules=cythonize(
        extensions,
        compiler_directives = {
            'language_level': "3",  # force Python 3
            'boundscheck': False,
            'wraparound': False,  # minujs indexing
        },
        annotate=False,
    ),
    cmdclass={"build_ext": CustomBuildExt},  # connected compiler detection class
    zip_safe=False,
)

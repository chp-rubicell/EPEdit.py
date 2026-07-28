import sys
from setuptools import setup, Extension
from Cython.Build import cythonize

if len(sys.argv) == 1:
    sys.argv.extend(["build_ext", "--inplace"])
# python setup.py build_ext --inplace 실행하는 것과 동일

# Define extensions separately to give the C++ file special instructions
ext_modules = [
    Extension("*", sources=["utils.pyx"], language="c++"),
    Extension("*", sources=["lexer.pyx"], language="c++"),
    Extension("*", sources=["idd.pyx"], language="c++"),
]

setup(
    ext_modules=cythonize(ext_modules, annotate=True),
)

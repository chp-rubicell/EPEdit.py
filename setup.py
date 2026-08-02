import sys
from setuptools import setup, Extension
from Cython.Build import cythonize

if len(sys.argv) == 1:
    sys.argv.extend(["build_ext", "--inplace"])
# same as executing `python setup.py build_ext --inplace`

# Define extensions separately to give the C++ file special instructions
ext_modules = [
    Extension("epedit.utils", sources=["src/epedit/utils.pyx"], language="c++"),
    Extension("epedit.lexer", sources=["src/epedit/lexer.pyx"], language="c++"),
    Extension("epedit.idd", sources=["src/epedit/idd.pyx"], language="c++"),
    Extension("epedit.idf", sources=["src/epedit/idf.pyx"], language="c++"),
]

setup(
    name="epedit",
    package_dir={"": "src"},  # declare package starting point as src
    packages=["epedit"],
    ext_modules=cythonize(ext_modules, language_level=3, annotate=True),
)

from libcpp.string cimport string
from libcpp cimport bool as cbool

cdef string trim(const string& s)
cdef string to_uppercase(const string& s)
cdef string to_titlecase(const string& s)
cdef cbool find_char(const string& s, char c)
cdef size_t find_char_pos(const string& s, char c)
cdef string fieldname_to_key(string& name)
cdef string extract_tag(string& block, string tag)
cdef pair[string, string] match_extensible_name(string& fieldname, cbool verbose = False)
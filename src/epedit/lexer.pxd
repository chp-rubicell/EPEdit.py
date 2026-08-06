from libcpp.string cimport string
from libcpp.vector cimport vector
from libcpp cimport bool as cbool

cdef enum TokenType:
    TOKEN_TEXT      = 0
    TOKEN_COMMA     = 1
    TOKEN_SEMICOLON = 2
    TOKEN_EOF       = 3
    TOKEN_ERROR     = 4

cdef struct Token:
    TokenType type
    string    value

cdef class Lexer:
    cdef vector[Token] buffer  # temporary storage for tokens
    cdef size_t        buffer_idx  # current index within the token buffer

    cdef int   line_num  # current line number (for debugging)
    cdef cbool is_idd  # for IDD parsing

    cdef string content  # the entire file
    cdef size_t pos  # current position in content

    cdef void c_init(self, bytes file_content, bint is_idd) noexcept
    cdef cbool scan_next_line(self, string& line) noexcept nogil
    cdef Token next_token(self) noexcept nogil
    cdef void tokenize_line(self, const string& line) noexcept nogil
    cdef void push_text_token(self, string& builder) noexcept nogil

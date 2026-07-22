# distutils: language = c++

from libcpp.string cimport string, npos
from libcpp.vector cimport vector
from libcpp cimport bool as cbool

from utils cimport trim_string

cdef class Lexer:

    def __init__(self, bytes file_content, bint is_idd):
        """
        Accepts raw bytes of the entire file.
        """
        # Python 'bytes' is automatically converted to C++ std::string
        self.content = file_content
        self.pos = 0
        self.line_num = 0
        self.is_idd = is_idd

        # Initialize buffer and index pointer
        self.buffer.clear()
        self.buffer_idx = 0

    cdef cbool scan_next_line(self, string& line) noexcept nogil:
        """
        Extracts next line from content and stores it in the provided `line` reference.
        Advances `pos` past the next `\n` character.
        Returns True if a line was successfully read, or False if EOF is reached.
        """
        if self.pos >= self.content.size():
            return False

        cdef size_t next_newline = self.content.find(b'\n', self.pos)

        if next_newline == npos:
            line = self.content.substr(self.pos)
            self.pos = self.content.size()
        else:
            line = self.content.substr(self.pos, next_newline - self.pos)
            self.pos = next_newline + 1

        # Handle CRLF (\r\n)
        if not line.empty() and line.back() == b'\r':
            line.pop_back()

        self.line_num += 1
        return True

    cdef Token next_token(self) noexcept nogil:
        """
        Return next token when parser requests.
        """
        cdef Token tok
        cdef string line
        cdef cbool has_more_lines

        # If there is a remaining token in the buffer
        if self.buffer_idx < self.buffer.size():
            tok = self.buffer[self.buffer_idx]
            self.buffer_idx += 1
            return tok

        # Clear buffer
        self.buffer.clear()
        self.buffer_idx = 0

        # Read next line
        while True:
            has_more_lines = self.scan_next_line(line)

            if not has_more_lines:
                break

            self.tokenize_line(line)

            # If tokens were generated, return first one and move pointer
            if self.buffer.size() > 0:
                tok = self.buffer[0]
                self.buffer_idx = 1
                return tok

        # Return EOF if no more content
        tok.type = TOKEN_EOF
        tok.value.clear()  # instead of tok.value = b""
        return tok

    cdef void tokenize_line(self, const string& line) noexcept nogil:
        # Find position of comment
        cdef size_t limit = line.find(b'!')

        # If no comment is found, set limit to end of string
        if limit == npos:
            limit = line.size()

        cdef string text_builder  # empty string
        cdef size_t byte_idx = 0
        cdef char c

        cdef string remainder

        # Iterate up to the `limit`
        while byte_idx < limit:
            c = line[byte_idx]

            if self.is_idd and c == b'\\':
                self.push_text_token(text_builder)
                remainder = line.substr(byte_idx, limit - byte_idx)
                remainder = trim_string(remainder)
                if not remainder.empty():
                    self.buffer.push_back(Token(TOKEN_TEXT, remainder))
                break

            if c == b',':
                self.push_text_token(text_builder)
                self.buffer.push_back(Token(TOKEN_COMMA, <const char*>b","))
            elif c == b';':
                self.push_text_token(text_builder)
                self.buffer.push_back(Token(TOKEN_SEMICOLON, <const char*>b";"))
            else:
                text_builder.push_back(c)

            byte_idx += 1

        # Final flush
        self.push_text_token(text_builder)

    cdef void push_text_token(self, string& builder) noexcept nogil:
        """
        Trims and pushes to buffer using reference.
        """
        cdef string trimmed = trim_string(builder)
        if not trimmed.empty():
            self.buffer.push_back(Token(TOKEN_TEXT, trimmed))
        # Clear builder to reuse its allocated capacity
        builder.clear()

    def test(self):
        cdef Token tok
        tokens = []

        while True:
            with nogil:
                tok = self.next_token()

            # Convert C++ struct the Python Tuple
            tokens.append((tok.type, tok.value.decode("utf-8")))

            if tok.type == TOKEN_EOF:
                break

        return tokens

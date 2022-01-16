require 'sexp'

p "1".parse_sexp
p "foo".parse_sexp
p "\"foo\"".parse_sexp
p "(+ 1 2)".parse_sexp

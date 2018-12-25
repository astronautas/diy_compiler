class LexerUtils
  def self.get_ascii
    ascii = (32..126).to_a
    ascii << 10
    ascii.map(&:chr)
  end

  def self.gen_transition_tbl(state, ascii_tbl)
    state.transitions.each do |trans|
      ascii_tbl.each do |ascii_symbol|
        if trans.can_transition?(ascii_symbol)
          state.transition_tbl[ascii_symbol.ord] = trans.target
        end
      end
    end
  end
end

# States
main = State.new(:MAIN)
int = State.new(:LIT_INT)
float = State.new(:LIT_FLOAT)
float_science = State.new(:FLOAT_SCIENTIFIC)
float_science_neg = State.new(:FLOAT_SCIENTIFIC_NEG)
id = State.new(:ID)
l_braces = State.new(:L_BRACES)
r_braces = State.new(:R_BRACES)
l_paranth = State.new(:L_PARANTH)
r_paranth = State.new(:R_PARANTH)
l_sq_bracket = State.new(:L_SQ_BRACKET)
r_sq_bracket = State.new(:R_SQ_BRACKET)
comma = State.new(:COMMA)
underscore = State.new(:UNDERSCORE)
dot = State.new(:DOT)
pointer_arrow = State.new(:POINTER_ARROW)

# OPS
colon = State.new(:COLON)
minus = State.new(:OP_MINUS)
ret_arrow = State.new(:OP_RET_TYPE)
assignment = State.new(:OP_ASSIGNMENT)
equality = State.new(:OP_EQUALITY)
separator = State.new(:SEPARATOR)
add = State.new(:OP_ADD)
mult = State.new(:OP_MULT)
division = State.new(:OP_DIVISION)
greater = State.new(:OP_GREATER)
greater_equal = State.new(:OP_GREATER_EQUAL)
lesser = State.new(:OP_LESSER)
lesser_equal = State.new(:OP_LESSER_EQUAL)
op_negate = State.new(:OP_NEGATE)
op_not_eq = State.new(:OP_NOT_EQ)

string_contents = State.new(:STRING_C)
string_esc = State.new(:STRING_ESC)
string_end = State.new(:LIT_STRING)

# Ignored states
space = State.new(:SPACE)
newline = State.new(:NEWLINE)
comment_1 = State.new(:COMMENT)
comment_1_content = State.new(:COMMENT_CONTENT)
comment_mult = State.new(:COMMENT_MULT)
comment_mult_hashtag = State.new(:COMMENT_MULT_HASHTAG)
comment_mult_end = State.new(:COMMENT_MULT_END)

error = State.new(:ERROR_INT)

# Transitions
main.transitions = [Transition.new(/^(\d)+$/, int),
                    Transition.new(/[[:alpha:]]|_/, id),
                    Transition.new(/ /, space),
                    Transition.new(/#/, comment_1),
                    Transition.new(/\^/, pointer_arrow),
                    Transition.new(/\r\n|\r|\n/, newline),
                    Transition.new(/{/, l_braces),
                    Transition.new(/}/, r_braces),
                    Transition.new(/\(/, l_paranth),
                    Transition.new(/\)/, r_paranth),
                    Transition.new(/,/, comma),
                    Transition.new(/_/, underscore),
                    Transition.new(/\./, dot),
                    Transition.new(/:/, colon),
                    Transition.new(/-/, minus),
                    Transition.new(/=/, assignment),
                    Transition.new(/;/, separator),
                    Transition.new(/\+/, add),
                    Transition.new(/\*/, mult),
                    Transition.new(/\//, division),
                    Transition.new(/\[/, l_sq_bracket),
                    Transition.new(/]/, r_sq_bracket),
                    Transition.new(/>/, greater),
                    Transition.new(/"/, string_contents),
                    Transition.new(/</, lesser),
                    Transition.new(/!/, op_negate)]

int.transitions = [Transition.new(/^(\d)+$/, int),
                   Transition.new(/^(\.)+$/, float),
                   Transition.new(/e/, float_science),
                   Transition.new(/[[:alpha:]]/, error)]

id.transitions = [Transition.new(/[[:alpha:]]|\d/, id)]

minus.transitions = [Transition.new(/>/, ret_arrow),
                     Transition.new(/^(\d)+$/, int)]

assignment.transitions = [Transition.new(/=/, equality)]


float.transitions = [Transition.new(/^(\d)+$/, float),
                     Transition.new(/e/, float_science)]

float_science.transitions = [Transition.new(/\d/, float_science),
                             Transition.new(/-/, float_science_neg)]

float_science_neg.transitions = [Transition.new(/\d/, float_science_neg)]

greater.transitions = [Transition.new(/=/, greater_equal)]
lesser.transitions = [Transition.new(/=/, lesser_equal)]
op_negate.transitions = [Transition.new(/=/, op_not_eq)]

string_contents.transitions = [Transition.new(/\\/, string_esc),
                               Transition.new(/"/, string_end),
                               Transition.new(/[^"\\]+/, string_contents)]

string_esc.transitions = [Transition.new(/n|'|"|a|b|f|r|t|v/, string_contents)]

comment_1.transitions = [Transition.new(/[^#^\n]/, comment_1_content),
                         Transition.new(/#/, comment_mult)]
comment_1_content.transitions = [Transition.new(/[^\n]/, comment_1_content)]
comment_mult.transitions = [Transition.new(/[^#]/, comment_mult),
                            Transition.new(/#/, comment_mult_hashtag)]
comment_mult_hashtag.transitions = [Transition.new(/[^#]/, comment_mult),
                                    Transition.new(/#/, comment_mult_end)]

states = [pointer_arrow, underscore, float_science_neg, main, int, float, float_science, id, l_braces, r_braces, l_paranth, r_paranth, l_sq_bracket, r_sq_bracket,
          comma, colon, minus, ret_arrow, assignment, separator, add, division, mult, greater, greater_equal, lesser, lesser_equal, op_negate, op_not_eq,
          string_contents, string_esc, string_end, equality, space, newline, comment_1, comment_1_content, comment_mult, comment_mult_hashtag, comment_mult_end, dot]

# Post processing mappings
keywords = {
    "if" => State.new(:KW_IF),
    "else" => State.new(:KW_ELSE),
    "elseif" => State.new(:KW_ELSE_IF),
    "constructor" => State.new(:KW_CONSTRUCTOR),
    "main" => State.new(:KW_MAIN),
    "class" => State.new(:KW_CLASS),
    "return" => State.new(:KW_RETURN),
    "for" => State.new(:KW_FOR),
    "to" => State.new(:KW_FOR_TO),
    "while" => State.new(:KW_WHILE),
    "foreach" => State.new(:KW_FOREACH),
    "in" => State.new(:KW_FOREACH_IN),
    "int" => State.new(:KW_INT),
    "float" => State.new(:KW_FLOAT),
    "string" => State.new(:KW_STRING),
    "true" => State.new(:KW_TRUE),
    "false" => State.new(:KW_FALSE),
    "mod" => State.new(:OP_MOD),
    "div" => State.new(:OP_DIV),
    "AND" => State.new(:OP_AND),
    "OR" => State.new(:OP_OR),
    "new" => State.new(:KW_NEW),
    "print" => State.new(:KW_PRINT),
    "read" => State.new(:KW_READ),
    "break" => State.new(:KW_BREAK),
    "continue" => State.new(:KW_CONTINUE),
    "bool" => State.new(:KW_BOOL),
    "printvram" => State.new(:KW_PRINT_VRAM),
    "clearvram" => State.new(:KW_CLEAR_VRAM),
    "flushvram" => State.new(:KW_FLUSH_VRAM),
    "sleep" => State.new(:KW_SLEEP),
    "rand" => State.new(:KW_RAND)
}


ascii = LexerUtils.get_ascii

# Each state receives state -> ASCII symbol -> nextState mapping
# Used to make lexer more efficient
states.each do |state|
  LexerUtils.gen_transition_tbl(state, ascii)
end

LexerConfig = {
    :STARTING_STATE => main,
    :IGNORED_STATES => [space, newline, comment_mult_end, comment_1, comment_1_content, comment_mult_hashtag, comment_mult],
    :ERROR_FALLBACK_STATES => [main, int, float],
    :KEYWORDS => keywords
}
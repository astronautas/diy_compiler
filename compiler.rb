require_relative 'lexer/lexer'
require_relative 'lexer/lexer_config'

require_relative 'parser/parser'
require_relative 'parser/ast_printer'
require_relative 'parser/resolve_names'
require_relative 'parser/check_types'
require_relative 'parser/gen_code'
require_relative 'parser/check_structure'
require_relative 'vm/vm'

$input_filename = ARGV[0]
$semantic_errors = 0
$main = nil

def semantic_error(token, message)
  if token
    STDERR.puts "%s:%s: semantic error: %s" % [
        $input_filename, token.line, message
    ]
  else
    STDERR.puts "%s: semantic error: %s" % [
        $input_filename, message
    ]
  end

  $semantic_errors += 1
end

raise Exception.new("Please specify input filename as cmd arg(0)") if ARGV.nil? || ARGV.empty?

def compile(source_file_path)
  # MAKE SOURCE
  source = IO.read(source_file_path)

  # PREPROCESS MACROS

  # GENERATE LEXEMES
  lexer = Lexer.new(source, LexerConfig[:STARTING_STATE],
                    LexerConfig[:IGNORED_STATES], LexerConfig[:KEYWORDS], ARGV[0],
                    LexerConfig[:ERROR_FALLBACK_STATES])

  lexems = []
  loop do
    lexem = lexer.get_lexem
    lexems << lexem

    break if lexem.type.name == :EOF
  end

  # Parsing
  parser = Parser.new(lexems, ARGV[0])
  program = parser.parse_all

  #printer = ASTPrinter.new
  #program.print(printer)

  # Name resolution
  scope = Scope.new
  program.resolve_names(scope)

  # Type checking
  program.check_types

  # Misc structure validations
  checker = StructureValidator.new
  #checker.validate_main($main)
  checker.validate_methods(parser.methods)
  #checker.add_default_returns(parser.methods)
  checker.validate_loop_skips(parser.loop_skips)

  # Generate OP-code
  if $semantic_errors == 0
    writer = CodeWriter.new
    program.gen_code(writer)
    writer.finalize_registers
    writer.code
  else
    false
  end
end
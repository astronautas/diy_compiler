require_relative 'ast'

class Parser
  attr_reader :methods, :loop_skips

  def initialize(tokens, filename)
    @tokens = tokens
    @offset = 0
    @filename = filename
    @methods = []
    @loops = []
    @loop_skips = []
  end

  def accept(token_type)
    curr_token = @tokens[@offset]

    if curr_token.type.name == token_type
      @offset += 1
      curr_token
    end
  end

  def accept_any(tokens)
    tok = nil

    tokens.find do |token|
      tok = accept(token)
    end

    tok
  end

  def current
    curr_token = @tokens[@offset]
    curr_token.type.name
  end

  def expect(token_type)
    curr_token = @tokens[@offset]
    if curr_token.type.name == token_type
      @offset += 1
      curr_token
    else
      filename = @filename
      line = curr_token.line
      msg = "Expected #{token_type}, found #{curr_token.type.name}"

      STDERR.puts "#{filename}:#{line}: error: #{msg}"
      exit 0
    end
  end

  def expect_any(token_types)
    token_types.each do |token_type|
      return expect(token_type) if expect(token_type)
    end
  end

  # RULES
  def parse_all
    parse_program
  end

  # <program> ::= <class_declarations>
  def parse_program
    declarations = parse_class_declarations
    Program.new(declarations)
  end

  # <class_declarations> ::= <class_declaration> {<class_declaration>}
  def parse_class_declarations
    decls = []

    decls << parse_class_declaration
    decls << parse_class_declaration until peek?(:EOF)

    decls
  end

  # <class_declaration> ::= "class" <identifier> <class_body>
  def parse_class_declaration
    expect(:KW_CLASS)

    @curr_parsed_class = DefClass.new(nil, nil)

    name = expect(:ID)
    body = parse_class_body

    @curr_parsed_class.name = name
    @curr_parsed_class.body = body

    @curr_parsed_class
  end

  # <class_body> ::= L_BRACES {<method_declaration> | <field_declaration>} R_BRACES
  def parse_class_body
    decls = []

    expect(:L_BRACES)

    until peek?(:R_BRACES)
      if peek_any?([:ID, :KW_CONSTRUCTOR, :KW_MAIN])
        decls << parse_method_declaration
      else
        decls << parse_field_declaration
      end
    end

    expect(:R_BRACES)

    decls
  end

  # <field_declaration> ::= <variable_declaration>
  def parse_field_declaration
    decl = parse_variable_declaration
    expect(:SEPARATOR)

    decl
  end

  # <method_declaration> ::= <main_declaration> | <constructor_declaration> | <identifier> <params>
  #                             "->" <type_keyword> <method_body>
  def parse_method_declaration
    if peek?(:KW_MAIN)
      parse_main_declaration
    elsif peek?(:KW_CONSTRUCTOR)
      parse_constructor_declaration
    else
      method = DefMethod.new(nil, nil,nil, nil, nil)
      @methods << method

      name = expect(:ID)
      params = parse_params

      expect(:OP_RET_TYPE)

      ret_type = parse_type_keyword
      @curr_parsed_method = method
      body = parse_method_body

      method.name = name
      method.params = params
      method.ret_type = ret_type
      method.body = body
      method.klass = @curr_parsed_class

      method
    end
  end

  # <main_declaration> ::= main <params><method_body>
  def parse_main_declaration
    main = DefMain.new(nil, nil, nil, nil)
    @curr_parsed_method = main

    name = expect(:KW_MAIN)
    params = parse_params

    expect(:OP_RET_TYPE)
    ret_type = parse_type_keyword

    body = parse_method_body

    main.name = name
    main.params = params
    main.body = body
    main.ret_type = ret_type
    main.klass = @curr_parsed_class

    $main = main

    @methods << main

    main
  end

  # <method_body> ::= <block>
  def parse_method_body
    parse_block
  end

  # <block> ::= {<block_element>}
  def parse_block
    expect(:L_BRACES)
    elements = []

    until peek?(:R_BRACES)
      elements << parse_block_element
    end

    expect(:R_BRACES)

    StmtBlock.new(elements)
  end

  # <block_element> ::= <statement> | <if_block> | <loop_block>
  def parse_block_element
    case current
    when :KW_IF then
      parse_if_block
    when :KW_FOR, :KW_WHILE, :KW_FOREACH
      parse_loop_block
    else
      parse_statement
    end
  end

  # <statement> ::= <function_return> <statement_separator>
  #                 | <loop_skip> <statement_separator>
  #                 | <variable_declaration> <statement_separator>
  #                 | <assignment> <statement_separator>
  #                 | <expression> <statement_separator>
  #                 | <IO_op> <statement_separator>
  def parse_statement

    if peek?(:KW_RETURN)
      stmt = parse_function_return
    elsif peek_any?([:KW_BREAK, :KW_CONTINUE])
      stmt = parse_loop_skip
    elsif peek?(:ID) and peek2?(:OP_ASSIGNMENT) or (peek?(:ID) and peek2?(:L_SQ_BRACKET))
      stmt = parse_assignment
    elsif peek_any?([:KW_READ, :KW_PRINT])
      stmt = parse_IO_op
    elsif peek_any?([:KW_BOOL, :KW_INT, :KW_FLOAT, :KW_STRING]) and !peek2?(:L_SQ_BRACKET)
      stmt = parse_variable_declaration
    elsif peek_any?([:KW_PRINT_VRAM, :KW_CLEAR_VRAM, :KW_FLUSH_VRAM])
      stmt = parse_VRAM_op
    elsif peek?(:KW_SLEEP)
      stmt = parse_sleep
    elsif peek?(:KW_RAND)
      stmt = parse_rand
    else
      stmt = StmtExpr.new(parse_expression)
    end

    expect(:SEPARATOR)

    stmt
  end

  def parse_rand
    token = expect(:KW_RAND)
    target=parse_variable

    expect(:COMMA)
    from = parse_expression

    expect(:COMMA)
    to = parse_expression

    StmtRand.new(token, target, from, to)
  end

  def parse_sleep
    StmtSleep.new(token=expect(:KW_SLEEP), time=parse_expression)
  end

  def parse_VRAM_op
    if peek?(:KW_CLEAR_VRAM)
      StmtClearVram.new(token=expect(:KW_CLEAR_VRAM))
    elsif peek?(:KW_FLUSH_VRAM)
      StmtFlushVram.new(token=expect(:KW_FLUSH_VRAM))
    else
      expect(:KW_PRINT_VRAM)

      x = parse_expression
      expect(:COMMA)
      y = parse_expression
      expect(:COMMA)
      color_val = parse_expression

      StmtPrintVram.new(x, y, color_val)
    end
  end

  # type keyword should be pointer
  # <variable_declaration> ::= <type_keyword> <variable> | <type_keyword> <variable> "=" <expression>
  def parse_variable_declaration
    type = parse_type_keyword
    name =  parse_variable

    value = nil

    if peek?(:OP_ASSIGNMENT)
      expect(:OP_ASSIGNMENT)
      value = parse_expression
    end

    StmtVarDecl.new(type, name, value)
  end

  # <IO_op> ::= <input> | <output>
  def parse_IO_op
    if peek?(:KW_READ)
      parse_input
    else
      parse_output
    end
  end

  # <output> ::= "print" <expression_list>
  def parse_output
    expect(:KW_PRINT)
    StmtIO_OpWrite.new(parse_expression_list)
  end

  # <input> ::= "read" <variable_list>
  def parse_input
    expect(:KW_READ)
    StmtIO_OpRead.new(parse_variable_list)
  end

  # <variable_list> ::= <variable> {COMMA <variable>}
  def parse_variable_list
    variables = []
    variables << parse_variable

    while accept(:COMMA)
      variables << parse_variable
    end

    variables
  end

  # <assignment> ::= <variable> "=" <expression>
  def parse_assignment
    name = parse_variable
    token = expect(:OP_ASSIGNMENT)
    value = parse_expression

    if name.instance_of?(ExprVarPointer)
      assign = StmtAssignmentPointer.new(name, value, name.offsets)
    else
      assign = StmtAssignment.new(name, value)
    end

    assign.token = token
    assign
  end

  # <loop_skip> ::= KW_BREAK | KW_CONTINUE
  def parse_loop_skip
    if peek?(:KW_BREAK)
      token = expect(:KW_BREAK)
      skip = StmtBreak.new(token, @curr_parsed_loop)
      @loop_skips << skip
    else
      token = expect(:KW_CONTINUE)
      skip = StmtContinue.new(token, @curr_parsed_loop)
      @loop_skips << skip
    end

    skip
  end

  # <function_return> ::= KW_RETURN <expression>
  #                     | KW_RETURN
  def parse_function_return
    return_kw = expect(:KW_RETURN)
    value = nil

    unless peek?(:SEPARATOR)
      value = parse_expression
    end

    ret = StmtReturn.new(@curr_parsed_method, value, return_kw)

    @curr_parsed_method.returns << ret

    ret
  end

  # <loop_block> ::= <loop_header> <block>
  def parse_loop_block
    loop = StmtLoop.new(nil, nil)
    previous_parsed_loop = @curr_parsed_loop
    @curr_parsed_loop = loop

    header = parse_loop_header
    body = parse_block

    loop.header = header
    loop.body = body

    @curr_parsed_loop = previous_parsed_loop

    loop
  end

  # <loop_header> ::= <while_header> | <for_header> | <foreach_header>
  def parse_loop_header
    case current
    when :KW_WHILE
      parse_while_header
    when :KW_FOR
      parse_for_header
    else
      parse_foreach_header
    end
  end

  # <foreach_header> ::= KW_FOREACH L_PARANTH <variable> KW_FOREACH_IN <expression> R_PARANTH
  def parse_foreach_header
    expect(:KW_FOREACH)
    expect(:L_PARANTH)
    var = parse_variable
    expect(:KW_FOREACH_IN)
    exp = parse_expression
    expect(:R_PARANTH)

    ForEachHeader.new(var, exp)
  end

  # <for_header> ::= KW_FOR L_PARANTH <for_condition> R_PARANTH
  def parse_for_header
    expect(:KW_FOR)
    expect(:L_PARANTH)
    header = parse_for_condition
    expect(:R_PARANTH)

    header
  end

  # <for_condition> ::= <variable_declaration> KW_FOR_TO <expression> COMMA <for_step_condition>
  def parse_for_condition
    start = parse_variable_declaration
    token = expect(:KW_FOR_TO)
    to = parse_expression
    expect(:COMMA)
    step = parse_for_step_condition

    # Useful in gen_code, to treat this ugly beast as a while loop
    cond = ExprEquality.new(Token.new(token.line, State.new(:OP_EQUALITY)), start.name, to)
    incr_stmt = StmtAssignment.new(start.name, ExprBinary.new(Token.new(token.line, State.new(:OP_ADD)), start.name, step))

    forh = ForHeader.new(start, to, step, @curr_parsed_loop, cond, incr_stmt)

    forh.token = token

    forh
  end

  # <for_step_condition> ::= <expression>
  def parse_for_step_condition
    parse_expression
  end

  # <while_header> ::= "while" L_PARANTH <expression> R_PARANTH
  def parse_while_header
    token = expect(:KW_WHILE)
    expect(:L_PARANTH)
    expr = parse_expression
    expect(:R_PARANTH)

    header = WhileHeader.new(expr, @curr_parsed_loop)
    header.token = token
    header
  end

  # <if_block> ::= <if_header> <block> [<multiple_else>]
  def parse_if_block
    conditional_stmt = StmtIf.new(nil, nil, nil)

    previous_parsed_conditional = @curr_parsed_if
    @curr_parsed_if = conditional_stmt

    cond = parse_if_header
    body = parse_block
    elses = []

    if peek_any?([:KW_ELSE, :KW_ELSE_IF])
      elses = parse_multiple_else
    end

    @curr_parsed_if.cond = cond
    @curr_parsed_if.body = body
    @curr_parsed_if.elses = elses

    @curr_parsed_if = previous_parsed_conditional
    conditional_stmt
  end

  # <multiple_else> ::= <multiple_else_if> <else_block> | <else_block>
  def parse_multiple_else
    elses = []

    if peek?(:KW_ELSE_IF)
      elses = parse_multiple_else_if
    end

    if peek?(:KW_ELSE)
      elses << parse_else_block
    end

    elses
  end

  # <else_block> ::= KW_ELSE <block>
  def parse_else_block
    expect(:KW_ELSE)

    StmtElse.new(parse_block)
  end

  # <multiple_else_if> ::= <else_if_header> <block> {<else_if_header> <block>}
  def parse_multiple_else_if
    elses = []

    cond = parse_else_if_header
    body = parse_block

    elses << StmtElseIf.new(cond, body, @curr_parsed_if)

    while peek?(:KW_ELSE_IF)
      cond = parse_else_if_header
      body = parse_block

      elses << StmtElseIf.new(cond, body, @curr_parsed_if)
    end

    elses
  end

  # <else_if_header> ::= KW_ELSE_IF L_PARANTH <expression> R_PARANTH
  def parse_else_if_header
    expect(:KW_ELSE_IF)
    expect(:L_PARANTH)
    cond = parse_expression
    expect(:R_PARANTH)

    cond
  end

  # <if_header> ::= KW_IF L_PARANTH <expression> R_PARANTH
  def parse_if_header
    token = expect(:KW_IF)
    expect(:L_PARANTH)
    cond = parse_expression
    expect(:R_PARANTH)

    @curr_parsed_if.token = token

    cond
  end

  # <constructor_declaration> ::= constructor <params><method_body>
  def parse_constructor_declaration
    name = expect(:KW_CONSTRUCTOR)
    params = parse_params
    body = parse_method_body

    ret_type = TypeVoid.new(Token.new(name.line, nil, nil))

    DefConstructor.new(params, body, ret_type)
  end

  # <expression> ::= <and_expression> {OP_OR <and_expression> }
  def parse_expression
    left = parse_and_expression

    while (op = accept(:OP_OR))
      right = parse_and_expression
      left = ExprBooleanRelational.new(op, left, right)
    end

    left
  end

  # <and_expression> ::=  <equality_exp> {OP_AND <equality_exp>}
  def parse_and_expression
    left = parse_equality_exp

    while (op = accept(:OP_AND))
      right = parse_equality_exp
      left = ExprBooleanRelational.new(op, left, right)
    end

    left
  end

  # <equality_exp> ::= <compare_exp> {OP_EQUALITY|OP_NOT_EQ <compare_exp>}
  def parse_equality_exp
    left = parse_compare_exp

    while (op = accept_any([:OP_EQUALITY, :OP_NOT_EQ]))
      right = parse_compare_exp
      left = ExprEquality.new(op, left, right)
    end

    left
  end

  # <compare_exp> ::= <add_exp> {<comparison_symbol> <add_exp>}
  def parse_compare_exp
    left = parse_add_exp

    while (op = accept_any(%i[OP_GREATER OP_GREATER_EQUAL OP_LESSER OP_LESSER_EQUAL]))
      right = parse_add_exp
      left = ExprRelational.new(op, left, right)
    end

    left
  end

  # <add_exp> ::= <mult_exp> {OP_ADD|OP_MINUS <mult_exp>}
  def parse_add_exp
    left = parse_mult_exp

    while (accept = accept_any([:OP_MINUS, :OP_ADD]))
      right = parse_mult_exp
      left = ExprArithmetic.new(accept, left, right)
    end

    left
  end

  # <mult_exp> ::= <unary> {OP_MULT|OP_MOD <unary>}
  def parse_mult_exp
    left = parse_unary

    while (mult = accept_any([:OP_MULT, :OP_MOD, :OP_DIVISION]))
      right = parse_unary
      left = ExprArithmetic.new(mult, left, right)
    end

    left
  end

  # <unary> ::= {!}<factor>
  def parse_unary
    if peek?(:OP_NEGATE)
      while (neg = accept(:OP_NEGATE))
        right = parse_unary
        left = ExprUnary.new(neg, right)

        left.token = neg

        left
      end

      left
    else
      parse_factor
    end
  end

  # <factor> ::= "(" <expression> ")" | <variable_exp> | <constant> | <class_init>
  def parse_factor
    case current
    when :L_PARANTH then
      expect(:L_PARANTH)
      exp = parse_expression
      expect(:R_PARANTH)

      exp
    when :ID then
      parse_variable_exp
    when :KW_NEW then
      parse_class_init
    else
      parse_constant
    end
  end

  # <constant> ::= <bool_constant> | <numeric_constant> | <complex_constant> | <string>
  def parse_constant
    case current
    when :LIT_STRING
      ExprString.new(expect(:LIT_STRING))
    when :KW_TRUE, :KW_FALSE then
      parse_bool_constant
    when :LIT_INT, :LIT_FLOAT then
      parse_numeric_constant
    else
      parse_complex_constant
    end
  end

  # <complex_constant> ::= <array_constant> | LIT_STRING
  def parse_complex_constant
    if peek?(:LIT_STRING)
      ExprString.new(expect(:LIT_STRING))
    else
      parse_array_constant
    end
  end

  # For declaration
  # <array_constant> ::= <simple_type_keyword> {L_SQ_BRACKET :LIT_INT R_SQ_BRACKET} // e.g. int[50][50][50]
  def parse_array_constant
    type = parse_simple_type_keyword
    token = nil
    size_exprs = []

    while peek?(:L_SQ_BRACKET)
      token = expect(:L_SQ_BRACKET)
      size_exprs << ExprInt.new(expect(:LIT_INT))
      expect(:R_SQ_BRACKET)
    end

    ExprArray.new(type, size_exprs, token)
  end

  # <numeric_constant> ::= LIT_INT | LIT_FLOAT
  def parse_numeric_constant
    if peek?(:LIT_INT)
      ExprInt.new(expect(:LIT_INT))
    else
      ExprFloat.new(expect(:LIT_FLOAT))
    end
  end

  # <bool_constant> ::= "true" | "false"
  def parse_bool_constant
    if peek?(:KW_TRUE)
      ExprBool.new(expect(:KW_TRUE))
    else
      ExprBool.new(expect(:KW_FALSE))
    end
  end

  # <class_init> ::= OP_NEW <identifier><arguments>
  def parse_class_init
    expect(:KW_NEW)

    id = expect(:ID)
    args = parse_arguments

    ExprClassInit.new(id, args)
  end

  # <params> ::= L_BRACKET [<params_list>] R_BRACKET
  def parse_params
    params = []

    expect(:L_PARANTH)

    params = parse_params_list if peek?(:ID)

    expect(:R_PARANTH)

    params
  end

  # <params_list> ::= <single_param_decl> {COMMA <single_param_decl>}
  def parse_params_list
    params = []

    params << parse_single_param_decl

    params << parse_single_param_decl while accept(:COMMA)

    params
  end

  # <single_param_decl> ::= <identifier><OP_COLON><type_keyword>
  def parse_single_param_decl
    name = expect(:ID)
    expect(:COLON)
    type = parse_type_keyword

    Param.new(name, type)
  end

  # <type_keyword> ::= <simple_type_keyword> | <array_keyword>
  def parse_type_keyword
    if peek2?(:POINTER_ARROW)
      parse_pointer_keyword
    else
      parse_simple_type_keyword
    end
  end

  # <simple_type_keyword> ::= "bool" | "int" | "float" | "string"
  def parse_simple_type_keyword
    case current
    # when :OP_OR then
    #   expect(:OP_OR)
    # when :OP_AND then
    #   expect(:OP_AND)
    when :KW_BOOL then
      TypeBool.new(expect(:KW_BOOL))
    when :KW_INT then
      TypeInt.new(expect(:KW_INT))
    when :KW_FLOAT then
      TypeFloat.new(expect(:KW_FLOAT))
    else
      TypeString.new(expect(:KW_STRING))
    end
  end

  # <pointer_keyword> ::= <type_keyword>^{L_SQ_BRACKET :LIT_INT R_SQ_BRACKET}
  def parse_pointer_keyword
    type = parse_simple_type_keyword
    dim_sizes = []
    expect(:POINTER_ARROW)

    while peek?(:L_SQ_BRACKET)
      token = expect(:L_SQ_BRACKET)
      dim_sizes << ExprInt.new(expect(:LIT_INT))
      expect(:R_SQ_BRACKET)
    end

    TypePointer.new(type, dim_sizes, token)
  end

  # <variable_exp> ::= <variable> | <function_call> | <method_call>
  def parse_variable_exp
    if peek?(:ID)
      if peek2?(:DOT)
        parse_method_call
      elsif peek2?(:L_PARANTH)
        parse_function_call
      else
        parse_variable
      end
    end
  end

  # <method_call> ::= <variable>"."<identifier><arguments>
  def parse_method_call
    class_name = parse_variable
    token = expect(:DOT)
    method_name = expect(:ID)
    arguments = parse_arguments

    ExprFn.new(class_name, method_name, arguments, token)
  end

  # <function_call> ::= <identifier><arguments>
  def parse_function_call
    method_name = expect(:ID)
    arguments = parse_arguments

    ExprFn.new(nil, method_name, arguments)
  end

  # <variable> ::= <identifier> | <identifier> {L_SQ_BRACKET <expression> R_SQ_BRACKET}
  def parse_variable
    if peek2?(:L_SQ_BRACKET)
      id = expect(:ID)
      offsets = []

      while peek?(:L_SQ_BRACKET)
        expect(:L_SQ_BRACKET)
        offsets << parse_expression
        expect(:R_SQ_BRACKET)
      end

      ExprVarPointer.new(id, offsets)
    else
      ExprVar.new(expect(:ID))
    end
  end

  # <arguments> ::= L_PARANTH [<expression_list>] R_PARANTH
  def parse_arguments
    args_list = []

    expect(:L_PARANTH)

    args_list = parse_expression_list unless peek?(:R_PARANTH)

    expect(:R_PARANTH)

    args_list
  end

  # <expression_list> ::= <expression> {COMMA <expression>}
  def parse_expression_list
    expressions = []

    expressions << parse_expression

    expressions << parse_expression while accept(:COMMA)

    expressions
  end

  def peek_any?(token_types)
    token_types.any? {|token_type| peek?(token_type)}
  end

  def peek?(token_type)
    curr_token = @tokens[@offset]
    curr_token if curr_token.type.name == token_type
  end

  def peek2?(token_type)
    if @tokens.size > @offset + 1
      curr_token = @tokens[@offset + 1]

      curr_token if curr_token.type.name == token_type
    end
  end

  def peek3?(token_type)
    if @tokens.size > @offset + 2
      curr_token = @tokens[@offset + 2]

      curr_token if curr_token.type.name == token_type
    end
  end
end
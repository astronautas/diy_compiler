class Node
  attr_accessor :token

  def initialize(token = nil)
    @token = token
  end

  def print(p)
    raise 'not implemented for clas %s' % [self.class]
  end
end

class Def < Node
end

class DefClass < Def
  attr_accessor :name
  attr_accessor :body

  def initialize(name, body)
    @name = name
    @body = body
  end

  def print(p)
    p.print('name', @name)
    p.print('declarations', @body)
  end
end

class DefMethod < Def
  attr_accessor :name
  attr_accessor :klass
  attr_accessor :ret_type
  attr_accessor :params
  attr_accessor :body
  attr_accessor :returns

  def initialize(name, klass, params, ret_type = "void", body)
    @name = name
    @params = params
    @ret_type = ret_type
    @body = body
    @returns = []
    @klass = klass
  end

  def print(p)
    p.print 'name', @name
    #p.print 'full_name', @full_name
    p.print 'params', @params
    p.print 'ret_type', @ret_type
    p.print 'body', @body
  end
end

class DefConstructor < DefMethod
  attr_reader :name

  def initialize(params, body, ret_type)
    @params = params
    @body = body
    @ret_type = ret_type
  end

  def print(p)
    p.print 'params', @params
    p.print 'body', @body
  end
end

class DefMain < DefMethod
  attr_accessor :name
  attr_accessor :params
  attr_accessor :returns
  attr_accessor :body
  attr_accessor :ret_type

  def initialize(name, params, body, ret_type)
    @name = name
    @params = params
    @body = body
    @returns = []
    @ret_type = ret_type
  end

  def print(p)
    p.print 'params', @params
    p.print 'body', @body
  end
end

class Expr < Node
end

class ExprFn < Expr
  def initialize(class_name, method_name, args, token=nil)
    @class_name = class_name
    @method_name = method_name
    @args = args
    @token = token
  end

  def print(p)
    p.print 'class_name', @class_name if @class_name
    p.print 'method_name', @method_name
    p.print 'args', @args
  end
end

class ExprClassInit < Expr
  attr_accessor :name, :args

  def initialize(name, args)
    @name = name
    @args = args
  end

  def print(p)
    p.print 'name', @name
    p.print 'args', @args
  end
end

class ExprBinary < Expr
  attr_accessor :op, :right, :left

  def initialize(op, left, right)
    @op = op
    @left = left
    @right = right
  end

  def print(p)
    p.print 'op', @op
    p.print 'left', @left
    p.print 'right', @right
  end
end

class ExprArithmetic < ExprBinary
end

class ExprRelational < ExprBinary
end

class ExprEquality < ExprBinary
end

class ExprBooleanRelational < ExprBinary
end

class ExprConst < Expr
  attr_accessor :lit

  def initialize(lit)
    @lit = lit
  end

  def print(p)
    p.print 'lit', @lit
  end
end

class ExprInt < ExprConst
end

class ExprBool < ExprConst
end

class ExprString < ExprConst
end

class ExprFloat < ExprConst
end

class ExprVoid < ExprConst
end

class ExprPrio < Expr
  def initialize(inner)
    @inner = inner
  end

  def print(p)
    p.print 'inner', @inner
  end
end

class ExprArray < Expr
  attr_reader :type, :size_exprs

  def initialize(type, size_exprs, token)
    @type = type
    @size_exprs = size_exprs
    @token = token
  end

  def print(p)
    p.print 'type', @type
    #p.print 'size', @size.each { |expr| p.prin}
    p.print 'dim', @dim
  end
end

class ExprVar < Expr
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def print(p)
    p.print 'name', @name
  end
end

class ExprVarPointer < ExprVar
  attr_reader :name, :offsets

  def initialize(name, offsets)
    super(name)

    @offsets = offsets
  end

  def print(p)
    p.print 'name', @name
    #p.print 'offsets', @dim_sizes
  end
end


class ExprUnary < Expr
  def initialize(op, operand)
    @op = op
    @operand = operand
  end

  def print(p)
    p.print 'op', @op
    p.print 'operand', @operand
  end
end

class Param < Node
  attr_reader :name
  attr_reader :type

  def initialize(name, type)
    @name = name
    @type = type
  end

  def print(p)
    p.print 'name', @name
    p.print 'type', @type
  end
end

class Program < Node
  def initialize(declarations)
    @declarations = declarations
  end

  def print(p)
    p.print('class_declarations', @declarations)
  end
end

class Stmt < Node
end

class StmtIO_Op < Stmt
end

class StmtIO_OpRead < StmtIO_Op
  def initialize(variables)
    @variables = variables
  end

  def print(p)
    p.print 'variables', @variables
  end
end

class StmtPrintVram < StmtIO_Op
  def initialize(x, y, color_val)
    @x = x
    @y = y
    @color_val = color_val
  end

  def print(p)
    #p.print 'variables', @variables
  end
end

class StmtClearVram < StmtIO_Op
  def initialize(token)
    @token = token
  end
end

class StmtFlushVram < StmtIO_Op
  def initialize(token)
    @token = token
  end
end

class StmtIO_OpWrite < StmtIO_Op
  attr_reader :exprs

  def initialize(exprs)
    @exprs = exprs
  end

  def print(p)
    p.print 'exprs', @exprs
  end
end

class StmtVarDecl < Stmt
  attr_accessor :type, :name, :value

  def initialize(type, name, value)
    @type = type
    @name = name
    @value = value
  end

  def print(p)
    p.print 'type', @type
    p.print 'name', @name
    p.print 'value', @value if @value
  end
end

class StmtAssignment < Stmt
  attr_accessor :name, :value

  def initialize(name, value)
    @name = name
    @value = value
  end

  def print(p)
    p.print 'name', @name
    p.print 'value', @value
  end
end

class StmtAssignmentPointer < StmtAssignment
  attr_accessor :offsets

  def initialize(name, value, offset)
    super(name, value)

    @dim_sizes = offset
  end

  def print(p)
    super.print(p)
    p.print 'offset', @dim_sizes
  end
end

class StmtBlock < Stmt
  attr_accessor :stmts

  def initialize(stmts)
    @stmts = stmts
  end

  def print(p)
    p.print 'stmts', @stmts
  end
end

class StmtBreak < Stmt
  attr_reader :break_token, :target_loop

  def initialize(break_token, target_loop)
    @break_token = break_token
    @target_loop = target_loop
  end

  def print(p)
    p.print 'token', @break_token
  end
end

class StmtContinue < Stmt
  attr_reader :break_token, :target_loop

  def initialize(break_token, target_loop)
    @break_token = break_token
    @target_loop = target_loop
  end

  def print(p)
    p.print 'token', @break_token
  end
end

class StmtExpr < Stmt
  def initialize(expr)
    @expr = expr
  end

  def print(p)
    p.print 'expr', @expr
  end
end

class StmtIf < Stmt
  attr_accessor :cond, :body, :elses

  def initialize(cond, body, elses)
    @cond = cond
    @body = body
    @elses = elses
  end

  def print(p)
    p.print 'cond', @cond
    p.print 'body', @body
    p.print 'elses', @elses
  end
end

class StmtElse < Stmt
  attr_accessor :body

  def initialize(body)
    @body = body
  end

  def print(p)
    p.print 'body', @body
  end
end

class StmtElseIf < Stmt
  attr_accessor :cond, :body, :parent_conditional

  def initialize(cond, body, parent_conditional)
    @cond = cond
    @parent_conditional = parent_conditional
    @body = body
  end

  def print(p)
    p.print 'condition', @cond
    p.print 'body', @body
  end
end

class StmtLet < Stmt
  def initialize(name, type)
    @name = name
    @type = type
  end

  def print(p)
    p.print 'name', @name
    p.print 'type', @type
  end
end

class StmtWhile < Stmt
  def initialize(cond, body)
    @cond = cond
    @body = body
  end

  def print(p)
    p.print 'condition', @cond
    p.print 'body', @body
  end
end

class StmtLoop < Stmt
  attr_accessor :header, :body

  def initialize(header, body)
    @header = header
    @body = body
  end

  def print(p)
    p.print 'header', @header
    p.print 'body', @body
  end
end

class StmtReturn < Stmt
  attr_reader :token, :value

  def initialize(ancestral_method, value, token)
    @token = token
    @ancestral_method = ancestral_method
    @value = value
  end

  def print(p)
    p.print 'value', @value if @value
  end
end

class StmtSleep < Node
  def initialize(token, time)
    super(token)
    @time = time
  end
end

class StmtRand < Node
  attr_reader :from, :to, :target

  def initialize(token, target, from, to)
    super(token)

    @target = target
    @from = from
    @to = to
  end
end

class Type < Node
  def get_type_name
    raise 'not implemented for clas %s' % [self.class]
  end
end

class TypePrim < Type
  attr_reader :token

  def initialize(token)
    @token = token
  end

  def print(p)
    p.print 'type', @token
  end
end

class TypeInt < TypePrim
  @@default_val = ExprInt.new(0)
  @@stack_slot_size = 1

  def self.default_val
    @@default_val
  end

  def get_stack_slot_size
    @@stack_slot_size
  end
end

class TypeBool < TypePrim
  @@default_val = ExprBool.new(Token.new(nil, nil, false))
  @@stack_slot_size = 1

  def self.default_val
    @@default_val
  end

  def get_stack_slot_size
    @@stack_slot_size
  end
end

class TypeFloat < TypePrim
  @@default_val = ExprFloat.new(Token.new(nil, nil, 0.0))
  @@stack_slot_size = 2

  def self.default_val
    @@default_val
  end

  def get_stack_slot_size
    @@stack_slot_size
  end
end

class TypeString < TypePrim
  @@default_val = ExprString.new(Token.new(nil, nil, ""))
  @@stack_slot_size = 1

  def self.default_val
    @@default_val
  end

  def get_stack_slot_size
    @@stack_slot_size
  end
end

class TypeVoid < TypePrim
  @@default_val = ExprVoid.new(Token.new(nil, nil, nil))
  @@stack_slot_size = 1

  def self.default_val
    @@default_val
  end

  def get_stack_slot_size
    @@stack_slot_size
  end
end

class TypePointer < Type
  @@stack_slot_size = 1

  attr_accessor :element_type, :dim_sizes

  def initialize(element_type, dim_sizes, token=nil)
    @element_type = element_type
    @dim_sizes = dim_sizes
    @token = token
  end

  def print(p)
    p.print 'element_type', @element_type
  end

  def get_stack_slot_size
    @@stack_slot_size
  end
end

class ForEachHeader < Node
  attr_accessor :var, :in_exp

  def initialize(var, in_exp)
    @var = var
    @in_exp = in_exp
  end

  def print(p)
    p.print 'cycle_variable', @var
    p.print 'in_expression', @in_exp
  end
end

class ForHeader < Node
  attr_accessor :start, :to, :step, :cond, :incr_stmt

  def initialize(start, to, step, target_loop, cond = nil, incr_stmt = nil)
    @start = start
    @to = to
    @step = step
    @target_loop = target_loop
    @cond = cond
    @incr_stmt = incr_stmt
  end

  def print(p)
    p.print 'start', @start
    p.print 'to', @to
    p.print 'step', @step
  end
end

class WhileHeader < Node
  attr_accessor :cond, :while_token

  def initialize(cond, target_loop)
    @cond = cond
    @target_loop = target_loop
  end

  def print(p)
    p.print 'condition', @cond
  end
end
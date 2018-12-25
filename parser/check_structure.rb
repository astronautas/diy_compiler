require_relative "ast"

class Program
  def find_main

  end
end

class DefClass
  def find_main
    @body.each do |method_or_field|
      if method_or_field.instance_of?(DefMain)
        if method_or_field.params.length != 1
          semantic_error(nil, "Main method must have only 1 parameter args: string[]")
        end
        true
      end
    end
  end
end

class StructureValidator
  def validate_main(main_node)
    if main_node.nil?
      semantic_error(nil, "Main function should be declared once in any of class definitions.")
    end

    main_required_params = [Param.new(nil, TypeString.new(nil))]

    if main_node.params.length != main_required_params.length
      semantic_error(main_node.klass.name, 'invalid main parameter count: %s vs %s' % [main_node.params.length, main_required_params.length])
    end

    # Even if param count != arg count, check the types
    min_check = [main_node.params.length, main_required_params.length].min

    (0...min_check).each do |i|
      unify_types(main_node.params[i].type, main_required_params[i].type, main_node.name)
    end

  end

  def validate_methods(methods)
    methods.each do |method_node|
      if method_node.returns.length == 0 and !method_node.ret_type.instance_of?(TypeVoid)
        semantic_error(nil, "#{method_node.klass.name.value}.#{method_node.name.value} method should have >= 1 return.")
      end
    end
  end

  def add_default_returns(methods)
    methods.each do |method|
        method.body.stmts << StmtReturn.new(method, method.ret_type.class.default_val, nil)
        method.returns << StmtReturn.new(method, nil, nil)
    end
  end

  def validate_loop_skips(skips)
    skips.each do |skip|
      if !skip.target_loop
        semantic_error(skip.break_token, "#{skip.break_token} should be inside of a loop.")
      end
    end
  end
end
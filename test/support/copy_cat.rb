# frozen_string_literal: true

require "parser"
require "prism"

module CopyCat
  module NoWarnRewrite
    def warn(message, category: nil, **kwargs)
      if /method redefined; discarding old|previous definition of/.match?(message) &&
         caller_locations.any? { _1.path["test/support/copy_cat.rb"] && _1.label["copy_methods"] }
        # ignore
      else
        super
      end
    end
  end
  ::Warning.singleton_class.prepend NoWarnRewrite

  extend self

  # Copy methods from The original rails class to our adapter.
  # While copying, we can rewrite the source code of the method using
  # ast. Use `debug: true` to lead you through that process.
  #
  # Once debug is set, you can check the closest node you want to edit
  # and then create a method `on_<node_type>` to handle it.
  def copy_methods(new_klass, old_klass, *methods, debug: false, &block)
    if debug and not block_given?
      puts "You need to provide a block to debug."
    end
    methods.each do |met|
      file, _ = old_klass.instance_method(met).source_location
      ast = find_method(Prism::Translation::Parser.parse_file(file), met)
      code =
        if block_given?
          source = ast.location.expression.source
          buffer = Parser::Source::Buffer.new(met, source: source)
          # We need to recompute the ast to have correct locations.
          ast = Prism::Translation::Parser.parse(source)

          if debug
            puts "=" * 80
            puts "Rewriter doc: https://www.rubydoc.info/gems/parser/3.3.0.5/Parser/TreeRewriter"
            puts "Pattern matching doc: https://docs.ruby-lang.org/en/master/syntax/pattern_matching_rdoc.html"
            puts
            puts "Method: #{met}"
            puts
            puts "Source:"
            puts buffer.source
            puts
            puts "AST:"
            pp ast
            puts
          end
          rewriter_class = Class.new(Parser::TreeRewriter, &block)
          rewriter_class.new.rewrite(buffer, ast)
        else
          ast.location.expression.source
        end
      if debug and block_given?
        puts "Rewritten source:"
        puts code
        puts "=" * 80
      end
      location = caller_locations(3, 1).first
      new_klass.class_eval(code, location.absolute_path || location.path, location.lineno)
    end
  end

  def find_method(ast, method_name)
    method_name = method_name.to_sym
    to_search = [ast]
    while !to_search.empty?
      node = to_search.shift
      next unless node.is_a?(Parser::AST::Node)
      if node in [:def, ^method_name, *]
        return node
      end
      to_search += node.children
    end
    return nil
  end
end

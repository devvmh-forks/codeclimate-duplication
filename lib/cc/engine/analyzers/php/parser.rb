require 'posix/spawn'
require 'timeout'
require 'cc/engine/analyzers/php/ast'
require 'cc/engine/analyzers/php/nodes'

module CC
  module Engine
    module Analyzers
      module Php
        class Parser
          attr_reader :code, :filename, :syntax_tree

          def initialize(code, filename)
            @code = code
            @filename = filename
          end

          def parse
            runner = CommandLineRunner.new("php #{parser_path}", self)
            runner.run(code) { |output| JSON.parse(output, max_nesting: false) }
            self
          end

          def on_success(output)
            @syntax_tree = CC::Engine::Analyzers::Php::Nodes::Node.new.tap do |node|
              node.stmts = CC::Engine::Analyzers::Php::AST.json_to_ast(output, filename)
              node.node_type = "AST"
            end
          end

        private

          def parser_path
            "vendor/php-parser/parser.php"
          end
        end

        class CommandLineRunner
          attr_reader :command, :delegate

          DEFAULT_TIMEOUT = 20
          EXCEPTIONS = [
            StandardError,
            Timeout::Error,
            POSIX::Spawn::TimeoutExceeded,
            SystemStackError
          ]

          def initialize(command, delegate)
            @command = command
            @delegate = delegate
          end

          def run(input, timeout = DEFAULT_TIMEOUT)
            Timeout.timeout(timeout) do
              child = ::POSIX::Spawn::Child.new(command, input: input, timeout: timeout)
              if child.status.success?
                output = block_given? ? yield(child.out) : child.out
                delegate.on_success(output)
              end

            end
          rescue *EXCEPTIONS
          end
        end
      end
    end
  end
end


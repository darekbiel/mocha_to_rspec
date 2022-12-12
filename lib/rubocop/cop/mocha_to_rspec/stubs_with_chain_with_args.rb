module RuboCop
  module Cop
    module MochaToRSpec
      class StubsWithChainWithArgs < Cop
        MSG = "expect and stub chains autocorrect".freeze

        def_node_matcher :candidate?, <<-CODE
          $(...)
        CODE

        def x_candidate?(node)
          (node.source.include?('expects_chain') || node.source.include?('stubs_chain')) && !node.source.scan('.with').count.zero? && node.source.include?('.returns')
        end

        def on_send(node)
          candidate?(node) do
            if x_candidate?(node)
              add_offense(node, location: :selector)
            else
              false
            end
          end
        end

        def extract_withs(x_array, output_arr)
          if x_array.last == :with
            output_arr << OpenStruct.new(source: 'no_args')
          else
            output_arr << x_array[2..-1]
          end

          if x_array.first.source.include?('.with')
            extract_withs(x_array.first.to_a, output_arr)
          else
            x_array.first
          end
        end

        def format(args)
          if args.kind_of?(Array)
            ".with(#{args.map(&:source).join(', ')})"
          else
            ".with(#{args.source})"
          end
        end

        def autocorrect(node)
          lambda do |corrector|
            node_without_returns, returns, ret_val = *node
            withs = []
            obj_stubs_x = extract_withs(node_without_returns.to_a, withs)
            withs = withs.reverse.map { |args| format(args) }.join('')

            # obj_stubs_x_with_y, returns, ret_val = *node
            # obj_stubs_x, _with, *args = *obj_stubs_x_with_y
            # args_list = args.map(&:source).join(", ")

            subject, variant, *method_names = *obj_stubs_x

            allow_or_expect = case variant
                              when :stubs, :stubs_chain
                                "allow"
                              when :expects, :expects_chain
                                "expect"
                              else
                                raise "Got #{variant}"
                              end

            # with_args = args_list.empty? ? 'no_args' : args_list

            # expect(Kai::PaymentInvoices::SurchargeInvoiceBuilder).to receive_message_chain(:new, :build).with(
            #   user, pay_plan: pay_plan, surcharge_in_cents: surcharge_in_cents
            # ).with(no_args).and_return(invoice)

            # Trzeba zrobić poprawki żeby mieć ret_val i method_names + dodawać no_args

            if variant == :expects_chain || variant == :stubs_chain
              replacement = "#{allow_or_expect}(#{subject.source}).to receive_message_chain(#{method_names.map(&:source).join(', ')})#{withs}.and_return(#{ret_val.source})"
            else
              replacement = "#{allow_or_expect}(#{subject.source}).to receive(#{method_names.first.source}).with(#{with_args}).and_return(#{ret_val.source})"
            end

            corrector.replace(node.source_range, replacement)
          rescue => e
            require 'pry'; binding.pry
          end
        end
      end
    end
  end
end

module RuboCop
  module Cop
    module MochaToRSpec
      class StubsWithChainWithArgs < Cop
        # TODO: Use seperate messages for allow/expect.
        MSG = "Use `allow/expect(object).to receive(...).with(...)` (rspec-mocks) instead of `object.stubs/expects(...).with(...)` (Mocha)".freeze

        def_node_matcher :candidate?, <<-CODE
          $(...)
        CODE

        def x_candidate?(node)
          node.source.include?('expects_chain') && !node.source.scan('.with').count.zero? && node.source.include?('.returns')
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

        def extract_withs(x, arr = [])
          arr << x.to_a.last

          if x.to_a.first.source.include?('.with')
            extract_withs(x.to_a.first, arr)
          else
            arr
          end
        end

        def autocorrect(node)
          lambda do |corrector|
            node_without_returns, returns, ret_val = *node

            withs = extract_withs(node_without_returns).reverse.map { |arg| ".with(#{arg.source})" }.join('')

            obj_stubs_x_with_y, returns, ret_val = *node
            obj_stubs_x, _with, *args = *obj_stubs_x_with_y

            subject, variant, *method_names = *obj_stubs_x
            args_list = args.map(&:source).join(", ")

            allow_or_expect = case variant
                              when :stubs
                                "allow"
                              when :expects, :expects_chain
                                "expect"
                              else
                                raise "Got #{variant}"
                              end

            with_args = args_list.empty? ? 'no_args' : args_list

            # expect(Kai::PaymentInvoices::SurchargeInvoiceBuilder).to receive_message_chain(:new, :build).with(
            #   user, pay_plan: pay_plan, surcharge_in_cents: surcharge_in_cents
            # ).with(no_args).and_return(invoice)

            # Trzeba zrobić poprawki żeby mieć ret_val i method_names + dodawać no_args

            if variant == :expects_chain
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

module RuboCop
  module Cop
    module MochaToRSpec
      class StubsWithChainWithArgs < Cop
        # TODO: Use seperate messages for allow/expect.
        MSG = "Use `allow/expect(object).to receive(...).with(...)` (rspec-mocks) instead of `object.stubs/expects(...).with(...)` (Mocha)".freeze
        # def_node_matcher :candidate?, <<-CODE
        #   (send (send (send _ {:expects_chain} ...) :with ...) :returns _)
        # CODE

        # def_node_matcher :candidate?, <<-CODE
        #   (send (send (send _ {:stubs :expects :expects_chain} ...) :with ...) :returns _)
        # CODE

        # (send (send (send (send _ {:expects_chain} ...) :with ...) :with ...) :returns _)

        # def_node_matcher :candidate?, <<-RUBY
        #   (send (send (send (send _ {:expects_chain} ...) :with ...) :with ...) :returns _)
        # RUBY

        # def_node_matcher :candidate?, <<-CODE
        #   {
        #     (send (send (send _ {:expects_chain} ...) :with ...) :returns _)
        #     (send (send (send _ {:expects_chain} (send() ) ) :with ...) :returns _)
        #   }
        # CODE
        #
        # def_node_matcher :candidate?, <<-CODE
        #   (send (send (send _ {:expects_chain} ...) :with ...) :returns _)
        #   (send nil? $_ $_ ...)
        # CODE

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

        def xxx(x, arr)
          arr << x.to_a.last

          if x.to_a.first.source.include?('.with')
            xxx(x.to_a.first, arr)
          else
            arr
          end
        end

        def autocorrect(node)
          lambda do |corrector|
            node_without_returns, returns, ret_val = *node

            a = []

            withs = xxx(node_without_returns, a).reverse

            withs = withs.map { |arg| ".with(#{arg.source})" }.join('')
            # do ugrania no_args


            obj_stubs_x_with_y, returns, ret_val = *node
            obj_stubs_x, _with, *args = *obj_stubs_x_with_y
            require 'pry'; binding.pry
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

            # node.to_a.first.to_a.first.to_a.first.to_a.last # Pierwszy
            # node.to_a.first.to_a.first.to_a.last            # Drugi
            # node.to_a.first.to_a.last                       # Trzeci with


            # expect(Kai::PaymentInvoices::SurchargeInvoiceBuilder).to receive_message_chain(:new, :build).with(
            #   user, pay_plan: pay_plan, surcharge_in_cents: surcharge_in_cents
            # ).with(no_args).and_return(invoice)

            require 'pry'; binding.pry

            if variant == :expects_chain
              replacement = "#{allow_or_expect}(#{subject.source}).to receive_message_chain(#{method_names.map(&:source).join(', ')})#{withs}.and_return(#{ret_val.source})"
            else
              replacement = "#{allow_or_expect}(#{subject.source}).to receive(#{method_names.first.source}).with(#{with_args}).and_return(#{ret_val.source})"
            end

            corrector.replace(node.source_range, replacement)
          rescue => e
            # require 'pry'; binding.pry
          end
        end
      end
    end
  end
end

module StripeMock
  module RequestHandlers
    module Invoices

      def Invoices.included(klass)
        klass.add_handler 'post /v1/invoices',               :new_invoice
        klass.add_handler 'get /v1/invoices/(.*)',           :get_invoice
        klass.add_handler 'get /v1/invoices',                :list_invoices
        klass.add_handler 'post /v1/invoices/(.*)/pay',      :pay_invoice
      end

      def new_invoice(route, method_url, params, headers)
        id = new_id('in')
        invoices[id] = Data.mock_invoice(params.merge :id => id)
      end

      def list_invoices(route, method_url, params, headers)
        params[:offset] ||= 0
        params[:count] ||= 10

        result = invoices.clone

        if params[:customer]
          result.delete_if { |k,v| v[:customer] != params[:customer] }
        end

        result.values[params[:offset], params[:count]]
      end

      def get_invoice(route, method_url, params, headers)
        route =~ method_url
        assert_existance :invoice, $1, invoices[$1]
        invoices[$1] ||= Data.mock_invoice(:id => $1)
      end
      
      def pay_invoice(route, method_url, params, headers)
        route =~ method_url
        assert_existance :invoice, $1, invoices[$1]
        paid_invoice = invoices[$1] ||= Data.mock_invoice(:id => $1)

        paid_invoice[:amount_due] = invoice_items.inject(0) { |sum, (idx,item)| sum += item[:amount] ; sum }
        paid_invoice[:subtotal]   = paid_invoice[:amount_due]
        paid_invoice[:total]      = paid_invoice[:subtotal] - (paid_invoice[:discount] || 0)
        paid_invoice[:paid]       = true
        paid_invoice[:attempted]  = true

        charge_id = new_id('charge')
        charges[charge_id] = Data.mock_charge(:id => charge_id, :amount => paid_invoice[:total], :invoice => $1)
        paid_invoice[:charge] = charge_id

        paid_invoice
      end

    end
  end
end

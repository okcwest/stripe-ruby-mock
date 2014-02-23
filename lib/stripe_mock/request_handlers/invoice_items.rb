module StripeMock
  module RequestHandlers
    module InvoiceItems

      def InvoiceItems.included(klass)
        klass.add_handler 'post /v1/invoiceitems',  :new_invoice_item
      end

      def new_invoice_item(route, method_url, params, headers)
        id = new_id('in_it')
        invoice_items[id] = Data.mock_invoice_item(params.merge(:id => id))
      end

    end
  end
end

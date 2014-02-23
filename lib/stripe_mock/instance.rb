module StripeMock
  class Instance

    # Handlers are ordered by priority
    @@handlers = []

    def self.add_handler(route, name)
      @@handlers << {
        :route => %r{^#{route}$},
        :name => name
      }
    end

    def self.handler_for_method_url(method_url)
      @@handlers.find {|h| method_url =~ h[:route] }
    end

    include StripeMock::RequestHandlers::Charges
    include StripeMock::RequestHandlers::Cards
    include StripeMock::RequestHandlers::Customers
    include StripeMock::RequestHandlers::Coupons
    include StripeMock::RequestHandlers::Events
    include StripeMock::RequestHandlers::Invoices
    include StripeMock::RequestHandlers::InvoiceItems
    include StripeMock::RequestHandlers::Plans
    include StripeMock::RequestHandlers::Recipients
    include StripeMock::RequestHandlers::Tokens


    attr_reader :bank_tokens, :charges, :coupons, :customers, :events,
                :invoices, :invoice_items, :plans, :recipients

    attr_accessor :error_queue, :debug, :strict

    def initialize
      @bank_tokens = {}
      @card_tokens = {}
      @customers = {}
      @charges = {}
      @coupons = {}
      @events = {}
      @invoices = {}
      @invoice_items = {}
      @plans = {}
      @recipients = {}

      @debug = false
      @error_queue = ErrorQueue.new
      @id_counter = 0
      @strict = true
    end

    def mock_request(method, url, api_key, params={}, headers={})
      return {} if method == :xtest

      # Ensure params hash has symbols as keys
      params = Stripe::Util.symbolize_names(params)

      method_url = "#{method} #{url}"

      if handler = Instance.handler_for_method_url(method_url)
        if @debug == true
          puts "[StripeMock req]::#{handler[:name]} #{method} #{url}"
          puts "                  #{params}"
        end

        if mock_error = @error_queue.error_for_handler_name(handler[:name])
          @error_queue.dequeue
          raise mock_error
        else
          res = self.send(handler[:name], handler[:route], method_url, params, headers)
          puts "           [res]  #{res}" if @debug == true
          [res, api_key]
        end
      else
        puts "WARNING: Unrecognized method + url: [#{method} #{url}]"
        puts " params: #{params}"
        [{}, api_key]
      end
    end

    def generate_bank_token(bank_params)
      token = new_id 'btok'
      @bank_tokens[token] = Data.mock_bank_account bank_params
      token
    end

    def generate_card_token(card_params)
      token = new_id 'tok'
      card_params[:id] = new_id 'cc'
      @card_tokens[token] = Data.mock_card symbolize_names(card_params)
      token
    end

    def generate_event(event_data)
      event_data[:id] ||= new_id 'evt'
      @events[ event_data[:id] ] = symbolize_names(event_data)
    end

    def get_bank_by_token(token)
      if token.nil? || @bank_tokens[token].nil?
        Data.mock_bank_account
      else
        @bank_tokens.delete(token)
      end
    end

    def get_card_by_token(token)
      if token.nil? || @card_tokens[token].nil?
        Data.mock_card :id => new_id('cc')
      else
        @card_tokens.delete(token)
      end
    end

    def get_customer_card(customer, token)
      customer[:cards][:data].find{|cc| cc[:id] == token }
    end

    def add_card_to_customer(card, cus)
      card[:customer] = cus[:id]

      if cus[:cards][:count] == 0
        cus[:cards][:count] += 1
      else
        cus[:cards][:data].delete_if {|card| card[:id] == cus[:default_card]}
      end

      cus[:cards][:data] << card

      card
    end

    private

    def assert_existance(type, id, obj, message=nil)
      return unless @strict == true

      if obj.nil?
        msg = message || "No such #{type}: #{id}"
        raise Stripe::InvalidRequestError.new(msg, type.to_s, 404)
      end
    end

    def new_id(prefix)
      # Stripe ids must be strings
      "test_#{prefix}_#{@id_counter += 1}"
    end

    def symbolize_names(hash)
      Stripe::Util.symbolize_names(hash)
    end

  end
end

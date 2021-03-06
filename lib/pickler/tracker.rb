class Pickler
  class Tracker

    ADDRESS = 'www.pivotaltracker.com'
    BASE_PATH = '/services/v1'
    SEARCH_KEYS = %w(label type state requester owner mywork id includedone)

    class Error < Pickler::Error; end

    attr_reader :token

    def initialize(token)
      require 'active_support'
      @token = token
    end

    def request(method, path, *args)
      require 'net/http'
      Net::HTTP.start(ADDRESS) do |http|
        headers = {
          "Token"        => @token,
          "Accept"       => "application/xml",
          "Content-type" => "application/xml"
        }
        klass = Net::HTTP.const_get(method.to_s.capitalize)
        http.request(klass.new("#{BASE_PATH}#{path}", headers), *args)
      end
    end

    def request_xml(method, path, *args)
      response = request(method,path,*args)
      raise response.inspect if response["Content-type"].split(/; */).first != "application/xml"
      Hash.from_xml(response.body)["response"]
    end

    def get_xml(path)
      response = request_xml(:get, path)
      unless response["success"] == "true"
        if response["message"]
          raise Error, response["message"], caller
        else
          raise "#{path}: #{response.inspect}"
        end
      end
      response
    end

    def project(id)
      Project.new(self,get_xml("/projects/#{id}")["project"].merge("id" => id.to_i))
    end

    class Abstract
      def initialize(attributes)
        @attributes = (attributes || {}).stringify_keys
        yield self if block_given?
      end

      def self.reader(*methods)
        methods.each do |method|
          define_method(method) { @attributes[method.to_s] }
        end
      end

      def self.accessor(*methods)
        reader(*methods)
        methods.each do |method|
          define_method("#{method}=") { |v| @attributes[method.to_s] = v }
        end
      end
      reader :id
    end

  end
end

require 'pickler/tracker/project'
require 'pickler/tracker/story'

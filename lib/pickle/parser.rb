require 'pickle/parser/matchers'

module Pickle
  class Parser
    @@step_mother = nil
    @@rb_language = nil

    include Matchers
    
    attr_reader :config
    
    def initialize(options = {})
      @config = options[:config] || raise(ArgumentError, "Parser.new requires a :config")
    end
    
    # given a string like 'foo: "bar", bar: "baz"' returns {"foo" => "bar", "bar" => "baz"}
    def parse_fields(fields)
      if fields.blank?
        {}
      elsif fields =~ /^#{match_fields}$/
        fields.scan(/(#{match_field})(?:,|$)/).inject({}) do |m, match|
          m.merge(parse_field(match[0]))
        end
      else
        raise ArgumentError, "The fields string is not in the correct format.\n\n'#{fields}' did not match: #{match_fields}" 
      end
    end

    def set_step_mother_from_object_space
      return if @@step_mother
      # This is getting ugly, I have not been able to find a  good way
      # to get at the StepMother that is running the features from
      # here. But ... we can fetch her from the object space.
      ObjectSpace.each_object(Cucumber::StepMother) { |o| @@step_mother = o }
      # There she is in all her glory. Can haz shower now?
      @@step_mother = :undefined unless @@step_mother
      @@step_mother
    end

    def set_rb_language
      return if @@rb_language
      set_step_mother_from_object_space

      # This is getting ugly, I have not been able to find a  good way
      # to get at the StepMother that is running the features from
      # here. But ... we can fetch her from the object space.
      ObjectSpace.each_object(Cucumber::StepMother) { |o| @@step_mother = o }
      # There she is in all her glory. Now I feel like I need a shower

      @@rb_language = if @@step_mother == :undefined
                        :undefined
                      else
                        @@step_mother.load_programming_language('rb')
                      end
    end

    def execute_transforms(arg)
      set_rb_language
      if @@rb_language == :undefined
        arg
      else
        @@rb_language.execute_transforms([arg]).first
      end
    end

    # given a string like 'foo: expr' returns {key => value}
    def parse_field(field)
      if field =~ /^#{capture_key_and_value_in_field}$/
        value = eval($2)
        if value.respond_to?(:match)
          value = execute_transforms(value)
        end
        { $1 => value }
      else
        raise ArgumentError, "The field argument is not in the correct format.\n\n'#{field}' did not match: #{match_field}"
      end
    end
    
    # returns really underscored name
    def canonical(str)
      str.to_s.underscore.gsub(' ','_').gsub('/','_')
    end
    
    # return [factory_name, name or integer index]
    def parse_model(model_name)
      apply_mappings!(model_name)
      if /#{capture_index} #{capture_factory}$/ =~ model_name
        [canonical($2), parse_index($1)]
      elsif /#{capture_factory}#{capture_name_in_label}?$/ =~ model_name
        [canonical($1), canonical($2)]
      end
    end
  
    def parse_index(index)
      case index
      when nil, '', 'last' then -1
      when /#{capture_number_in_ordinal}/ then $1.to_i - 1
      when 'first' then 0
      end
    end

  private
    def apply_mappings!(string)
      config.mappings.each do |mapping|
        string.sub! /^#{mapping.search}$/, mapping.replacement
      end
    end
  end
end

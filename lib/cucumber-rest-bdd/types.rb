require 'active_support/inflector'

HAVE_ALTERNATION = "has/have/having/contain/contains/containing/with"
RESOURCE_NAME_SYNONYM = '\w+\b(?:\s+\w+\b)*?|`[^`]*`'
FIELD_NAME_SYNONYM = "#{RESOURCE_NAME_SYNONYM}"
MAXIMAL_FIELD_NAME_SYNONYM = '\w+\b(?:\s+\w+\b)*|`[^`]*`'

ParameterType(
    name: 'resource_name',
    regexp: /#{RESOURCE_NAME_SYNONYM}/,
    transformer: -> (s) { get_resource(s) },
    use_for_snippets: false
)

ParameterType(
    name: 'field_name',
    regexp: /#{FIELD_NAME_SYNONYM}/,
    transformer: -> (s) { ResponseField.new(s) },
    use_for_snippets: false
)

module Boolean; end
class TrueClass; include Boolean; end
class FalseClass; include Boolean; end

module Enum; end
class String; include Enum; end

class String
  def to_type(type)
    # cannot use 'case type' which checks for instances of a type rather than type equality
    if type == Boolean then !(self =~ /true|yes/i).nil?
    elsif type == Enum then self.upcase.tr(" ", "_")
    elsif type == Float then self.to_f
    elsif type == Integer then self.to_i
    elsif type == NilClass then nil
    else self
    end
  end
end

class ResponseField
    def initialize(names)
        @fields = get_fields(names)
    end

    def to_json_path()
        return "#{get_root_data_key()}#{@fields.join('.')}"
    end

    def get_value(type)
        return @response.get_as_type to_json_path(), parse_type(type)
    end

    def validate_value(value, regex)
        raise %/Expected #{json_path} value '#{value}' to match regex: #{regex}\n#{@response.to_json_s}/ if (regex =~ value).nil?
    end
end

def parse_type(type)
    replacements = {
        /^numeric$/i => 'integer',
        /^int$/i => 'integer',
        /^long$/i => 'integer',
        /^number$/i => 'integer',
        /^decimal$/i => 'float',
        /^double$/i => 'float',
        /^bool$/i => 'boolean',
        /^null$/i => 'nil_class',
        /^nil$/i => 'nil_class',
        /^text$/i => 'string'
    }
    type.tr(' ', '_')
    replacements.each { |k,v| type.gsub!(k, v) }
    type
end

def get_resource(name)
    if name[0] == '`' && name[-1] == '`'
        name = name[1..-2]
    else
        name = name.parameterize
        name = (ENV.has_key?('resource_single') && ENV['resource_single'] == 'true') ? name.singularize : name.pluralize
    end
    return name
end

def get_root_data_key()
    return ENV.has_key?('data_key') && !ENV['data_key'].empty? ? "$.#{ENV['data_key']}." : "$."
end

def get_json_path(names)
    return "#{get_root_data_key()}#{get_fields(names).join('.')}"
end

def get_fields(names)
    return names.split(':').map { |n| get_field(n.strip) }
end

def get_field(name)
    if name[0] == '`' && name[-1] == '`'
        name = name[1..-2]
    elsif name[0] != '[' || name[-1] != ']'
        separator = ENV.has_key?('field_separator') ? ENV['field_separator'] : '_'
        name = name.parameterize(separator: separator)
        name = name.camelize(:lower) if (ENV.has_key?('field_camel') && ENV['field_camel'] == 'true')
    end
    return name
end

def get_attributes(hashes)
    attributes = hashes.each_with_object({}) do |row, hash|
      name, value, type = row["attribute"], row["value"], row["type"]
      value = resolve(value)
      value.gsub!(/\\n/, "\n")
      type = parse_type(type)
      names = get_fields(name)
      new_hash = names.reverse.inject(value.to_type(type.camelize.constantize)) { |a, n| add_to_hash(a, n) }
      hash.deep_merge!(new_hash) { |key, old, new| new.kind_of?(Array) ? merge_arrays(old, new) : new }
    end
end

def add_to_hash(a, n)
    result = nil    
    if (n[0] == '[' && n[-1] == ']') then
        array = Array.new(n[1..-2].to_i() + 1)
        array[n[1..-2].to_i()] = a
        result = array
    end
    result != nil ? result : { n => a };
end

def merge_arrays(a, b)
    new_length = [a.length, b.length].max
    new_array = Array.new(new_length)
    new_length.times do |n|
        if b[n].nil? then
            new_array[n] = a[n]
        else
            if a[n].nil? then
                new_array[n] = b[n]
            else
                new_array[n] = a[n].merge(b[n])
            end
        end
    end
    return new_array
end

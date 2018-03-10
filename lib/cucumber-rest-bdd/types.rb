require 'active_support/inflector'

HAVE_SYNONYM = %{(?:has|have|having|contain|contains|containing|with)}
RESOURCE_NAME = '[\w\s]+'
RESOURCE_NAME_CAPTURE = /([\w\s]+)/
ARTICLE = %{(?:an?|the)}
FIELD_NAME_SYNONYM = %q{[\w\s]+|`[^`]*`}
FEWER_MORE_THAN_SYNONYM = %q{(?:fewer|less|more) than|at (?:least|most)}
INT_AS_WORDS_SYNONYM = %q{zero|one|two|three|four|five|six|seven|eight|nine|ten}

ParameterType(
    name: 'field_name',
    regexp: /[\w\s]+|`[^`]*`/,
    transformer: -> (s) { get_fields(s) },
    use_for_snippets: false
)

ParameterType(
  name: 'int_as_words',
  regexp: /#{INT_AS_WORDS_SYNONYM}/,
  transformer: -> (s) { to_num(s) }
)

ParameterType(
  name: 'fewer_more_than',
  regexp: /#{FEWER_MORE_THAN_SYNONYM}/,
  transformer: -> (s) { to_compare(s) }
)

ParameterType(
    name: 'list_has_count',
    regexp: /a|an|(?:(#{FEWER_MORE_THAN_SYNONYM})\s+)?(#{INT_AS_WORDS_SYNONYM})/,
    transformer: -> (count_mod, count) {
        ListCountComparison.new(count_mod.nil? ? to_compare(count_mod) : CMP_EQUALS, count.nil? ? to_num(count) : 1)
    },
    use_for_snippets: false
)

CMP_LESS_THAN = '<'
CMP_MORE_THAN = '>'
CMP_AT_LEAST = '>='
CMP_AT_MOST = '<='
CMP_EQUALS = '='

# take a number modifier string (fewer than, less than, etc) and return an operator '<', etc
def to_compare(compare)
    return case compare
    when 'fewer than' then CMP_LESS_THAN
    when 'less than' then CMP_LESS_THAN
    when 'more than' then CMP_MORE_THAN
    when 'at least' then CMP_AT_LEAST
    when 'at most' then CMP_AT_MOST
    else CMP_EQUALS
    end
end

# turn a comparison into a string
def compare_to_string(compare)
    case compare
    when CMP_LESS_THAN then 'fewer than '
    when CMP_MORE_THAN then 'more than '
    when CMP_AT_LEAST then 'at least '
    when CMP_AT_MOST then 'at most '
    when CMP_EQUALS then ''
    else ''
    end
end

# compare two numbers using the fewer_more_than optional modifier
def num_compare(type, left, right)
    case type
    when CMP_LESS_THAN then left < right
    when CMP_MORE_THAN then left > right
    when CMP_AT_MOST then left <= right
    when CMP_AT_LEAST then left >= right
    when CMP_EQUALS then left == right
    else left == right
    end
end

def to_num(num)
    if /^(?:zero|one|two|three|four|five|six|seven|eight|nine|ten)$/.match(num)
        return %w(zero one two three four five six seven eight nine ten).index(num)
    end
    return num.to_i
end

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

class ListCountComparison
    def initialize(type, amount)
        @type = type
        @amount = amount
    end

    def compare(actual)
        case @type
            when CMP_LESS_THAN then actual < @amount
            when CMP_MORE_THAN then actual > @amount
            when CMP_AT_MOST then actual <= @amount
            when CMP_AT_LEAST then actual >= @amount
            when CMP_EQUALS then actual == @amount
            else actual == @amount
        end
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
    name = name.parameterize
    name = (ENV.has_key?('resource_single') && ENV['resource_single'] == 'true') ? name.singularize : name.pluralize
    return name
end

def get_root_data_key()
    return ENV.has_key?('data_key') && !ENV['data_key'].empty? ? "$.#{ENV['data_key']}." : "$."
end

def get_root_error_key()
    return "$."
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
        new_array[n] = b[n] == nil ? a[n] : b[n]
    end
    return new_array
end

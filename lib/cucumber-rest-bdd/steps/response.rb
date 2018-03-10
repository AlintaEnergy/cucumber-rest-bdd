require 'cucumber-rest-bdd/steps/resource'
require 'cucumber-rest-bdd/types'

LIST_HAS_SYNONYM = %r{(?:a|an|(?:(#{FEWER_MORE_THAN_SYNONYM})\s+)?(#{INT_AS_WORDS_SYNONYM}|\d+))\s+(#{FIELD_NAME_SYNONYM})}
LIST_HAS_SYNONYM_WITHOUT_CAPTURE = %r{(?:a|an|(?:(?:#{FEWER_MORE_THAN_SYNONYM})\s+)?(?:#{INT_AS_WORDS_SYNONYM}|\d+))\s+(?:#{FIELD_NAME_SYNONYM})}

Then(/^print the response$/) do
    puts %/The response:\n#{@response.to_json_s}/
end

# response interrogation

Then(/^the response #{HAVE_SYNONYM} (#{FIELD_NAME_SYNONYM}) of type (datetime|guid)$/) do |names, type|
    regex = case type
    when 'datetime' then /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:[+|-]\d{2}:\d{2})?$/i
    when 'guid' then /^[{(]?[0-9A-F]{8}[-]?([0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$/i
    else 'UNKNOWN'
    end
    validate_value(names, 'string', regex)
end

Then(/^the response #{HAVE_SYNONYM} (#{FIELD_NAME_SYNONYM}) of type (\w+) that matches "(.+)"$/) do |names, type, regex|
    validate_value(names, type, Regexp.new(regex))
end

def validate_value(names, type, regex)
    json_path = get_json_path(names)
    type = parse_type(type)
    value = @response.get_as_type json_path, type
    raise %/Expected #{json_path} value '#{value}' to match regex: #{regex}\n#{@response.to_json_s}/ if (regex =~ value).nil?
end

Then("the response is a list of/containing {list_has_count} {field_name}") do |list_comparison, item|
    list = @response.get_as_type get_root_data_key(), 'array'
    raise %/Expected at least #{count} items in array for path '#{get_root_data_key()}', found: #{list.count}\n#{@response.to_json_s}/ if !list_comparison.compare(list.count)
end

Then(/^the response ((?:#{HAVE_SYNONYM}\s+#{LIST_HAS_SYNONYM_WITHOUT_CAPTURE}\s+)*)#{HAVE_SYNONYM} (?:the )?(?:following )?(?:data|error )?attributes:$/) do |nesting, attributes|
    expected = get_attributes(attributes.hashes)
    groups = nesting
    grouping = get_grouping(groups)
    grouping.push({
        root: true,
        type: 'single'
    })
    data = @response.get get_key(grouping)
    raise %/Could not find a match for: #{nesting}\n#{expected.inspect}\n#{@response.to_json_s}/ if data.empty? || !nest_match_attributes(data, grouping, expected)
end

Then(/^the response ((?:#{HAVE_SYNONYM}\s+#{LIST_HAS_SYNONYM_WITHOUT_CAPTURE}\s+)*)#{HAVE_SYNONYM} (?:the )?(?:following )?value "([^"]*)"$/) do |nesting, value|
    expected = value
    groups = nesting
    grouping = get_grouping(groups)
    grouping.push({
        root: true,
        type: 'single'
    })
    data = @response.get get_key(grouping)
    raise %/Could not find a match for: #{nesting}\n#{expected}\n#{@response.to_json_s}/ if data.empty? || !nest_match_value(data, grouping, expected)
end

Then(/^the response ((?:#{HAVE_SYNONYM}\s+#{LIST_HAS_SYNONYM_WITHOUT_CAPTURE}\s+)+)$/) do |nesting|
    groups = nesting
    grouping = get_grouping(groups)
    grouping.push({
        root: true,
        type: 'single'
    })
    data = @response.get get_key(grouping)
    raise %/Could not find a match for: #{nesting}\n#{@response.to_json_s}/ if data.empty? || !nest_match_attributes(data, grouping, {})
end

Then(/^#{LIST_HAS_SYNONYM} ((?:#{HAVE_SYNONYM}\s+#{LIST_HAS_SYNONYM_WITHOUT_CAPTURE}\s+)*)#{HAVE_SYNONYM} (?:the )?(?:following )?(?:data )?attributes:$/) do |count_mod, count, count_item, nesting, attributes|
    expected = get_attributes(attributes.hashes)
    groups = nesting
    grouping = get_grouping(groups)
    grouping.push({
        root: true,
        type: 'multiple',
        count: to_num(count),
        count_mod: to_compare(count_mod)
    })
    data = @response.get get_key(grouping)
    raise %/Expected #{compare_to_string(count_mod)}#{count} items in array with attributes for: #{nesting}\n#{expected.inspect}\n#{@response.to_json_s}/ if !nest_match_attributes(data, grouping, expected)
end

Then(/^#{LIST_HAS_SYNONYM} ((?:#{HAVE_SYNONYM}\s+#{LIST_HAS_SYNONYM_WITHOUT_CAPTURE}\s+)+)$/) do |count_mod, count, count_item, nesting|
    groups = nesting
    grouping = get_grouping(groups)
    grouping.push({
        root: true,
        type: 'multiple',
        count: to_num(count),
        count_mod: to_compare(count_mod)
    })
    data = @response.get get_key(grouping)
    raise %/Expected #{compare_to_string(count_mod)}#{count} items in array with: #{nesting}\n#{@response.to_json_s}/ if !nest_match_attributes(data, grouping, {})
end

Then(/^the response ((?:#{HAVE_SYNONYM}\s+#{LIST_HAS_SYNONYM_WITHOUT_CAPTURE}\s+)*)#{HAVE_SYNONYM} a list of #{LIST_HAS_SYNONYM}$/) do |nesting, num_mod, num, item|
    groups = nesting
    list = {
        type: 'list',
        key: get_resource(item)
    }
    if (num) then
        list[:count] = num.to_i
        list[:count_mod] = num_mod
    end
    grouping = [list]
    grouping.concat(get_grouping(groups))
    grouping.push({
        root: true,
        type: 'single'
    })
    data = @response.get get_key(grouping)
    raise %/Could not find a match for #{nesting}#{compare_to_string(num_mod)}#{num} #{item}\n#{@response.to_json_s}/ if !nest_match_attributes(data, grouping, {})
end

Then(/^#{LIST_HAS_SYNONYM} ((?:#{HAVE_SYNONYM}\s+#{LIST_HAS_SYNONYM_WITHOUT_CAPTURE}\s+)*)#{HAVE_SYNONYM} a list of #{LIST_HAS_SYNONYM}$/) do |count_mod, count, count_item, nesting, num_mod, num, item|
    groups = nesting
    list = {
        type: 'list',
        key: get_resource(item)
    }
    if (num) then
        list[:count] = num.to_i
        list[:count_mod] = num_mod
    end
    grouping = [list]
    grouping.concat(get_grouping(groups))
    grouping.push({
        root: true,
        type: 'multiple',
        count: to_num(count),
        count_mod: to_compare(count_mod)
    })
    data = @response.get get_key(grouping)
    raise %/Expected #{compare_to_string(count_mod)}#{count} items with #{nesting}#{compare_to_string(num_mod)}#{num}#{item}\n#{@response.to_json_s}/ if !nest_match_attributes(data, grouping, {})
end

# gets the relevant key for the response based on the first key element
def get_key(grouping)
    if ENV['error_key'] && !ENV['error_key'].empty? && grouping.count > 1 && grouping[-2][:key].singularize == ENV['error_key'] then
        get_root_error_key()
    else
        get_root_data_key()
    end
end

# gets an array in the nesting format that nest_match_attributes understands to interrogate nested object and array data
def get_grouping(nesting)
    grouping = []
    while matches = /#{LIST_HAS_SYNONYM}/.match(nesting)
        nesting = nesting[matches.end(0), nesting.length]
        if matches[2].nil? then
            level = {
                type: 'single',
                key: matches[3],
                root: false
            }
        else
            level = {
                type: 'multiple',
                key: matches[3],
                count: to_num(matches[2]),
                root: false,
                count_mod: to_compare(matches[1])
            }
        end
        grouping.push(level)
    end
    return grouping.reverse
end

# top level has 2 children with an item containing at most three fish with attributes:
#
# nesting = [{key=fish,count=3,count_mod='<=',type=multiple},{key=item,type=single},{key=children,type=multiple,count=2,count_mod='='},{root=true,type=single}]
#
# returns true if the expected data is contained within the data based on the nesting information
def nest_match_attributes(data, nesting, expected)
    return false if !data
    return data.deep_include?(expected) if nesting.size == 0

    local_nesting = nesting.dup
    level = local_nesting.pop
    case level[:type]
    when 'single' then
        child_data = level[:root] ? data.dup : data[get_field(level[:key])]
        return nest_match_attributes(child_data, local_nesting, expected)
    when 'multiple' then
        child_data = level[:root] ? data.dup : data[get_field(level[:key])]
        matched = child_data.select { |item| nest_match_attributes(item, local_nesting, expected) }
        return num_compare(level[:count_mod], matched.count, level[:count])
    when 'list' then
        child_data = level[:root] ? data.dup : data[get_resource(level[:key])]
        return false if !child_data.is_a?(Array)
        if level.has_key?(:count) then
            return num_compare(level[:count_mod], child_data.count, level[:count])
        end
        return true
    else
        raise %/Unknown nested data type: #{level[:type]}/
    end
end

def nest_match_value(data, nesting, expected)
    return false if !data
    return data.include?(expected) if nesting.size == 0

    local_nesting = nesting.dup
    level = local_nesting.pop
    case level[:type]
    when 'single' then
        child_data = level[:root] ? data.dup : data[get_field(level[:key])]
        return nest_match_value(child_data, local_nesting, expected)
    when 'multiple' then
        child_data = level[:root] ? data.dup : data[get_field(level[:key])]
        raise %/Key not found: #{level[:key]} as #{get_field(level[:key])} in #{data}/ if !child_data
        matched = child_data.select { |item| nest_match_value(item, local_nesting, expected) }
        return num_compare(level[:count_mod], matched.count, level[:count])
    when 'list' then
        child_data = level[:root] ? data.dup : data[get_resource(level[:key])]
        return false if !child_data.is_a?(Array)
        if level.has_key?(:count) then
            return num_compare(level[:count_mod], child_data.count, level[:count])
        end
        return true
    else
        raise %/Unknown nested data type: #{level[:type]}/
    end
end

require 'cucumber-rest-bdd/steps/resource'
require 'cucumber-rest-bdd/types'
require 'cucumber-rest-bdd/list'
require 'cucumber-rest-bdd/data'

Then("print the response") do
    puts %/The response:\n#{@response.to_json_s}/
end

# response interrogation

Then("the response #{HAVE_ALTERNATION} {field_name} of type {word}") do |field, type|
    regex = case type
        when 'datetime' then /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:[+|-]\d{2}:\d{2})?$/i
        when 'guid' then /^[{(]?[0-9A-F]{8}[-]?([0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$/i
        else nil
    end

    type = 'string' if regex.nil?
    value = field.get_value(@response, type)
    field.validate_value(@response, value.to_s, Regexp.new(regex))
end

Then("the response #{HAVE_ALTERNATION} {field_name} of type {word} that matches {string}") do |field, type, regex|
    value = field.get_value(@response, type)
    field.validate_value(@response, value.to_s, Regexp.new(regex))
end

Then("the response is a list of/containing {list_has_count} {field_name}") do |list_comparison, item|
    list = @response.get_as_type get_root_data_key(), 'array'
    raise %/Expected #{list_comparison.to_string()} items in array for path '#{get_root_data_key()}', found: #{list.count}\n#{@response.to_json_s}/ if !list_comparison.compare(list.count)
end

# Responses without nesting

Then("the response #{HAVE_ALTERNATION} (the )(following )attributes:") do |attributes|
    expected = get_attributes(attributes.hashes)
    data = @response.get get_root_data_key()
    raise %/Response did not match:\n#{expected.inspect}\n#{data}/ if data.empty? || !data.deep_include?(expected)
end

Then("the response #{HAVE_ALTERNATION} (the )(following )value {string}") do |value|
    expected = value
    data = @response.get get_root_data_key()
    raise %/Response did not match: #{expected}\n#{data}/ if data.empty? || !data.include?(expected)
end

Then("{list_has_count} {field_name} #{HAVE_ALTERNATION} (the )(following )(data )attributes:") do |list_comparison, count_item, attributes|
    expected = get_attributes(attributes.hashes)
    data = @response.get get_root_data_key()
    matched = data.select { |item| !item.empty? && item.deep_include?(expected) }
    raise %/Expected #{list_comparison.to_string()} items in array that matched:\n#{expected.inspect}\n#{data}/ if !list_comparison.compare(matched.count)
end

Then("{list_has_count} {field_name} #{HAVE_ALTERNATION} (the )(following )value {string}") do |list_comparison, count_item, value|
    expected = value
    data = @response.get get_root_data_key()
    matched = data.select { |item| !item.empty? && item.include?(expected) }
    raise %/Expected #{list_comparison.to_string()} items in array that matched:\n#{expected}\n#{data}/ if !list_comparison.compare(matched.count)
end

# Responses with nesting

Then("the response {list_nesting} #{HAVE_ALTERNATION} (the )(following )attributes:") do |nesting, attributes|
    expected = get_attributes(attributes.hashes)
    nesting.push({
        root: true,
        type: 'single'
    })
    data = @response.get get_key(nesting.grouping)
    raise %/Could not find a match for: #{nesting.match}\n#{expected.inspect}\n#{@response.to_json_s}/ if data.empty? || !nest_match_attributes(data, nesting.grouping, expected, false)
end

Then("the response {list_nesting} #{HAVE_ALTERNATION} (the )(following )value {string}") do |nesting, value|
    expected = value
    nesting.push({
        root: true,
        type: 'single'
    })
    data = @response.get get_key(nesting.grouping)
    raise %/Could not find a match for: #{nesting.match}\n#{expected}\n#{@response.to_json_s}/ if data.empty? || !nest_match_attributes(data, nesting.grouping, expected, true)
end

Then("the response {list_nesting}") do |nesting|
    nesting.push({
        root: true,
        type: 'single'
    })
    data = @response.get get_key(nesting.grouping)
    raise %/Could not find a match for: #{nesting.match}\n#{@response.to_json_s}/ if data.empty? || !nest_match_attributes(data, nesting.grouping, {}, false)
end

Then("{list_has_count} {field_name} {list_nesting} #{HAVE_ALTERNATION} (the )(following )(data )attributes:") do |list_comparison, count_item, nesting, attributes|
    expected = get_attributes(attributes.hashes)
    nesting.push({
        root: true,
        type: 'multiple',
        comparison: list_comparison
    })
    data = @response.get get_key(nesting.grouping)
    raise %/Expected #{list_comparison.to_string()} items in array with attributes for: #{nesting.match}\n#{expected.inspect}\n#{@response.to_json_s}/ if !nest_match_attributes(data, nesting.grouping, expected, false)
end

Then("{list_has_count} {field_name} {list_nesting}") do |list_comparison, item, nesting|
    nesting.push({
        root: true,
        type: 'multiple',
        comparison: list_comparison
    })
    data = @response.get get_key(nesting.grouping)
    raise %/Expected #{list_comparison.to_string()} items in array with: #{nesting.match}\n#{@response.to_json_s}/ if !nest_match_attributes(data, nesting.grouping, {}, false)
end

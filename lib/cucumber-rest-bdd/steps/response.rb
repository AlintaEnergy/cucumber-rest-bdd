require 'cucumber-rest-bdd/steps/resource'
require 'cucumber-rest-bdd/types'
require 'cucumber-rest-bdd/list'
require 'cucumber-rest-bdd/data'

Then("print the response") do
    puts %/The response:\n#{@response.to_json_s}/
end

# SIMPLE VALUE RESPONSE

# response is a string with the specified value
Then("the response #{HAVE_ALTERNATION} (the )(following )value {string}") do |value|
    expected = value
    data = @response.get get_root_data_key()
    raise %/Response did not match: #{expected}\n#{data}/ if data.empty? || !data.include?(expected)
end

# OBJECT RESPONSE

# response is an object with a field that is validated by a pre-defined regex
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

# response is an object with a field that is validated by a custom regex
Then("the response #{HAVE_ALTERNATION} {field_name} of type {word} that matches {string}") do |field, type, regex|
    value = field.get_value(@response, type)
    field.validate_value(@response, value.to_s, Regexp.new(regex))
end

# response is an object with specific attributes having defined values
Then("the response #{HAVE_ALTERNATION} (the )(following )attributes:") do |attributes|
    expected = get_attributes(attributes.hashes)
    data = @response.get get_root_data_key()
    raise %/Response did not match:\n#{expected.inspect}\n#{data}/ if data.empty? || !data.deep_include?(expected)
end

# ARRAY RESPONSE

# response is an array of objects
Then("the response is a list of/containing {list_has_count} {field_name}") do |list_comparison, item|
    list = @response.get_as_type get_root_data_key(), 'array'
    raise %/Expected #{list_comparison.to_string()} items in array for path '#{get_root_data_key()}', found: #{list.count}\n#{@response.to_json_s}/ if !list_comparison.compare(list.count)
end

# response is an array of objects where the specified number of entries match the defined data attributes
Then("the response is a list with {list_has_count} entry/entries having/containing/with (the )(following )(data )attributes:") do |list_comparison, attributes|
    expected = get_attributes(attributes.hashes)
    data = @response.get_as_type get_root_data_key(), 'array'
    matched = data.select { |item| !item.empty? && item.deep_include?(expected) }
    raise %/Expected #{list_comparison.to_string()} items in array that matched:\n#{expected.inspect}\n#{data}/ if !list_comparison.compare(matched.count)
end

# response is an array of objects where the specified number of entries match the defined data attributes
Then("the response is a list with {list_has_count} entry/entries {list_nesting}") do |list_comparison, nesting|
    nesting.push({
        root: true,
        type: 'multiple',
        comparison: list_comparison
    })
    data = @response.get get_key(nesting.grouping)
    raise %/Could not find a match for: #{nesting.match}\n#{@response.to_json_s}/ if data.empty? || !nest_match_attributes(data, nesting.grouping, {}, false)
end

# response is an array of objects where the specified number of entries match the defined data attributes
Then("the response is a list with {list_has_count} entry/entries {list_nesting} #{HAVE_ALTERNATION} (the )(following )(data )attributes:") do |list_comparison, nesting, attributes|
    expected = get_attributes(attributes.hashes)
    nesting.push({
        root: true,
        type: 'multiple',
        comparison: list_comparison
    })
    data = @response.get get_key(nesting.grouping)
    raise %/Could not find a match for: #{nesting.match}\n#{expected.inspect}\n#{@response.to_json_s}/ if data.empty? || !nest_match_attributes(data, nesting.grouping, expected, false)
end

# response is an array of objects where the specified number of entries match the defined string value
Then("the response is a list with {list_has_count} entry/entries having/containing/with (the )(following )value {string}") do |list_comparison, value|
    expected = value
    data = @response.get_as_type get_root_data_key(), 'array'
    matched = data.select { |item| !item.empty? && item.include?(expected) }
    raise %/Expected #{list_comparison.to_string()} items in array that matched:\n#{expected}\n#{data}/ if !list_comparison.compare(matched.count)
end

# response is an array of objects where the specified number of entries match the defined string value
Then("the response is a list with {list_has_count} entry/entries {list_nesting} #{HAVE_ALTERNATION} (the )(following )value {string}") do |list_comparison, nesting, value|
    expected = value
    nesting.push({
        root: true,
        type: 'multiple',
        comparison: list_comparison
    })
    data = @response.get get_key(nesting.grouping)
    raise %/Could not find a match for: #{nesting.match}\n#{expected}\n#{@response.to_json_s}/ if data.empty? || !nest_match_attributes(data, nesting.grouping, expected, true)
end

# HIERARCHICAL RESPONSE

# response has the specified hierarchy of objects / lists where the specified number of leaf items match the defined data attributes
Then("the response {list_nesting} #{HAVE_ALTERNATION} (the )(following )attributes:") do |nesting, attributes|
    expected = get_attributes(attributes.hashes)
    nesting.push({
        root: true,
        type: 'single'
    })
    data = @response.get get_key(nesting.grouping)
    raise %/Could not find a match for: #{nesting.match}\n#{expected.inspect}\n#{@response.to_json_s}/ if data.empty? || !nest_match_attributes(data, nesting.grouping, expected, false)
end

# response has the specified hierarchy of objects / lists where the specified number of leaf items match the defined string value
Then("the response {list_nesting} #{HAVE_ALTERNATION} (the )(following )value {string}") do |nesting, value|
    expected = value
    nesting.push({
        root: true,
        type: 'single'
    })
    data = @response.get get_key(nesting.grouping)
    raise %/Could not find a match for: #{nesting.match}\n#{expected}\n#{@response.to_json_s}/ if data.empty? || !nest_match_attributes(data, nesting.grouping, expected, true)
end

# response has the specified hierarchy of objects / lists where the specified number of leaf items is as expected only (no data checked)
Then("the response {list_nesting}") do |nesting|
    nesting.push({
        root: true,
        type: 'single'
    })
    data = @response.get get_key(nesting.grouping)
    raise %/Could not find a match for: #{nesting.match}\n#{@response.to_json_s}/ if data.empty? || !nest_match_attributes(data, nesting.grouping, {}, false)
end

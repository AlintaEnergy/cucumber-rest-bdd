require 'cucumber-api/response'
require 'cucumber-api/steps'
require 'active_support/inflector'
require 'cucumber-rest-bdd/url'
require 'cucumber-rest-bdd/types'
require 'cucumber-rest-bdd/level'
require 'cucumber-rest-bdd/hash'
require 'easy_diff'

GET_TYPES = %{(?:an?(?! list)|the)}%
WITH_ID = %{(?: with (?:key|id))? "([^"]*)"}%

Given(/^I am a client$/) do
    steps %Q{
      Given I send "application/json" and accept JSON
    }
end

Given(/^I am issuing requests for #{RESOURCE_NAME_CAPTURE}$/) do |resource|
    @urlbasepath = get_resource(resource)
end

# GET

When(/^I request #{GET_TYPES} #{RESOURCE_NAME_CAPTURE}#{WITH_ID}#{LEVELS}$/) do |resource, id, levels|
    resource_name = get_resource(resource)
    url = get_url("#{Level.new(levels).url}#{resource_name}/#{id}")
    steps %Q{When I send a GET request to "#{url}"}
end

When(/^I request #{GET_TYPES} #{RESOURCE_NAME_CAPTURE}#{WITH_ID}#{LEVELS} with:$/) do |resource, id, levels, params|
    resource_name = get_resource(resource)
    url = get_url("#{Level.new(levels).url}#{resource_name}/#{id}")
    unless params.raw.empty?
        query = params.raw.map{|key, value| %/#{get_field(key)}=#{resolve(value)}/}.join("&")
        url = "#{url}?#{query}"
    end
    steps %Q{When I send a GET request to "#{url}"}
end

When(/^I request a list of #{RESOURCE_NAME_CAPTURE}#{LEVELS}$/) do |resource, levels|
    resource_name = get_resource(resource)
    url = get_url("#{Level.new(levels).url}#{resource_name}")
    steps %Q{When I send a GET request to "#{url}"}
end

When(/^I request a list of #{RESOURCE_NAME_CAPTURE}#{LEVELS} with:$/) do |resource, levels, params|
    resource_name = get_resource(resource)
    url = get_url("#{Level.new(levels).url}#{resource_name}")
    unless params.raw.empty?
        query = params.raw.map{|key, value| %/#{get_field(key)}=#{resolve(value)}/}.join("&")
        url = "#{url}?#{query}"
    end
    steps %Q{When I send a GET request to "#{url}"}
end

# DELETE

When(/^I request to (?:delete|remove) #{ARTICLE} #{RESOURCE_NAME_CAPTURE}#{WITH_ID}#{LEVELS}$/) do |resource, id, levels|
    resource_name = get_resource(resource)
    url = get_url("#{Level.new(levels).url}#{resource_name}/#{id}")
    steps %Q{When I send a DELETE request to "#{url}"}
end

# POST

When(/^I request to create #{ARTICLE} #{RESOURCE_NAME_CAPTURE}#{LEVELS}$/) do |resource, levels|
    resource_name = get_resource(resource)
    level = Level.new(levels)
    if ENV['set_parent_id'] == 'true'
        json = MultiJson.dump(level.last_hash)
        steps %Q{
            When I set JSON request body to:
            """
            #{json}
            """
        }
    end
    url = get_url("#{level.url}#{resource_name}")
    steps %Q{When I send a POST request to "#{url}"}
end

When(/^I request to create #{ARTICLE} #{RESOURCE_NAME_CAPTURE}#{LEVELS} with:$/) do |resource, levels, params|
    resource_name = get_resource(resource)
    request_hash = get_attributes(params.hashes)
    level = Level.new(levels)
    request_hash = request_hash.merge(level.last_hash) if ENV['set_parent_id'] == 'true'
    json = MultiJson.dump(request_hash)
    url = get_url("#{level.url}#{resource_name}")
    steps %Q{
        When I set JSON request body to:
            """
            #{json}
            """
        And I send a POST request to "#{url}"
    }
end

# PUT

When(/^I request to (?:create|replace|set) #{ARTICLE} #{RESOURCE_NAME_CAPTURE}#{WITH_ID}#{LEVELS}$/) do |resource, id, levels|
    resource_name = get_resource(resource)
    level = Level.new(levels)
    if ENV['set_parent_id'] == 'true'
        json = MultiJson.dump(level.last_hash)
        steps %Q{
            When I set JSON request body to:
            """
            #{json}
            """
        }
    end
    url = get_url("#{level.url}#{resource_name}/#{id}")
    steps %Q{
        When I send a PUT request to "#{url}"
    }
end

When(/^I request to (?:create|replace|set) #{ARTICLE} #{RESOURCE_NAME_CAPTURE}#{WITH_ID}#{LEVELS} (?:with|to):$/) do |resource, id, levels, params|
    resource_name = get_resource(resource)
    request_hash = get_attributes(params.hashes)
    level = Level.new(levels)
    request_hash = request_hash.merge(level.last_hash) if ENV['set_parent_id'] == 'true'
    json = MultiJson.dump(request_hash)
    url = get_url("#{level.url}#{resource_name}/#{id}")
    steps %Q{
        When I set JSON request body to:
            """
            #{json}
            """
        And I send a PUT request to "#{url}"
    }
end

# PATCH

When(/^I request to modify #{ARTICLE} #{RESOURCE_NAME_CAPTURE}#{WITH_ID}#{LEVELS} with:$/) do |resource, id, levels, params|
    resource_name = get_resource(resource)
    request_hash = get_attributes(params.hashes)
    json = MultiJson.dump(request_hash)
    url = get_url("#{Level.new(levels).url}#{resource_name}/#{id}")
    steps %Q{
        When I set JSON request body to:
            """
            #{json}
            """
        And I send a PATCH request to "#{url}"
    }
end

# value capture

When(/^I save (?:attribute )?"([^"]+)"$/) do |attribute|
    steps %Q{When I grab "#{get_json_path(attribute)}" as "#{attribute}"}
end

When(/^I save (?:attribute )?"([^"]+)" to "([^"]+)"$/) do |attribute, ref|
    steps %Q{When I grab "#{get_json_path(attribute)}" as "#{ref}"}
end

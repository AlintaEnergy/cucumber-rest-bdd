Given("I retrieve the API Management subscription key secret {string} from Azure Storage Vault {string} using tenant {string} with credentials {string} and {string}") do |secret_name, vault_name, tenant_id, client_id, client_secret|
    if @apim_subscription_key.to_s.empty?
        steps %Q{
            Given I retrieve the secret "#{secret_name}" from Azure Storage Vault "#{vault_name}" using tenant "#{tenant_id}" with credentials "#{client_id}" and "#{client_secret}"
        }
        @apim_subscription_key = @response.get_as_type "$..value", "string"
    end
end

Given("I add the API Management key header") do
    steps %Q{
        And I add Headers:
        | Ocp-Apim-Subscription-Key | #{@apim_subscription_key} |
    }
end

Given("I retrieve the secret {string} from Azure Storage Vault {string} using tenant {string} with credentials {string} and {string}") do |secret_name, vault_name, tenant_id, client_id, client_secret|
    steps %Q{
        Given I authenticate with Azure tenant "#{tenant_id}" using client credentials "#{client_id}" and "#{client_secret}"
    }
    access_token = @response.get_as_type "$..access_token", "string"
    steps %Q{
        Given I retrieve the secret "#{secret_name}" from Azure Storage Vault "#{vault_name}" using access token "#{access_token}"
    }
end

Given("I authenticate with Azure tenant {string} using client credentials {string} and {string}") do |tenant_id, client_id, client_secret|
    steps %Q{
        Given I authenticate with "https://login.windows.net/#{tenant_id}/oauth2/token" using client credentials "#{client_id}" and "#{client_secret}"
    }
end

Given("I authenticate with {string} using client credentials {string} and {string}") do |url, client_id, client_secret|
    steps %Q{
        Given I send "www-x-form-urlencoded" and accept JSON
        When I set form request body to:
        | grant_type    | client_credentials      |
        | client_id     | #{client_id}            |
        | client_secret | #{client_secret}        |
        | resource      | https://vault.azure.net |
        And I send a POST request to "#{url}"
        Then the request was successful
    }
end

Given("I retrieve the secret {string} from Azure Storage Vault {string} using access token {string}") do |secret_name, vault_name, access_token|
    api_version = '2015-06-01'
    url = "https://#{vault_name}.vault.azure.net/secrets/#{secret_name}?api-version=#{api_version}"
    steps %Q{
        Given I send and accept JSON
        And I add Headers:
        | Authorization | Bearer #{access_token} |
        When I send a GET request to "#{url}"
        Then the request was successful
    }
end
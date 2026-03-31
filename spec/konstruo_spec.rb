# typed: false
# frozen_string_literal: true

require 'konstruo/mapper'

class Address < Konstruo::Mapper
  field :street, String, required: true, error_message: 'Street is required.'
  field :city, String, required: true
end

class Person < Konstruo::Mapper
  field :name, String, required: true, error_message: 'You must provide a name.'
  field :age, Integer
  field :email, String
  field :address, Address, required: true
  field :addresses, [Address], required: true
  field :user_id, Integer, required: true, custom_name: 'userId'
  field :signup_date, Date, required: true, custom_name: 'signupDate', mapper: ->(v) { Date.parse(v) }
  field :friends, [String], required: false # Array of strings
  field :is_active, Konstruo::Boolean, required: true # Boolean field
end

RSpec.describe Konstruo do
  let(:valid_json) do
    {
      'name'       => 'John Doe',
      'age'        => 30,
      'email'      => 'john@example.com',
      'address'    => { 'street' => '123 Main St', 'city' => 'New York' },
      'addresses'  => [
        { 'street' => '123 Main St', 'city' => 'New York' },
        { 'street' => '456 Maple Ave', 'city' => 'Los Angeles' }
      ],
      'userId'     => 42,
      'signupDate' => '2023-08-31',
      'friends'    => %w[Alice Bob Charlie],
      'is_active'  => true
    }.to_json
  end

  let(:valid_hash) do
    {
      name:       'John Doe',
      age:        30,
      email:      'john@example.com',
      address:    { street: '123 Main St', city: 'New York' },
      addresses:  [{ street: '123 Main St', city: 'New York' },
        { street: '456 Maple Ave', city: 'Los Angeles' }],
      userId:     42,
      signupDate: '2023-08-31',
      friends:    %w[Alice Bob Charlie],
      is_active:  true
    }
  end

  describe '#from_json' do
    it 'parses valid json and maps to the correct object p1', :aggregate_failures do
      person = Person.from_json(valid_json)
      expect(person.name).to eq('John Doe')
      expect(person.age).to eq(30)
      expect(person.email).to eq('john@example.com')
    end

    it 'parses valid json and maps to the correct object p2', :aggregate_failures do
      person = Person.from_json(valid_json)
      expect(person.address.street).to eq('123 Main St')
      expect(person.address.city).to eq('New York')
    end

    it 'parses valid json and maps to the correct object p3', :aggregate_failures do
      person = Person.from_json(valid_json)
      expect(person.user_id).to eq(42)
      expect(person.signup_date).to eq(Date.new(2023, 8, 31))
      expect(person.friends).to eq(%w[Alice Bob Charlie])
      expect(person.is_active).to be(true)
    end
  end

  describe '#from_json with array of nested objects' do
    it 'parses an array of nested objects correctly', :aggregate_failures do
      person = Person.from_json(valid_json)
      expect(person.name).to eq('John Doe')
      expect(person.addresses.size).to eq(2)
      expect(person.addresses[0].street).to eq('123 Main St')
      expect(person.addresses[1].city).to eq('Los Angeles')
    end

    it 'raises ValidationError if an element in the array is invalid' do
      invalid_json = valid_hash.tap { |h| h[:addresses][0].tap { |x| x[:street] = nil } }.to_json

      expect { Person.from_json(invalid_json) }.to raise_error(Konstruo::ValidationError, 'addresses[0]: Street is required.')
    end
  end

  describe '#from_hash' do
    it 'parses a valid hash and maps to the correct object p1', :aggregate_failures do
      person = Person.new.from_hash(valid_hash)
      expect(person.name).to eq('John Doe')
      expect(person.age).to eq(30)
      expect(person.email).to eq('john@example.com')
    end

    it 'parses a valid hash and maps to the correct object p2', :aggregate_failures do
      person = Person.new.from_hash(valid_hash)
      expect(person.address.street).to eq('123 Main St')
      expect(person.address.city).to eq('New York')
    end

    it 'parses a valid hash and maps to the correct object p3', :aggregate_failures do
      person = Person.new.from_hash(valid_hash)
      expect(person.user_id).to eq(42)
      expect(person.signup_date).to eq(Date.new(2023, 8, 31))
      expect(person.friends).to eq(%w[Alice Bob Charlie])
      expect(person.is_active).to be(true)
    end
  end

  describe 'missing required fields' do
    it 'raises ValidationError for missing required field: name' do
      invalid_json = valid_hash.tap { |h| h.delete(:name) }.to_json
      expect { Person.from_json(invalid_json) }.to raise_error(Konstruo::ValidationError, 'You must provide a name.')
    end

    it 'raises ValidationError for missing required field: address' do
      invalid_json = valid_hash.tap { |h| h.delete(:address) }.to_json
      expect { Person.from_json(invalid_json) }.to raise_error(Konstruo::ValidationError, 'Missing required field: address')
    end

    it 'raises ValidationError for missing required boolean field: is_active' do
      invalid_json = valid_hash.tap { |h| h.delete(:is_active) }.to_json
      expect { Person.from_json(invalid_json) }.to raise_error(Konstruo::ValidationError, 'Missing required field: is_active')
    end
  end

  describe 'type validation' do
    it 'raises ValidationError when a string field is given an integer' do
      invalid_json = valid_hash.tap { |h| h[:name] = 123 }.to_json
      expect { Person.from_json(invalid_json) }.to raise_error(Konstruo::ValidationError, 'You must provide a name.')
    end

    it 'raises ValidationError when an integer field is given a string' do
      invalid_json = valid_hash.tap { |h| h[:age] = 'thirty' }.to_json
      expect { Person.from_json(invalid_json) }.to raise_error(Konstruo::ValidationError, 'Expected Integer for field: age, got String')
    end

    it 'raises ValidationError when a boolean field is given an invalid value' do
      invalid_json = valid_hash.tap { |h| h[:is_active] = 'yes' }.to_json
      expect { Person.from_json(invalid_json) }.to raise_error(Konstruo::ValidationError, 'Expected Boolean for field: is_active, got String')
    end

    it 'raises ValidationError when array contains an invalid element type' do
      invalid_json = valid_hash.tap { |h| h[:friends] = [123, 'Bob'] }.to_json
      expect { Person.from_json(invalid_json) }.to raise_error(Konstruo::ValidationError, 'Expected String for field: friends[0], got Integer')
    end
  end

  describe 'custom converters' do
    it 'applies the date converter for signupDate field' do
      person = Person.from_json(valid_json)
      expect(person.signup_date).to eq(Date.new(2023, 8, 31))
    end

    it 'raises an error if date conversion fails' do
      invalid_json = valid_hash.tap { |h| h[:signupDate] = 'invalid-date' }.to_json
      expect { Person.from_json(invalid_json) }.to raise_error(ArgumentError) # Date.parse will raise ArgumentError for invalid date
    end
  end

  describe 'nested objects' do
    it 'parses nested address object correctly', :aggregate_failures do
      person = Person.from_json(valid_json)
      expect(person.address).to be_a(Address)
      expect(person.address.street).to eq('123 Main St')
      expect(person.address.city).to eq('New York')
    end

    it 'raises ValidationError if nested object validation fails' do
      invalid_json = valid_hash.tap { |h| h[:address][:street] = nil }.to_json
      expect { Person.from_json(invalid_json) }.to raise_error(Konstruo::ValidationError, 'address: Street is required.')
    end
  end

  describe 'falsey and malformed inputs' do
    it 'accepts false for required boolean fields' do
      payload = valid_hash.merge(is_active: false).to_json
      person = Person.from_json(payload)

      expect(person.is_active).to be(false)
    end

    it 'raises ValidationError when root JSON is not an object' do
      expect { Person.from_json('["not", "an", "object"]') }
        .to raise_error(Konstruo::ValidationError, 'Expected JSON object at root')
    end

    it 'raises ValidationError when nested mapper field is not a hash' do
      invalid_json = valid_hash.merge(address: 'not-a-hash').to_json

      expect { Person.from_json(invalid_json) }
        .to raise_error(Konstruo::ValidationError, 'Expected Hash for field: address, got String')
    end

    it 'raises ValidationError when nested mapper array element is not a hash' do
      invalid_json = valid_hash.merge(addresses: ['bad-element']).to_json

      expect { Person.from_json(invalid_json) }
        .to raise_error(Konstruo::ValidationError, 'Expected Hash for field: addresses[0], got String')
    end
  end

  describe 'field definition validation' do
    it 'raises ArgumentError for invalid array type declarations' do
      expect do
        Class.new(Konstruo::Mapper) do
          field :invalid, [String, Integer]
        end
      end.to raise_error(ArgumentError, 'Array field type must contain exactly one class')
    end
  end

  describe 'inheritance' do
    it 'inherits parent field definitions into subclasses' do
      parent_mapper = Class.new(Konstruo::Mapper) do
        field :id, Integer, required: true
      end

      child_mapper = Class.new(parent_mapper) do
        field :name, String, required: true
      end

      model = child_mapper.from_hash({ id: 10, name: 'Jane' })
      expect(model.id).to eq(10)
      expect(model.name).to eq('Jane')
    end
  end

  describe 'strict unknown keys mode' do
    it 'raises for unknown keys when strict mode is enabled' do
      strict_person = Class.new(Konstruo::Mapper) do
        strict_unknown_keys
        field :name, String, required: true
      end

      expect { strict_person.from_hash({ name: 'Jane', extra: 'value' }) }
        .to raise_error(Konstruo::ValidationError, 'Unknown fields: extra')
    end

    it 'allows unknown keys by default' do
      loose_person = Class.new(Konstruo::Mapper) do
        field :name, String, required: true
      end

      person = loose_person.from_hash({ name: 'Jane', extra: 'value' })
      expect(person.name).to eq('Jane')
    end
  end

  describe 'nested error paths' do
    it 'prefixes nested missing-field errors with full path' do
      invalid_json = valid_hash.tap { |h| h[:address].delete(:city) }.to_json
      expect { Person.from_json(invalid_json) }.to raise_error(Konstruo::ValidationError, 'Missing required field: address.city')
    end

    it 'prefixes nested array errors with full path' do
      invalid_json = valid_hash.tap { |h| h[:addresses][0].delete(:city) }.to_json
      expect { Person.from_json(invalid_json) }.to raise_error(Konstruo::ValidationError, 'Missing required field: addresses[0].city')
    end
  end
end

# typed: true
# frozen_string_literal: true

require_relative 'test_helper'

class KonstruoTest < Minitest::Test
  def valid_hash
    {
      name:       'John Doe',
      age:        30,
      email:      'john@example.com',
      address:    { street: '123 Main St', city: 'New York' },
      addresses:  [{ street: '123 Main St', city: 'New York' }, { street: '456 Maple Ave', city: 'Los Angeles' }],
      userId:     42,
      signupDate: '2023-08-31',
      friends:    %w[Alice Bob Charlie],
      is_active:  true
    }
  end

  def valid_json
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

  def test_from_json_parses_valid_json
    person = Person.from_json(valid_json)

    assert_equal('John Doe', person.name)
    assert_equal(30, person.age)
    assert_equal('john@example.com', person.email)
    assert_equal('123 Main St', person.address.street)
    assert_equal('New York', person.address.city)
    assert_equal(42, person.user_id)
    assert_equal(Date.new(2023, 8, 31), person.signup_date)
    assert_equal(%w[Alice Bob Charlie], person.friends)
    assert(person.is_active)
  end

  def test_from_json_parses_array_of_nested_objects
    person = Person.from_json(valid_json)

    assert_equal('John Doe', person.name)
    assert_equal(2, person.addresses.size)
    assert_equal('123 Main St', T.must(person.addresses[0]).street)
    assert_equal('Los Angeles', T.must(person.addresses[1]).city)
  end

  def test_from_json_raises_when_nested_array_element_invalid
    invalid_json = valid_hash.tap { |h| h[:addresses][0].tap { |x| x[:street] = nil } }.to_json
    error = assert_raises(Konstruo::ValidationError) { Person.from_json(invalid_json) }
    assert_equal('addresses[0]: Street is required.', error.message)
  end

  def test_from_hash_parses_valid_hash
    person = Person.from_hash(valid_hash)

    assert_equal('John Doe', person.name)
    assert_equal(30, person.age)
    assert_equal('john@example.com', person.email)
    assert_equal('123 Main St', person.address.street)
    assert_equal('New York', person.address.city)
    assert_equal(42, person.user_id)
    assert_equal(Date.new(2023, 8, 31), person.signup_date)
    assert_equal(%w[Alice Bob Charlie], person.friends)
    assert(person.is_active)
  end

  def test_missing_required_name
    invalid_json = valid_hash.tap { |h| h.delete(:name) }.to_json
    error = assert_raises(Konstruo::ValidationError) { Person.from_json(invalid_json) }
    assert_equal('You must provide a name.', error.message)
  end

  def test_missing_required_address
    invalid_json = valid_hash.tap { |h| h.delete(:address) }.to_json
    error = assert_raises(Konstruo::ValidationError) { Person.from_json(invalid_json) }
    assert_equal('Missing required field: address', error.message)
  end

  def test_missing_required_boolean
    invalid_json = valid_hash.tap { |h| h.delete(:is_active) }.to_json
    error = assert_raises(Konstruo::ValidationError) { Person.from_json(invalid_json) }
    assert_equal('Missing required field: is_active', error.message)
  end

  def test_string_field_given_integer
    invalid_json = valid_hash.tap { |h| h[:name] = 123 }.to_json
    error = assert_raises(Konstruo::ValidationError) { Person.from_json(invalid_json) }
    assert_equal('You must provide a name.', error.message)
  end

  def test_integer_field_given_string
    invalid_json = valid_hash.tap { |h| h[:age] = 'thirty' }.to_json
    error = assert_raises(Konstruo::ValidationError) { Person.from_json(invalid_json) }
    assert_equal('Expected Integer for field: age, got String', error.message)
  end

  def test_boolean_field_given_invalid_value
    invalid_json = valid_hash.tap { |h| h[:is_active] = 'yes' }.to_json
    error = assert_raises(Konstruo::ValidationError) { Person.from_json(invalid_json) }
    assert_equal('Expected Boolean for field: is_active, got String', error.message)
  end

  def test_array_contains_invalid_element_type
    invalid_json = valid_hash.tap { |h| h[:friends] = [123, 'Bob'] }.to_json
    error = assert_raises(Konstruo::ValidationError) { Person.from_json(invalid_json) }
    assert_equal('Expected String for field: friends[0], got Integer', error.message)
  end

  def test_custom_converter_applies
    person = Person.from_json(valid_json)

    assert_equal(Date.new(2023, 8, 31), person.signup_date)
  end

  def test_custom_converter_failure_bubbles_up
    invalid_json = valid_hash.tap { |h| h[:signupDate] = 'invalid-date' }.to_json
    assert_raises(ArgumentError) { Person.from_json(invalid_json) }
  end

  def test_nested_object_parses
    person = Person.from_json(valid_json)

    assert_instance_of(Address, person.address)
    assert_equal('123 Main St', person.address.street)
    assert_equal('New York', person.address.city)
  end

  def test_nested_object_validation_fails_with_prefixed_path
    invalid_json = valid_hash.tap { |h| h[:address][:street] = nil }.to_json
    error = assert_raises(Konstruo::ValidationError) { Person.from_json(invalid_json) }
    assert_equal('address: Street is required.', error.message)
  end

  def test_required_boolean_accepts_false
    payload = valid_hash.merge(is_active: false).to_json
    person = Person.from_json(payload)

    refute(person.is_active)
  end

  def test_from_json_requires_object_root
    error = assert_raises(Konstruo::ValidationError) { Person.from_json('["not", "an", "object"]') }
    assert_equal('Expected JSON object at root', error.message)
  end

  def test_nested_mapper_field_must_be_hash
    invalid_json = valid_hash.merge(address: 'not-a-hash').to_json
    error = assert_raises(Konstruo::ValidationError) { Person.from_json(invalid_json) }
    assert_equal('Expected Hash for field: address, got String', error.message)
  end

  def test_nested_mapper_array_element_must_be_hash
    invalid_json = valid_hash.merge(addresses: ['bad-element']).to_json
    error = assert_raises(Konstruo::ValidationError) { Person.from_json(invalid_json) }
    assert_equal('Expected Hash for field: addresses[0], got String', error.message)
  end

  def test_invalid_array_type_declaration_raises
    error = assert_raises(ArgumentError) do
      InvalidFieldDefinitionMapper.field(:invalid, [String, Integer])
    end
    assert_equal('Array field type must contain exactly one class', error.message)
  end

  def test_fields_are_inherited
    model = InheritanceChildMapper.from_hash({ id: 10, name: 'Jane' })

    assert_equal(10, model.id)
    assert_equal('Jane', model.name)
  end

  def test_strict_unknown_keys_enabled_raises
    error = assert_raises(Konstruo::ValidationError) { StrictPersonMapper.from_hash({ name: 'Jane', extra: 'value' }) }
    assert_equal('Unknown fields: extra', error.message)
  end

  def test_unknown_keys_allowed_by_default
    person = LoosePersonMapper.from_hash({ name: 'Jane', extra: 'value' })

    assert_equal('Jane', person.name)
  end

  def test_nested_missing_field_error_is_prefixed
    invalid_json = valid_hash.tap { |h| h[:address].delete(:city) }.to_json
    error = assert_raises(Konstruo::ValidationError) { Person.from_json(invalid_json) }
    assert_equal('Missing required field: address.city', error.message)
  end

  def test_nested_array_missing_field_error_is_prefixed
    invalid_json = valid_hash.tap { |h| h[:addresses][0].delete(:city) }.to_json
    error = assert_raises(Konstruo::ValidationError) { Person.from_json(invalid_json) }
    assert_equal('Missing required field: addresses[0].city', error.message)
  end
end

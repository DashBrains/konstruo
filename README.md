# Konstruo

Konstruo maps JSON, hashes, and Rails params into typed Ruby objects with:

- Required field validation
- Runtime type checks
- Custom key mapping (for example `userId` -> `user_id`)
- Value transformation hooks (mappers)
- Nested object support (including arrays of nested objects)
- Inherited field definitions for mapper subclasses
- Optional strict mode to reject unknown input keys

## Installation

Add to your `Gemfile`:

```ruby
gem 'konstruo'
```

Then install:

```bash
bundle install
```

Or install directly:

```bash
gem install konstruo
```

## Quick Start

```ruby
require 'konstruo'

class Address < Konstruo::Mapper
  field :street, String, required: true
  field :city, String, required: true
end

class Person < Konstruo::Mapper
  field :name, String, required: true
  field :age, Integer
  field :is_active, Konstruo::Boolean, required: true
  field :address, Address, required: true
  field :tags, [String]

  # Map external keys to ruby-style attribute names
  field :user_id, Integer, required: true, custom_name: 'userId'

  # Transform value before type validation/assignment
  field :signup_date, Date, custom_name: 'signupDate', mapper: ->(v) { Date.parse(v) }
end

json = <<~JSON
  {
    "name": "John Doe",
    "age": 30,
    "is_active": true,
    "address": { "street": "123 Main St", "city": "New York" },
    "tags": ["ruby", "rails"],
    "userId": 42,
    "signupDate": "2023-08-31"
  }
JSON

person = Person.from_json(json)
person.name         # => "John Doe"
person.user_id      # => 42
person.signup_date  # => #<Date: 2023-08-31 ...>
person.address.city # => "New York"
```

## Inheritance

Mapper fields are inherited by subclasses:

```ruby
class BasePayload < Konstruo::Mapper
  field :request_id, String, required: true, custom_name: 'requestId'
end

class CreateUserPayload < BasePayload
  field :name, String, required: true
end

payload = CreateUserPayload.from_hash(requestId: 'abc-123', name: 'Jane')
payload.request_id # => "abc-123"
payload.name       # => "Jane"
```

## Defining Fields

Field API:

```ruby
field(name, type, required: false, custom_name: nil, mapper: nil, error_message: nil)
```

Options:

- `name` (`Symbol`): Ruby attribute name.
- `type` (`Class` or `[Class]`): Expected value type.
- `required` (`Boolean`): Raises `Konstruo::ValidationError` when missing.
- `custom_name` (`String`): External key name to read from input.
- `mapper` (`Proc`): Converts raw input value before assignment.
- `error_message` (`String`): Custom validation error message.

Supported type patterns:

- Primitive/class values: `String`, `Integer`, `Date`, etc.
- Boolean: `Konstruo::Boolean`
- Nested mapper: any subclass of `Konstruo::Mapper`
- Array of primitives: `[String]`, `[Integer]`, etc.
- Array of nested mappers: `[Address]`

Array type declarations must contain exactly one element class (for example `[String]`).

## Parsing Input

Konstruo supports three entry points:

- `YourMapper.from_json(json_string)`
- `YourMapper.from_hash(hash)`
- `YourMapper.from_params(action_controller_params)`

All return an instance of your mapper class.

Notes:

- `from_hash` accepts string or symbol keys.
- `from_json` expects a JSON object at the root and raises `Konstruo::ValidationError` otherwise.

```ruby
person = Person.from_hash(
  name: 'Jane',
  is_active: true,
  address: { street: '42 Broadway', city: 'NYC' },
  userId: 7
)
```

## Validation Behavior

### Required fields

Missing required fields raise:

```ruby
Konstruo::ValidationError
```

Default message format:

```text
Missing required field: field_name
```

### Type errors

Type mismatches raise `Konstruo::ValidationError` with details like:

```text
Expected Integer for field: age, got String
Expected String for field: friends[0], got Integer
Expected Boolean for field: is_active, got String
```

`Konstruo::Boolean` only accepts real booleans (`true` or `false`).

### Nested error paths

Errors coming from nested mappers are prefixed with their full path:

```text
address: Street is required.
addresses[0]: Street is required.
Missing required field: address.city
```

### Strict unknown key mode

Enable strict mode in a mapper to reject keys that are not declared with `field`:

```ruby
class StrictPerson < Konstruo::Mapper
  strict_unknown_keys
  field :name, String, required: true
end

StrictPerson.from_hash(name: 'Jane', extra: 'value')
# => raises Konstruo::ValidationError: Unknown fields: extra
```

By default, unknown keys are ignored.  
Strict mode is inherited by subclasses.  
You can explicitly disable it with `strict_unknown_keys(false)`.

### Custom mappers

Mapper lambdas are executed as provided. If they raise (for example `Date.parse`), that error bubbles up.

### Custom error messages

`error_message:` is used for both missing required fields and type errors on that field.

## Sorbet Integration

`field` is defined dynamically at runtime, so static typing for generated accessors comes from Tapioca DSL RBIs.

Konstruo exports a Tapioca DSL compiler from the gem path `tapioca/dsl/compilers`, so consumer apps pick it up automatically when Konstruo is in the bundle.

Run:

```bash
bundle exec tapioca dsl
```

The compiler generates typed accessors for mapper fields, so you do not need to manually write repeated `sig + attr_accessor` declarations for each field.

## Rails Params Support

Use `from_params` when parsing `ActionController::Parameters`:

```ruby
def create
  person = Person.from_params(params.require(:person).permit!)
  # ...
end
```

## Development

```bash
bin/setup
bundle exec rake test
```

Useful commands:

- `bin/console` for interactive experimentation
- `bundle exec rake install` to install the gem locally
- `bundle exec rake release` to tag and publish

## Contributing

Issues and pull requests are welcome:
https://github.com/DashBrains/konstruo

## License

MIT: [LICENSE.txt](LICENSE.txt)

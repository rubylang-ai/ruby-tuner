# RubyTuner

This is a framework for ongoing development of [Rubylang.ai](https://www.rubylang.ai)'s effort to develop a fine-tuned LLM for Ruby code generation.

## Setup and Installation

### Prerequisites

**NOTICE:** RubyTuner requires Python 3.x with shared libraries enabled and the
`transformers` and `pytorch` packages installed. If a valid Python environment
is not detected, the setup process will attempt to install a suitable version
into the RubyTuner workspace (`./.ruby-tuner/bin/` by default).

### Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add ruby-tuner

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install ruby-tuner

After installation, run the setup command:

```bash
ruby-tuner setup
```

## Usage

1. Generate a feature – an outline of a problem with a specific solution in Ruby
2. Implement the feature
3. Evaluate the implementation
4. Generate training data
5. Fine-tune the model
6. Use the fine-tuned model

## Generating a Feature

To generate a Feature, use the following command:

```bash
ruby-tuner generate_feature "Your feature description"
```

This will create a directory for the feature based on the description (uses
`parameterize`) and generate the files needed to spec
out the implementation that will get fine-tuned for this feature:

```
.ruby-tuner/
└── features/
    └── your-feature-description/
            ├── feature.rb
            ├── implementation.rb
            └── test_cases.yml
```

`test_cases.yml` are optional, but they can help guide the feature's fine-tune
direction to specific styling or further desired implementation detail(s). More
details on this below.

### Optionally provide a file that contains an example implementation

```bash
ruby-tuner generate_feature "Your feature description"  --implementation path/to/implementation.rb
```

This will replace the default generated `implementation.rb` file in the generated feature folder.

### Test Cases File

To further refine the fine-tuning process and help align outputs, we provide a
mechanism for establishing test-cases for more granular tuning:

```bash
ruby-tuner generate_feature "Your feature description"  --test_cases path/to/test_cases.yml
```
The test cases file should be a YAML file containing an array of test case
objects. Each test case should have a `name`, `input`, and `expected` field.
Here's an example:

```yaml
- name: first_leaf
  input: [3, 1, 4]
  expected: [1, 3, 4]
- name: third_tier_leaf
  input: [3, 7, 4, 3, 1, 8]
  expected: [1, 3, 3, 4, 7, 8]
```

You can find a full example of a test cases file in the docs/examples/test_cases.yml file of this repository.

## Implementing a Feature

After generating a feeature, implement your solution in the `implementation.rb`
file.

## Evaluating an Implementation

RubyTuner provides an `evaluate` command to assess various evaluation criteria
for generated content and the original implementation of a feature. This command is
useful for testing the output of fine-tuned models or for comparing different
implementations.

### Usage

```bash
ruby-tuner evaluate FEATURE_ID [IMPLEMENTATION]
```

**Parameters:**

- `FEATURE_ID`: The ID of the feature to evaluate (required).
- `IMPLEMENTATION`: The implementation to evaluate (optional).

**Options:**

* `--similarity-method METHOD`: Specify the similarity method to use (`tf_idf` or `exact`; default: `tf_idf`).
* `--acceptance-score SCORE`: Set the similarity score that passes evaluation (default: `0.8`).
* `--file PATH`: Specify a file containing the implementation to evaluate.

### Examples

Evaluate an inline implementation:

```bash
ruby-tuner evaluate sort-array "def sort_array(arr); arr.sort; end"
```

Evaluate an implementation from a file:

```bash
ruby-tuner evaluate sort-array --file ./implementations/sort_array.rb
```

Evaluate an implementation from standard input:

```bash
echo "def sort_array(arr); arr.sort; end" | ruby-tuner evaluate sort-array
```

Use a different similarity method and threshold:

```
ruby-tuner evaluate sort-array --similarity-method exact --similarity-threshold 0.9 "def sort_array(arr); arr.sort; end"
```

### How it works

The evaluate command compares the provided implementation with the original
implementation stored in the feature's directory. It uses the specified
similarity method to calculate a similarity score and determines if the
implementation passes based on the similarity threshold.

This command is particularly useful for:

* Assessing the quality of generated code from fine-tuned models
* Comparing different implementations of the same feature
* Validating machine-generated code against human-written implementations

The evaluation results, including similarity scores and pass/fail status, will
be displayed in the console output.

## Generating Training Data

Comming soon...

```bash
ruby-tuner generate_training_data your-feature-description
```

## Fine-tuning a Model

Coming soon...

```bash
ruby-tuner fine_tune
```

## Using a Fine-tuned Model

Coming soon...

```bash
ruby-tuner run "a method to stream the contents of a file appended to another file"
```

## Configuration

You can configure RubyTuner by creating a .ruby-tuner/config.rb file in your project root:

```ruby
RubyTuner.configure do |config|
  config.workspace_dir = '/custom/path/to/.ruby-tuner'
  # Add more configuration options as they become available
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rubylang-ai/ruby_tuner. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/rubylang-ai/ruby_tuner/blob/main/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the RubyTuner project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/rubylang-ai/ruby_tuner/blob/main/CODE_OF_CONDUCT.md).

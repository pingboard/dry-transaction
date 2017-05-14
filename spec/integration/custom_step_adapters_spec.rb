RSpec.describe "Custom step adapters" do
  let(:transaction) {
    Class.new do
      include Dry::Transaction::Builder.new(container: Test::Container, step_adapters: Test::CustomStepAdapters)

      map :process
      tee :persist
      enqueue :deliver
    end.new
  }

  let(:container) {
    {
      process: -> input { {name: input["name"], email: input["email"]} },
      persist: -> input { Test::DB << input and true },
      deliver: -> input { "Delivered email to #{input[:email]}" },
    }
  }

  before do
    Test::DB = []
    Test::QUEUE = []

    module Test
      Container = {
        process: -> input { {name: input["name"], email: input["email"]} },
        persist: -> input { Test::DB << input and true },
        deliver: -> input { "Delivered email to #{input[:email]}" },
      }

      class CustomStepAdapters < Dry::Transaction::StepAdapters
        extend Dry::Monads::Either::Mixin

        register :enqueue, -> step, input, *args {
          Test::QUEUE << step.operation.call(input, *args)
          Right(input)
        }
      end
    end
  end

  it "supports custom step adapters" do
    input = {"name" => "Jane", "email" => "jane@doe.com"}
    transaction.call(input)
    expect(Test::QUEUE).to include("Delivered email to jane@doe.com")
  end
end

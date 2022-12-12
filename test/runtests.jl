using Test
import ChoosyDataLoggers: ChoosyDataLoggers, construct_logger, @data
import Logging: with_logger
import Random


include("example_project.jl")
import .ExampleProject: data_macro_test, data_macro_test_2, data_macro_test_3

function run_experiment(steps, seed=1)
    data, logger = construct_logger([["Exp", "log_v"], ["Test", "y"], ["Exp", "log_v_p", "test_proc"], ["Exp", "log_v_c", 10]])
    with_logger(logger) do
        for i in 1:steps
            v = i
            @data Exp log_v=v.+[1,2,3]
            @data Exp log_v_p=v.+[1,2,3]
            @data Exp log_v_c=v.+[1,2,3]
            data_macro_test(v%3)
            data_macro_test_2(v÷5)
        end
    end
    data
end

function run_experiment_idx(steps, seed=1)
    Random.seed!(seed)
    data, logger = construct_logger([(:Exp, :log_v), (:Test, :y)]; steps=steps)
    with_logger(logger) do
        for i in 1:(steps-1)
            v = rand(Int)
            @data Exp log_v=v idx=i
        end
    end
    data
end


ChoosyDataLoggers.process_data(::Val{:test_proc}, data) = sum(data)

@testset "ChoosyDataLogger.jl" begin

    run_experiment()


end

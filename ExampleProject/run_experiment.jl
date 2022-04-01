import ExampleProject: ExampleProject, data_macro_test, data_macro_test_2
import ChoosyDataLoggers: construct_logger, @data
import Logging: with_logger
import Random


function run_experiment(steps, seed=1)
    Random.seed!(seed)
    data, logger = construct_logger([(:Exp, :log_v), (:Test, :y)])
    with_logger(logger) do
        for i in 1:steps
            v = rand(Int)
            @data Exp log_v=v.+[1,2,3]
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


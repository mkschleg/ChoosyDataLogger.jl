module ExampleProject

using ChoosyDataLogger

ChoosyDataLogger.@init

function data_macro_test(x)
    ChoosyDataLogger.@data "Test" x
end


function data_macro_test_2(y)
    ChoosyDataLogger.@data "Test" y
end

function data_macro_test_3(x)
    ChoosyDataLogger.@data "Test" x
end

function __init__()
    ChoosyDataLogger.@register_data_logs
end


end # module

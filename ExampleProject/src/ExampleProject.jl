module ExampleProject

using ChoosyDataLoggers

ChoosyDataLoggers.@init

function data_macro_test(x)
    ChoosyDataLoggers.@data "Test" x
end


function data_macro_test_2(y)
    ChoosyDataLoggers.@data "Test" y
end

function data_macro_test_3(x)
    ChoosyDataLoggers.@data "Test" z
end

function __init__()
    ChoosyDataLoggers.@register
end


end # module

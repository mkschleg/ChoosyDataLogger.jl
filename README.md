# ChoosyDataLoggers


The ChoosyDataLoggers package is used to log various groups and variables in a large code base. The data can be sunk into an array sink which will populate a dictionary based on the group and variable being logged. 

Using the logging functionality is very simple, and takes advantage of julia's logging features.

```julia
data, logger = construct_logger([(:Exp, :log_v)])
with_logger(logger) do
    v = 1
    # somthing
    @data Exp log_v=v
end
```

A few caveats/extra pieces of info:
1. Each group and variable combination should only be called once in a path of an experiment/during runtime. If this isn't the case, or if you
can't guarantee this I recommend you make unique groups for each file or function depending on your use case. Variables should make sense
for the local scope, but groups can give insight into which scope you are in.
2. The `idx` keyword can be used to have support for in-place storage if you pass in a `steps` variable at logger construction. This is still wip
and not fully supported quite yet.
3. A third argument can be passed with each group and name which indicates a processing step. This processing step calls `process_data(t::Val{symbol}, data)` where symbol is the symbol passed into the constructor. This function needs to be implemented by the user.


## Automatic reporting of possible logging variables

Often code bases can get quite complicated. If you want to figure out what you can log w/o going through the entire code base ChoosyDataLoggers has support for automatic registration of uses. To use add to each **module** which uses the `@data` macro:

```julia
ChoosyDataLogger.@init
function __init__()
    ChoosyDataLogger.@register_data_logs
end
```

These functions create all the necessary components for registering the data logs for view later. You can call the function `get_data_macro_uses` and `get_raw_data_macro_uses`
to get the information. The first returns as a formatted markdown object which is still WIP, the second is the raw information stored (i.e. group, names, and source locations).






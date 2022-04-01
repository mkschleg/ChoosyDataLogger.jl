module ChoosyDataLoggers

import LoggingExtras: EarlyFilteredLogger, ActiveFilteredLogger, AbstractLogger, TeeLogger
import Logging: Logging, @logmsg, Info, handle_message, LogLevel, current_logger
import MacroTools: @capture
import Markdown: Markdown, @md_str
# import Distributed

const DataLevel = LogLevel(-93)
const SPECIAL_NAMES = [:idx]
const DataGroupsAndNames = Dict{Symbol, Dict{Symbol, Vector{LineNumberNode}}}()

const ABUSIVE_ARR_NAME = :_cdl_info_arr_1938123

function proc_exs(group_sym, source, exs, __module__)
    @nospecialize
    if group_sym ∉ keys(DataGroupsAndNames)
        DataGroupsAndNames[group_sym] = Dict{String, LineNumberNode}()
    end
    NamesDict = get!(Dict{String, Vector{LineNumberNode}}, DataGroupsAndNames, group_sym)
    
    for ex in filter((ex)->!any([startswith(string(ex), string(k)) for k in SPECIAL_NAMES]), exs)
        if @capture(ex, name_=value_)
            if name ∉ keys(NamesDict)
                NamesDict[name] = [source]
            elseif source ∉ NamesDict[name]
                push!(NamesDict[name], source)
            end
            if isdefined(__module__, ABUSIVE_ARR_NAME)
                push!(getproperty(__module__, ABUSIVE_ARR_NAME), (group_sym, name, source))
            end
        elseif @capture(ex, name_) && !contains(string(name), "=") 
            if name ∉ keys(NamesDict)
                NamesDict[name] = [source]
            elseif source ∉ NamesDict[name]
                push!(NamesDict[name], source)
            end
            if isdefined(__module__, ABUSIVE_ARR_NAME)
                push!(getproperty(__module__, ABUSIVE_ARR_NAME), (group_sym, name, source))
            end
        else
            throw("Not a valid expressions for @data")
        end
    end

end

macro data(group, exs...)
    group_str = string(group)
    proc_exs(Symbol(group_str), __source__, exs, __module__)
    group_exp = :(_group = Symbol($group_str))
    :($Logging.@logmsg($DataLevel, "DATA", $(exs...), $group_exp)) |> esc
end


macro init()
    mod = __module__
    func_name = :get_data_macro_uses
    func_name_2 = :get_raw_data_macro_uses
    arr_name = ABUSIVE_ARR_NAME
    init_func = :__init__
    quote
        const $arr_name = []
        function $func_name()
            ChoosyDataLoggers.format_data_groups_and_names(ChoosyDataLoggers.DataGroupsAndNames)
        end
        function $func_name_2()
            ChoosyDataLoggers.DataGroupsAndNames
        end
    end |> esc
end

macro register()
    mod = __module__
    quote
        if isdefined($mod, ABUSIVE_ARR_NAME)
            for (group_sym, name, source) in getproperty($mod, ABUSIVE_ARR_NAME)
                NamesDict = get!(Dict{String, Vector{LineNumberNode}}, ChoosyDataLoggers.DataGroupsAndNames, group_sym)
                if name ∉ keys(NamesDict)
                    NamesDict[name] = [source]
                elseif source ∉ NamesDict[name]
                    push!(NamesDict[name], source)
                end
            end
        end
    end
end


function format_data_groups_and_names(dnag)
    ks = keys(dnag)
    s="""
    # Data Logging Options:

    \t Groups: $(ks)
    """
    s *= "\n\n"
    for grp in ks
        s *= "\t" * string(grp) * ":\n"
        logs = dnag[grp]
        for l in keys(logs)
            s *= "\t\t" * string(l) * ": $(length(logs[l]))\n"
            for ln in logs[l]
                s *= "\t\t- " * relpath(string(ln.file)) * ":$(ln.line)\n"
            end
        end
    end

    Markdown.parse(s)
end

#=
Data Loging Sinks
=#
"""
    construct_logger

Create a logger which tee's the current logger (filtering out data logs).

Arguments:
- `groups_names_and_procs::Vector` where each element is a valid argument 
    for a datalogger.
- `kwargs...`: these are passed to the data loggers.


"""
function construct_logger(groups_names_and_procs; kwargs...)
    res = Dict{Symbol, Dict{Symbol, AbstractArray}}()
    logger = TeeLogger(
        NotDataFilter(current_logger()),
        (DataLogger(gn, res; kwargs...) for gn in groups_names_and_procs)...
    )
    res, logger
end

"""
    NotDataFilter

A convenience constructor for baring data logs going through the
other logging frameworks. Maybe could remove this now that the data
logger is very low priority?
"""
NotDataFilter(logger) = EarlyFilteredLogger(logger) do log_args
    log_args.level != DataLevel
end

"""
    DataLogger(args...; kwargs...)
    DataLogger(group::Symbol, args...; kwargs...)
    DataLogger((group, name)::Tuple{Symbol, Symbol}, args...; kwargs...)
    DataLogger((group, name, proc)::Tuple{Symbol, Symbol, Symbol}, args...; kwargs...)

Convenience Functions for making data loggers using array loggers.
"""
DataLogger(args...; kwargs...) = EarlyFilteredLogger(ArrayLogger(args...; kwargs...)) do log_args
    log_args.level == DataLevel
end

DataLogger(group::Symbol, args...; kwargs...) = EarlyFilteredLogger(ArrayLogger(args...; kwargs...)) do log_args
    log_args.level == DataLevel && log_args.group == group
end

DataLogger((group, name)::Tuple{Symbol, Symbol}, args...; kwargs...) = EarlyFilteredLogger(
    ActiveFilteredLogger(ArrayLogger(args...; kwargs...)) do log
        name ∈ keys(log.kwargs)
    end) do log_args
        log_args.level == DataLevel && log_args.group == group
    end

DataLogger((group, name, proc)::Tuple{Symbol, Symbol, Symbol}, args...; kwargs...) = EarlyFilteredLogger(
    ActiveFilteredLogger(ArrayLogger(args...; proc=proc, kwargs...)) do log
        name ∈ keys(log.kwargs)
    end) do log_args
        log_args.level == DataLevel && log_args.group == group
    end

"""
    DataLogger(group::String, args...; kwargs...)
    DataLogger(gnp::Vector{<:AbstractString}, args...; kwargs...)
    DataLogger(gnp::Union{Tuple{String}, Tuple{String, String}, Tuple{String, String, String}}, args...; kwargs...)

Convencience for string arguments.
"""
DataLogger(group::String, args...; kwargs...) = DataLogger(Symbol(group), args...; kwargs...)

function DataLogger(gnp::Vector{<:AbstractString}, args...; kwargs...)
    if length(gnp) == 1
        DataLogger(Symbol(gnp[1]), args...; kwargs...)
    elseif length(gnp) == 2
        DataLogger((Symbol(gnp[1]), Symbol(gnp[2])), args...; kwargs...)
    elseif length(gnp) == 3
        DataLogger((Symbol(gnp[1]), Symbol(gnp[2]), Symbol(gnp[3])), args...; kwargs...)
    else
        @error "Logging extras can only have up-to 3 arguments"
    end
end

DataLogger(gnp::Union{Tuple{String}, Tuple{String, String}, Tuple{String, String, String}}, args...; kwargs...) =
    DataLogger(Symbol.(gnp), args...; kwargs...)

"""
    ArrayLogger

This is a data sink logger which stores information into an array. 
They are meant to only be used in conjuction with the above DataLogger functions,
but could likely be used more generally. 

Currently you should only be using the DataLogger constructors to take advantage of 
the choosy data logging platform.
"""
struct ArrayLogger{V<:Union{Val, Nothing}} <: AbstractLogger
    data::Dict{Symbol, Dict{Symbol, AbstractArray}}
    n::Union{Int, Nothing}
    proc::V
end

ArrayLogger(data; proc=nothing, steps=nothing) = ArrayLogger(data, steps, isnothing(proc) ? nothing : Val(proc))

function Logging.handle_message(logger::ArrayLogger, level, message, _module, group, id, file, line; kwargs...)
    group_strg = get!(logger.data, group, Dict{Symbol, AbstractArray}())
    for (k, v) in filter((kv)->kv.first!=:idx, kwargs)
        data_strg = get!(group_strg, k) do
            if :idx ∈ keys(kwargs)
                create_new_strg(logger.proc, v, logger.n)
            else
                create_new_strg(logger.proc, v, nothing)
            end
        end
        
        if isnothing(logger.n) || :idx ∉ keys(kwargs)
            insert_data_strg!(logger.proc, data_strg, v, nothing)
        else
            insert_data_strg!(logger.proc, data_strg, v, kwargs[:idx])
        end
    end
end

Logging.min_enabled_level(::ArrayLogger) = DataLevel#LogLevel(-93)
Logging.shouldlog(::ArrayLogger, ::Base.CoreLogging.LogLevel, args...) = true
Logging.catch_exceptions(::ArrayLogger) = false

create_new_strg(data::T, n::Nothing) where T = T[]
create_new_strg(data::AbstractArray{<:Number}, n::Int) = zeros(eltype(data), size(data)..., n) # create matrix to store all the data
create_new_strg(data::AbstractArray, n::Int) = begin
    Array{eltype{data}}(undef, size(data)..., n)
end

create_new_strg(data::Number, n::Int) = zeros(typeof(data), n)
create_new_strg(data, n::Int) = Vector{eltype{data}}(undef, n)

insert_data_strg!(strg::AbstractVector, data, ::Nothing) = push!(strg, data)

insert_data_strg!(strg::AbstractVector, data, idx::Int) = if length(strg) < idx
    push!(strg, data)
else
    strg[idx] = data
end

insert_data_strg!(strg::AbstractArray, data, idx::Int) = strg[.., idx] .= data

# processing data while logging

create_new_strg(t::Union{Val, Nothing}, data, n) = create_new_strg(process_data(t, data), n)
insert_data_strg!(t::Union{Val, Nothing}, strg, data, idx) = insert_data_strg!(strg, process_data(t, data), idx)

process_data(t::Nothing, data) = data

end

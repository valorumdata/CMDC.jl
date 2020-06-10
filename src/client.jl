"""

Example:

```julia
c = Client()

request!(
    c, 
    covid(),
    economics(state="CA")
)

df = fetch(c)
```
"""
@with_kw struct Client
    apikey::Union{Missing,String} = missing
    current_request::Dict{Symbol,Endpoint} = Dict()
end

reset!(c::Client) = empty!(c.current_request)

function Base.show(io::IO, ::MIME"text/plain", c::Client)
    print(io, "CMDC Client")
    length(c.current_request) > 0 && println(io, ". Current request:")
    for (k, v) in c.current_request
        print(io, " - ")
        show(io, MIME"text/plain"(), v)
    end
end

"""
Add one or more endpoints to the current request
"""
function request!(c::Client, eps::Endpoint...)
    for ep in eps
        c.current_request[path(ep)] = ep
    end
    c
end

"Combine all filters"
function combine_filters(c::Client)
    common = Dict{Symbol,Any}()
    out = Dict{Symbol,Dict{Symbol,Any}}()
    for (name, ep) in c.current_request
        out[name] = Dict()
        for (filt, val) in applied_filters(ep)
            if filt === :variable
                out[name][filt] = val
                continue
            end
            
            if haskey(common, filt)
                curr = common[filt]
                if curr != val
                    error("Found two values for filter $filt: $cur and $val")
                end
            else
                common[filt] = val
            end
        end 
    end
    
    for (name, ep) in c.current_request, (filt, val) in common
        if hasproperty(ep, filt)
            if filt == :state
                if hasproperty(ep, :fips)
                    out[name][:fips] = _handle_state(val)
                    continue
                end
            end
            out[name][filt] = val
        end
    end
    
    out
end

create_filter_rhs(x::Any) = "eq.$(x)"
create_filter_rhs(x::Union{Tuple,AbstractArray,Set}) = "in.($(join(x, ',')))"
function create_filter_rhs(x::String)
    for (op, txt) in [">" => "gt", "<" => "lt", "!=" => "neq"]
        if occursin(op, x)
            op_eq = "$(op)="
            if occursin(op_eq, x)
                return replace(x, op_eq => string(txt, "e."))
            end
            return replace(x, op => string(txt, "."))
        end
    end
    return "eq.$(x)"
end


"Create POSTgrest query arg string based on filter value"
create_filter_rhs

"Transform from wide to long"
function _reshape_df(df::DataFrames.DataFrame)
    size(df, 1) == 0 && return df
    
    cols = names(df)
    for c in ["variable", "value"]
        if !(c in cols)
            gh_issues = "https://github.com/valorumdata/CMDC.jl/issues/new"
            msg = "Column $c not found, please report a bug at $gh_issues"
            error(msg)
        end
    end
    
    if "meta_date" in cols
        if "variable" in cols
            df[!, :variable] = map(
                xy -> "$(xy[2])_$(xy[1])", 
                zip(df[!, :meta_date], df[!, :variable])
            )
            df = DataFrames.select(df, DataFrames.Not(:meta_date))
        end
    end
    ## this will unstack based on :variable and :value columns :)
    DataFrames.unstack(df)
end

"""
Combine longform DataFrames into a single wide DataFrame by reshaping each of the
input frames and then merging on common columns
"""
function combine_dfs(dfs::Dict{Symbol,DataFrames.DataFrame})
    # reshape
    reshaped = [_reshape_df(df) for df in values(dfs)]
    
    # then join on common columns
    out = reshaped[1]
    for right in reshaped[2:end]
        on = ∩(names(out), names(right))
        out = DataFrames.innerjoin(out, right, on=Symbol.(on))
    end
    out    
end

"Execute currently built request"
function Base.fetch(c::Client)
    filts = combine_filters(c)
    transformed_filts = Dict(
        path => Dict(
            nm => create_filter_rhs(v) for (nm, v) in p_filts
        ) for (path, p_filts) in filts
    )
    dfs = Dict(path => fetch(c, path, query=filts) for (path, filts) in transformed_filts)
    out = combine_dfs(dfs)
    reset!(c)
    out
end

"Make a single request to the API `path` using query args `query`"
function Base.fetch(c::Client, path::Union{Symbol,String}; query=Dict())
    headers = Dict(:Accept => "text/csv")
    if !ismissing(c.apikey)
        headers[:apikey] = c.apikey
    end
    res = HTTP.request("GET", _url(path, query=query), headers=headers)
    # TODO: check for error
    buf = IOBuffer(res.body)
    CSV.read(buf)
end

function _handle_state(states::AbstractVector{<:Integer})
    want = map(x -> in(x, states), CMDC._counties[][!, :state])
    return vcat(collect(_counties[][want, :fips]), states...)
end 
_handle_state(state::Integer) = _handle_state([state])

# TODO: accept string input someday...
_handle_state(state::String) = _handle_state(parse(Int, state))
_handle_state(states::AbstractVector{String}) = _handle_state(parse.(Int, state))

"""
Helper function to allow users to request states (including all counties)

This function consumes a FIPS code for one or more states and returns
the FIPS codes for all counties in the passed states
"""

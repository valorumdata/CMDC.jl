_keyfile() = joinpath(homedir(), ".cmdc", "apikey")

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
    current_request::Dict{Symbol,Endpoint} = Dict{Symbol,Endpoint}()

    function Client(::Missing, current_request::Dict{Symbol,Endpoint})
        # try to look up api key, b/c we didn't get one
        keyfile = _keyfile()
        if isfile(keyfile)
            return new(String(open(read, keyfile, "r")), current_request)
        end
        new(missing, current_request)
    end
    Client(apikey::String, current_request::Dict{Symbol,Endpoint}) = new(apikey, current_request)
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

function _savekey(key::String)
    !(isdir(dirname(_keyfile()))) && mkdir(dirname(_keyfile()))
    open(f -> print(f, key), _keyfile(), "w")
    msg = string(
        "The API key has been reqeusted and will be used on all ",
        "future requests unless another key is given when creating a Client."
    )
    println(msg)
end


function register(c::Client, email::Union{Missing,String}=missing)
    if isfile(_keyfile())
        msg = "An API key already exists at $(_keyfile())."
        print(msg)
        while true
            print("\nWould you like to delete the existing key (y/n)? ")
            ans = readline(stdin)
            if lowercase(strip(ans))[1] == 'n'
                println("Existing key will be used, no need to register")
                return String(open(read, _keyfile(), "r"))
            end
            if lowercase(strip(ans))[1] == 'y'
                rm(_keyfile())
                break
            end
            println("Answer not understood, please try again")
        end
    end

    if ismissing(email)
        msg = "Please provide an email address to request a free API key: "
        print(msg)
        email = readline(stdin)
        if !(occursin(r"^[^@]+@[^@]+\.[^@]+$", email))
            msg = string(
                "We received $email, which doesn't look like an email address. ",
                "Please provide a valid email address"
            )
            error(msg)
        end
    end
    res = HTTP.request(
        "POST",
        _url("auth"),
        ["Content-Type" => "application/json"],
            JSON.json((email=email,)),
            status_exception=false,
    )
    @show res.status
    if res.status == 409
        # already exists
        res2 = HTTP.request("GET", _url("auth/$(email)"))
        @show res2
        if res2.status != 200
            msg = string(
                "Email address already in use. Failed to fetch existing key. ",
                "Message from server was $(String(res.body))"
            )
            error(msg)
        end
        key = JSON.parse(String(res2.body))["key"]
        _savekey(key)
        return Client(apikey=key)
    elseif res.status > 300
        msg = "Error requesting API key. Message from server: $(String(res.body))"
        error(msg)
    end
    # otherwise get the key, save to file, and return
    key = JSON.parse(String(res.body))["key"]
    _savekey(key)
    return Client(apikey=key)
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
                if hasproperty(ep, :location)
                    out[name][:location] = _handle_state(val)
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

    cols = map(String, names(df))
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
    res = HTTP.request("GET", _url(path), headers=headers, query=query)
    # TODO: check for error
    buf = IOBuffer(res.body)
    CSV.read(buf)
end

function _handle_state(states::AbstractVector{<:Integer})
    want = map(x -> in(x, states), CMDC._counties[][!, :state])
    return vcat(collect(_counties[][want, :location]), states...)
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

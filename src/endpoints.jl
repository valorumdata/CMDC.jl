abstract type Endpoint end

path(e::Union{Type{T},T}) where T <: Endpoint =  Symbol(split(repr(T), '.')[end])
Base.hasproperty(::Type{T}, x::Symbol) where T <: Endpoint = hasproperty(T(), x)

function Base.show(io::IO, ::MIME"text/plain", e::T) where T <: Endpoint
    println(io, path(e))
    for (nm, prop) in applied_filters(e)
        println(io, "  - $nm: $prop")
    end
end

function applied_filters(ep::Endpoint)::Dict{Symbol,Any}
    out = Dict{Symbol,Any}()
    for nm in propertynames(ep)
        prop = getproperty(ep, nm)
        ismissing(prop) && continue
        out[nm] = prop
    end
    out
end

## Metaprogramming stuff
function get_endpoint_params(fn::Symbol, sw::Dict)
    thekey = "\$ref"
    prefix = "#/parameters/"
    params = sw["paths"]["/$(fn)"]["get"]["parameters"]
    specs = Dict[]

    for param in params
        length(param) != 1 && continue
        haskey(param, thekey) || continue

        pname = param[thekey]
        startswith(pname, prefix) || continue

        param_spec = sw["parameters"][replace(pname, prefix => "")]
        param_spec["in"] === "query" && push!(specs, param_spec)
    end
    specs
end


function make_endpoint(fn::Symbol, sw::Dict)
    specs = get_endpoint_params(fn, sw)
    fields = Expr[]
    for spec in specs
        param_sym = Symbol(spec["name"])
        push!(fields, Expr(:(=), param_sym, :missing))
        param_sym == :location && push!(fields, Expr(:(=), :state, :missing))
    end
    out = :(
        @with_kw struct $(fn) <: Endpoint
        end
    )
    out.args[3].args[3] = Expr(:block, fields...)
    out
end

function make_endpoint_docs(fn::Symbol, sw::Dict, )
    desc = get(sw["paths"][string("/", fn)]["get"], "description", missing)
    docs = IOBuffer()
    println(docs, "CMDC endpoint $fn\n")
    if !ismissing(desc)
        println(docs, desc)
        println(docs, "")
    end

    filters = [x["name"] for x in get_endpoint_params(fn, sw)]
    print(docs, "Available filters are: ")
    join(docs, filters, ", ", " and ")
    println(docs, "\n\nSet any filter as keyword argument to $(fn)() function")
    String(take!(docs))
end

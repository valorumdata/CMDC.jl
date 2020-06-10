module CMDC

import HTTP, JSON, CSV, DataFrames
using Parameters: @with_kw

# other functions/types are exported from __init__()
export Client, request!, reset!, register

const BASE_URL = "https://api.covid.valorum.ai"
_url(x::Union{Symbol,String}) = string(BASE_URL, "/", x)
const _counties = Ref(DataFrames.DataFrame())

include("endpoints.jl")
include("client.jl")


# On import, dynamically create types for each API endpoint
# Also extract a list of counties to use when filtering on state
function __init__()
    res = HTTP.request("GET", _url("swagger.json"))
    sw = JSON.parse(String(res.body))
    datasets = Symbol[]
    
    # define Endpoint subtypes
    for path in keys(sw["paths"])
        occursin("swagger", path) && continue
        tn = Symbol(strip(path, '/'))
        push!(datasets, tn)
        code = make_endpoint(tn, sw)
        eval(code)
        @eval export $tn
        docs = make_endpoint_docs(tn, sw)
        eval(:(@doc $docs $tn))
    end
    
    @eval datasets() = $datasets
    @eval export datasets

    # fetch list of counties for later
    _counties[] = fetch(Client(), "counties")
    _counties[][!, :state] = map(
        x-> parse(Int, lpad(x, 5, '0')[1:2]), 
        CMDC._counties[][!, :fips]
    )
    nothing
    
end

end # module

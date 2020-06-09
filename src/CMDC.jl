module CMDC

import HTTP, JSON, CSV, DataFrames
using Parameters: @with_kw

# other functions/types are exported from __init__()
export Client, request!

const BASE_URL = "https://api.covid.valorum.ai"
function _url(x::Union{Symbol,String}; query=Dict())
    if length(query) > 0
        qs = join(["$(k)=$(v)" for (k, v) in query], "&")
        string(BASE_URL, "/", x, "?", qs)
    end
    string(BASE_URL, "/", x)
end
const _counties = Ref(DataFrames.DataFrame())

include("endpoints.jl")
include("client.jl")


# On import, dynamically create types for each API endpoint
# Also extract a list of counties to use when filtering on state
function __init__()
    res = HTTP.request("GET", _url("swagger.json"))
    sw = JSON.parse(String(res.body))
    
    # define Endpoint subtypes
    for path in keys(sw["paths"])
        occursin("swagger", path) && continue
        tn = Symbol(strip(path, '/'))
        code = make_endpoint(tn, sw)
        eval(code)
        @eval export $tn
        docs = make_endpoint_docs(tn, sw)
        eval(:(@doc $docs $tn))
    end
    
    # fetch list of counties for later
    _counties[] = fetch(Client(), "counties")
    _counties[][!, :state] = map(
        x-> parse(Int, lpad(x, 5, '0')[1:2]), 
        CMDC._counties[][!, :fips]
    )
    nothing
    
end

end # module
